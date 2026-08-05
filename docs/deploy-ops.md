# 部署与维护手册

> 适用：ARM64 设备（如 Podroid 手机 VM）部署 Microsoft Rewards Script

## 1. 环境要求

- 设备：Linux aarch64，Docker + Compose
- 网络可达：codeload.github.com、registry.npmmirror.com、m.daocloud.io（Docker Hub 不可达时）
- 磁盘 ≥ 5GB，内存 ≥ 2GB

## 2. 部署

```sh
# 一键部署 (下载源码 + 适配 + 补丁 + 构建)
sh deploy.sh /root/microsoft-rewards

# 编辑账号
vi /root/microsoft-rewards/.env
chmod 600 /root/microsoft-rewards/.env

# 查看构建进度
tail -f /root/microsoft-rewards/build.log
```

构建耗时参考（arm64 2GB 内存）：

| 步骤 | 耗时 |
|---|---|
| npm ci (npmmirror) | ~12 min |
| npm run build (tsc) | 8-10 min |
| npm ci --omit=dev | ~7 min |
| patchright install (apt + 109MB 浏览器) | ~28 min |

## 3. 常用命令

```bash
# 状态
docker ps -a
docker inspect microsoft-rewards --format '{{.State.Status}} {{.State.Health.Status}}'

# 日志
docker logs -f microsoft-rewards
docker logs --tail 100 microsoft-rewards
docker logs --since 30m microsoft-rewards 2>&1 | grep -aE 'LOGIN|SEARCH|ERROR|积分'

# 手动触发一次运行
docker exec microsoft-rewards sh -c 'cd /usr/src/microsoft-rewards-script && node ./dist/index.js'

# 重启 / 重建
docker restart microsoft-rewards
cd /root/microsoft-rewards && docker compose up -d --build   # 改过源码后必须 --build
```

## 4. 数据位置与备份

| 路径 | 内容 | 备份建议 |
|---|---|---|
| `sessions/` | 登录会话 cookie | **每周备份，丢了要重登+注入** |
| `config/` | 生成的 accounts/config | entrypoint 自动维护 |
| `.env` | 账号凭据 | 权限 600 |
| `src/` | 源码(含补丁) | 不需要(可从仓库重建) |

```bash
tar czf ~/sessions-backup-$(date +%F).tar.gz /root/microsoft-rewards/sessions/
```

## 5. 升级

```sh
cd /root/microsoft-rewards
sh <(curl -sL https://raw.githubusercontent.com/Townrain/microsoft-rewards-arm-deploy/main/deploy.sh) /root/microsoft-rewards
# config/ 和 sessions/ 在容器外, 升级不丢
```

> deploy.sh 检测到已有 src/ 会先备份为 src.bak.*，安全重来。

## 6. 故障排查速查表

| 症状 | 原因 | 处理 |
|---|---|---|
| 登录超时 (25 轮 UNKNOWN) | 超时补丁丢失 (重建前没打) | 确认源码 `timeout: 5000`，重建 |
| OAuth 180s 超时 / 401 | 会话无效 | docs/session-injection.md |
| 资源加载 12s/个 | IPv6 未禁用 | 确认 compose sysctls，`docker compose up -d` |
| npm ci 网络错误 | npmjs.org 不稳 | 确认 .npmrc + lockfile 已切 npmmirror |
| 幽灵容器 (名字冲突但 ps 看不到) | Podroid docker daemon 状态残留 | `rc-service docker restart` 后重新 up |
| tsc 极慢 (8-10min) | 2GB 内存 arm64 正常 | 耐心等，勿中断 |
| 每天 03:00 不跑 | 时区/调度问题 | 查日志 `CRON_SCHEDULE=0 3 * * *`、`TZ=Asia/Shanghai` |

## 7. 验证清单

- [ ] `docker ps` healthy
- [ ] 日志 `accounts.json written with 1 account(s)`
- [ ] 日志 `迭代 1/25 → LOGGED_IN`（复用会话）
- [ ] `OAuth轮询URL已更改 → ...code=...`（秒级）
- [ ] `URL-REWARD ... 状态=200 ... 获得积分=N`
- [ ] `RUN-END ... 总收集积分: +N`
- [ ] `sessions/` cookie 数量 > 50
