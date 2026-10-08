# .153 静态目录原始数据最小片段

性质：P153 原始二进制只读字节转录；没有执行目标。只包含目录计数、短协议字段名、枚举值及一个错误码，未附带二进制。

- 原始路径：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/AlmaComputerUse.bin`
- universal 文件 SHA256：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`
- arm64 slice：universal offset `1212416`，长度 `1164096`
- arm64 slice SHA256：`de569c288715c2e12243832aa61a02e671c497784c3d87d6dda9e9fc8d7d3fb4`
- VA 映射：本页所有取样均在已核实的 `__TEXT`/`__DATA` 映射，slice offset = VA − `0x100000000`；universal offset 再加 slice offset `1212416`
- String 数组形状：头部 +0x10 为元素数；+0x20 起每元素16字节；本页数组元素均为 Swift small-string，末字节低4bit 为 UTF-8 长度
- 行号为同目录反汇编文件的消费调用点；原始 binary 没有文本行号

## tools array header

- VA `0x10008deb0`；slice offset `581296`；universal offset `1793712`；长度 `16` bytes
- 片段 SHA256：`867464c24d9211ca6913b97a28ea96159314b2e173cf6969e97b4103f3e4b73d`
- 研究性解码：UInt64 tuple=(14,28)，静态工具数组元素数14

```text
0008deb0: 0e 00 00 00 00 00 00 00 1c 00 00 00 00 00 00 00
```

## button enum

- VA `0x1000ad118`；slice offset `708888`；universal offset `1921304`；长度 `80` bytes
- 片段 SHA256：`6a54bc7c18b7bbd3abeab89484c98ea27c4952206ed60bf242b7916cb0585b24`
- 消费调用点：D153:95548
- 研究性解码：count=3；有序值 `['left', 'right', 'middle']`

```text
000ad118: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad128: 03 00 00 00 00 00 00 00 06 00 00 00 00 00 00 00
000ad138: 6c 65 66 74 00 00 00 00 00 00 00 00 00 00 00 e4
000ad148: 72 69 67 68 74 00 00 00 00 00 00 00 00 00 00 e5
000ad158: 6d 69 64 64 6c 65 00 00 00 00 00 00 00 00 00 e6
```

## coord_space enum

- VA `0x1000ad170`；slice offset `708976`；universal offset `1921392`；长度 `64` bytes
- 片段 SHA256：`18eff482b6136ab1827a723b64f17de5f155177a33dcacaa4af901ae2d11541d`
- 消费调用点：D153:95839
- 研究性解码：count=2；有序值 `['screen', 'screenshot']`

```text
000ad170: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad180: 02 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00
000ad190: 73 63 72 65 65 6e 00 00 00 00 00 00 00 00 00 e6
000ad1a0: 73 63 72 65 65 6e 73 68 6f 74 00 00 00 00 00 ea
```

## input_method enum

- VA `0x1000ad1b8`；slice offset `709048`；universal offset `1921464`；长度 `96` bytes
- 片段 SHA256：`6c99c96a6bd8973ab3af01920032a5b2b217bf9bc2436fffc2618cb3a17f94f4`
- 消费调用点：D153:96451
- 研究性解码：count=4；有序值 `['auto', 'physical', 'unicode', 'ax']`

```text
000ad1b8: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad1c8: 04 00 00 00 00 00 00 00 08 00 00 00 00 00 00 00
000ad1d8: 61 75 74 6f 00 00 00 00 00 00 00 00 00 00 00 e4
000ad1e8: 70 68 79 73 69 63 61 6c 00 00 00 00 00 00 00 e8
000ad1f8: 75 6e 69 63 6f 64 65 00 00 00 00 00 00 00 00 e7
000ad208: 61 78 00 00 00 00 00 00 00 00 00 00 00 00 00 e2
```

## type_text.required

- VA `0x1000ad220`；slice offset `709152`；universal offset `1921568`；长度 `48` bytes
- 片段 SHA256：`9e5bd1b44a2564c48f6433b0a19a0847f2b160ec416c28311fc1648d69096bc3`
- 消费调用点：D153:96757
- 研究性解码：count=1；有序值 `['text']`

```text
000ad220: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad230: 01 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00
000ad240: 74 65 78 74 00 00 00 00 00 00 00 00 00 00 00 e4
```

## press_key.required

- VA `0x1000ad258`；slice offset `709208`；universal offset `1921624`；长度 `48` bytes
- 片段 SHA256：`79074c3f071b4a44244d3dfa312929e83e8cf78408f2863ac9c04fb37dc59c6a`
- 消费调用点：D153:97119
- 研究性解码：count=1；有序值 `['combo']`

```text
000ad258: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad268: 01 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00
000ad278: 63 6f 6d 62 6f 00 00 00 00 00 00 00 00 00 00 e5
```

## direction enum

- VA `0x1000ad290`；slice offset `709264`；universal offset `1921680`；长度 `96` bytes
- 片段 SHA256：`a050606b6db26252814c2d301c60cdcc1cf58dfd3a38171eb1387b015429c717`
- 消费调用点：D153:97265
- 研究性解码：count=4；有序值 `['up', 'down', 'left', 'right']`

```text
000ad290: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad2a0: 04 00 00 00 00 00 00 00 08 00 00 00 00 00 00 00
000ad2b0: 75 70 00 00 00 00 00 00 00 00 00 00 00 00 00 e2
000ad2c0: 64 6f 77 6e 00 00 00 00 00 00 00 00 00 00 00 e4
000ad2d0: 6c 65 66 74 00 00 00 00 00 00 00 00 00 00 00 e4
000ad2e0: 72 69 67 68 74 00 00 00 00 00 00 00 00 00 00 e5
```

## scroll.required

- VA `0x1000ad2f8`；slice offset `709368`；universal offset `1921784`；长度 `64` bytes
- 片段 SHA256：`30fde987206d60cf40d911c247738f17f0bc88e3dbfc7b373c395047900d8e27`
- 消费调用点：D153:97589
- 研究性解码：count=2；有序值 `['ref', 'direction']`

```text
000ad2f8: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad308: 02 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00
000ad318: 72 65 66 00 00 00 00 00 00 00 00 00 00 00 00 e3
000ad328: 64 69 72 65 63 74 69 6f 6e 00 00 00 00 00 00 e9
```

## screenshot.required

- VA `0x1000ad340`；slice offset `709440`；universal offset `1921856`；长度 `48` bytes
- 片段 SHA256：`743da39559e78e6a9c46a695b8e8e22ae95b8a95d5a94e89ae181606c0e0519f`
- 消费调用点：D153:98227
- 研究性解码：count=1；有序值 `['out']`

```text
000ad340: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad350: 01 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00
000ad360: 6f 75 74 00 00 00 00 00 00 00 00 00 00 00 00 e3
```

## open_url.required

- VA `0x1000ad378`；slice offset `709496`；universal offset `1921912`；长度 `48` bytes
- 片段 SHA256：`b95822bbf7fc088c58cc38cc7a56c89fb10de692f3bc0f6fca0eafa6b44fc116`
- 消费调用点：D153:98387
- 研究性解码：count=1；有序值 `['url']`

```text
000ad378: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad388: 01 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00
000ad398: 75 72 6c 00 00 00 00 00 00 00 00 00 00 00 00 e3
```

## intent.required

- VA `0x1000ad3b0`；slice offset `709552`；universal offset `1921968`；长度 `64` bytes
- 片段 SHA256：`ac05af120ee44a4a22849a7ecb3149269e694889aa0cdd7f210b84d0918b1602`
- 消费调用点：D153:98752
- 研究性解码：count=2；有序值 `['bundle', 'intent']`

```text
000ad3b0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad3c0: 02 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00
000ad3d0: 62 75 6e 64 6c 65 00 00 00 00 00 00 00 00 00 e6
000ad3e0: 69 6e 74 65 6e 74 00 00 00 00 00 00 00 00 00 e6
```

## Daemon not attached error code

- VA `0x10008dea0`；slice offset `581280`；universal offset `1793696`；长度 `16` bytes
- 片段 SHA256：`07e34dba016b633f5f40cc05cd1d617161f7593885e00479f30738aa5da34743`
- 消费调用点：D153:92477
- 研究性解码：Int64首值=-32000；后8字节是消息字符串描述字

```text
0008dea0: 00 83 ff ff ff ff ff ff 13 00 00 00 00 00 00 d0
```

