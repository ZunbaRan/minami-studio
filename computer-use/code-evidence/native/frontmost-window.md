# 原始反汇编节选 frontmost-window

样本：用户提供 .153 universal helper；本页只用ARM64反汇编。helper SHA256 `b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`；ARM64 slice SHA256 `de569c288715c2e12243832aa61a02e671c497784c3d87d6dda9e9fc8d7d3fb4`。原文档路径 `alma-computer-use-0.4.153/evidence/disasm.annot.txt`；全文件SHA256 `543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`。

证据强度：原始二进制的既有带注释反汇编文本（STATIC、NOT_EXECUTED），不是厂商Swift源码，也不是本次运行结果。保留原注释便于复核，但自动字符串注释可能使用陈旧寄存器，结论必须从指令与分支推导。此页不能单独证明 .164 同行为；对应 .164 研究契约与跨版本局部核验分开引用。代码前的行号为原文件行号。

## L113230

### layer转换与pid>=1 guard

原行范围 `113230–113292`（inclusive）；VA `000000010006e06c–000000010006e164`；最近函数符号 `_$s4main7AppshotO15frontmostWindow15excludeBundleIdAC09FrontmostD0VSgSSSg_tFZ:`；原区间SHA256 `5ab8d3c12101ba2767b3494f572c33f92f174ad1263981a9c9bd576976caf5bc`。

```asm
113230  000000010006e06c	mov	x0, x23
113231  000000010006e070	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
113232  000000010006e074	add	x0, sp, #0x38
113233  000000010006e078	add	x1, sp, #0xc0
113234  000000010006e07c	add	x2, x24, #0x8
113235  000000010006e080	adrp	x3, 50 ; 0x1000a0000
113236  000000010006e084	ldr	x3, [x3, #0xa60] ; literal pool symbol address: _$sSiN
113237  000000010006e088	mov	w4, #0x6
113238  000000010006e08c	bl	0x100089c50 ; symbol stub for: _swift_dynamicCast
113239  000000010006e090	tbz	w0, #0x0, 0x10006e0bc
113240  000000010006e094	ldr	x8, [sp, #0x38]
113241  000000010006e098	cbnz	x8, 0x10006e528
113242  000000010006e09c	b	0x10006e0bc
113243  000000010006e0a0	mov	x0, x21
113244  000000010006e0a4	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
113245  000000010006e0a8	b	0x10006e0b4
113246  000000010006e0ac	mov	x0, x21
113247  000000010006e0b0	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
113248  000000010006e0b4	mov	x0, x23
113249  000000010006e0b8	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
113250  000000010006e0bc	ldr	x0, [sp, #0x30]
113251  000000010006e0c0	bl	0x100088d98 ; symbol stub for: _$sSS10FoundationE36_unconditionallyBridgeFromObjectiveCySSSo8NSStringCSgFZ
113252  000000010006e0c4	mov	x23, x1
113253  000000010006e0c8	ldr	x8, [x21, #0x10]
113254  000000010006e0cc	cbz	x8, 0x10006e1ec
113255  000000010006e0d0	mov	x20, x0
113256  000000010006e0d4	mov	x0, x21
113257  000000010006e0d8	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
113258  000000010006e0dc	mov	x0, x20
113259  000000010006e0e0	mov	x1, x23
113260  000000010006e0e4	mov	x20, x21
113261  000000010006e0e8	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
113262  000000010006e0ec	tbz	w1, #0x0, 0x10006e1e0
113263  000000010006e0f0	ldr	x8, [x21, #0x38]
113264  000000010006e0f4	add	x0, x8, x0, lsl #5
113265  000000010006e0f8	add	x1, sp, #0xc0
113266  000000010006e0fc	bl	_$sypWOc
113267  000000010006e100	mov	x0, x21
113268  000000010006e104	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
113269  000000010006e108	mov	x0, x23
113270  000000010006e10c	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
113271  000000010006e110	add	x0, sp, #0x38
113272  000000010006e114	add	x1, sp, #0xc0
113273  000000010006e118	add	x2, x24, #0x8
113274  000000010006e11c	adrp	x3, 50 ; 0x1000a0000
113275  000000010006e120	ldr	x3, [x3, #0xd58] ; literal pool symbol address: _$ss5Int32VN
113276  000000010006e124	mov	w4, #0x6
113277  000000010006e128	bl	0x100089c50 ; symbol stub for: _swift_dynamicCast
113278  000000010006e12c	tbz	w0, #0x0, 0x10006e528
113279  000000010006e130	ldr	w23, [sp, #0x38]
113280  000000010006e134	cmp	w23, #0x1
113281  000000010006e138	b.lt	0x10006e528
113282  000000010006e13c	adrp	x8, 60 ; 0x1000aa000
113283  000000010006e140	ldr	x0, [x8, #0x490] ; Objc class ref: bad class ref
113284  000000010006e144	bl	0x100089ac4 ; symbol stub for: _objc_opt_self
113285  000000010006e148	mov	x2, x23
113286  000000010006e14c	bl	"_objc_msgSend$runningApplicationWithProcessIdentifier:"
113287  000000010006e150	mov	x29, x29
113288  000000010006e154	bl	0x100089af4 ; symbol stub for: _objc_retainAutoreleasedReturnValue
113289  000000010006e158	cbz	x0, 0x10006e528
113290  000000010006e15c	str	x0, [sp, #0x28]
113291  000000010006e160	ldr	x24, [sp, #0x20]
113292  000000010006e164	cbz	x24, 0x10006e254
```
