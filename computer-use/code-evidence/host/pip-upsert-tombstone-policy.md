# 原始 .164 局部 pip-upsert-tombstone-policy

源：`out/main/index.js`；原始单行源码，SHA256 `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175`；Unicode字符半开范围 `[422210,422476)`，UTF-8字节半开范围 `[423710,423976)`；区间SHA256 `10762e7c3933416f351144d6636b0702d2c136707034d85afbd94c7830608660`。已从原文件精确substring复核；STATIC/NOT_EXECUTED，非完整运行模块。

## Source

```javascript
function np({auto:e,...t}){if(e){if(!Dh.has(t.id)&&function(e){const t=jh(e),n=Bh.get(t);if(void 0===n)return!1;const r=Date.now();return r-n>6e5?(Bh.delete(t),!1):(Bh.set(t,r),!0)}(t))return}else for(const n of[...Bh.keys()])n.startsWith(`${t.id}\0`)&&Bh.delete(n);
```
