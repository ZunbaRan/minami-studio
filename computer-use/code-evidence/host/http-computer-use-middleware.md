# 原始 .164 局部 http-computer-use-middleware

源：`out/main/index.js`；原始单行源码，SHA256 `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175`；Unicode字符半开范围 `[2269418,2270066)`，UTF-8字节半开范围 `[2285440,2286088)`；区间SHA256 `7354bfa5e822adaebe0e3352d4037b0af0eb0f066c14b38bbad2530c1a7073e3`。已从原文件精确substring复核；STATIC/NOT_EXECUTED，非完整运行模块。

## Source

```javascript
this.app.use(["/api/computer-use/get_app_state","/api/computer-use/click","/api/computer-use/perform_secondary_action","/api/computer-use/drag","/api/computer-use/type","/api/computer-use/type_text","/api/computer-use/press","/api/computer-use/press_key","/api/computer-use/set_value","/api/computer-use/scroll","/api/computer-use/raise","/api/computer-use/launch_app"],(e,t,n)=>{(async()=>{try{const{noteComputerUseActivity:t}=await import("./chunks/computerUsePip-BTut449V.js");t({threadId:e.body?.threadId||void 0,bundle:"string"==typeof e.body?.bundle?e.body.bundle:void 0,pid:"number"==typeof e.body?.pid?e.body.pid:void 0})}catch{}})(),n()}),
```
