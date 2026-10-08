# initialize 元数据原始常量片段

P153；原始 binary 的最小只读字节转录，未执行目标，也未复制相邻 instructions/prompt 字符串。VA 为arm64未slide地址。

- 原始路径：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/AlmaComputerUse.bin`
- universal SHA256：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`
- arm64 slice起点：0x128000；slice SHA256：`de569c288715c2e12243832aa61a02e671c497784c3d87d6dda9e9fc8d7d3fb4`
- 这些VA位于已核对的__TEXT/__DATA；slice offset=VA−0x100000000；universal offset=slice offset+0x128000

## tools capabilities

- VA：0x1000ad770；slice offset=710512；universal offset=1922928；length=56
- 消费D153行：90974–90979
- 片段SHA256：`88b2c5324802fbcb02a3defb34af8b3cfc96e3e125f7de04e1fc2c2bb6b62347`
- 研究性解码：String/Bool tuple数组count1，listChanged=false

```text
000ad770: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad780: 01 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00
000ad790: 6c 69 73 74 43 68 61 6e 67 65 64 00 00 00 00 eb
000ad7a0: 00 00 00 00 00 00 00 00
```

## prompts capabilities

- VA：0x1000ad7c0；slice offset=710592；universal offset=1923008；length=56
- 消费D153行：90998–91003
- 片段SHA256：`88b2c5324802fbcb02a3defb34af8b3cfc96e3e125f7de04e1fc2c2bb6b62347`
- 研究性解码：String/Bool tuple数组count1，listChanged=false

```text
000ad7c0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad7d0: 01 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00
000ad7e0: 6c 69 73 74 43 68 61 6e 67 65 64 00 00 00 00 eb
000ad7f0: 00 00 00 00 00 00 00 00
```

## resources capabilities

- VA：0x1000ad800；slice offset=710656；universal offset=1923072；length=80
- 消费D153行：91017–91022
- 片段SHA256：`834ee2b977a55876a6e06ef0c9df68366e9058e3f8a24ae63eb12d91904288cf`
- 研究性解码：String/Bool tuple数组count2，listChanged=true，subscribe=false

```text
000ad800: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad810: 02 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00
000ad820: 6c 69 73 74 43 68 61 6e 67 65 64 00 00 00 00 eb
000ad830: 01 00 00 00 00 00 00 00 73 75 62 73 63 72 69 62
000ad840: 65 00 00 00 00 00 00 e9 00 00 00 00 00 00 00 00
```

## serverInfo

- VA：0x1000ad868；slice offset=710760；universal offset=1923176；length=96
- 消费D153行：91066–91075
- 片段SHA256：`4a129eb8f7bc4bca97d95323bde751ab3e0ee94af8242baa8115b556347f03f6`
- 研究性解码：String/String tuple数组count2；name大字符串指针，version small-string为0.2

```text
000ad868: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
000ad878: 02 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00
000ad888: 6e 61 6d 65 00 00 00 00 00 00 00 00 00 00 00 e4
000ad898: 11 00 00 00 00 00 00 d0 00 17 09 00 00 08 50 01
000ad8a8: 76 65 72 73 69 6f 6e 00 00 00 00 00 00 00 00 e7
000ad8b8: 30 2e 32 00 00 00 00 00 00 00 00 00 00 00 00 e3
```

## serverInfo.name内容

- VA：0x100091720；slice offset=595744；universal offset=1808160；length=17
- 消费D153行：serverInfo tuple的chained rebase目标+0x20
- 片段SHA256：`a82b881054b82386e7920c31280b3efb10b8f4c2e9ef94e6e8b1cfcaeb8c90cf`
- 研究性解码：UTF8字符串alma-computer-use及末尾NUL

```text
00091720: 61 6c 6d 61 2d 63 6f 6d 70 75 74 65 72 2d 75 73
00091730: 65
```

