#!/bin/sh
# ============================================================
# Microsoft Rewards Script — ARM64/Podroid 一键部署脚本
# 用法: sh deploy.sh [工作目录, 默认 /root/microsoft-rewards]
# 前提: 设备可访问 codeload.github.com / registry.npmmirror.com / m.daocloud.io
# ============================================================
set -e

BASE="${1:-/root/microsoft-rewards}"
UPSTREAM="chiihero/Microsoft-Rewards-Script"
BRANCH="main"

echo "==> [1/6] 创建目录 $BASE"
mkdir -p "$BASE"

echo "==> [2/6] 下载源码 (codeload, 绕过 github.com)"
cd "$BASE"
if [ -d src ]; then
  echo "    检测到已有 src/, 备份为 src.bak.$(date +%s)"
  mv src "src.bak.$(date +%s)"
fi
curl -sL -o src.tar.gz "https://codeload.github.com/${UPSTREAM}/tar.gz/refs/heads/${BRANCH}"
tar xzf src.tar.gz
mv "Microsoft-Rewards-Script-${BRANCH}" src

echo "==> [3/6] 网络适配 (npmmirror + 浏览器下载镜像)"
cd "$BASE/src"
# 3.1 npm 源切 npmmirror (npmjs.org 批量下载不稳定)
echo 'registry=https://registry.npmmirror.com/' > .npmrc
sed -i 's|https://registry.npmjs.org/|https://registry.npmmirror.com/|g' package-lock.json
# 3.2 patchright 浏览器下载走 npmmirror 镜像
if ! grep -q "PLAYWRIGHT_DOWNLOAD_HOST" Dockerfile; then
  sed -i 's|ENV PLAYWRIGHT_BROWSERS_PATH=0|ENV PLAYWRIGHT_BROWSERS_PATH=0\nENV PLAYWRIGHT_DOWNLOAD_HOST=https://registry.npmmirror.com/-/binary/playwright|' Dockerfile
fi

echo "==> [4/6] 应用登录修复补丁 (慢速环境适配)"
# 4.1 checkSelector 超时 200ms -> 5000ms (页面加载慢时检测必失败)
sed -i "s/{ state: 'visible', timeout: 200 }/{ state: 'visible', timeout: 5000 }/" src/browser/auth/Login.ts
# 4.2 passkey 注册引导页自动跳过 (登录成功后被微软引导注册通行密钥)
if ! grep -q "PASSKEY_ENROLL" src/browser/auth/Login.ts; then
  sed -i "s/    | 'PASSKEY_VIDEO'/    | 'PASSKEY_VIDEO'\n    | 'PASSKEY_ENROLL'/" src/browser/auth/Login.ts
  sed -i "/if (url.hostname === 'rewards.bing.com' || url.hostname === 'account.microsoft.com') {/i\\
        // passkey enroll / fido pages: login already done, navigate back to rewards\\
        if (url.hostname === 'account.live.com' && url.pathname.includes('interrupt/passkey')) {\\
            this.bot.logger.info(this.bot.isMobile, 'DETECT-STATE', 'detected passkey enroll page, skipping');\\
            await page.goto('https://rewards.bing.com/', { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {});\\
            return 'LOGGED_IN'\\
        }\\
        if (url.hostname === 'login.microsoft.com' && url.pathname.includes('fido')) {\\
            this.bot.logger.info(this.bot.isMobile, 'DETECT-STATE', 'detected fido page, navigating back');\\
            await page.goto('https://rewards.bing.com/', { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {});\\
            return 'LOGGED_IN'\\
        }" src/browser/auth/Login.ts
  sed -i "/case 'PASSKEY_VIDEO':/i\\
            case 'PASSKEY_ENROLL': {\\
                this.bot.logger.info(this.bot.isMobile, 'LOGIN', 'handling passkey enroll, navigating back');\\
                await page.goto('https://rewards.bing.com/', { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {});\\
                return true\\
            }" src/browser/auth/Login.ts
fi

echo "==> [5/6] 写入 compose 文件"
if [ ! -f "$BASE/docker-compose.yml" ]; then
  cp "$(dirname "$0")/docker-compose.yml" "$BASE/docker-compose.yml" 2>/dev/null || \
  echo "WARN: 未找到 docker-compose.yml, 请手动放置 (参考本仓库)"
fi
if [ ! -f "$BASE/.env" ]; then
  cp "$(dirname "$0")/.env.example" "$BASE/.env" 2>/dev/null && echo "    已从 .env.example 生成 .env, 请编辑填入账号!" || \
  echo "WARN: 未找到 .env.example, 请手动创建 .env"
fi

echo "==> [6/6] 构建并启动 (约 40-50 分钟, arm64 tsc 慢属正常)"
cd "$BASE"
nohup docker compose up -d --build > build.log 2>&1 &
echo "    构建已后台启动, 查看: tail -f $BASE/build.log"

echo ""
echo "======================================================"
echo " 部署完成! 后续步骤:"
echo " 1) 编辑 $BASE/.env 确认账号配置"
echo " 2) 首次运行若 OAuth 超时/401 (会话无效):"
echo "    参照 docs/session-injection.md 注入真实浏览器会话"
echo " 3) 常用命令见 docs/ops.md"
echo "======================================================"
