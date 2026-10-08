# 原始 .164 局部 http-activity-route

源：`out/main/index.js`；原始单行源码，SHA256 `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175`；Unicode字符半开范围 `[2265727,2266082)`，UTF-8字节半开范围 `[2281749,2282104)`；区间SHA256 `5fc52754c8542c1d98cc0ef4506405e80076eb35b810f67fa75d0d9ba3431538`。已从原文件精确substring复核；STATIC/NOT_EXECUTED，非完整运行模块。

## Source

```javascript
this.app.post("/api/pip/computer-use-activity",async(e,t)=>{try{const{noteComputerUseActivity:n}=await import("./chunks/computerUsePip-BTut449V.js");n({bundle:"string"==typeof e.body?.bundle?e.body.bundle:void 0,pid:"number"==typeof e.body?.pid?e.body.pid:void 0}),t.json({ok:!0})}catch(n){t.status(500).json({error:n?.message||"pip activity failed"})}}),
```
