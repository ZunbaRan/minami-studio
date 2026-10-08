# 原始 .164 host 局部 iab-pip-route

源：`out/main/index.js` 第1行（原始打包单行文件）；全文件SHA256 `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175`。Unicode字符半开范围 `[2263552,2263981)`，对应UTF-8字节半开范围 `[2279574,2280003)`；原区间SHA256 `efed6c87e370aabac7bd4096e4821224d9cfe34fddff51a5b5a5004dec14dab7`。来源：官方 .164 mac-arm64 包已验证样本。证据强度：原始JS局部原文，STATIC/NOT_EXECUTED。本页是有界证据窗口，首尾可能处于相邻声明内，不是可运行模块；minified符号的重命名必须先对照具体函数。

## Source

```javascript
this.app.post("/api/iab/pip/:action",async(e,t)=>{try{const{showPreviewPip:n,hidePreviewPip:r,isPreviewPipOpen:o,getPreviewPipWorkspace:s}=await Promise.resolve().then(()=>hp),i=e.params.action,a=e.body?.workspace||$p.soleWorkspaceId();"show"===i?n(a):"hide"===i?(r(),$p.stopPipStreamFor(a)):"toggle"===i&&(o()?(r(),$p.stopPipStreamFor(a)):n(a)),t.json({open:o(),workspace:s()})}catch(n){t.status(500).json({error:n.message})}}),
```
