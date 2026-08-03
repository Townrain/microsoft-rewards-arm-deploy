# éƒ¨ç½²å˜æ›´è®°å½• â€” 2026-08-02 æ™š / 08-03 å‡Œæ™¨

## èƒŒæ™¯
Microsoft Rewards è‡ªåŠ¨åŒ–è„šæœ¬ï¼ˆå®¹å™¨ microsoft-rewards-2ï¼‰å­˜åœ¨ 8 é¡¹é—®é¢˜ï¼š
OAuth ä¸ç¨³å®šã€é‡è¯•é€»è¾‘ç¼ºé™·ã€verifyBingSession ææ…¢ã€æœç´¢ 0 ç§¯åˆ†ã€frame é”™è¯¯ã€
è®¾å¤‡è´Ÿè½½é«˜ã€è¡¥ä¸åˆ†æ•£ã€ä¸‰å¤„ä»£ç åŒæ­¥ä¸ä¸€è‡´ã€‚

## æœ¬æ¬¡å˜æ›´ï¼ˆåŸºäºå››ä»£ç†è®¨è®ºåçš„æœ€ç»ˆæ–¹æ¡ˆï¼‰

### 1. OAuth é‡è¯•å¾ªç¯é‡æ„ï¼ˆMobileAccessLogin.tsï¼‰
- **æ–°å¢ `MobileAccessLoginError` å¼‚å¸¸ç±»**ï¼ˆcode + retryable å±æ€§ï¼‰
- **break æ¡ä»¶ä¿®å¤**ï¼š`includes('oauth20_desktop.srf')` â†’ URLSearchParams ç²¾ç¡®è§£æï¼Œ
  ä»… `code` éç©ºä¸”æ—  `error` æ‰ breakï¼ˆä¿®å¤ removed=true / ä¸­é—´æ€è¯¯ breakï¼‰
- **removed=true**ï¼šå¿«é€Ÿé‡è¯• 1 æ¬¡ï¼Œä» removed â†’ æŠ› REVOKEDï¼ˆä¸å¯é‡è¯•ï¼Œé€šçŸ¥ç”¨æˆ·ï¼‰
- **error å‚æ•°åˆ†ç±»**ï¼štemporarily_unavailable/server_error å¯é‡è¯•ï¼Œå…¶ä»–æŠ› OAUTH_*
- **ECONNRESET é€€é¿**ï¼š5sÃ—(attempt+1)
- **è½®è¯¢å¾ªç¯å¢å¼º**ï¼šremoved/access_denied/dashboard æå‰å¤±è´¥æ£€æµ‹ï¼ˆä¸å†æ­»ç­‰ 240sï¼‰
- **åˆ é™¤å…¨éƒ¨ `return ''` è·¯å¾„**ï¼šè½®è¯¢è¶…æ—¶æŠ› POLL_TIMEOUTï¼ˆretryableï¼‰ï¼Œæœç» 401 é“¾

### 2. index.ts è°ƒç”¨æ–¹é€‚é…
- import MobileAccessLoginError
- catch æŒ‰ retryable åˆ†ç±»ï¼šå¯é‡è¯• â†’ æ—¥å¿—åç»§ç»­ï¼›è‡´å‘½ï¼ˆREVOKED ç­‰ï¼‰â†’ æŠ›å‡ºè®©
  ä¸»æµç¨‹è·³è¿‡æœ¬è´¦å·ï¼ˆæµè§ˆå™¨æ¸…ç†ç”± Main çš„ try/finally ä¿è¯ï¼‰

### 3. verifyBingSession é‡æ„ï¼ˆLogin.tsï¼‰
- **å•è½® 60s ç¡¬æˆªæ­¢**ï¼ˆPromise.raceï¼‰+ ä¿ç•™ 90s æ€»é¢„ç®— + è¶…æ—¶å 5s å†·å´å¤ä½
- **networkidle â†’ domcontentloaded**ï¼ˆ3 å¤„ï¼‰â€”â€”æ¯è½®éªŒè¯ä» 10-15s é™åˆ° 2-5s
- **loopMax 5 â†’ 3**
- **æ“ä½œçº§è€—æ—¶æ—¥å¿—**ï¼ˆdetectCurrentState/tryDismissAllMessages/waitForSelectorï¼‰
- **waitForSelector(bingProfile) é˜²æŠ¤**ï¼šcontext é”€æ¯ç±»é”™è¯¯é™çº§å¤„ç†

### 4. åŒé‡éªŒè¯å»é‡ï¼ˆSearchManager.tsï¼‰
- åˆ é™¤ createDesktopSession ä¸­çš„ç¬¬äºŒæ¬¡ verifyBingSession è°ƒç”¨

### 5. ghostClick åŠ å›ºï¼ˆBrowserUtils.tsï¼‰
- catch ä¸­æ£€æµ‹ context é”€æ¯ç±»é”™è¯¯ â†’ é™çº§åŸç”Ÿ `locator.click({force:true})`
- **cursor.click è¿½åŠ  .catch(() => false)**ï¼šåæ‰ Promise.race è¾“å®¶ rejection

### 6. unhandledRejection åˆ†ç±»å¤„ç†ï¼ˆindex.tsï¼‰
- context é”€æ¯ç±»å¹½çµ rejectionï¼ˆDOM.describeNode / Cannot find context /
  Execution context was destroyedï¼‰â†’ ä»… warn è®°å½•ä¸é€€å‡º
- å…¶ä»– rejection â†’ ä¿æŒ flushAllWebhooks + exit(1)

## éƒ¨ç½²æ–¹å¼
1. æœ¬åœ° `npm run build`ï¼ˆtsc ç¼–è¯‘ï¼ŒEXIT=0ï¼‰
2. tar æ‰“åŒ…ä¸Šä¼  NASï¼Œdocker cp æ›¿æ¢å®¹å™¨ dist
3. å¤‡ä»½ï¼š/root/backups/dist-20260802_1416
4. è¿½åŠ ä¿®å¤æŒ‰æ–‡ä»¶å•ç‹¬æ›¿æ¢ï¼ˆMobileAccessLogin.js / BrowserUtils.js / index.jsï¼‰
5. docker restart è§¦å‘éªŒè¯è½®

## éªŒè¯ç»“æœï¼ˆéªŒè¯è½® 2/3/4ï¼Œå¤šæ¬¡é‡å¯å®æµ‹ï¼‰
- âœ… verifyBingSessionï¼š3 è½®å…± 39 ç§’ï¼ˆåŸ 13 åˆ†é’ŸæŒ‚èµ·ï¼‰ï¼Œæ“ä½œçº§æ—¥å¿—æ­£å¸¸
- âœ… OAuthï¼šè¿ç»­ 3 è½®æˆåŠŸï¼ˆ26s / 14s / 29s æ‹¿ codeï¼Œæ—  401ï¼‰
- âœ… ç§»åŠ¨ç«¯æ´»åŠ¨ï¼šç­¾åˆ° +5ã€é˜…è¯» 10/10 +30 åˆ†ï¼ˆéªŒè¯è½® 2ï¼‰
- âœ… å¹½çµ rejection ä¿®å¤ï¼šDOM.describeNode è¢« IGNORED æ•è·ï¼Œè¿›ç¨‹å­˜æ´»è‡³ RUN-END
  ï¼ˆ49.5 åˆ†é’Ÿå®Œæ•´è·‘å®Œï¼›ä¿®å¤å‰åŒæ ·ä½ç½®å¿…å´©ï¼‰
- âœ… æ¡Œé¢ç«¯ç™»å½•ä»… 3 åˆ†é’Ÿï¼ˆåŒé‡éªŒè¯å»é‡ + domcontentloaded ç”Ÿæ•ˆï¼‰
- âš ï¸ æ¡Œé¢ç«¯æœç´¢ï¼šrandomBytes å´©æºƒå·²ä¿®å¤ï¼ˆæŸ¥è¯¢çœŸæ­£æäº¤åˆ°å¿…åº”ï¼‰ï¼Œä½†æ‹¿åˆ†ä» 0
  ï¼ˆremaining æ’å®š 60ï¼‰â€”â€”ç‹¬ç«‹æ·±å±‚é—®é¢˜ï¼Œç–‘ç‚¹ï¼š
  â‘  Search.js bingHome ç¡¬ç¼–ç  bing.comï¼ˆCN è´¦å·è®¡åˆ†å¯èƒ½éœ€è¦ cn.bing.comï¼‰
  â‘¡ æ¡Œé¢ä¼šè¯ç™»å½•æ€æœ‰æ•ˆæ€§ï¼ˆéªŒè¯é™çº§åç»§ç»­ï¼‰
  â‘¢ getDashboardData æ’ç”¨ mobile cookie è¯»è®¡æ•°
  å¾…å•ç‹¬æ’æŸ¥

## éƒ¨ç½²è¿‡ç¨‹ä¸­å‘ç°çš„è¿½åŠ  bug åŠä¿®å¤
1. **AUTH_TIMEOUT çŸ­è·¯**ï¼ˆéªŒè¯è½® 1 å‘ç°ï¼‰ï¼šthrow åŸä½äºè½®è¯¢å¾ªç¯å‰ï¼Œgoto æ‹¿åˆ°
   code ä¹Ÿä¼šæŠ›å¼‚å¸¸ã€è½®è¯¢ä¿åº•å¤±æ•ˆ â†’ åˆ é™¤ throwï¼Œgoto è€—å°½åè‡ªç„¶è¿›å…¥è½®è¯¢å¾ªç¯
2. **ghostClick æ‚¬ç©º rejection**ï¼ˆéªŒè¯è½® 2 å‘ç°ï¼‰ï¼šPromise.race è¾“å®¶
   cursor.click çš„ rejection æ‚¬ç©ºè§¦å‘ unhandledRejection â†’ åŠ  .catch(() => false)
3. **patchright å†…éƒ¨ dispatcher rejection**ï¼ˆéªŒè¯è½® 2/3 å‘ç°ï¼‰ï¼šDOM.describeNode
   é”™è¯¯ä¸åœ¨åº”ç”¨å±‚ promise é“¾ä¸Šï¼Œåº”ç”¨å±‚ catch æ‹¦ä¸ä½ â†’ å…¨å±€å¤„ç†å™¨åˆ†ç±»å¤„ç†

## å—å½±å“æ–‡ä»¶
- src/browser/auth/methods/MobileAccessLogin.tsï¼ˆå¼‚å¸¸ç±» + é‡è¯•é‡æ„ + AUTH_TIMEOUT ç§»é™¤ï¼‰
- src/index.tsï¼ˆè°ƒç”¨æ–¹é€‚é… + unhandledRejection åˆ†ç±»ï¼‰
- src/browser/auth/Login.tsï¼ˆverifyBingSessionï¼‰
- src/functions/SearchManager.tsï¼ˆåŒé‡éªŒè¯å»é‡ï¼‰
- src/browser/BrowserUtils.tsï¼ˆghostClick åŠ å›º Ã—2ï¼‰
- å®¹å™¨ dist å¯¹åº” js æ–‡ä»¶ï¼ˆå…¨é‡æ›¿æ¢ + 3 æ¬¡è¿½åŠ æ›¿æ¢ï¼‰

## é—ç•™è§‚å¯Ÿé¡¹
- æ¡Œé¢ç«¯æœç´¢æ‹¿åˆ†ï¼ˆç‹¬ç«‹æ·±å±‚é—®é¢˜ï¼Œç–‘ç‚¹è§ä¸Šï¼Œå»ºè®®å•ç‹¬æ’æŸ¥ bingHome åŸŸåï¼‰
- SUPPORTED_DEPLOYMENT_ID 20260624-3 vs çº¿ä¸Š 20260730-3ï¼ˆæœ‰è‡ªåŠ¨é™çº§è·¯å¾„ï¼‰
- getDashboardData æ’ç”¨ mobile cookieï¼ˆå¯èƒ½ä¸æ¡Œé¢æ‹¿åˆ†ç›¸å…³ï¼‰
- SearchOnBing.ts src æœªåŒæ­¥ mainMobilePage ä¿®å¤ï¼ˆå®¹å™¨ 15:39 å·²ä¿®ï¼‰

## ×·¼ÓĞŞ¸´£¨ËÑË÷ÄÃ·ÖÏß£¬08-03 Áè³¿£©

### ¸ùÒò£¨ÊµÖ¤Á´£©
- bing.com ¡ú 301 ¡ú cn.bing.com£»Éè±¸ÂıÍøÂçÏÂÒ³Ãæ¼ÓÔØĞè 20-60s
- ±¾µØ¸Ä°æÉ¾³ıÁËÉÏÓÎµÄ networkidle µÈ´ı£¨Ö»µÈ domcontentloaded+1500ms£©¡ú Ò³ÃæÎ´ÎÈ¶¨¾Í½»»¥
- ²¼¾Ö³ÖĞø±ä¶¯ ¡ú ghost-cursor move() µÄ maxTries=10 intersects Ğ£Ñé·´¸´Ê§°Ü ¡ú 12s ³¬Ê±½µ¼¶Ô­Éúµã»÷
- ²éÑ¯Ìá½»Ê±»ú´íÂÒ ¡ú Bing ·şÎñ¶Ë²»¼ÇÂ¼ ¡ú 0 »ı·Ö£¨¼ÆÊı¶ÁÈ¡ÑéÖ¤Õı³££¬»á»°µÇÂ¼Ì¬ÑéÖ¤Õı³££©

### ĞŞ¸´£¨Search.ts + BrowserUtils.ts£©
1. ³õÊ¼»¯µ¼º½×·¼Ó waitForLoadState('networkidle', 15s) + wait(2000)£¨µÈÖØ¶¨Ïò+²¼¾ÖÎÈ¶¨£©
2. ËÑË÷¿ò waitFor 20s¡ú30s
3. ghostClick ´« maxTries:3£¨¼õÉÙÄÚ²¿ÖØÊÔ£©+ ³¬Ê± 12s¡ú25s
4. ËÑË÷¿ò½»»¥È«Ê§°Üºó URL Ö±½ÓËÑË÷¶µµ×£¨goto bing.com/search?q=£©
5. Ìá½»ºó URL ÑéÖ¤ÈÕÖ¾£¨Õï¶ÏÓÃ£©
6. unhandledRejection ¹ıÂËÆ÷À©Õ¹£ºProtocol error È«×å IGNORED£¨ĞÂ³öÏÖ Unable to adopt element handle ´íÎó£©

### ×îÖÕÑéÖ¤£¨ÑéÖ¤ÂÖ 6£©
- ×ÀÃæ¶ËËÑË÷ 51/51 È«ÄÃ£¨remaining 60¡ú0£©
- ×ÜÊÕ¼¯ +54 ·Ö£¨ÒÆ¶¯¶Ë +3 + ×ÀÃæ 51£©
- È«³ÌÁã±ÀÀ££¨ÓÄÁé rejection È«±» IGNORED£©
- RUN-END Õı³££¨110.9 ·ÖÖÓ£©

## ÊµÀı 1 ×ÀÃæ¶Ë¼Æ·ÖĞŞ¸´£¨08-03 Íí£©¡ª¡ª ×îÖÕ¸ùÒò£ºUA/Ö¸ÎÆÓë»á»°Ç©·¢²»Æ¥Åä

### ÍêÕû¸ùÒòÁ´£¨¶à¼ÙÉèÊµÖ¤ÅÅ³ı£©
1. ? cookie Óò¼ÙÉè£ºÊÖ¹¤¼Ó .msn.cn SID£¨Í¬Öµ¸´ÖÆ£©¡ú 0 ·Ö£»Õı¹æË«Óò SID£¨cn.bing.com Èë¿Ú + msn.cn ·ÃÎÊ´¥·¢£©¡ú ÈÔ 0 ·Ö
2. ? IP °ó¶¨¼ÙÉè£ºÊµÀı 2 Óë MCP ä¯ÀÀÆ÷ MSCC ¾ùÎª 120.230.220.205-CN£¨Í¬ IP£©¡ú ÅÅ³ı
3. ? »á»°ÓĞĞ§ĞÔ£ºMCP ä¯ÀÀÆ÷£¨Ç©·¢ UA£©ËÑË÷ +3 ·Ö ¡ú »á»°±¾ÉíÓĞĞ§
4. ? **UA/Ö¸ÎÆÆ¥Åä = ¸ùÒò**£ºBing ×ÀÃæ¼Æ·ÖĞ£ÑéËÑË÷ÇëÇó UA Óë SID Ç©·¢ UA Ò»ÖÂ¡£Íâ²¿£¨Playwright MCP£©Ç©·¢µÄ»á»°ÔÚÈİÆ÷ÄÚÊ¹ÓÃÊ±£¬ÈİÆ÷Ëæ»úÖ¸ÎÆ UA ¡Ù Ç©·¢ UA ¡ú ²»¼Æ·Ö£»ÊµÀı 2 ³É¹¦ÒòÎª»á»°ÈİÆ÷×ÔÇ©£¨UA ÌìÈ»Æ¥Åä£©

### ĞŞ¸´×é¼ş£¨ÊµÀı 1£©
1. session_fingerprint_desktop.json£ºfingerprint-generator Éú³ÉÍêÕûÖ¸ÎÆ + ¸²¸Ç UA Îª MCP ä¯ÀÀÆ÷µÄ Chrome/150.0.0.0£¨º¬ userAgentData/headers sec-ch-ua Í¬²½£©
2. session_desktop.json£º93 cookies£¨MCP µÇÂ¼ zj + ·ÃÎÊ www.msn.cn ´¥·¢ .msn.cn Óò¶ÀÁ¢ SID + ËÑË÷¼¤»î£©
3. ÈİÆ÷ÄÚ entrypoint.sh£ºsaveFingerprint.desktop false¡útrue£¨sed ĞŞ¸Ä£¬**ÖØ½¨ÈİÆ÷»á»¹Ô­**£©

### ÑéÖ¤½á¹û
- ×ÀÃæ¶Ë UA ÈÕÖ¾È·ÈÏ = Chrome/150.0.0.0£¨Ö¸ÎÆ×¢ÈëÉúĞ§£©
- Á¬ĞøÄÃ·Ö ¡ú 51/51 È«ÄÃ£¨3398¡ú3449£¬+51£©£¬RUN-END Õı³££¨107.9 ·ÖÖÓ£©
- ÊµÀı 2 ²»ÊÜÓ°Ïì£¨Î´¸Ä¶¯£©

### ?? Î¬»¤Òªµã£¨ÖØÒª£©
1. **ÖØ½¨ÈİÆ÷»á»¹Ô­ entrypoint.sh**£¨saveFingerprint »Ø false£©¡ú ĞèÖØ´ò sed
2. **»á»°»á¹ıÆÚ**£¨SID ÓĞÊ±Ğ§£©¡ú ¹ıÆÚºóĞèÓÃ Playwright MCP ÖØĞÂµÇÂ¼ zj£¨ÓÊÏä zj13713431458@outlook.com + TOTP£©¡ú ·ÃÎÊ cn.bing.com ËÑË÷Ò»´Î + ·ÃÎÊ www.msn.cn£¨´¥·¢ .msn.cn SID£©¡ú µ¼³ö cookies£¨×ß±¾µØ http server Í¨µÀ£©¡ú ²¿Êğ session_desktop.json
3. Ö¸ÎÆÎÄ¼şÎŞĞè¸üĞÂ£¨UA ¹Ì¶¨£©
4. ±¾µØ cookie server ½Å±¾£ºcookie-server2.js£¨18766 ¶Ë¿Ú£¬POST /save£©
