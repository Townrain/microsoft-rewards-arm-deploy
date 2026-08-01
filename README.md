# Microsoft Rewards Script — ARM64/Podroid 部署微调仓库

针对 [chiihero/Microsoft-Rewards-Script](https://github.com/chiihero/Microsoft-Rewards-Script) (v3.1.6.4) 在 **ARM64 / 弱网络 / 无 IPv6 / 风控环境**（如 Podroid 手机 VM）下部署的完整微调方案。

> ⚠️ 上游 GHCR 镜像**只有 amd64**，ARM64 必须从源码本地构建。本仓库只存**增量修改**（补丁/配置/文档），不 fork 上游完整源码，升级时重新拉上游 + 重打补丁即可。

## 解决的问题（三个叠加坑）

| # | 问题 | 症状 | 修复 |
|---|---|---|---|
| 1 | 设备无 IPv6 路由 | Chromium 每个 CDN 资源等 IPv6 超时 → 每个 JS 12 秒，登录页 230 秒 | compose `sysctls` 禁用容器 IPv6（资源加载 100 倍提速） |
| 2 | `checkSelector` 超时 200ms 太短 | 慢速环境页面加载完也要 230s，200ms 检测必然错过 → 25 轮 UNKNOWN → 登录超时 | 改 `Login.ts`：`timeout: 200 → 5000` |
| 3 | headless + 伪造指纹被微软风控 | 登录流程走完但 `rn_S` 认证 cookie 缺失 → 后续 API 全 401 → +0 积分 | 真实浏览器登录一次 → 导出 cookie 注入容器（见 `docs/session-injection.md`） |

附加适配：npm 源切 npmmirror（npmjs.org 批量下载会断连）、patchright 浏览器走 npmmirror 镜像。

## 快速开始（设备上一条命令）

```sh
# 在 ARM64 设备上执行 (需可访问 codeload / npmmirror / m.daocloud.io)
sh deploy.sh /root/microsoft-rewards
# 然后编辑 .env 填入账号, 等待构建完成 (40-50 分钟属正常)
```

`deploy.sh` 自动完成：下载源码 → 网络适配 → 打补丁 → 生成 compose/.env → 后台构建启动。

## 仓库结构

```
├── deploy.sh                 # 一键部署脚本 (下载+适配+补丁+启动)
├── docker-compose.yml        # 微调版 compose (IPv6 禁用 + build context=./src)
├── .env.example              # 环境变量模板 (账号/TOTP/PushPlus)
├── patches/
│   └── login.patch           # Login.ts 补丁 (超时 + passkey 跳过)
└── docs/
    ├── deploy-ops.md         # 部署/维护手册 (命令、备份、故障排查)
    └── session-injection.md  # 会话注入流程 (风控环境关键步骤)
```

## 手动应用补丁（不跑 deploy.sh 时）

```sh
# 1. 下载源码
curl -sL -o src.tar.gz https://codeload.github.com/chiihero/Microsoft-Rewards-Script/tar.gz/refs/heads/main
tar xzf src.tar.gz && mv Microsoft-Rewards-Script-main src

# 2. 网络适配
cd src
echo 'registry=https://registry.npmmirror.com/' > .npmrc
sed -i 's|https://registry.npmjs.org/|https://registry.npmmirror.com/|g' package-lock.json
sed -i 's|ENV PLAYWRIGHT_BROWSERS_PATH=0|ENV PLAYWRIGHT_BROWSERS_PATH=0\nENV PLAYWRIGHT_DOWNLOAD_HOST=https://registry.npmmirror.com/-/binary/playwright|' Dockerfile

# 3. 登录修复补丁
patch -p1 < ../patches/login.patch   # 需在 src/ 内执行 (路径按实际调整)
# 或手动: sed -i "s/{ state: 'visible', timeout: 200 }/{ state: 'visible', timeout: 5000 }/" src/browser/auth/Login.ts
```

## 会话续期（重要）

- 每次运行脚本会**自动刷新并保存**认证 cookie（`rn_SID` 滚动续期、`__Host-MSAAUTHP` 390 天）
- 只要 cron 每天运行，**会话不会过期，无需手动刷新**
- 唯一失效场景：容器停机超过约 30 天 → 重新执行 `docs/session-injection.md`

## 已验证环境

- Podroid (Alpine 3.24 / aarch64 / 4 核 2GB)
- Docker 29.5.3 + Compose v5.1.4
- 上游 v3.1.6.4 (main 分支)
- 结果：OAuth 6 秒取码、Server Action 全 200、积分正常收集

## License

微调内容基于上游 GPL-3.0-or-later 项目，本仓库同样适用 GPL-3.0。上游项目风险自负，使用自动化脚本可能导致微软账号被暂停。
