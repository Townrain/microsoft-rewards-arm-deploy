# 部署变更记录 — 2026-08-02 晚 / 08-03 凌晨

> 注：本文件早期部分因编辑器编码问题已损坏（乱码），下文仅保留可恢复内容（08-03 起）。

修复（搜索拿分线，08-03 凌晨）

### 根因（实证链）
- bing.com → 301 → cn.bing.com；设备慢网络下页面加载需 20-60s
- 本地改版删除了上游的 networkidle 等待（只等 domcontentloaded+1500ms）→ 页面未稳定就交互
- 布局持续变动 → ghost-cursor move() 的 maxTries=10 intersects 校验反复失败 → 12s 超时降级原生点击
- 查询提交时机错乱 → Bing 服务端不记录 → 0 积分（计数读取验证正常，会话登录态验证正常）

### 修复（Search.ts + BrowserUtils.ts）
1. 初始化导航追加 waitForLoadState('networkidle', 15s) + wait(2000)（等重定向+布局稳定）
2. 搜索框 waitFor 20s→30s
3. ghostClick 传 maxTries:3（减少内部重试）+ 超时 12s→25s
4. 搜索框交互全失败后 URL 直接搜索兜底（goto bing.com/search?q=）
5. 提交后 URL 验证日志（诊断用）
6. unhandledRejection 过滤器扩展：Protocol error 全族 IGNORED（新出现 Unable to adopt element handle 错误）

### 最终验证（验证轮 6）
- 桌面端搜索 51/51 全拿（remaining 60→0）
- 总收集 +54 分（移动端 +3 + 桌面 51）
- 全程零崩溃（幽灵 rejection 全被 IGNORED）
- RUN-END 正常（110.9 分钟）

## 实例 1 桌面端计分修复（08-03 晚）—— 最终根因：UA/指纹与会话签发不匹配

### 完整根因链（多假设实证排除）
1. ? cookie 域假设：手工加 .msn.cn SID（同值复制）→ 0 分；正规双域 SID（cn.bing.com 入口 + msn.cn 访问触发）→ 仍 0 分
2. ? IP 绑定假设：实例 2 与 MCP 浏览器 MSCC 均为 120.230.220.205-CN（同 IP）→ 排除
3. ? 会话有效性：MCP 浏览器（签发 UA）搜索 +3 分 → 会话本身有效
4. ? **UA/指纹匹配 = 根因**：Bing 桌面计分校验搜索请求 UA 与 SID 签发 UA 一致。外部（Playwright MCP）签发的会话在容器内使用时，容器随机指纹 UA ≠ 签发 UA → 不计分；实例 2 成功因为会话容器自签（UA 天然匹配）

### 修复组件（实例 1）
1. session_fingerprint_desktop.json：fingerprint-generator 生成完整指纹 + 覆盖 UA 为 MCP 浏览器的 Chrome/150.0.0.0（含 userAgentData/headers sec-ch-ua 同步）
2. session_desktop.json：93 cookies（MCP 登录 zj + 访问 www.msn.cn 触发 .msn.cn 域独立 SID + 搜索激活）
3. 容器内 entrypoint.sh：saveFingerprint.desktop false→true（sed 修改，**重建容器会还原**）

### 验证结果
- 桌面端 UA 日志确认 = Chrome/150.0.0.0（指纹注入生效）
- 连续拿分 → 51/51 全拿（3398→3449，+51），RUN-END 正常（107.9 分钟）
- 实例 2 不受影响（未改动）

### ?? 维护要点（重要）
1. **重建容器会还原 entrypoint.sh**（saveFingerprint 回 false）→ 需重打 sed
2. **会话会过期**（SID 有时效）→ 过期后需用 Playwright MCP 重新登录（账号邮箱 + TOTP）→ 访问 cn.bing.com 搜索一次 + 访问 www.msn.cn（触发 .msn.cn SID）→ 导出 cookies（走本地 http server 通道）→ 部署 session_desktop.json
3. 指纹文件无需更新（UA 固定）
4. 本地 cookie server 脚本：cookie-server2.js（18766 端口，POST /save）


## rn_SID 会话 cookie 修复（08-04 晚 — 08-05 凌晨）—— Server Action 静默失败

### 症状
- 2026-08-02 起 CLAIM-BONUS-POINTS 每次返回 200 但余额不变（"领取奖励积分完成但无积分变化"），
  dashboard 大额积分（实例1 的 900 点）一直领不到；连击保护 toggle 同样疑似无效

### 根因（实证链）
1. action hash：9381 chunk 中 createServerReference("00cf5ba...", callServer, ...) — hash 未变，排除
2. 请求格式：真实点击抓包 = POST /dashboard + next-action header + body []，与脚本一致，排除
3. next-router-state-tree：RSC 导航抓包与脚本硬编码值逐字节一致，排除
4. 手动构造请求（node fetch 各种 header 组合）均返回 163KB 完整页面流（action 被静默忽略），
   而浏览器 context 内 fetch 返回 46B action 结果流（1:false）→ 差异在浏览器运行时 cookie 状态
5. cookie 对比：打开 dashboard 后 context 新增 rn_SID（rewards.bing.com 域会话 ID）+ _C_ETH；
   会话文件/登录时快照均不含 rn_SID → 根因确认
- 微软更新 dashboard 后，Server Action 请求缺少 rn_SID 时被静默忽略（200 + 完整页面流，不执行）
- 脚本 cookies.mobile 是登录时快照（index.ts:488），页面拿到 rn_SID 后未同步（549 行刷新在 Server Action 之后）

### 修复（BrowserFunc.ts callServerAction）
1. 调用前实时从浏览器 context 刷新 cookies.mobile
2. 缺 rn_SID 时自动导航 dashboard 获取后刷新
3. 新增响应体 debug 日志（验证用）

### 验证结果
- 真实点击实验：实例2 可领取 3 点 → 领取成功（余额 5580→5583），证明 hash/格式/会话链路有效
- 部署后实跑：响应体从 163KB 页面流 → `0:{"a":"$@1","f":"","q":"","i":false}|1:false`（action 真正执行）
- 连击保护 toggle 响应 `1:"$undefined"`（执行成功）

### 影响文件
- src/browser/BrowserFunc.ts（callServerAction cookie 刷新 + 响应体日志）
- 镜像重建部署（microsoft-rewards:local，两实例）


## 重建镜像丢失 dist 修复（08-05）—— 8/3 晚修复回灌源码

### 症状
- 08-05 重建镜像（rn_SID 修复）部署后，实例1 补跑在搜索阶段崩溃：
  UNHANDLED-REJECTION: Unable to adopt element handle from a different document（进程退出，run_daily.sh 报错）
- 桌面端指纹设置失效（entrypoint.sh sed 修改随重建还原，saveFingerprint.desktop 回 false）
- 实例1 旧镜像出现"余额 0 空跑"（+0 积分，11 分钟结束）

### 根因
- 8/3 晚的修复只改了容器内 dist（patch_*.sh 系列），未回灌构建上下文 src
- 重建镜像后 dist 层修复全部丢失（grep 远程 src/src/index.ts 'Unable to adopt' = 0 确认）

### 修复
1. 对比远程构建上下文 vs 本地完整修复版源码，确认 7 个文件差异：
   Browser.ts / BrowserUtils.ts / Login.ts / MobileAccessLogin.ts / SearchManager.ts / Search.ts / index.ts
2. 7 文件回灌远程 src + entrypoint.sh 固化 saveFingerprint.desktop: true
3. 重新构建镜像部署两实例（patches/fixes-20260804.patch）

### 验证
- 实例2 完整跑通：第一轮 +97（RUN_ON_START 手动触发）+ 第二轮 +33（7:00 cron，含 CLAIM 实领 3 分响应 1:true）= 总计 +130（5680→5713），搜索拿满，零崩溃
- 实例1：余额读取恢复正常（旧余额=4600），CLAIM/连击保护响应体均为 action 流
- 幽灵 rejection 全部 IGNORED（不再有 UNHANDLED-REJECTION 退出）

### 教训
- 所有修复必须回灌 src 再重建镜像；dist 层补丁只适合临时应急
- entrypoint.sh 的 sed 修改重建必还原，需固化到源码
