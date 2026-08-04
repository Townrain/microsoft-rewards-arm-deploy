# Microsoft Rewards Script — ARM64 / 弱网络环境部署修复实录

> 让 [chiihero/Microsoft-Rewards-Script](https://github.com/chiihero/Microsoft-Rewards-Script) (v3.1.6.4) 在 **ARM64 手机 VM（Podroid）**、**无 IPv6**、**弱网络**、**微软风控**环境下真正跑通的完整修复方案。
>
> 上游官方 GHCR 镜像**只有 amd64**，且 arm64 上直接跑会踩到三个"看似无解"的坑。本仓库记录了每个坑的**诊断过程、根因、修复**，并提供一键复用脚本。

---

## 🎯 我们做了什么（核心）

### 三个叠加的坑，每个都会让部署"看似失败"

#### 坑 1：设备无 IPv6 → 页面加载慢 100 倍

- **症状**：登录页 230 秒都加载不完；每个 CDN 资源（JS/CSS）耗时 12 秒
- **诊断**：`nslookup` 发现域名解析出 IPv6 地址（`2620:1ec:bdf::73`），但设备 `ping6` 直接 `Network unreachable`。Chromium 优先尝试 IPv6，等超时才回退 IPv4
- **修复**：compose 加 `sysctls` 禁用容器 IPv6
  ```yaml
  sysctls:
    - net.ipv6.conf.all.disable_ipv6=1
    - net.ipv6.conf.default.disable_ipv6=1
  ```
- **效果**：资源加载 12s → **130ms**（100 倍）

#### 坑 2：脚本检测超时 200ms 太短 → 登录永远"超时"

- **症状**：日志 25 轮状态检测全 `UNKNOWN`，最终"登录超时: 超过最大迭代次数"
- **诊断**：A/B 测试证明——即使页面 `readyState=complete`、元素 CSS 完全可见（`display:block; visibility:visible; opacity:1`），`waitForSelector(state:'visible', timeout:200)` 也要 **766–1075ms** 才能抓到元素。200ms 必然错过
- **修复**：`Login.ts` 的 `checkSelector` 超时 `200 → 5000`（一行）
  ```ts
  .waitForSelector(selector, { state: 'visible', timeout: 5000 })
  ```
- **效果**：邮箱/密码/TOTP 全部能检测到，登录流程能走完

#### 坑 3：headless + 伪造指纹被微软风控 → 登录"成功"但会话无效

- **症状**：登录流程看似全成功（TOTP 通过、KMSI 接受、日志"登录成功"），但保存的 cookie 里 `rn_S`（rewards 域 JWT 认证 token）**缺失**、`_C_Auth` 为空 → 后续 API 全 **401** → 跑完 **+0 积分**
- **诊断**：用保存的 52 个 cookie 打开 rewards.bing.com，仍是未登录页。对比 amd 环境日志：amd 是"迭代 1 直接 LOGGED_IN"（复用**已保存的有效会话**），arm 是"每次完整登录但被拦截"
- **根因**：headless Chromium + fingerprint-injector 伪造指纹 + 手机 IP 组合，被微软判定为可疑设备，登录流程走完但**不发放完整认证**（中途弹出"获取代码"验证，无 TTY 无法完成）
- **修复**：在**可信环境**（本机真实浏览器）登录一次 → 导出 41 个有效 cookie（含 `rn_S`/`__Host-MSAAUTHP`）→ 注入容器会话文件 → 重启
  ```bash
  docker cp mrs-cookies.json microsoft-rewards:/usr/src/microsoft-rewards-script/dist/browser/sessions/<邮箱>/session_mobile.json
  docker restart microsoft-rewards
  ```
- **效果**：OAuth 取码从 180s 超时 → **6 秒**，Server Action 全 200，**积分正常增长**

### 附加适配（网络环境必需）

| 适配 | 原因 | 做法 |
|---|---|---|
| npm 源切 npmmirror | registry.npmjs.org 批量下载 300+ 包会断连（`npm error network`） | `.npmrc` + 批量替换 lockfile URL |
| patchright 浏览器走镜像 | 构建时下载 109MB Chromium | Dockerfile 加 `ENV PLAYWRIGHT_DOWNLOAD_HOST=https://registry.npmmirror.com/-/binary/playwright` |
| 基础镜像走 DaoCloud | Docker Hub 不可达 | 上游 Dockerfile 已用 `m.daocloud.io/docker.io/library/node:24-slim`，无需改 |

### 附带修复：passkey 注册引导页卡死

- **症状**：登录成功后被微软引导"设置通行密钥"（`account.live.com/interrupt/passkey/enroll`），脚本不认识该页面 → 25 轮 UNKNOWN → 超时
- **修复**：检测到 passkey/fido 页面直接导航回 rewards（此时 cookie 已写入，登录已完成）——见 `patches/login.patch`

---


#### 坑 4：外部注入桌面会话 → 搜索 0 分（UA/指纹不匹配）

- **症状**：从可信浏览器（Playwright MCP）登录导出 cookies 注入 session_desktop.json 后，桌面端登录成功（LOGGED_IN）、搜索正常提交，但**计分恒为 0**；容器自签会话的实例则 51/51 正常
- **诊断**：排除 cookie 域（.msn.cn SID）、IP 绑定（MSCC 相同）后，用签发浏览器同会话搜索 +3 分 → 会话有效；容器注入签发 UA 后计分恢复 → **Bing 校验「搜索请求 UA」与「SID 签发 UA」一致**
- **根因**：容器默认用 fingerprint-injector 随机指纹 UA（Edg 系），与外部签发会话的 UA（Chrome/150 系）不一致
- **修复**：① 容器内 fingerprint-generator 生成指纹并覆盖 UA 为签发 UA → session_fingerprint_desktop.json；② entrypoint.sh 改 saveFingerprint.desktop: true（**重建容器会还原**）；③ 会话含双域 SID（登录后访问 www.msn.cn 触发 .msn.cn 域 SID）
- **验证**：桌面 UA 日志与签发 UA 一致 → 搜索 获得积分=3 points → 51/51 全拿
- 完整流程见 docs/desktop-session-fingerprint.md

#### 坑 5：Server Action 静默失败（200 但积分不涨）— rn_SID 会话 cookie

- **症状**：2026-08-02 起 CLAIM-BONUS-POINTS 每次返回 200 但余额不变（"领取奖励积分完成但无积分变化"），dashboard 大额积分（实例1 的 900 点）一直领不到；连击保护 toggle 同样疑似无效
- **诊断**：真实浏览器点击领取成功（+3 到账），但脚本手动构造的 Server Action 请求返回**完整页面流（163KB）**而非 action 结果流（46B）——action 被服务端静默忽略。逐项排除：action hash 未变（9381 chunk 中 createServerReference 确认）、next-router-state-tree 与真实请求逐字节一致、请求格式（next-action header + body []）相同。最终用浏览器 context 实时 cookie 与会话文件对比，发现关键差异：**`rn_SID`（rewards.bing.com 域会话 ID）只在打开 dashboard 页面时由服务端 set-cookie 下发**，脚本 `cookies.mobile` 是登录时快照（index.ts:488），页面拿到 rn_SID 后未同步（549 行刷新发生在 Server Action 之后）
- **根因**：微软更新 dashboard 后，Server Action 请求缺少 rn_SID 时被静默忽略（返回 200 + 完整页面流，不执行 action）
- **修复**：`callServerAction` 调用前实时从浏览器 context 刷新 mobile cookies（缺 rn_SID 时自动导航 dashboard）——见 `patches/rn-sid-fix-20260804.patch`
- **验证**：修复后响应体从 163KB 页面流 → `0:{"a":"$@1","f":"","q":"","i":false}|1:false`（action 真正执行）；连击保护 toggle 恢复

## 🧰 补丁（patches/）

- login.patch：passkey 注册引导页跳过 + checkSelector 超时 5000ms（旧）
- ixes-20260803.patch：**2026-08-03 累计修复**（基于上游 v3.1.6.4 打补丁后即得当前部署源码）：
  - OAuth 重试循环重构（break 条件精确化、removed 快速重试、MobileAccessLoginError 异常体系、轮询提前失败检测）
  - verifyBingSession（60s 轮硬截止、domcontentloaded、loopMax 3、双重验证去重）
  - 搜索时序（networkidle 等待恢复、URL 直接搜索兜底、提交后 URL 日志）
  - ghostClick 加固（悬空 rejection 吞掉、context 错误降级、25s 超时）
  - unhandledRejection 分类（Protocol error 全族仅记录不退出）
  - Login 入口保留 createuser + oauth20_desktop.srf 带 code 判定 LOGGED_IN
  - 应用：cd <repo> && git apply -p2 patches/fixes-20260803.patch
- rn-sid-fix-20260804.patch：**2026-08-04 rn_SID 修复**（callServerAction 调用前实时刷新 mobile cookies，缺 rn_SID 自动导航 dashboard；含响应体 debug 日志）
  - 应用：cd <repo> && git apply -p2 patches/rn-sid-fix-20260804.patch
## 🚀 快速开始（一条命令）

```sh
# 在 ARM64 设备上执行 (需可访问 codeload / npmmirror / m.daocloud.io)
sh deploy.sh /root/microsoft-rewards
# 编辑 .env 填入账号 → 等待构建 (40-50 分钟, arm64 tsc 慢属正常)
```

`deploy.sh` 自动完成：下载上游源码 → npmmirror 适配 → 打补丁 → 生成 compose/.env → 后台构建启动。重复执行安全（已有 `src/` 自动备份）。

---

## 📁 仓库结构

```
├── deploy.sh                 # ★ 一键部署 (下载+适配+补丁+启动)
├── docker-compose.yml        # 微调版 (IPv6 禁用 + build context=./src)
├── .env.example              # 环境变量模板 (全部脱敏)
├── patches/
│   ├── login.patch           # Login.ts 补丁 (超时 5000ms + passkey 跳过)
│   └── rn-sid-fix-20260804.patch # rn_SID 会话 cookie 修复 (08-04)
└── docs/
    ├── deploy-ops.md         # 部署/维护/备份/故障排查
    └── session-injection.md  # 会话注入流程 (风控环境关键步骤)
```

---

## 🔄 会话续期（为什么不用反复登录）

- 每次运行，脚本访问 rewards.bing.com 时微软**自动刷新**认证 cookie（`rn_SID` 滚动续期、`__Host-MSAAUTHP` 有效期 390 天）
- 运行结束脚本保存刷新后的新 cookie（注入时 41 个 → 运行后 61 个）
- **只要 cron 每天运行，会话永久有效**；唯一失效场景：容器停机 >30 天

---

## ✅ 验证结果（实际部署环境）

| 指标 | 修复前 | 修复后 |
|---|---|---|
| CDN 资源加载 | 12s/个 | 130ms |
| 登录检测 | 25 轮 UNKNOWN 超时 | 迭代 1 LOGGED_IN |
| OAuth 取码 | 180s 超时 | **6 秒** |
| Server Action | 401 | 全 200 |
| Server Action 响应 | 163KB 页面流（静默忽略） | 46B action 结果流（真正执行） |
| 积分收集 | +0 | 正常增长 |

环境：Podroid（Alpine 3.24 / aarch64 / 4 核 2GB）· Docker 29.5.3 + Compose v5.1.4 · 上游 v3.1.6.4

---

## 📜 License

基于上游 GPL-3.0-or-later 项目，本仓库同样适用 GPL-3.0。使用自动化脚本可能导致微软账号被暂停，风险自负。
