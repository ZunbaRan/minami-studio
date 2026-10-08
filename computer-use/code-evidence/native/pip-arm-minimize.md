# 原始反汇编节选 pip-arm-minimize

样本：用户提供 .153 universal helper；本页只用ARM64反汇编。helper SHA256 `b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`；ARM64 slice SHA256 `de569c288715c2e12243832aa61a02e671c497784c3d87d6dda9e9fc8d7d3fb4`。原文档路径 `alma-computer-use-0.4.153/evidence/disasm.annot.txt`；全文件SHA256 `543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`。

证据强度：原始二进制的既有带注释反汇编文本（STATIC、NOT_EXECUTED），不是厂商Swift源码，也不是本次运行结果。保留原注释便于复核，但自动字符串注释可能使用陈旧寄存器，结论必须从指令与分支推导。此页不能单独证明 .164 同行为；对应 .164 研究契约与跨版本局部核验分开引用。代码前的行号为原文件行号。

## L82785

### 已有session时disarm

原行范围 `82785–82824`（inclusive）；VA `0000000100050b98–0000000100050c34`；最近函数符号 `_$s4main16PIPMinimizeArmerC3arm8windowId3pid5titleys6UInt32V_s5Int32VSSSgtKFySo13AXObserverRefa_So011AXUIElementL0aSo08CFStringL0aSvSgtcfU_yyScMYccfU_TA:`；原区间SHA256 `4e21a67b0391edcc1a7f4a1a2fd29a72e4863bad3981f20fec9e5b4b4fa81e05`。

```asm
082785  0000000100050b98	bl	0x100089b90 ; symbol stub for: _swift_beginAccess
082786  0000000100050b9c	ldr	w23, [x19, #0x10]
082787  0000000100050ba0	adrp	x8, 95 ; 0x1000af000
082788  0000000100050ba4	ldr	x8, [x8, #0xff0]
082789  0000000100050ba8	cmn	x8, #0x1
082790  0000000100050bac	b.ne	0x100050e7c
082791  0000000100050bb0	adrp	x8, 93 ; 0x1000ad000
082792  0000000100050bb4	ldr	x21, [x8, #0xed0]
082793  0000000100050bb8	ldr	x0, [x21, #0x18]
082794  0000000100050bbc	bl	_objc_msgSend$lock
082795  0000000100050bc0	add	x0, x21, #0x10
082796  0000000100050bc4	add	x1, sp, #0x48
082797  0000000100050bc8	mov	w2, #0x20
082798  0000000100050bcc	mov	x3, #0x0
082799  0000000100050bd0	bl	0x100089b90 ; symbol stub for: _swift_beginAccess
082800  0000000100050bd4	ldr	x20, [x21, #0x10]
082801  0000000100050bd8	ldr	x8, [x20, #0x10]
082802  0000000100050bdc	cbz	x8, 0x100050c0c
082803  0000000100050be0	mov	x0, x23
082804  0000000100050be4	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFs5Int32V_Tg5
082805  0000000100050be8	tbz	w1, #0x0, 0x100050c0c
082806  0000000100050bec	add	x0, sp, #0x48
082807  0000000100050bf0	bl	0x100089c98 ; symbol stub for: _swift_endAccess
082808  0000000100050bf4	ldr	x0, [x21, #0x18]
082809  0000000100050bf8	bl	_objc_msgSend$unlock
082810  0000000100050bfc	mov	x0, x23
082811  0000000100050c00	mov	x20, x25
082812  0000000100050c04	bl	_$s4main16PIPMinimizeArmerC6disarm8windowIdSbs6UInt32V_tF
082813  0000000100050c08	b	0x100050e5c
082814  0000000100050c0c	add	x0, sp, #0x48
082815  0000000100050c10	bl	0x100089c98 ; symbol stub for: _swift_endAccess
082816  0000000100050c14	ldr	x0, [x21, #0x18]
082817  0000000100050c18	bl	_objc_msgSend$unlock
082818  0000000100050c1c	ldr	x19, [x25, #0x18]
082819  0000000100050c20	mov	x0, x19
082820  0000000100050c24	bl	_objc_msgSend$lock
082821  0000000100050c28	add	x0, x25, #0x10
082822  0000000100050c2c	add	x1, sp, #0x30
082823  0000000100050c30	mov	w2, #0x20
082824  0000000100050c34	mov	x3, #0x0
```

## L82845

### 成功open

原行范围 `82845–82873`（inclusive）；VA `0000000100050c88–0000000100050cf8`；最近函数符号 `_$s4main16PIPMinimizeArmerC3arm8windowId3pid5titleys6UInt32V_s5Int32VSSSgtKFySo13AXObserverRefa_So011AXUIElementL0aSo08CFStringL0aSvSgtcfU_yyScMYccfU_TA:`；原区间SHA256 `ce8053f063cd9eaefaae28eeab402a89d9e11b148b9f1bcb11a868ad1cd0f7e2`。

```asm
082845  0000000100050c88	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
082846  0000000100050c8c	mov	x26, x22
082847  0000000100050c90	b	0x100050c9c
082848  0000000100050c94	mov	x27, #0x0
082849  0000000100050c98	mov	x26, #0x0
082850  0000000100050c9c	mov	x0, x23
082851  0000000100050ca0	mov	x1, x20
082852  0000000100050ca4	mov	x2, x27
082853  0000000100050ca8	mov	x3, x26
082854  0000000100050cac	mov	x4, #0x0
082855  0000000100050cb0	mov	x5, #0x0
082856  0000000100050cb4	mov	w6, #0x1
082857  0000000100050cb8	mov	x20, x21
082858  0000000100050cbc	mov	x21, #0x0
082859  0000000100050cc0	bl	_$s4main10PIPManagerC4open8windowId3pid5title13preferredSizeSDySSypSgGs6UInt32V_s5Int32VSgSSSgSo6CGSizeVSgtKF
082860  0000000100050cc4	cbz	x21, 0x100050e2c
082861  0000000100050cc8	mov	x0, x26
082862  0000000100050ccc	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
082863  0000000100050cd0	adrp	x8, 90 ; 0x1000aa000
082864  0000000100050cd4	ldr	x0, [x8, #0x458] ; Objc class ref: bad class ref
082865  0000000100050cd8	bl	0x100089ac4 ; symbol stub for: _objc_opt_self
082866  0000000100050cdc	bl	_objc_msgSend$fileHandleWithStandardError
082867  0000000100050ce0	mov	x29, x29
082868  0000000100050ce4	bl	0x100089af4 ; symbol stub for: _objc_retainAutoreleasedReturnValue
082869  0000000100050ce8	mov	x25, x0
082870  0000000100050cec	mov	x8, #-0x2000000000000000
082871  0000000100050cf0	stp	xzr, x8, [sp, #0x30]
082872  0000000100050cf4	add	x20, sp, #0x30
082873  0000000100050cf8	mov	w0, #0x2f
```

## L82925

### 失败保留与成功disarm

原行范围 `82925–82970`（inclusive）；VA `0000000100050dc8–0000000100050e7c`；最近函数符号 `_$s4main16PIPMinimizeArmerC3arm8windowId3pid5titleys6UInt32V_s5Int32VSSSgtKFySo13AXObserverRefa_So011AXUIElementL0aSo08CFStringL0aSvSgtcfU_yyScMYccfU_TA:`；原区间SHA256 `c85960b779dadc37bda858f36bea38ff51f8a6d11159cdd0fbbccb5f82602835`。

```asm
082925  0000000100050dc8	ldp	x0, x1, [sp, #0x30]
082926  0000000100050dcc	bl	_$s10Foundation4DataVyACxcSTRzs5UInt8V7ElementRtzlufCSS8UTF8ViewV_Tt0g5
082927  0000000100050dd0	mov	x20, x0
082928  0000000100050dd4	mov	x23, x1
082929  0000000100050dd8	bl	0x100088a20 ; symbol stub for: _$s10Foundation4DataV19_bridgeToObjectiveCSo6NSDataCyF
082930  0000000100050ddc	mov	x26, x0
082931  0000000100050de0	mov	x0, x20
082932  0000000100050de4	mov	x1, x23
082933  0000000100050de8	bl	_$s10Foundation4DataV15_RepresentationOWOe
082934  0000000100050dec	mov	x0, x25
082935  0000000100050df0	mov	x2, x26
082936  0000000100050df4	bl	"_objc_msgSend$writeData:"
082937  0000000100050df8	mov	x0, x24
082938  0000000100050dfc	bl	0x100089ad0 ; symbol stub for: _objc_release
082939  0000000100050e00	mov	x0, x22
082940  0000000100050e04	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
082941  0000000100050e08	mov	x0, x19
082942  0000000100050e0c	bl	0x100089ad0 ; symbol stub for: _objc_release
082943  0000000100050e10	mov	x0, x25
082944  0000000100050e14	bl	0x100089ad0 ; symbol stub for: _objc_release
082945  0000000100050e18	mov	x0, x26
082946  0000000100050e1c	bl	0x100089ad0 ; symbol stub for: _objc_release
082947  0000000100050e20	mov	x0, x21
082948  0000000100050e24	bl	0x100089ca4 ; symbol stub for: _swift_errorRelease
082949  0000000100050e28	b	0x100050e5c
082950  0000000100050e2c	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
082951  0000000100050e30	mov	x0, x26
082952  0000000100050e34	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
082953  0000000100050e38	mov	x0, x23
082954  0000000100050e3c	mov	x20, x25
082955  0000000100050e40	bl	_$s4main16PIPMinimizeArmerC6disarm8windowIdSbs6UInt32V_tF
082956  0000000100050e44	mov	x0, x24
082957  0000000100050e48	bl	0x100089ad0 ; symbol stub for: _objc_release
082958  0000000100050e4c	mov	x0, x22
082959  0000000100050e50	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
082960  0000000100050e54	mov	x0, x19
082961  0000000100050e58	bl	0x100089ad0 ; symbol stub for: _objc_release
082962  0000000100050e5c	ldp	x29, x30, [sp, #0xc0]
082963  0000000100050e60	ldp	x20, x19, [sp, #0xb0]
082964  0000000100050e64	ldp	x22, x21, [sp, #0xa0]
082965  0000000100050e68	ldp	x24, x23, [sp, #0x90]
082966  0000000100050e6c	ldp	x26, x25, [sp, #0x80]
082967  0000000100050e70	ldp	x28, x27, [sp, #0x70]
082968  0000000100050e74	add	sp, sp, #0xd0
082969  0000000100050e78	ret
082970  0000000100050e7c	adrp	x0, 95 ; 0x1000af000
```
