# 会话注入流程（风控环境关键步骤）

## 为什么需要

headless Chromium + 伪造指纹 + 数据中心/手机 IP 组合会被微软判定为可疑设备：
- 登录流程**看似成功**（TOTP 通过、KMSI 接受、日志"登录成功"）
- 但 rewards.bing.com 域的核心认证 cookie `rn_S`（JWT）**缺失**、`_C_Auth` 为空
- 后果：OAuth 取码 180 秒超时、Server Action 全 401、+0 积分

**判定方法**：登录后检查容器内 cookie：

```bash
docker exec microsoft-rewards sh -c 'cat /usr/src/microsoft-rewards-script/dist/browser/sessions/*/session_mobile.json' | grep -o '"name":"rn_S"' | head -1
# 无输出 = 会话无效, 需要注入
```

## 方案 A：真实浏览器登录 + 导出 cookie（推荐）

在**可信环境**（本机 Windows/浏览器）完成一次真实登录，导出 cookie 注入容器。

### 步骤

1. **可信环境登录**（任选其一）：
   - 本机 Edge/Chrome 无痕模式访问 `https://rewards.bing.com/`，手动登录（邮箱→密码→TOTP→保持登录）
   - 或使用 Playwright MCP / 任何浏览器自动化，用真实浏览器登录到 dashboard 可见

2. **导出 cookie**：需要包含以下域的 cookie（一个都不能少）：
   ```
   rewards.bing.com    (rn_S, rn_SID, GRNID, ai_session ...)
   .bing.com           (MUID, _EDGE_S, _SS ...)
   .login.live.com     (MSPOK, MSPRequ, __Host-MSAAUTHP ...)
   .live.com           (PPLState, WLSSC ...)
   login.microsoftonline.com / .microsoft.com
   ```
   格式为 JSON 数组（Playwright `context.cookies()` 直接输出即此格式）。

3. **注入容器**：
   ```bash
   # 上传 cookie 文件到设备
   scp -P 9922 mrs-cookies.json root@<设备IP>:/tmp/
   # 写入容器会话文件 (路径含账号邮箱)
   docker cp /tmp/mrs-cookies.json microsoft-rewards:/usr/src/microsoft-rewards-script/dist/browser/sessions/<邮箱>/session_mobile.json
   # 重启容器触发运行
   docker restart microsoft-rewards
   ```

4. **验证成功**：
   ```bash
   docker logs -f microsoft-rewards
   # 期望: 迭代 1/25 → LOGGED_IN (直接复用会话, 不走登录)
   #       OAuth轮询URL已更改 → oauth20_desktop.srf?code=... (6秒内)
   #       URL-REWARD 状态=200 获得积分
   ```

## 方案 B：本机运行项目 Win 版生成会话

如果你能运行项目的 Windows 版（Node 24）：

```sh
# 1. 克隆项目, npm install, 配置 accounts.json/config.json
# 2. 有头模式跑一次 (headless: false), 手动补登
npm start
# 3. 成功后 sessions/<邮箱>/session_mobile.json 即为有效 cookie
# 4. 上传该文件到设备并 docker cp 注入 (同方案 A 步骤 3)
```

## 会话续期

- 每次容器运行，脚本访问 rewards.bing.com 时微软会**自动刷新** cookie（`rn_SID` 滚动续期、`__Host-MSAAUTHP` 有效期 390 天）
- 运行结束脚本保存刷新后的新 cookie
- **只要 cron 每天运行，会话永久有效，无需再次注入**
- 唯一失效场景：容器停机 >30 天 → 重新执行本流程

## 安全提示

- cookie 文件包含账号认证信息，传输/存储注意保密，用完可删除
- 不要在公开渠道分享 cookie 或含账号信息的日志

---

## 桌面会话（session_desktop.json）—— 额外要求：UA/指纹匹配

> ⚠️ 移动端注入不需要本节。**桌面端**外部注入会话后若搜索 0 分，是因为容器浏览器随机指纹 UA ≠ 会话签发 UA，Bing 不计分。

**必须同时注入**（缺一不可）：
1. session_desktop.json（cookies，含 .bing.com + .msn.cn 双域 _EDGE_S——登录后访问 https://www.msn.cn/ 触发 .msn.cn 域 SID）
2. session_fingerprint_desktop.json（指纹，ingerprint.navigator.userAgent = 签发浏览器的 UA）
3. entrypoint.sh 改 saveFingerprint.desktop: true（容器内 sed，重建会还原）

完整流程与验证见 desktop-session-fingerprint.md。