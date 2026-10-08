# 原始 .164 局部 pump-and-stop

源：`out/main/chunks/pipFrameSources-BwOu2Plt.js`；原始单行源码，SHA256 `2627830c47678782aec65d856900f02dbad07a00c15bb5f27a4a13c79db4717c`；Unicode字符半开范围 `[2697,3911)`，UTF-8字节半开范围 `[2697,3913)`；区间SHA256 `700247c7cc551714a91a9c0431b3613024e3a020c68f1340a6d98051cf9c9f79`。已从原文件精确substring复核；STATIC/NOT_EXECUTED，非完整运行模块。

## Source

```javascript
const d=new Map;function c(o,t){if(d.has(o))return;const a=function(o){const t=o.replace(/[^a-zA-Z0-9_-]+/g,"_");return e.join(i.tmpdir(),`alma-pip-${t}.jpg`)}(o),c={outPath:a,inFlight:!1,timer:setInterval(async()=>{if(c.inFlight)Date.now()-(c.inFlightSince??0)>4e3&&(console.warn("[PIP] desktop capture wedged past watchdog — dropping it and retrying"),c.inFlight=!1);else if(!(p()<1200)){c.inFlight=!0,c.inFlightSince=Date.now();try{const i=n(o),e=i?.targetBundle,p=i?.targetPid;let d=null;if(e||"number"==typeof p)try{d=await s.shot({out:a,max_width:1024,...e?{bundle:e}:{},..."number"==typeof p?{pid:p}:{}})}catch{d=null}d||(d=await s.shotDisplay({out:a,max_width:1024,quality:.5,..."number"==typeof t?{display_id:t}:{}})),m(o,d.width,d.height),c.cursor=d.cursor,c.latest=r.readFileSync(a).toString("base64"),c.failures=0}catch(i){c.failures=(c.failures??0)+1,1!==c.failures&&c.failures%15!=0||console.warn(`[PIP] desktop capture failed (${c.failures}x): ${i instanceof Error?i.message:String(i)}`)}finally{c.inFlight=!1}}},Math.round(1e3/3))};d.set(o,c)}function l(o){const t=d.get(o);if(t){clearInterval(t.timer),d.delete(o);try{r.unlinkSync(t.outPath)}catch{}}}function f(){for(const o of[...d.keys()])l(o)}
```
