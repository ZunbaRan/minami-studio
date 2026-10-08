# 原始 .164 局部 http-frame-route

源：`out/main/index.js`；原始单行源码，SHA256 `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175`；Unicode字符半开范围 `[2263981,2264215)`，UTF-8字节半开范围 `[2280003,2280237)`；区间SHA256 `ef153c56ffd3fa63d4051640bf5751e85c018e86932e81a4b5468ecdf4bdf1f1`。已从原文件精确substring复核；STATIC/NOT_EXECUTED，非完整运行模块。

## Source

```javascript
this.app.get("/api/pip/frame",async(e,t)=>{try{const{pipFrameFor:n}=await import("./chunks/pipFrameSources-BwOu2Plt.js");t.json(await n(String(e.query?.item||"")))}catch(n){t.json({success:!1,error:n?.message||"pip frame failed"})}}),
```
