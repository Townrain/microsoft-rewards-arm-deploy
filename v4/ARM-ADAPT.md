# v4.3.2 (V4-china) ARM64 本地适配清单

基线：上游 `chiihero/Microsoft-Rewards-Script` **V4-china 分支 @ 5e8a14e**（2026-08-31，v4.3.2）
适配目标：ARM64 (Podroid, aarch64) / 无 IPv6 / 弱网络 / 微软风控环境 —— 与 v3.1.6.4 部署同环境。

---

## 一、源码改动（相对上游 v4.3.2）

| # | 文件 | 改动 | 来源 |
|---|------|------|------|
| 1 | `.npmrc`（新增） | `registry=https://registry.npmmirror.com/` | v3 部署同款（npmjs.org 批量下载断连） |
| 2 | `package-lock.json` | 176 处 `registry.npmjs.org` → `registry.npmmirror.com`（npm ci 用 lockfile resolved URL，必须替换） | v3 部署同款 |
| 3 | `Dockerfile` | builder + runtime 两段加 `ENV PLAYWRIGHT_DOWNLOAD_HOST=https://registry.npmmirror.com/-/binary/playwright`（v4 的 patchright install 在 runtime 段执行，两段都要） | v3 部署同款 |
| 4 | `src/browser/auth/Login.ts` | `verifyBingSession` 加固（见下） | 移植自 v3 `fixes-20260820-login.patch`（本环境实测有效） |

### 改动 4 细节：verifyBingSession 三处加固

1. **rewards.bing.com 直达判定**：auth 重定向落到 `rewards.bing.com/dashboard` 即证明 bing.com 会话 cookie 有效（无效会停在 login.live.com），直接返回成功，不再空转 5 轮。
2. **弹窗清理 10s 硬上限**：`tryDismissAllMessages`（ghost-cursor 模拟点击）在慢页面可能拖 200s+，包 `Promise.race` 加 10s 上限，防止验证被弹窗清理拖死。
3. **登录信号双通道**：头像 `#id_n` 可见 **或** `#id_s`（Sign in 按钮）隐藏，任一命中即判已登录；并保留上下文丢失（Cannot find context / DOM.describeNode）容错。

## 二、v4 已原生覆盖（无需移植的 v3 本地补丁）

| v3 补丁 | v4 原生替代 | 位置 |
|---------|------------|------|
| login.patch（checkSelector 200→5000ms） | ✅ 原生 `timeout: 5000` | `Login.ts:325` |
| login.patch（passkey 跳过） | ✅ `disableFido()` 请求拦截伪造 `isFidoSupported=false`，源头阻断 | `BrowserUtils.ts:229` |
| rn-sid-fix-20260804（rn_SID 刷新） | ✅ 会话存储即存即取 + 过期 cookie 自动清理 | `SessionStore.ts` |
| fixes-20260804（指纹固化） | ✅ 指纹与会话同库持久化，`fingerprintMatches` 校验 | `SessionStore.ts / Browser.ts` |
| fixes-20260829-nav-race（page.content 竞态） | ✅ v4 改用 RSC 快照（`bootstrap`/`reactSnapshot`），无 `page.content()` | `Login.ts getRewardsSession` |
| fixes-20260820-server-actions（硬编码 hash） | ✅ v4 从页面动态拉取 Next.js server-action 信息 | `ReactFunc.ts / BrowserFunc.ts reportServerAction` |
| fixes-20260803（OAuth 重试/搜索时序等） | ⚠️ v4 登录流程整体重写（EmailLogin/GetACodeLogin/PasswordlessLogin 等分模块），无法逐条对应，**试点验证** | — |

## 三、部署层适配（compose，见 `docker-compose.yml`）

- **IPv6 禁用 sysctls**（坑 1：无 IPv6 设备上 Chromium 等 IPv6 超时，资源加载慢 100 倍）
- **挂载路径 v4 化**：`./config → $SCRIPT_DIR/config`、`./sessions → $SCRIPT_DIR/sessions`（v3 是 `dist/config`、`dist/browser/sessions`）
- **键名修正**：`CONFIG_SEARCH_QUERY_ENGINES`（v3 compose 里的 `CONFIG_QUERY_ENGINES` 对 v4 无效）
- 镜像 tag 用 `microsoft-rewards-v4:local`，与 v3 镜像隔离，便于回滚

## 四、已知差异 / 迁移风险（试点时验证）

1. **会话格式不兼容**：v3 = JSON 文件（`sessions/<email>/session_*.json`）；v4 = SQLite（`sessions/sessions.db`，表 sessions: email/platform/storage_state/fingerprint）。
   → 旧会话不能直接复用，每个账号首跑需重新登录；若被风控拦截，沿用"可信浏览器登录 → 导出 → 注入"流程（目标改为写入 v4 的 SQLite，或直接用容器内 `npm run open-session`）。
2. **watcher 日志关键字**：`/root/watcher/watcher_notify.sh` 按关键字 grep 容器日志（如 `RUN-END`、`邮件发送成功`），v4 日志格式/关键字可能不同，试点时确认邮件通知仍正常，必要时调整 watcher。
3. **搜索得分口径**：v4 `queryEngines: china,local` 是新机制（gmya 热搜 + 本地词），得分节奏与 v3 不同，以 3~5 天累计对比为准。
4. **风控检测**：v4 默认 `contintueOnBotWarning: false`（遇 Bot 警告即停），比 v3 更保守；如误报频繁再按需开启。

## 五、构建要点（服务器上执行）

```sh
# 网络适配已内置（npmmirror 源 + 浏览器下载镜像 + daocloud 基础镜像）
docker build -t microsoft-rewards-v4:local /root/mrs-v4-src
# arm64 全量构建约 40-60 分钟（tsc 慢属正常），构建日志：
#   docker build ... 2>&1 | tee /root/mrs-v4-build.log
```
