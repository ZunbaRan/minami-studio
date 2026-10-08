# 原始 .164 局部 activity-enable-note-end

源：`out/main/chunks/computerUsePip-BTut449V.js`；原始单行源码，SHA256 `cb01bc4f46b21b8077448b5737900de7ac30c7d1a09651d029e0d4eea118c8e2`；Unicode字符半开范围 `[2722,3569)`，UTF-8字节半开范围 `[2722,3569)`；区间SHA256 `521e66ab06983ba8fca1cbfd6bb16131cbbefd180bdc417d55c0238f2423ef16`。已从原文件精确substring复核；STATIC/NOT_EXECUTED，非完整运行模块。

## Source

```javascript
const s="computer:desktop";let d=null,l=null;function a(o){if(!o)return;const t=o.split(".").pop();return t?t.replace(/[-_]+/g," ").replace(/([a-z])([A-Z])/g,"$1 $2").replace(/^./,o=>o.toUpperCase()):void 0}function c(){try{const o=e.getSettings();return!o?.settingsData||!1!==JSON.parse(o.settingsData)?.computerUsePipEnabled}catch{return!0}}function f(o={}){if(m(),c()){(o.bundle||"number"==typeof o.pid)&&(l={bundle:o.bundle,pid:o.pid});try{p({auto:!0,id:s,kind:"computer",label:o.label||a(l?.bundle)||"Screen",threadId:o.threadId,displayId:o.displayId,targetBundle:l?.bundle,targetPid:l?.pid})}catch{return}d&&clearTimeout(d),d=setTimeout(()=>{u()},9e4)}}function u(){d&&(clearTimeout(d),d=null),l=null,r(s)&&(n(s),i(s))}export{s as COMPUTER_PIP_ITEM_ID,u as endComputerUsePipSession,c as isComputerUsePipEnabled,f as noteComputerUseActivity};
```
