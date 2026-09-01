# v3 → v4.3.2 迁移步骤（<SERVER-IP> Podroid）

> 原则：**先备份、后构建、再试点、逐步切换、随时回滚**。全程不碰运行中的 v3 容器，直到试点通过。

## 阶段 0：全量备份（必做）

```sh
cd /root
tar czf mrs-v4-migration-backup-$(date +%Y%m%d).tar.gz \
  microsoft-rewards microsoft-rewards-2 microsoft-rewards-3 microsoft-rewards-4 watcher
# 验证
tar tzf mrs-v4-migration-backup-*.tar.gz | head -5
```

## 阶段 1：上传 v4 源码并构建镜像（不影响运行中的容器）

本地（Windows）打包：

```powershell
# 已本地改进的 v4 源码树（含 .npmrc / lockfile 替换 / Dockerfile / Login.ts 加固）
tar -czf mrs-v4-china-arm.tar.gz Microsoft-Rewards-Script-4-china
```

上传 + 解压到服务器共享源码目录（4 个项目共用一份，只构建一次）：

```sh
# 服务器上
mkdir -p /root/mrs-v4-src
# 把 mrs-v4-china-arm.tar.gz 传到 /root/ 后：
tar xzf /root/mrs-v4-china-arm.tar.gz -C /root/mrs-v4-src --strip-components=1

# 后台构建（arm64 约 40-60 分钟），日志落盘
cd /root/mrs-v4-src
nohup docker build -t microsoft-rewards-v4:local . > /root/mrs-v4-build.log 2>&1 &
tail -f /root/mrs-v4-build.log   # 观察，直到出现 BUILD_EXIT 或 "naming to ... microsoft-rewards-v4:local"
```

构建失败的常见点：npm 网络（npmmirror 已适配）、patchright 浏览器下载（镜像已适配）、apt 源（daocloud 基础镜像）。

## 阶段 2：试点（选 microsoft-rewards-4，账号 <ACCOUNT-EMAIL>）

```sh
cd /root/microsoft-rewards-4
# 1) 备份现有 compose（保留 v3 配置以便回滚）
cp docker-compose.yml docker-compose.yml.bak-v3
# 2) 换成 v4 compose（本地 v4-arm/docker-compose.yml，build 段删掉，用共享镜像）
#    注意改：container_name 保持 microsoft-rewards-4、CRON_SCHEDULE 保持 17:00 左右的错峰时间、
#    RUN_ON_START: 'true'（首跑验证）
# 3) 新建 config 目录预置（v4 entrypoint 会自动生成，无需手动）
# 4) 停旧容器（bind mount 数据不丢，sessions 目录保留在宿主机）
docker compose down
# 5) 启动 v4
docker compose up -d
docker logs -f microsoft-rewards-4
```

首跑观察点：
- 会话：v4 用 SQLite，旧 JSON 会话无效 → 观察登录流程是否走通（v4 登录已重写 + 超时已修复，预期能自动登录）；
  若被风控拦截（登录成功但 +0 分），走注入流程：可信浏览器登录导出 storageState → 服务器写 `sessions/sessions.db`
  （或容器内 `npm run open-session` 交互登录）。
- 搜索：`[SEARCH-DESKTOP-SEQUENTIAL] 结果` 与累计分；`queryEngines=china,local` 生效（日志应有中国热搜词）。
- watcher：确认 QQ 邮件通知仍能解析 v4 日志关键字（`RUN-END` 等），不行则调整 `/root/watcher/watcher_notify.sh`。
- 健康：`docker ps` 显示 healthy；`docker logs` 无 `UNHANDLED-REJECTION` 崩溃。

## 阶段 3：对比评估（3~5 天）

| 指标 | v3（其他 3 容器同期） | v4 试点 |
|------|---------------------|---------|
| 每日总积分 | 记录 | 记录 |
| 运行时长 / 稳定性 | 记录 | 记录 |
| 登录成功率 | — | 记录 |
| watcher 通知 | 正常 | 验证 |

达标判据：积分 ≥ v3 同期 80% 且无崩溃/频繁重登录 → 通过。

## 阶段 4：逐个切换（每 1~2 天一个）

对 microsoft-rewards、-2、-3 重复阶段 2 步骤（RUN_ON_START 按需），**旧容器 `docker compose down` 后不删除数据、不删 v3 镜像**。

## 阶段 5：收尾

- 全部稳定 1 周后：删除 v3 镜像 `docker rmi microsoft-rewards:local`（保留备份 tar 与 compose.bak-v3）
- 更新 `/root/watcher` 若做过关键字调整
- 记录新基线（版本 4.3.2 + 本地适配），更新 arm-deploy 仓库文档

## 回滚（任何阶段）

```sh
cd /root/microsoft-rewards-4
docker compose down
mv docker-compose.yml docker-compose.yml.v4
mv docker-compose.yml.bak-v3 docker-compose.yml
docker compose up -d --build   # 或直接 docker compose up -d（v3 镜像仍在）
# sessions 目录 v3 数据仍在（bind mount 未删），配置/会话原样恢复
```
