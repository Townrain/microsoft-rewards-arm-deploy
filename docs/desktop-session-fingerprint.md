# 桌面会话 UA/指纹匹配（坑 4：外部注入会话搜索 0 分）

> 适用：容器内交互登录不可用（渲染卡死/风控），必须从外部（可信浏览器）导入桌面会话的场景。
> 本文是 `session-injection.md` 的桌面端补充。移动端注入见原文档（无需指纹匹配）。

## 症状

- 从外部浏览器（如 Playwright MCP / 本机 Chrome）登录导出 cookies 注入容器 `session_desktop.json`
- 容器桌面端**登录成功**（`LOGGED_IN`，URL 判断路径），搜索**正常提交**（`cn.bing.com/search?q=...`）
- 但**计分始终为 0**（`remaining` 不变），而实例 2（容器自签会话）51/51 正常

## 根因（多假设实证排除后确认）

**Bing 桌面搜索计分校验「搜索请求 UA」与「SID 签发 UA」的一致性。**

| 假设 | 验证方法 | 结果 |
|---|---|---|
| cookie 域（`.msn.cn` SID） | 手工复制 `.bing.com` SID 到 `.msn.cn`；再从 cn.bing.com 入口登录 + 访问 www.msn.cn 触发服务端签发真 `.msn.cn` SID | ❌ 均 0 分 |
| IP 绑定 | 对比容器会话与外部浏览器会话的 `MSCC` cookie（`120.230.220.205-CN` 相同） | ❌ 排除 |
| 会话无效 | 在**签发浏览器**（Playwright MCP）里用同一会话搜索 → **+3 分** | ✅ 会话有效 |
| **UA/指纹不匹配** | 容器注入与签发浏览器相同的 UA（指纹文件）→ **+3 分** | ✅ **根因** |

结论：外部签发的会话本身有效，但容器浏览器默认用 fingerprint-injector 随机生成的指纹 UA（如 Edg/151 系），与 SID 签发时的 UA（如 Chrome/150）不一致 → 服务端拒绝计入桌面搜索额度。

## 修复：容器复用「签发浏览器的指纹」

### 1. 提取签发浏览器的 UA（一次性）

用 Playwright MCP（或任何浏览器自动化）在登录会话的页面执行：

```js
navigator.userAgent
// 例: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
```

### 2. 生成指纹文件（容器内，用 fingerprint-generator）

```bash
docker exec microsoft-rewards node /tmp/gen-fp.js
```

`gen-fp.js` 逻辑（示例，需按实际 UA 覆盖）：

```js
const { FingerprintGenerator } = require('/usr/src/microsoft-rewards-script/node_modules/fingerprint-generator');
const g = new FingerprintGenerator();
const { fingerprint, headers } = g.getFingerprint({
  locales: ['zh-CN'], devices: ['desktop'],
  operatingSystems: ['windows'],
  browsers: [{ name: 'chrome', minVersion: 150, maxVersion: 150 }]
});
// 覆盖为签发浏览器的 UA（关键：与 SID 签发 UA 一致）
const MCP_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';
fingerprint.navigator.userAgent = MCP_UA;
// userAgentData.brands / fullVersionList、headers['user-agent']、headers['sec-ch-ua'] 等同步覆盖
const out = { headers, fingerprint };
fs.writeFileSync('/usr/src/microsoft-rewards-script/dist/browser/sessions/<邮箱>/session_fingerprint_desktop.json', JSON.stringify(out));
```

### 3. 开启 saveFingerprint.desktop（必须，否则指纹文件不被加载）

容器内 entrypoint.sh 硬编码 `saveFingerprint: { mobile: false, desktop: false }`，不读环境变量。需修改：

```bash
docker exec microsoft-rewards sed -i 's/desktop: false/desktop: true/' /usr/local/bin/entrypoint.sh
```

⚠️ **重建容器会还原**（镜像内是 false），重建后需重新执行。

### 4. 确保桌面会话包含双域 SID（可选但推荐）

Bing 中国版（cn.bing.com）桌面计分依赖完整登录态。外部登录后**访问一次 `https://www.msn.cn/`**，触发服务端向 `.msn.cn` 域签发独立 `_EDGE_S`（与 `.bing.com` 域 SID 值不同，服务端独立签发）。会话应同时包含：

```
_EDGE_S @.bing.com   SID=...   （国际版/基础）
_EDGE_S @.msn.cn     SID=...   （中国版，访问 msn.cn 后下发）
```

导出 cookies（Playwright `context.cookies()` 格式即 JSON 数组，直接兼容）→ 注入 `session_desktop.json`。

### 5. 验证

```bash
docker restart microsoft-rewards
docker logs -f microsoft-rewards
```

- 期望日志：`创建浏览器，用户代理: "...Chrome/150.0.0.0..."`（指纹生效）
- 搜索后出现 `获得积分=3 points | remaining=...`（计分恢复）
- 实测结果：51/51 全拿（+51 分）

## 会话刷新 SOP（SID 过期后）

1. Playwright MCP（或可信浏览器）登录账号（邮箱 → 密码 → TOTP）
2. 访问 `https://cn.bing.com/` 搜索一次（激活会话）
3. 访问 `https://www.msn.cn/`（触发 `.msn.cn` 域 SID）
4. 导出 `context.cookies()` → 覆盖容器 `session_desktop.json`（同路径同文件名）
5. `docker restart microsoft-rewards`

指纹文件（`session_fingerprint_desktop.json`）**无需更新**（UA 固定）。

## 补充说明

- 移动端（`session_mobile.json`）注入不需要指纹匹配（移动计分走不同端点，仅 `.bing.com` 域 SID 即可，见原 session-injection.md）
- 指纹文件缺失时脚本会随机生成新指纹 → UA 与会话再次不匹配 → 0 分。排查顺序：先确认指纹文件存在 + saveFingerprint 生效 + 桌面 UA 日志与签发 UA 一致
