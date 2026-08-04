# 閮ㄧ讲鍙樻洿璁板綍 鈥� 2026-08-02 鏅� / 08-03 鍑屾櫒

## 鑳屾櫙
Microsoft Rewards 鑷�鍔ㄥ寲鑴氭湰锛堝�瑰櫒 microsoft-rewards-2锛夊瓨鍦� 8 椤归棶棰橈細
OAuth 涓嶇ǔ瀹氥�侀噸璇曢�昏緫缂洪櫡銆乿erifyBingSession 鏋佹參銆佹悳绱� 0 绉�鍒嗐�乫rame 閿欒��銆�
璁惧�囪礋杞介珮銆佽ˉ涓佸垎鏁ｃ�佷笁澶勪唬鐮佸悓姝ヤ笉涓�鑷淬��

## 鏈�娆″彉鏇达紙鍩轰簬鍥涗唬鐞嗚�ㄨ�哄悗鐨勬渶缁堟柟妗堬級

### 1. OAuth 閲嶈瘯寰�鐜�閲嶆瀯锛圡obileAccessLogin.ts锛�
- **鏂板�� `MobileAccessLoginError` 寮傚父绫�**锛坈ode + retryable 灞炴�э級
- **break 鏉′欢淇�澶�**锛歚includes('oauth20_desktop.srf')` 鈫� URLSearchParams 绮剧‘瑙ｆ瀽锛�
  浠� `code` 闈炵┖涓旀棤 `error` 鎵� break锛堜慨澶� removed=true / 涓�闂存�佽�� break锛�
- **removed=true**锛氬揩閫熼噸璇� 1 娆★紝浠� removed 鈫� 鎶� REVOKED锛堜笉鍙�閲嶈瘯锛岄�氱煡鐢ㄦ埛锛�
- **error 鍙傛暟鍒嗙被**锛歵emporarily_unavailable/server_error 鍙�閲嶈瘯锛屽叾浠栨姏 OAUTH_*
- **ECONNRESET 閫�閬�**锛�5s脳(attempt+1)
- **杞�璇㈠惊鐜�澧炲己**锛歳emoved/access_denied/dashboard 鎻愬墠澶辫触妫�娴嬶紙涓嶅啀姝荤瓑 240s锛�
- **鍒犻櫎鍏ㄩ儴 `return ''` 璺�寰�**锛氳疆璇㈣秴鏃舵姏 POLL_TIMEOUT锛坮etryable锛夛紝鏉滅粷 401 閾�

### 2. index.ts 璋冪敤鏂归�傞厤
- import MobileAccessLoginError
- catch 鎸� retryable 鍒嗙被锛氬彲閲嶈瘯 鈫� 鏃ュ織鍚庣户缁�锛涜嚧鍛斤紙REVOKED 绛夛級鈫� 鎶涘嚭璁�
  涓绘祦绋嬭烦杩囨湰璐﹀彿锛堟祻瑙堝櫒娓呯悊鐢� Main 鐨� try/finally 淇濊瘉锛�

### 3. verifyBingSession 閲嶆瀯锛圠ogin.ts锛�
- **鍗曡疆 60s 纭�鎴�姝�**锛圥romise.race锛�+ 淇濈暀 90s 鎬婚�勭畻 + 瓒呮椂鍚� 5s 鍐峰嵈澶嶄綅
- **networkidle 鈫� domcontentloaded**锛�3 澶勶級鈥斺�旀瘡杞�楠岃瘉浠� 10-15s 闄嶅埌 2-5s
- **loopMax 5 鈫� 3**
- **鎿嶄綔绾ц�楁椂鏃ュ織**锛坉etectCurrentState/tryDismissAllMessages/waitForSelector锛�
- **waitForSelector(bingProfile) 闃叉姢**锛歝ontext 閿�姣佺被閿欒��闄嶇骇澶勭悊

### 4. 鍙岄噸楠岃瘉鍘婚噸锛圫earchManager.ts锛�
- 鍒犻櫎 createDesktopSession 涓�鐨勭��浜屾�� verifyBingSession 璋冪敤

### 5. ghostClick 鍔犲浐锛圔rowserUtils.ts锛�
- catch 涓�妫�娴� context 閿�姣佺被閿欒�� 鈫� 闄嶇骇鍘熺敓 `locator.click({force:true})`
- **cursor.click 杩藉姞 .catch(() => false)**锛氬悶鎺� Promise.race 杈撳�� rejection

### 6. unhandledRejection 鍒嗙被澶勭悊锛坕ndex.ts锛�
- context 閿�姣佺被骞界伒 rejection锛圖OM.describeNode / Cannot find context /
  Execution context was destroyed锛夆啋 浠� warn 璁板綍涓嶉��鍑�
- 鍏朵粬 rejection 鈫� 淇濇寔 flushAllWebhooks + exit(1)

## 閮ㄧ讲鏂瑰紡
1. 鏈�鍦� `npm run build`锛坱sc 缂栬瘧锛孍XIT=0锛�
2. tar 鎵撳寘涓婁紶 NAS锛宒ocker cp 鏇挎崲瀹瑰櫒 dist
3. 澶囦唤锛�/root/backups/dist-20260802_1416
4. 杩藉姞淇�澶嶆寜鏂囦欢鍗曠嫭鏇挎崲锛圡obileAccessLogin.js / BrowserUtils.js / index.js锛�
5. docker restart 瑙﹀彂楠岃瘉杞�

## 楠岃瘉缁撴灉锛堥獙璇佽疆 2/3/4锛屽�氭�￠噸鍚�瀹炴祴锛�
- 鉁� verifyBingSession锛�3 杞�鍏� 39 绉掞紙鍘� 13 鍒嗛挓鎸傝捣锛夛紝鎿嶄綔绾ф棩蹇楁�ｅ父
- 鉁� OAuth锛氳繛缁� 3 杞�鎴愬姛锛�26s / 14s / 29s 鎷� code锛屾棤 401锛�
- 鉁� 绉诲姩绔�娲诲姩锛氱�惧埌 +5銆侀槄璇� 10/10 +30 鍒嗭紙楠岃瘉杞� 2锛�
- 鉁� 骞界伒 rejection 淇�澶嶏細DOM.describeNode 琚� IGNORED 鎹曡幏锛岃繘绋嬪瓨娲昏嚦 RUN-END
  锛�49.5 鍒嗛挓瀹屾暣璺戝畬锛涗慨澶嶅墠鍚屾牱浣嶇疆蹇呭穿锛�
- 鉁� 妗岄潰绔�鐧诲綍浠� 3 鍒嗛挓锛堝弻閲嶉獙璇佸幓閲� + domcontentloaded 鐢熸晥锛�
- 鈿狅笍 妗岄潰绔�鎼滅储锛歳andomBytes 宕╂簝宸蹭慨澶嶏紙鏌ヨ�㈢湡姝ｆ彁浜ゅ埌蹇呭簲锛夛紝浣嗘嬁鍒嗕粛 0
  锛坮emaining 鎭掑畾 60锛夆�斺�旂嫭绔嬫繁灞傞棶棰橈紝鐤戠偣锛�
  鈶� Search.js bingHome 纭�缂栫爜 bing.com锛圕N 璐﹀彿璁″垎鍙�鑳介渶瑕� cn.bing.com锛�
  鈶� 妗岄潰浼氳瘽鐧诲綍鎬佹湁鏁堟�э紙楠岃瘉闄嶇骇鍚庣户缁�锛�
  鈶� getDashboardData 鎭掔敤 mobile cookie 璇昏�℃暟
  寰呭崟鐙�鎺掓煡

## 閮ㄧ讲杩囩▼涓�鍙戠幇鐨勮拷鍔� bug 鍙婁慨澶�
1. **AUTH_TIMEOUT 鐭�璺�**锛堥獙璇佽疆 1 鍙戠幇锛夛細throw 鍘熶綅浜庤疆璇㈠惊鐜�鍓嶏紝goto 鎷垮埌
   code 涔熶細鎶涘紓甯搞�佽疆璇�淇濆簳澶辨晥 鈫� 鍒犻櫎 throw锛実oto 鑰楀敖鍚庤嚜鐒惰繘鍏ヨ疆璇㈠惊鐜�
2. **ghostClick 鎮�绌� rejection**锛堥獙璇佽疆 2 鍙戠幇锛夛細Promise.race 杈撳��
   cursor.click 鐨� rejection 鎮�绌鸿Е鍙� unhandledRejection 鈫� 鍔� .catch(() => false)
3. **patchright 鍐呴儴 dispatcher rejection**锛堥獙璇佽疆 2/3 鍙戠幇锛夛細DOM.describeNode
   閿欒��涓嶅湪搴旂敤灞� promise 閾句笂锛屽簲鐢ㄥ眰 catch 鎷︿笉浣� 鈫� 鍏ㄥ眬澶勭悊鍣ㄥ垎绫诲�勭悊

## 鍙楀奖鍝嶆枃浠�
- src/browser/auth/methods/MobileAccessLogin.ts锛堝紓甯哥被 + 閲嶈瘯閲嶆瀯 + AUTH_TIMEOUT 绉婚櫎锛�
- src/index.ts锛堣皟鐢ㄦ柟閫傞厤 + unhandledRejection 鍒嗙被锛�
- src/browser/auth/Login.ts锛坴erifyBingSession锛�
- src/functions/SearchManager.ts锛堝弻閲嶉獙璇佸幓閲嶏級
- src/browser/BrowserUtils.ts锛坓hostClick 鍔犲浐 脳2锛�
- 瀹瑰櫒 dist 瀵瑰簲 js 鏂囦欢锛堝叏閲忔浛鎹� + 3 娆¤拷鍔犳浛鎹�锛�

## 閬楃暀瑙傚療椤�
- 妗岄潰绔�鎼滅储鎷垮垎锛堢嫭绔嬫繁灞傞棶棰橈紝鐤戠偣瑙佷笂锛屽缓璁�鍗曠嫭鎺掓煡 bingHome 鍩熷悕锛�
- SUPPORTED_DEPLOYMENT_ID 20260624-3 vs 绾夸笂 20260730-3锛堟湁鑷�鍔ㄩ檷绾ц矾寰勶級
- getDashboardData 鎭掔敤 mobile cookie锛堝彲鑳戒笌妗岄潰鎷垮垎鐩稿叧锛�
- SearchOnBing.ts src 鏈�鍚屾�� mainMobilePage 淇�澶嶏紙瀹瑰櫒 15:39 宸蹭慨锛�

## 追加修复（搜索拿分线，08-03 凌晨）

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
2. **会话会过期**（SID 有时效）→ 过期后需用 Playwright MCP 重新登录 zj（邮箱 zj13713431458@outlook.com + TOTP）→ 访问 cn.bing.com 搜索一次 + 访问 www.msn.cn（触发 .msn.cn SID）→ 导出 cookies（走本地 http server 通道）→ 部署 session_desktop.json
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
