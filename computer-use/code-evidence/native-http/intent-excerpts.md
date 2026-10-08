# AppCommandRegistry：.153 原始证据摘录

仅静态读取；未运行目标二进制、注册 intent、原始探针或示例业务 ID。本文不等于 Swift 原源码。反汇编中的注释由输入文件原样保留；编译器立即数与二进制数据的解释另标为研究解释。所有 VA 为 .153 arm64 未加 slide 的地址。

强度标签：P153 = 本次直接读取 .153 原始反汇编／二进制；C164 = 既有 .164 契约（不是本次新验证）；R = 研究解释或独立实现建议；U = 未闭合。每个代码块是注明范围的连续原文，未做语义性修订。


## I01 — 精确 bundle 查询与未注册返回空数组

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46989–47027`（闭区间）
- VA：`0x10002e868–0x10002e900`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7intents3forSayAC6IntentVGSS_tFZ`

```asm
000000010002e868	mov	x19, x1
000000010002e86c	mov	x21, x0
000000010002e870	adrp	x8, 129 ; 0x1000af000
000000010002e874	ldr	x8, [x8, #0x5d0]
000000010002e878	cmn	x8, #0x1
000000010002e87c	b.ne	0x10002e8ec
000000010002e880	adrp	x8, 129 ; 0x1000af000
000000010002e884	ldr	x20, [x8, #0x5d8]
000000010002e888	ldr	x8, [x20, #0x10]
000000010002e88c	cbz	x8, 0x10002e8bc
000000010002e890	mov	x0, x20
000000010002e894	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e898	mov	x0, x21
000000010002e89c	mov	x1, x19
000000010002e8a0	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e8a4	tbz	w1, #0x0, 0x10002e8c8
000000010002e8a8	ldr	x8, [x20, #0x38]
000000010002e8ac	ldr	x19, [x8, x0, lsl #3]
000000010002e8b0	mov	x0, x19
000000010002e8b4	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e8b8	b	0x10002e8d0
000000010002e8bc	adrp	x19, 114 ; 0x1000a0000
000000010002e8c0	ldr	x19, [x19, #0xe78] ; literal pool symbol address: __swiftEmptyArrayStorage
000000010002e8c4	b	0x10002e8d8
000000010002e8c8	adrp	x19, 114 ; 0x1000a0000
000000010002e8cc	ldr	x19, [x19, #0xe78] ; literal pool symbol address: __swiftEmptyArrayStorage
000000010002e8d0	mov	x0, x20
000000010002e8d4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e8d8	mov	x0, x19
000000010002e8dc	ldp	x29, x30, [sp, #0x20]
000000010002e8e0	ldp	x20, x19, [sp, #0x10]
000000010002e8e4	ldp	x22, x21, [sp], #0x30
000000010002e8e8	ret
000000010002e8ec	adrp	x0, 129 ; 0x1000af000
000000010002e8f0	add	x0, x0, #0x5d0
000000010002e8f4	adrp	x1, -1 ; 0x10002d000
000000010002e8f8	add	x1, x1, #0x8
000000010002e8fc	bl	0x100089d88 ; symbol stub for: _swift_once
000000010002e900	b	0x10002e880
```


## I02 — dispatch 的精确 bundle、intent 名称匹配

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47065–47104`（闭区间）
- VA：`0x10002e990–0x10002ea2c`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002e990	adrp	x8, 129 ; 0x1000af000
000000010002e994	ldr	x20, [x8, #0x5d8]
000000010002e998	ldr	x8, [x20, #0x10]
000000010002e99c	cbz	x8, 0x10002eac8
000000010002e9a0	str	x9, [x19, #0x20]
000000010002e9a4	mov	x0, x20
000000010002e9a8	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e9ac	mov	x0, x26
000000010002e9b0	mov	x1, x22
000000010002e9b4	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e9b8	tbz	w1, #0x0, 0x10002eac0
000000010002e9bc	str	x24, [x19, #0x18]
000000010002e9c0	ldr	x8, [x20, #0x38]
000000010002e9c4	ldr	x25, [x8, x0, lsl #3]
000000010002e9c8	mov	x0, x25
000000010002e9cc	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e9d0	mov	x0, x20
000000010002e9d4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e9d8	ldr	x24, [x25, #0x10]
000000010002e9dc	cbz	x24, 0x10002ed4c
000000010002e9e0	stp	x26, x22, [x19, #0x8]
000000010002e9e4	mov	w20, #0x20
000000010002e9e8	mov	x22, x24
000000010002e9ec	add	x8, x25, x20
000000010002e9f0	ldp	q0, q1, [x8, #0x20]
000000010002e9f4	ldp	q3, q2, [x8]
000000010002e9f8	stp	q0, q1, [x19, #0x90]
000000010002e9fc	stp	q3, q2, [x19, #0x70]
000000010002ea00	ldp	x0, x1, [x19, #0x70]
000000010002ea04	cmp	x0, x28
000000010002ea08	ccmp	x1, x23, #0x0, eq
000000010002ea0c	b.eq	0x10002eb84
000000010002ea10	mov	x2, x28
000000010002ea14	mov	x3, x23
000000010002ea18	mov	w4, #0x0
000000010002ea1c	bl	0x1000893a4 ; symbol stub for: _$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF
000000010002ea20	tbnz	w0, #0x0, 0x10002eb84
000000010002ea24	add	x20, x20, #0x40
000000010002ea28	subs	x22, x22, #0x1
000000010002ea2c	b.ne	0x10002e9ec
```


## I03 — 未注册 bundle 的 invalidArg 分支

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47143–47174`（闭区间）
- VA：`0x10002eac8–0x10002eb44`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002eac8	mov	x8, #-0x2000000000000000
000000010002eacc	stp	xzr, x8, [x19, #0x70]
000000010002ead0	add	x20, x19, #0x70
000000010002ead4	mov	w0, #0x71
000000010002ead8	bl	0x100089260 ; symbol stub for: _$ss11_StringGutsV4growyySiF
000000010002eadc	ldp	x8, x9, [x19, #0x70]
000000010002eae0	stp	x8, x9, [x19, #0x70]
000000010002eae4	adrp	x8, 97 ; 0x10008f000
000000010002eae8	add	x8, x8, #0xb40 ; literal pool for: "no intents registered for bundle \""   ; "no intents registered for bundle ""
000000010002eaec	sub	x8, x8, #0x20
000000010002eaf0	mov	x9, #0x12
000000010002eaf4	movk	x9, #0xd000, lsl #48
000000010002eaf8	add	x0, x9, #0x10
000000010002eafc	orr	x1, x8, #0x8000000000000000
000000010002eb00	add	x20, x19, #0x70
000000010002eb04	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002eb08	add	x20, x19, #0x70
000000010002eb0c	mov	x0, x26
000000010002eb10	mov	x1, x22
000000010002eb14	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002eb18	adrp	x8, 97 ; 0x10008f000
000000010002eb1c	add	x8, x8, #0xb70 ; literal pool for: "\" \342\200\224 either add it to AppCommandRegistry, or use `click`/`type_text` instead"   ; "" — either add it to AppCommandRegistry, or use `click`/`type_text` instead"
000000010002eb20	sub	x8, x8, #0x20
000000010002eb24	orr	x1, x8, #0x8000000000000000
000000010002eb28	add	x20, x19, #0x70
000000010002eb2c	mov	x0, #0x4d
000000010002eb30	movk	x0, #0x1000, lsl #48
000000010002eb34	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002eb38	ldp	x0, x20, [x19, #0x70]
000000010002eb3c	sub	x8, x29, #0x88
000000010002eb40	mov	x1, x20
000000010002eb44	bl	_$s4main7CUErrorV10invalidArgyACSSFZ
```


## I04 — 按 requiredParams 顺序只检查键存在，然后一次调用 builder

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47195–47235`（闭区间）
- VA：`0x10002eb98–0x10002ec38`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002eb98	ldr	x26, [x19, #0x90]
000000010002eb9c	ldr	x8, [x26, #0x10]
000000010002eba0	str	x8, [x19, #0x28]
000000010002eba4	cbz	x8, 0x10002ec28
000000010002eba8	str	x28, [x19]
000000010002ebac	mov	x0, x26
000000010002ebb0	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002ebb4	mov	x28, #0x0
000000010002ebb8	add	x22, x26, #0x28
000000010002ebbc	ldr	x8, [x26, #0x10]
000000010002ebc0	cmp	x28, x8
000000010002ebc4	b.hs	0x10002f058
000000010002ebc8	ldp	x25, x24, [x22, #-0x8]
000000010002ebcc	ldr	x21, [x27, #0x10]
000000010002ebd0	mov	x0, x24
000000010002ebd4	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002ebd8	cbz	x21, 0x10002ef44
000000010002ebdc	mov	x0, x27
000000010002ebe0	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002ebe4	mov	x0, x25
000000010002ebe8	mov	x1, x24
000000010002ebec	mov	x20, x27
000000010002ebf0	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002ebf4	tbz	w1, #0x0, 0x10002ef3c
000000010002ebf8	add	x28, x28, #0x1
000000010002ebfc	mov	x0, x24
000000010002ec00	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002ec04	mov	x0, x27
000000010002ec08	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002ec0c	add	x22, x22, #0x10
000000010002ec10	ldr	x8, [x19, #0x28]
000000010002ec14	cmp	x8, x28
000000010002ec18	b.ne	0x10002ebbc
000000010002ec1c	mov	x0, x26
000000010002ec20	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002ec24	ldr	x28, [x19]
000000010002ec28	ldp	x9, x20, [x19, #0xa0]
000000010002ec2c	ldr	x25, [x19, #0x20]
000000010002ec30	mov	x8, x25
000000010002ec34	mov	x0, x27
000000010002ec38	blr	x9
```


## I05 — builder 可空 URL 检查

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47236–47246`（闭区间）
- VA：`0x10002ec3c–0x10002ec64`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002ec3c	mov	x0, #0x0
000000010002ec40	bl	0x1000889e4 ; symbol stub for: _$s10Foundation3URLVMa
000000010002ec44	mov	x24, x0
000000010002ec48	ldur	x22, [x0, #-0x8]
000000010002ec4c	ldr	x8, [x22, #0x30]
000000010002ec50	mov	x0, x25
000000010002ec54	mov	w1, #0x1
000000010002ec58	mov	x2, x24
000000010002ec5c	blr	x8
000000010002ec60	cmp	w0, #0x1
000000010002ec64	b.ne	0x10002eef0
```


## I06 — 无效 URL 的 invalidArg 分支

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47267–47284`（闭区间）
- VA：`0x10002ecb8–0x10002ecfc`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002ecb8	add	x20, x19, #0x30
000000010002ecbc	mov	x0, x28
000000010002ecc0	mov	x1, x23
000000010002ecc4	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ecc8	adrp	x8, 97 ; 0x10008f000
000000010002eccc	add	x8, x8, #0xbe0 ; literal pool for: "\" could not build a valid URL from the given params"   ; "" could not build a valid URL from the given params"
000000010002ecd0	sub	x8, x8, #0x20
000000010002ecd4	mov	w9, #0x21
000000010002ecd8	mov	x10, #0x12
000000010002ecdc	movk	x10, #0xd000, lsl #48
000000010002ece0	orr	x0, x10, x9
000000010002ece4	orr	x1, x8, #0x8000000000000000
000000010002ece8	add	x20, x19, #0x30
000000010002ecec	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ecf0	ldp	x0, x20, [x19, #0x30]
000000010002ecf4	add	x8, x19, #0xe8
000000010002ecf8	mov	x1, x20
000000010002ecfc	bl	_$s4main7CUErrorV10invalidArgyACSSFZ
```


## I07 — unknown intent 的已知名称列表与 separator

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47314–47327`（闭区间）
- VA：`0x10002ed74–0x10002eda8`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002ed74	str	x27, [x19, #0x70]
000000010002ed78	adrp	x0, 124 ; 0x1000aa000
000000010002ed7c	add	x0, x0, #0xd48
000000010002ed80	adrp	x1, 94 ; 0x10008c000
000000010002ed84	add	x1, x1, #0x690
000000010002ed88	bl	___swift_instantiateConcreteTypeFromMangledNameV2
000000010002ed8c	mov	x24, x0
000000010002ed90	bl	_$sSaySSGSayxGSKsWl
000000010002ed94	mov	x3, x0
000000010002ed98	add	x20, x19, #0x70
000000010002ed9c	mov	w0, #0x202c
000000010002eda0	mov	x1, #-0x1e00000000000000
000000010002eda4	mov	x2, x24
000000010002eda8	bl	0x100088d50 ; symbol stub for: _$sSKsSS7ElementRtzrlE6joined9separatorS2S_tF
```


## I08 — unknown intent 错误串组成及 invalidArg

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47339–47382`（闭区间）
- VA：`0x10002edd8–0x10002ee84`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002edd8	adrp	x8, 97 ; 0x10008f000
000000010002eddc	add	x8, x8, #0xc20 ; literal pool for: "unknown intent \""   ; "unknown intent ""
000000010002ede0	sub	x8, x8, #0x20
000000010002ede4	orr	x8, x8, #0x8000000000000000
000000010002ede8	mov	x9, #0x12
000000010002edec	movk	x9, #0xd000, lsl #48
000000010002edf0	sub	x9, x9, #0x2
000000010002edf4	stp	x9, x8, [x19, #0x70]
000000010002edf8	add	x20, x19, #0x70
000000010002edfc	mov	x0, x28
000000010002ee00	mov	x1, x23
000000010002ee04	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ee08	mov	x0, #0x2022
000000010002ee0c	movk	x0, #0x6f66, lsl #16
000000010002ee10	movk	x0, #0x2072, lsl #32
000000010002ee14	add	x20, x19, #0x70
000000010002ee18	mov	x1, #-0x1a00000000000000
000000010002ee1c	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ee20	add	x20, x19, #0x70
000000010002ee24	mov	x0, x26
000000010002ee28	mov	x1, x22
000000010002ee2c	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ee30	adrp	x8, 97 ; 0x10008f000
000000010002ee34	add	x8, x8, #0xc40 ; literal pool for: "; known intents: ["   ; "; known intents: ["
000000010002ee38	sub	x8, x8, #0x20
000000010002ee3c	orr	x1, x8, #0x8000000000000000
000000010002ee40	add	x20, x19, #0x70
000000010002ee44	mov	x0, #0x12
000000010002ee48	movk	x0, #0xd000, lsl #48
000000010002ee4c	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ee50	add	x20, x19, #0x70
000000010002ee54	mov	x0, x25
000000010002ee58	mov	x1, x24
000000010002ee5c	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ee60	mov	x0, x24
000000010002ee64	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002ee68	add	x20, x19, #0x70
000000010002ee6c	mov	w0, #0x5d
000000010002ee70	mov	x1, #-0x1f00000000000000
000000010002ee74	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ee78	ldp	x0, x20, [x19, #0x70]
000000010002ee7c	sub	x8, x29, #0xb8
000000010002ee80	mov	x1, x20
000000010002ee84	bl	_$s4main7CUErrorV10invalidArgyACSSFZ
```


## I09 — dispatch 自己调用 openQuietly；失败不返回 URL

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47409–47427`（闭区间）
- VA：`0x10002eef0–0x10002ef38`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002eef0	ldr	x8, [x22, #0x20]
000000010002eef4	ldr	x23, [x19, #0x18]
000000010002eef8	mov	x0, x23
000000010002eefc	mov	x1, x25
000000010002ef00	mov	x2, x24
000000010002ef04	blr	x8
000000010002ef08	mov	x0, x23
000000010002ef0c	ldp	x1, x2, [x19, #0x8]
000000010002ef10	ldur	x21, [x29, #-0x48]
000000010002ef14	bl	_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n
000000010002ef18	mov	x20, x21
000000010002ef1c	cbz	x21, 0x10002ef30
000000010002ef20	ldr	x8, [x22, #0x8]
000000010002ef24	mov	x0, x23
000000010002ef28	mov	x1, x24
000000010002ef2c	blr	x8
000000010002ef30	add	x0, x19, #0x70
000000010002ef34	bl	_$s4main18AppCommandRegistryO6IntentVWOh
000000010002ef38	b	0x10002eecc
```


## I10 — 首个缺失参数的 invalidArg

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47443–47468`（闭区间）
- VA：`0x10002ef78–0x10002efdc`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO8dispatch8bundleId6intent6params10Foundation3URLVSS_SSSDyS2SGtKFZ`

```asm
000000010002ef78	add	x20, x19, #0x30
000000010002ef7c	ldr	x0, [x19]
000000010002ef80	mov	x1, x23
000000010002ef84	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ef88	adrp	x8, 97 ; 0x10008f000
000000010002ef8c	add	x8, x8, #0xbc0 ; literal pool for: "\" requires param \""   ; "" requires param ""
000000010002ef90	sub	x8, x8, #0x20
000000010002ef94	orr	x1, x8, #0x8000000000000000
000000010002ef98	add	x20, x19, #0x30
000000010002ef9c	mov	x0, #0x12
000000010002efa0	movk	x0, #0xd000, lsl #48
000000010002efa4	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002efa8	add	x20, x19, #0x30
000000010002efac	mov	x0, x25
000000010002efb0	mov	x1, x24
000000010002efb4	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002efb8	mov	x0, x24
000000010002efbc	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002efc0	add	x20, x19, #0x30
000000010002efc4	mov	w0, #0x22
000000010002efc8	mov	x1, #-0x1f00000000000000
000000010002efcc	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002efd0	ldp	x0, x20, [x19, #0x30]
000000010002efd4	add	x8, x19, #0xb8
000000010002efd8	mov	x1, x20
000000010002efdc	bl	_$s4main7CUErrorV10invalidArgyACSSFZ
```


## I11 — quiet 配置三个布尔均为 false

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47717–47731`（闭区间）
- VA：`0x10002f398–0x10002f3d0`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f398	adrp	x8, 123 ; 0x1000aa000
000000010002f39c	ldr	x0, [x8, #0x4a0] ; Objc class ref: bad class ref
000000010002f3a0	bl	0x100089aac ; symbol stub for: _objc_allocWithZone
000000010002f3a4	bl	_objc_msgSend$init
000000010002f3a8	mov	x19, x0
000000010002f3ac	mov	w2, #0x0
000000010002f3b0	bl	"_objc_msgSend$setActivates:"
000000010002f3b4	mov	x0, x19
000000010002f3b8	mov	w2, #0x0
000000010002f3bc	bl	"_objc_msgSend$setAddsToRecentItems:"
000000010002f3c0	sub	x8, x29, #0x28
000000010002f3c4	stur	x19, [x8, #-0x100]
000000010002f3c8	mov	x0, x19
000000010002f3cc	mov	w2, #0x0
000000010002f3d0	bl	"_objc_msgSend$setHidesOthers:"
```


## I12 — preferred bundle 存在性与应用 URL 查询分支

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47768–47799`（闭区间）
- VA：`0x10002f464–0x10002f4e0`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f464	cbz	x28, 0x10002f690
000000010002f468	ldr	x0, [x25, #0x488]
000000010002f46c	bl	0x100089ac4 ; symbol stub for: _objc_opt_self
000000010002f470	mov	x21, x19
000000010002f474	mov	x19, x0
000000010002f478	mov	x0, x23
000000010002f47c	bl	0x100089db8 ; symbol stub for: _swift_retain
000000010002f480	mov	x0, x21
000000010002f484	bl	0x100089db8 ; symbol stub for: _swift_retain
000000010002f488	mov	x0, x20
000000010002f48c	bl	0x100089adc ; symbol stub for: _objc_retain
000000010002f490	mov	x0, x19
000000010002f494	bl	_objc_msgSend$sharedWorkspace
000000010002f498	mov	x29, x29
000000010002f49c	bl	0x100089af4 ; symbol stub for: _objc_retainAutoreleasedReturnValue
000000010002f4a0	mov	x23, x0
000000010002f4a4	sub	x8, x29, #0x68
000000010002f4a8	ldur	x0, [x8, #-0x100]
000000010002f4ac	mov	x1, x28
000000010002f4b0	bl	0x100088d74 ; symbol stub for: _$sSS10FoundationE19_bridgeToObjectiveCSo8NSStringCyF
000000010002f4b4	mov	x20, x0
000000010002f4b8	mov	x0, x23
000000010002f4bc	mov	x2, x20
000000010002f4c0	bl	"_objc_msgSend$URLForApplicationWithBundleIdentifier:"
000000010002f4c4	mov	x29, x29
000000010002f4c8	bl	0x100089af4 ; symbol stub for: _objc_retainAutoreleasedReturnValue
000000010002f4cc	mov	x28, x0
000000010002f4d0	mov	x0, x23
000000010002f4d4	bl	0x100089ad0 ; symbol stub for: _objc_release
000000010002f4d8	mov	x0, x20
000000010002f4dc	bl	0x100089ad0 ; symbol stub for: _objc_release
000000010002f4e0	cbz	x28, 0x10002f6a8
```


## I13 — 单 URL 数组与指定应用 open 调用

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47830–47889`（闭区间）
- VA：`0x10002f55c–0x10002f644`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f55c	adrp	x8, 92 ; 0x10008b000
000000010002f560	ldr	q0, [x8, #0xfa0]
000000010002f564	str	q0, [x0, #0x10]
000000010002f568	ldr	x8, [x27, #0x10]
000000010002f56c	add	x0, x0, x23
000000010002f570	sub	x9, x29, #0x20
000000010002f574	ldur	x1, [x9, #-0x100]
000000010002f578	mov	x2, x22
000000010002f57c	blr	x8
000000010002f580	mov	x0, x19
000000010002f584	mov	x1, x22
000000010002f588	bl	0x100088f54 ; symbol stub for: _$sSa10FoundationE19_bridgeToObjectiveCSo7NSArrayCyF
000000010002f58c	mov	x24, x0
000000010002f590	mov	x0, x19
000000010002f594	bl	0x100089da0 ; symbol stub for: _swift_release
000000010002f598	bl	0x1000889a8 ; symbol stub for: _$s10Foundation3URLV19_bridgeToObjectiveCSo5NSURLCyF
000000010002f59c	mov	x19, x0
000000010002f5a0	adrp	x0, 115 ; 0x1000a2000
000000010002f5a4	add	x0, x0, #0xf30
000000010002f5a8	mov	w1, #0x20
000000010002f5ac	mov	w2, #0x7
000000010002f5b0	bl	0x100089b54 ; symbol stub for: _swift_allocObject
000000010002f5b4	adrp	x8, 0 ; 0x10002f000
000000010002f5b8	add	x9, x8, #0xdb8
000000010002f5bc	sub	x8, x29, #0x40
000000010002f5c0	ldur	x25, [x8, #-0x100]
000000010002f5c4	stp	x9, x25, [x0, #0x10]
000000010002f5c8	adrp	x8, 0 ; 0x10002f000
000000010002f5cc	add	x8, x8, #0xe9c
000000010002f5d0	stp	x8, x0, [x29, #-0xc8]
000000010002f5d4	adrp	x8, 113 ; 0x1000a0000
000000010002f5d8	ldr	x8, [x8, #0x328] ; literal pool symbol address: __NSConcreteStackBlock   ; "]"
000000010002f5d8	ldr	x8, [x8, #0x328] ; literal pool symbol address: __NSConcreteStackBlock
000000010002f5dc	stur	x8, [x29, #-0xe8]
000000010002f5e0	adrp	x8, 93 ; 0x10008c000
000000010002f5e4	ldr	d0, [x8, #0x650]
000000010002f5e8	stur	d0, [x29, #-0xe0]
000000010002f5ec	adrp	x8, 0 ; 0x10002f000
000000010002f5f0	add	x8, x8, #0x70
000000010002f5f4	adrp	x9, 115 ; 0x1000a2000
000000010002f5f8	add	x9, x9, #0xf48
000000010002f5fc	stp	x8, x9, [x29, #-0xd8]
000000010002f600	sub	x0, x29, #0xe8
000000010002f604	bl	0x100089998 ; symbol stub for: __Block_copy
000000010002f608	mov	x20, x0
000000010002f60c	ldur	x21, [x29, #-0xc0]
000000010002f610	mov	x0, x25
000000010002f614	bl	0x100089db8 ; symbol stub for: _swift_retain
000000010002f618	mov	x0, x21
000000010002f61c	bl	0x100089da0 ; symbol stub for: _swift_release
000000010002f620	mov	x0, x28
000000010002f624	mov	x2, x24
000000010002f628	mov	x3, x19
000000010002f62c	mov	x23, x22
000000010002f630	mov	x22, x26
000000010002f634	sub	x8, x29, #0x28
000000010002f638	ldur	x26, [x8, #-0x100]
000000010002f63c	mov	x4, x26
000000010002f640	mov	x5, x20
000000010002f644	bl	"_objc_msgSend$openURLs:withApplicationAtURL:configuration:completionHandler:"
```


## I14 — 指定应用路径结束后跳过 fallback

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47902–47922`（闭区间）
- VA：`0x10002f678–0x10002f6c8`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f678	ldr	x8, [x27, #0x8]
000000010002f67c	sub	x9, x29, #0x60
000000010002f680	ldur	x0, [x9, #-0x100]
000000010002f684	mov	x1, x23
000000010002f688	blr	x8
000000010002f68c	b	0x10002f788
000000010002f690	mov	x0, x23
000000010002f694	bl	0x100089db8 ; symbol stub for: _swift_retain
000000010002f698	mov	x0, x19
000000010002f69c	bl	0x100089db8 ; symbol stub for: _swift_retain
000000010002f6a0	mov	x0, x20
000000010002f6a4	bl	0x100089adc ; symbol stub for: _objc_retain
000000010002f6a8	ldr	x0, [x25, #0x488]
000000010002f6ac	bl	0x100089ac4 ; symbol stub for: _objc_opt_self
000000010002f6b0	bl	_objc_msgSend$sharedWorkspace
000000010002f6b4	mov	x29, x29
000000010002f6b8	bl	0x100089af4 ; symbol stub for: _objc_retainAutoreleasedReturnValue
000000010002f6bc	mov	x19, x0
000000010002f6c0	sub	x8, x29, #0x20
000000010002f6c4	ldur	x24, [x8, #-0x100]
000000010002f6c8	mov	x20, x24
```


## I15 — 通用 URL open 调用

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47958–47972`（闭区间）
- VA：`0x10002f754–0x10002f78c`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f754	mov	x0, x19
000000010002f758	mov	x2, x20
000000010002f75c	sub	x8, x29, #0x28
000000010002f760	ldur	x28, [x8, #-0x100]
000000010002f764	mov	x3, x28
000000010002f768	mov	x4, x22
000000010002f76c	bl	"_objc_msgSend$openURL:configuration:completionHandler:"
000000010002f770	mov	x0, x22
000000010002f774	bl	0x1000899a4 ; symbol stub for: __Block_release
000000010002f778	mov	x0, x19
000000010002f77c	bl	0x100089ad0 ; symbol stub for: _objc_release
000000010002f780	mov	x0, x20
000000010002f784	bl	0x100089ad0 ; symbol stub for: _objc_release
000000010002f788	mov	x8, x26
000000010002f78c	bl	0x100088cfc ; symbol stub for: _$s8Dispatch0A4TimeV3nowACyFZ
```


## I16 — 5 秒等待与超时判定

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`47973–47998`（闭区间）
- VA：`0x10002f790–0x10002f7f4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f790	fmov	d0, #5.00000000
000000010002f794	sub	x8, x29, #0x58
000000010002f798	ldur	x27, [x8, #-0x100]
000000010002f79c	mov	x8, x27
000000010002f7a0	mov	x0, x26
000000010002f7a4	bl	0x100088d14 ; symbol stub for: _$s8Dispatch1poiyAA0A4TimeVAD_SdtF
000000010002f7a8	sub	x8, x29, #0x50
000000010002f7ac	ldur	x8, [x8, #-0x100]
000000010002f7b0	ldr	x22, [x8, #0x8]
000000010002f7b4	mov	x0, x26
000000010002f7b8	sub	x8, x29, #0x48
000000010002f7bc	ldur	x23, [x8, #-0x100]
000000010002f7c0	mov	x1, x23
000000010002f7c4	blr	x22
000000010002f7c8	mov	x0, x27
000000010002f7cc	sub	x8, x29, #0x18
000000010002f7d0	ldur	x20, [x8, #-0x100]
000000010002f7d4	bl	0x1000890a4 ; symbol stub for: _$sSo21OS_dispatch_semaphoreC8DispatchE4wait7timeoutAC0D13TimeoutResultOAC0D4TimeV_tF
000000010002f7d8	mov	x19, x0
000000010002f7dc	mov	x0, x27
000000010002f7e0	mov	x1, x23
000000010002f7e4	blr	x22
000000010002f7e8	mov	x0, x19
000000010002f7ec	mov	w1, #0x1
000000010002f7f0	bl	0x100088c9c ; symbol stub for: _$s8Dispatch0A13TimeoutResultO2eeoiySbAC_ACtFZ
000000010002f7f4	tbz	w0, #0x0, 0x10002f8bc
```


## I17 — 超时构成 internalError

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`48006–48029`（闭区间）
- VA：`0x10002f814–0x10002f870`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f814	adrp	x8, 96 ; 0x10008f000
000000010002f818	add	x8, x8, #0xc60 ; literal pool for: "NSWorkspace.open("   ; "NSWorkspace.open("
000000010002f81c	sub	x8, x8, #0x20
000000010002f820	orr	x8, x8, #0x8000000000000000
000000010002f824	mov	x22, #0x11
000000010002f828	movk	x22, #0xd000, lsl #48
000000010002f82c	stp	x22, x8, [x29, #-0xe8]
000000010002f830	mov	x20, x24
000000010002f834	bl	0x100088990 ; symbol stub for: _$s10Foundation3URLV14absoluteStringSSvg
000000010002f838	mov	x19, x1
000000010002f83c	sub	x20, x29, #0xe8
000000010002f840	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002f844	mov	x0, x19
000000010002f848	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002f84c	adrp	x8, 96 ; 0x10008f000
000000010002f850	add	x8, x8, #0xc80 ; literal pool for: ") timed out after 5s"   ; ") timed out after 5s"
000000010002f854	sub	x8, x8, #0x20
000000010002f858	add	x0, x22, #0x3
000000010002f85c	orr	x1, x8, #0x8000000000000000
000000010002f860	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002f864	ldp	x0, x19, [x29, #-0xe8]
000000010002f868	sub	x8, x29, #0xb8
000000010002f86c	mov	x1, x19
000000010002f870	bl	_$s4main7CUErrorV13internalErroryACSSFZ
```


## I18 — 非超时检查回调 error

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`48048–48060`（闭区间）
- VA：`0x10002f8bc–0x10002f8ec`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f8bc	sub	x1, x29, #0xe8
000000010002f8c0	sub	x8, x29, #0x70
000000010002f8c4	ldur	x19, [x8, #-0x100]
000000010002f8c8	mov	x0, x19
000000010002f8cc	mov	x2, #0x0
000000010002f8d0	mov	x3, #0x0
000000010002f8d4	bl	0x100089b90 ; symbol stub for: _swift_beginAccess
000000010002f8d8	ldr	x19, [x19]
000000010002f8dc	cbz	x19, 0x10002fa48
000000010002f8e0	mov	x8, #-0x2000000000000000
000000010002f8e4	stp	xzr, x8, [x29, #-0xf8]
000000010002f8e8	mov	x0, x19
000000010002f8ec	bl	0x100089cb0 ; symbol stub for: _swift_errorRetain
```


## I19 — 回调失败包含 localizedDescription 并成为 internalError

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`48066–48105`（闭区间）
- VA：`0x10002f904–0x10002f9a0`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002f904	adrp	x8, 96 ; 0x10008f000
000000010002f908	add	x8, x8, #0xc60 ; literal pool for: "NSWorkspace.open("   ; "NSWorkspace.open("
000000010002f90c	sub	x8, x8, #0x20
000000010002f910	orr	x8, x8, #0x8000000000000000
000000010002f914	mov	x9, #0x11
000000010002f918	movk	x9, #0xd000, lsl #48
000000010002f91c	stp	x9, x8, [x29, #-0xf8]
000000010002f920	mov	x20, x24
000000010002f924	bl	0x100088990 ; symbol stub for: _$s10Foundation3URLV14absoluteStringSSvg
000000010002f928	mov	x22, x1
000000010002f92c	sub	x20, x29, #0xf8
000000010002f930	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002f934	mov	x0, x22
000000010002f938	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002f93c	mov	x0, #0x2029
000000010002f940	movk	x0, #0x6166, lsl #16
000000010002f944	movk	x0, #0x6c69, lsl #32
000000010002f948	movk	x0, #0x6465, lsl #48
000000010002f94c	mov	x1, #0x203a
000000010002f950	movk	x1, #0xea00, lsl #48
000000010002f954	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002f958	sub	x1, x29, #0x48
000000010002f95c	sub	x2, x29, #0x110
000000010002f960	mov	x0, x19
000000010002f964	bl	0x100089cd4 ; symbol stub for: _swift_getErrorValue
000000010002f968	sub	x8, x29, #0x10
000000010002f96c	ldur	x20, [x8, #-0x100]
000000010002f970	sub	x8, x29, #0x8
000000010002f974	ldur	x0, [x8, #-0x100]
000000010002f978	ldur	x1, [x29, #-0x100]
000000010002f97c	bl	0x100089488 ; symbol stub for: _$ss5ErrorP10FoundationE20localizedDescriptionSSvg
000000010002f980	mov	x22, x1
000000010002f984	sub	x20, x29, #0xf8
000000010002f988	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002f98c	mov	x0, x22
000000010002f990	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002f994	ldp	x0, x20, [x29, #-0xf8]
000000010002f998	sub	x8, x29, #0x88
000000010002f99c	mov	x1, x20
000000010002f9a0	bl	_$s4main7CUErrorV13internalErroryACSSFZ
```


## I20 — 无回调 error 的成功出口

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`48147–48162`（闭区间）
- VA：`0x10002fa48–0x10002fa84`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZTf4nnd_n`

```asm
000000010002fa48	mov	x0, x28
000000010002fa4c	bl	0x100089ad0 ; symbol stub for: _objc_release
000000010002fa50	sub	x8, x29, #0x18
000000010002fa54	ldur	x0, [x8, #-0x100]
000000010002fa58	bl	0x100089ad0 ; symbol stub for: _objc_release
000000010002fa5c	sub	x8, x29, #0x30
000000010002fa60	ldur	x0, [x8, #-0x100]
000000010002fa64	bl	0x100089da0 ; symbol stub for: _swift_release
000000010002fa68	sub	x8, x29, #0x38
000000010002fa6c	ldur	x0, [x8, #-0x100]
000000010002fa70	bl	0x100089da0 ; symbol stub for: _swift_release
000000010002fa74	mov	x0, x25
000000010002fa78	bl	0x100089da0 ; symbol stub for: _swift_release
000000010002fa7c	sub	x8, x29, #0x78
000000010002fa80	ldur	x20, [x8, #-0x100]
000000010002fa84	b	0x10002fa24
```


## I21 — 回调保存 error、只 signal 一次

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`48383–48411`（闭区间）
- VA：`0x10002fdd0–0x10002fe40`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZys5Error_pSgcfU_TA`

```asm
000000010002fdd0	mov	x19, x0
000000010002fdd4	ldp	x24, x22, [x20, #0x10]
000000010002fdd8	ldr	x20, [x20, #0x20]
000000010002fddc	mov	w23, #0x1
000000010002fde0	add	x0, x24, #0x10
000000010002fde4	add	x1, sp, #0x38
000000010002fde8	mov	w2, #0x1
000000010002fdec	mov	x3, #0x0
000000010002fdf0	bl	0x100089b90 ; symbol stub for: _swift_beginAccess
000000010002fdf4	ldr	x21, [x24, #0x10]
000000010002fdf8	str	x19, [x24, #0x10]
000000010002fdfc	mov	x0, x19
000000010002fe00	bl	0x100089cb0 ; symbol stub for: _swift_errorRetain
000000010002fe04	mov	x0, x21
000000010002fe08	bl	0x100089ca4 ; symbol stub for: _swift_errorRelease
000000010002fe0c	add	x0, x22, #0x10
000000010002fe10	add	x1, sp, #0x20
000000010002fe14	mov	x2, #0x0
000000010002fe18	mov	x3, #0x0
000000010002fe1c	bl	0x100089b90 ; symbol stub for: _swift_beginAccess
000000010002fe20	ldrb	w8, [x22, #0x10]
000000010002fe24	tbnz	w8, #0x0, 0x10002fe44
000000010002fe28	add	x0, x22, #0x10
000000010002fe2c	add	x1, sp, #0x8
000000010002fe30	mov	w2, #0x1
000000010002fe34	mov	x3, #0x0
000000010002fe38	bl	0x100089b90 ; symbol stub for: _swift_beginAccess
000000010002fe3c	sturb	w23, [x22, #0x10]
000000010002fe40	bl	0x1000890bc ; symbol stub for: _$sSo21OS_dispatch_semaphoreC8DispatchE6signalSiyF
```


## I22 — workspace completion 丢弃 application，仅传 error

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`48437–48454`（闭区间）
- VA：`0x10002fe9c–0x10002fed0`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZySo20NSRunningApplicationCSg_s5Error_pSgtYbcfU0_TA`; `_block_copy_helper.13`; `_block_destroy_helper.14`; `_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZySo20NSRunningApplicationCSg_s5Error_pSgtYbcfU1_TA`; `_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU6_`

```asm
000000010002fe9c	stp	x20, x19, [sp, #-0x20]!
000000010002fea0	stp	x29, x30, [sp, #0x10]
000000010002fea4	add	x29, sp, #0x10
000000010002fea8	mov	x0, x1
000000010002feac	ldp	x8, x20, [x20, #0x10]
000000010002feb0	blr	x8
000000010002feb4	ldp	x29, x30, [sp, #0x10]
000000010002feb8	ldp	x20, x19, [sp], #0x20
000000010002febc	ret
000000010002fec0	b	0x10002fe78
_block_copy_helper.13:
000000010002fec4	b	_block_copy_helper
_block_destroy_helper.14:
000000010002fec8	b	_block_destroy_helper
_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZySo20NSRunningApplicationCSg_s5Error_pSgtYbcfU1_TA:
000000010002fecc	b	_$s4main18AppCommandRegistryO11openQuietly3url17preferredBundleIdy10Foundation3URLV_SSSgtKFZySo20NSRunningApplicationCSg_s5Error_pSgtYbcfU0_TA
_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU6_:
000000010002fed0	b	_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU10_
```


## I23 — NetEase launch 常量 URL

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46079–46085`（闭区间）
- VA：`0x10002da8c–0x10002daa4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU_`

```asm
000000010002da8c	mov	x0, #0x726f
000000010002da90	movk	x0, #0x6870, lsl #16
000000010002da94	movk	x0, #0x7565, lsl #32
000000010002da98	movk	x0, #0x3a73, lsl #48
000000010002da9c	mov	x1, #0x2f2f
000000010002daa0	movk	x1, #0xea00, lsl #48
000000010002daa4	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I24 — song_id 查找、URL 前缀、queryAllowed 编码

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46111–46152`（闭区间）
- VA：`0x10002db04–0x10002dba8`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU0_`

```asm
000000010002db04	ldr	x8, [x20, #0x10]
000000010002db08	cbz	x8, 0x10002dc2c
000000010002db0c	mov	x0, x20
000000010002db10	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002db14	mov	x0, #0x6f73
000000010002db18	movk	x0, #0x676e, lsl #16
000000010002db1c	movk	x0, #0x695f, lsl #32
000000010002db20	movk	x0, #0x64, lsl #48
000000010002db24	mov	x1, #-0x1900000000000000
000000010002db28	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002db2c	tbz	w1, #0x0, 0x10002dc24
000000010002db30	ldr	x8, [x20, #0x38]
000000010002db34	add	x8, x8, x0, lsl #4
000000010002db38	ldp	x24, x23, [x8]
000000010002db3c	mov	x0, x23
000000010002db40	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002db44	mov	x0, x20
000000010002db48	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002db4c	mov	x8, #-0x2000000000000000
000000010002db50	stp	xzr, x8, [x29, #-0x50]
000000010002db54	sub	x20, x29, #0x50
000000010002db58	mov	w0, #0x15
000000010002db5c	bl	0x100089260 ; symbol stub for: _$ss11_StringGutsV4growyySiF
000000010002db60	ldur	x0, [x29, #-0x48]
000000010002db64	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002db68	adrp	x8, 99 ; 0x100090000
000000010002db6c	add	x8, x8, #0x2d0 ; literal pool for: "orpheus://song/?id="   ; "orpheus://song/?id="
000000010002db70	sub	x8, x8, #0x20
000000010002db74	orr	x8, x8, #0x8000000000000000
000000010002db78	mov	x9, #0x13
000000010002db7c	movk	x9, #0xd000, lsl #48
000000010002db80	stp	x9, x8, [x29, #-0x50]
000000010002db84	stp	x24, x23, [x29, #-0x60]
000000010002db88	mov	x8, x22
000000010002db8c	bl	0x1000888a0 ; symbol stub for: _$s10Foundation12CharacterSetV15urlQueryAllowedACvgZ
000000010002db90	bl	_$sS2SSysWl
000000010002db94	mov	x2, x0
000000010002db98	adrp	x1, 115 ; 0x1000a0000
000000010002db9c	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002dba0	sub	x20, x29, #0x60
000000010002dba4	mov	x0, x22
000000010002dba8	bl	0x100089158 ; symbol stub for: _$sSy10FoundationE21addingPercentEncoding21withAllowedCharactersSSSgAA12CharacterSetV_tF
```


## I25 — song 编码失败保留原串，然后 URL(string:)

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46153–46173`（闭区间）
- VA：`0x10002dbac–0x10002dbfc`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU0_`

```asm
000000010002dbac	mov	x20, x0
000000010002dbb0	mov	x25, x1
000000010002dbb4	ldr	x8, [x26, #0x8]
000000010002dbb8	mov	x0, x22
000000010002dbbc	mov	x1, x21
000000010002dbc0	blr	x8
000000010002dbc4	cbz	x25, 0x10002dbd8
000000010002dbc8	mov	x0, x23
000000010002dbcc	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dbd0	mov	x24, x20
000000010002dbd4	mov	x23, x25
000000010002dbd8	sub	x20, x29, #0x50
000000010002dbdc	mov	x0, x24
000000010002dbe0	mov	x1, x23
000000010002dbe4	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002dbe8	mov	x0, x23
000000010002dbec	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dbf0	ldp	x0, x20, [x29, #-0x50]
000000010002dbf4	mov	x8, x19
000000010002dbf8	mov	x1, x20
000000010002dbfc	bl	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I26 — playlist_id 查找、URL 前缀、queryAllowed 编码

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46225–46268`（闭区间）
- VA：`0x10002dcc4–0x10002dd70`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU1_`

```asm
000000010002dcc4	ldr	x8, [x20, #0x10]
000000010002dcc8	cbz	x8, 0x10002ddf4
000000010002dccc	mov	x0, x20
000000010002dcd0	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002dcd4	mov	x0, #0x6c70
000000010002dcd8	movk	x0, #0x7961, lsl #16
000000010002dcdc	movk	x0, #0x696c, lsl #32
000000010002dce0	movk	x0, #0x7473, lsl #48
000000010002dce4	mov	x1, #0x695f
000000010002dce8	movk	x1, #0x64, lsl #16
000000010002dcec	movk	x1, #0xeb00, lsl #48
000000010002dcf0	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002dcf4	tbz	w1, #0x0, 0x10002ddec
000000010002dcf8	ldr	x8, [x20, #0x38]
000000010002dcfc	add	x8, x8, x0, lsl #4
000000010002dd00	ldp	x24, x23, [x8]
000000010002dd04	mov	x0, x23
000000010002dd08	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002dd0c	mov	x0, x20
000000010002dd10	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dd14	mov	x8, #-0x2000000000000000
000000010002dd18	stp	xzr, x8, [x29, #-0x50]
000000010002dd1c	sub	x20, x29, #0x50
000000010002dd20	mov	w0, #0x19
000000010002dd24	bl	0x100089260 ; symbol stub for: _$ss11_StringGutsV4growyySiF
000000010002dd28	ldur	x0, [x29, #-0x48]
000000010002dd2c	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dd30	adrp	x8, 99 ; 0x100090000
000000010002dd34	add	x8, x8, #0x2b0 ; literal pool for: "orpheus://playlist/?id="   ; "orpheus://playlist/?id="
000000010002dd38	sub	x8, x8, #0x20
000000010002dd3c	orr	x8, x8, #0x8000000000000000
000000010002dd40	mov	x9, #0x17
000000010002dd44	movk	x9, #0xd000, lsl #48
000000010002dd48	stp	x9, x8, [x29, #-0x50]
000000010002dd4c	stp	x24, x23, [x29, #-0x60]
000000010002dd50	mov	x8, x22
000000010002dd54	bl	0x1000888a0 ; symbol stub for: _$s10Foundation12CharacterSetV15urlQueryAllowedACvgZ
000000010002dd58	bl	_$sS2SSysWl
000000010002dd5c	mov	x2, x0
000000010002dd60	adrp	x1, 115 ; 0x1000a0000
000000010002dd64	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002dd68	sub	x20, x29, #0x60
000000010002dd6c	mov	x0, x22
000000010002dd70	bl	0x100089158 ; symbol stub for: _$sSy10FoundationE21addingPercentEncoding21withAllowedCharactersSSSgAA12CharacterSetV_tF
```


## I27 — playlist 编码失败保留原串，然后 URL(string:)

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46269–46289`（闭区间）
- VA：`0x10002dd74–0x10002ddc4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU1_`

```asm
000000010002dd74	mov	x20, x0
000000010002dd78	mov	x25, x1
000000010002dd7c	ldr	x8, [x26, #0x8]
000000010002dd80	mov	x0, x22
000000010002dd84	mov	x1, x21
000000010002dd88	blr	x8
000000010002dd8c	cbz	x25, 0x10002dda0
000000010002dd90	mov	x0, x23
000000010002dd94	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dd98	mov	x24, x20
000000010002dd9c	mov	x23, x25
000000010002dda0	sub	x20, x29, #0x50
000000010002dda4	mov	x0, x24
000000010002dda8	mov	x1, x23
000000010002ddac	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002ddb0	mov	x0, x23
000000010002ddb4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002ddb8	ldp	x0, x20, [x29, #-0x50]
000000010002ddbc	mov	x8, x19
000000010002ddc0	mov	x1, x20
000000010002ddc4	bl	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I28 — 两个固定推荐路由

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46317–46331`（闭区间）
- VA：`0x10002de30–0x10002de64`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU2_`; `_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU3_`

```asm
000000010002de30	adrp	x9, 99 ; 0x100090000
000000010002de34	add	x9, x9, #0x290 ; literal pool for: "orpheus://route/dailyRecommend"   ; "orpheus://route/dailyRecommend"
000000010002de38	sub	x9, x9, #0x20
000000010002de3c	orr	x1, x9, #0x8000000000000000
000000010002de40	mov	x0, #0x1e
000000010002de44	movk	x0, #0xd000, lsl #48
000000010002de48	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU3_:
000000010002de4c	adrp	x9, 99 ; 0x100090000
000000010002de50	add	x9, x9, #0x260 ; literal pool for: "orpheus://route/historyRecommend"   ; "orpheus://route/historyRecommend"
000000010002de54	sub	x9, x9, #0x20
000000010002de58	orr	x1, x9, #0x8000000000000000
000000010002de5c	mov	x0, #0x20
000000010002de60	movk	x0, #0xd000, lsl #48
000000010002de64	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I29 — route 键存在与字符串长度检查

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46357–46378`（闭区间）
- VA：`0x10002dec4–0x10002df18`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU4_`

```asm
000000010002dec4	ldr	x8, [x20, #0x10]
000000010002dec8	cbz	x8, 0x10002e000
000000010002decc	mov	x0, x20
000000010002ded0	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002ded4	mov	x0, #0x6f72
000000010002ded8	movk	x0, #0x7475, lsl #16
000000010002dedc	movk	x0, #0x65, lsl #32
000000010002dee0	mov	x1, #-0x1b00000000000000
000000010002dee4	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002dee8	tbz	w1, #0x0, 0x10002dff8
000000010002deec	ldr	x8, [x20, #0x38]
000000010002def0	add	x8, x8, x0, lsl #4
000000010002def4	ldp	x24, x22, [x8]
000000010002def8	mov	x0, x22
000000010002defc	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002df00	mov	x0, x20
000000010002df04	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002df08	and	x8, x24, #0xffffffffffff
000000010002df0c	ubfx	x9, x22, #56, #4
000000010002df10	tst	x22, #0x2000000000000000
000000010002df14	csel	x8, x8, x9, eq
000000010002df18	cbz	x8, 0x10002dff4
```


## I30 — route 前缀、queryAllowed 编码与原串 fallback

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46386–46423`（闭区间）
- VA：`0x10002df38–0x10002dfcc`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU4_`

```asm
000000010002df38	adrp	x8, 99 ; 0x100090000
000000010002df3c	add	x8, x8, #0x240 ; literal pool for: "orpheus://route/"   ; "orpheus://route/"
000000010002df40	sub	x8, x8, #0x20
000000010002df44	orr	x8, x8, #0x8000000000000000
000000010002df48	mov	x9, #0x10
000000010002df4c	movk	x9, #0xd000, lsl #48
000000010002df50	stp	x9, x8, [x29, #-0x50]
000000010002df54	stp	x24, x22, [x29, #-0x60]
000000010002df58	mov	x8, x23
000000010002df5c	bl	0x1000888a0 ; symbol stub for: _$s10Foundation12CharacterSetV15urlQueryAllowedACvgZ
000000010002df60	bl	_$sS2SSysWl
000000010002df64	mov	x2, x0
000000010002df68	adrp	x1, 115 ; 0x1000a0000
000000010002df6c	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002df70	sub	x20, x29, #0x60
000000010002df74	mov	x0, x23
000000010002df78	bl	0x100089158 ; symbol stub for: _$sSy10FoundationE21addingPercentEncoding21withAllowedCharactersSSSgAA12CharacterSetV_tF
000000010002df7c	mov	x20, x0
000000010002df80	mov	x25, x1
000000010002df84	ldr	x8, [x26, #0x8]
000000010002df88	mov	x0, x23
000000010002df8c	mov	x1, x21
000000010002df90	blr	x8
000000010002df94	cbz	x25, 0x10002dfa8
000000010002df98	mov	x0, x22
000000010002df9c	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dfa0	mov	x24, x20
000000010002dfa4	mov	x22, x25
000000010002dfa8	sub	x20, x29, #0x50
000000010002dfac	mov	x0, x24
000000010002dfb0	mov	x1, x22
000000010002dfb4	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002dfb8	mov	x0, x22
000000010002dfbc	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002dfc0	ldp	x0, x20, [x29, #-0x50]
000000010002dfc4	mov	x8, x19
000000010002dfc8	mov	x1, x20
000000010002dfcc	bl	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I31 — Music/Spotify launch 与 URI wrapper

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46452–46467`（闭区间）
- VA：`0x10002e03c–0x10002e070`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU5_`; `_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU7_`; `_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU8_`

```asm
000000010002e03c	mov	x0, #0x756d
000000010002e040	movk	x0, #0x6973, lsl #16
000000010002e044	movk	x0, #0x3a63, lsl #32
000000010002e048	mov	x1, #-0x1a00000000000000
000000010002e04c	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU7_:
000000010002e050	mov	x0, #0x7073
000000010002e054	movk	x0, #0x746f, lsl #16
000000010002e058	movk	x0, #0x6669, lsl #32
000000010002e05c	movk	x0, #0x3a79, lsl #48
000000010002e060	mov	x1, #-0x1800000000000000
000000010002e064	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU8_:
000000010002e068	mov	w1, #0x7275
000000010002e06c	movk	w1, #0x69, lsl #16
000000010002e070	b	_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU6_Tm
```


## I32 — Mail to 缺失默认空串、编码与 URLComponents

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46542–46600`（闭区间）
- VA：`0x10002e188–0x10002e270`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU9_`

```asm
000000010002e188	mov	x8, #0x616d
000000010002e18c	movk	x8, #0x6c69, lsl #16
000000010002e190	movk	x8, #0x6f74, lsl #32
000000010002e194	movk	x8, #0x3a, lsl #48
000000010002e198	mov	x9, #-0x1900000000000000
000000010002e19c	stp	x8, x9, [x29, #-0x60]
000000010002e1a0	ldr	x8, [x24, #0x10]
000000010002e1a4	cbz	x8, 0x10002e1dc
000000010002e1a8	mov	x0, x24
000000010002e1ac	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e1b0	mov	w0, #0x6f74
000000010002e1b4	mov	x1, #-0x1e00000000000000
000000010002e1b8	mov	x20, x24
000000010002e1bc	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e1c0	tbz	w1, #0x0, 0x10002e1e8
000000010002e1c4	ldr	x8, [x24, #0x38]
000000010002e1c8	add	x8, x8, x0, lsl #4
000000010002e1cc	ldp	x22, x21, [x8]
000000010002e1d0	mov	x0, x21
000000010002e1d4	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e1d8	b	0x10002e1f0
000000010002e1dc	mov	x22, #0x0
000000010002e1e0	mov	x21, #-0x2000000000000000
000000010002e1e4	b	0x10002e1f8
000000010002e1e8	mov	x22, #0x0
000000010002e1ec	mov	x21, #-0x2000000000000000
000000010002e1f0	mov	x0, x24
000000010002e1f4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e1f8	stp	x22, x21, [x29, #-0x70]
000000010002e1fc	mov	x8, x28
000000010002e200	bl	0x1000888a0 ; symbol stub for: _$s10Foundation12CharacterSetV15urlQueryAllowedACvgZ
000000010002e204	bl	_$sS2SSysWl
000000010002e208	mov	x2, x0
000000010002e20c	adrp	x1, 114 ; 0x1000a0000
000000010002e210	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002e214	sub	x20, x29, #0x70
000000010002e218	mov	x0, x28
000000010002e21c	bl	0x100089158 ; symbol stub for: _$sSy10FoundationE21addingPercentEncoding21withAllowedCharactersSSSgAA12CharacterSetV_tF
000000010002e220	mov	x20, x0
000000010002e224	mov	x19, x1
000000010002e228	ldr	x8, [x25, #0x8]
000000010002e22c	mov	x0, x28
000000010002e230	mov	x1, x27
000000010002e234	blr	x8
000000010002e238	cbz	x19, 0x10002e24c
000000010002e23c	mov	x0, x21
000000010002e240	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e244	mov	x22, x20
000000010002e248	mov	x21, x19
000000010002e24c	sub	x20, x29, #0x60
000000010002e250	mov	x0, x22
000000010002e254	mov	x1, x21
000000010002e258	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002e25c	mov	x0, x21
000000010002e260	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e264	ldp	x0, x19, [x29, #-0x60]
000000010002e268	ldur	x8, [x29, #-0x80]
000000010002e26c	mov	x1, x19
000000010002e270	bl	0x10008890c ; symbol stub for: _$s10Foundation13URLComponentsV6stringACSgSSh_tcfC
```


## I33 — Mail 四字段有序循环及 URLQueryItem

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46603–46640`（闭区间）
- VA：`0x10002e27c–0x10002e310`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU9_`

```asm
000000010002e27c	adrp	x27, 114 ; 0x1000a0000
000000010002e280	ldr	x27, [x27, #0xe78] ; literal pool symbol address: __swiftEmptyArrayStorage
000000010002e284	adrp	x28, 126 ; 0x1000ac000
000000010002e288	add	x28, x28, #0x288
000000010002e28c	mov	w25, #0x4
000000010002e290	b	0x10002e2b0
000000010002e294	mov	x0, x19
000000010002e298	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e29c	mov	x0, x24
000000010002e2a0	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e2a4	add	x28, x28, #0x10
000000010002e2a8	subs	x25, x25, #0x1
000000010002e2ac	b.eq	0x10002e3b0
000000010002e2b0	ldr	x8, [x24, #0x10]
000000010002e2b4	cbz	x8, 0x10002e2a4
000000010002e2b8	ldp	x22, x19, [x28, #-0x8]
000000010002e2bc	mov	x0, x24
000000010002e2c0	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e2c4	mov	x0, x19
000000010002e2c8	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e2cc	mov	x0, x22
000000010002e2d0	mov	x1, x19
000000010002e2d4	mov	x20, x24
000000010002e2d8	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e2dc	tbz	w1, #0x0, 0x10002e294
000000010002e2e0	ldr	x8, [x24, #0x38]
000000010002e2e4	add	x8, x8, x0, lsl #4
000000010002e2e8	ldp	x20, x21, [x8]
000000010002e2ec	mov	x0, x21
000000010002e2f0	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e2f4	mov	x0, x24
000000010002e2f8	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e2fc	mov	x8, x26
000000010002e300	mov	x0, x22
000000010002e304	mov	x1, x19
000000010002e308	mov	x2, x20
000000010002e30c	mov	x3, x21
000000010002e310	bl	0x1000888dc ; symbol stub for: _$s10Foundation12URLQueryItemV4name5valueACSSh_SSSghtcfC
```


## I34 — Mail 仅有 queryItem 时设 queryItems，返回 components.url

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46680–46724`（闭区间）
- VA：`0x10002e3b0–0x10002e460`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU9_`

```asm
000000010002e3b0	adrp	x0, 126 ; 0x1000ac000
000000010002e3b4	add	x0, x0, #0x280   ; "subject"
000000010002e3b8	adrp	x2, 114 ; 0x1000a0000
000000010002e3bc	ldr	x2, [x2, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002e3c0	mov	w1, #0x4
000000010002e3c4	bl	0x100089b60 ; symbol stub for: _swift_arrayDestroy
000000010002e3c8	ldr	x8, [x27, #0x10]
000000010002e3cc	ldp	x22, x21, [x29, #-0x98]
000000010002e3d0	ldr	x19, [x22, #0x30]
000000010002e3d4	ldur	x23, [x29, #-0x80]
000000010002e3d8	cbz	x8, 0x10002e400
000000010002e3dc	mov	x0, x23
000000010002e3e0	mov	w1, #0x1
000000010002e3e4	mov	x2, x21
000000010002e3e8	blr	x19
000000010002e3ec	cbnz	w0, 0x10002e400
000000010002e3f0	mov	x0, x27
000000010002e3f4	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e3f8	mov	x20, x23
000000010002e3fc	bl	0x1000888f4 ; symbol stub for: _$s10Foundation13URLComponentsV10queryItemsSayAA12URLQueryItemVGSgvs
000000010002e400	mov	x0, x23
000000010002e404	mov	w1, #0x1
000000010002e408	mov	x2, x21
000000010002e40c	blr	x19
000000010002e410	cbz	w0, 0x10002e444
000000010002e414	mov	x0, x27
000000010002e418	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e41c	mov	x0, #0x0
000000010002e420	bl	0x1000889e4 ; symbol stub for: _$s10Foundation3URLVMa
000000010002e424	mov	x3, x0
000000010002e428	ldur	x8, [x0, #-0x8]
000000010002e42c	ldr	x8, [x8, #0x38]
000000010002e430	ldur	x0, [x29, #-0x88]
000000010002e434	mov	w1, #0x1
000000010002e438	mov	w2, #0x1
000000010002e43c	blr	x8
000000010002e440	b	0x10002e47c
000000010002e444	ldr	x8, [x22, #0x10]
000000010002e448	ldur	x20, [x29, #-0xa0]
000000010002e44c	mov	x0, x20
000000010002e450	mov	x1, x23
000000010002e454	mov	x2, x21
000000010002e458	blr	x8
000000010002e45c	ldur	x8, [x29, #-0x88]
000000010002e460	bl	0x100088900 ; symbol stub for: _$s10Foundation13URLComponentsV3urlAA3URLVSgvg
```


## I35 — URL/URI 共用 builder，无 scheme 或非空分支

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46746–46796`（闭区间）
- VA：`0x10002e4b4–0x10002e578`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU10_`; `_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU6_Tm`

```asm
000000010002e4b4	mov	w1, #0x7275
000000010002e4b8	movk	w1, #0x6c, lsl #16
000000010002e4bc	b	_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU6_Tm
_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU6_Tm:
000000010002e4c0	stp	x22, x21, [sp, #-0x30]!
000000010002e4c4	stp	x20, x19, [sp, #0x10]
000000010002e4c8	stp	x29, x30, [sp, #0x20]
000000010002e4cc	add	x29, sp, #0x20
000000010002e4d0	mov	x19, x8
000000010002e4d4	ldr	x8, [x0, #0x10]
000000010002e4d8	cbz	x8, 0x10002e54c
000000010002e4dc	mov	x21, x1
000000010002e4e0	mov	x20, x0
000000010002e4e4	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e4e8	mov	x0, x21
000000010002e4ec	mov	x1, #-0x1d00000000000000
000000010002e4f0	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e4f4	tbz	w1, #0x0, 0x10002e544
000000010002e4f8	ldr	x8, [x20, #0x38]
000000010002e4fc	add	x8, x8, x0, lsl #4
000000010002e500	ldp	x21, x22, [x8]
000000010002e504	mov	x0, x22
000000010002e508	mov	w1, #0x2
000000010002e50c	bl	0x100089bc0 ; symbol stub for: _swift_bridgeObjectRetain_n
000000010002e510	mov	x0, x20
000000010002e514	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e518	mov	x8, x19
000000010002e51c	mov	x0, x21
000000010002e520	mov	x1, x22
000000010002e524	bl	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
000000010002e528	mov	x0, x22
000000010002e52c	mov	w1, #0x2
000000010002e530	bl	0x100089ba8 ; symbol stub for: _swift_bridgeObjectRelease_n
000000010002e534	ldp	x29, x30, [sp, #0x20]
000000010002e538	ldp	x20, x19, [sp, #0x10]
000000010002e53c	ldp	x22, x21, [sp], #0x30
000000010002e540	ret
000000010002e544	mov	x0, x20
000000010002e548	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e54c	mov	x0, #0x0
000000010002e550	bl	0x1000889e4 ; symbol stub for: _$s10Foundation3URLVMa
000000010002e554	mov	x3, x0
000000010002e558	ldur	x8, [x0, #-0x8]
000000010002e55c	ldr	x4, [x8, #0x38]
000000010002e560	mov	x0, x19
000000010002e564	mov	w1, #0x1
000000010002e568	mov	w2, #0x1
000000010002e56c	ldp	x29, x30, [sp, #0x20]
000000010002e570	ldp	x20, x19, [sp, #0x10]
000000010002e574	ldp	x22, x21, [sp], #0x30
000000010002e578	br	x4
```


## I36 — WeChat 与 Slack launch 常量

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46798–46811`（闭区间）
- VA：`0x10002e57c–0x10002e5ac`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU11_`; `_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU12_`

```asm
000000010002e57c	mov	x0, #0x6577
000000010002e580	movk	x0, #0x7869, lsl #16
000000010002e584	movk	x0, #0x6e69, lsl #32
000000010002e588	movk	x0, #0x2f3a, lsl #48
000000010002e58c	mov	x1, #0x2f
000000010002e590	movk	x1, #0xe900, lsl #48
000000010002e594	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU12_:
000000010002e598	mov	x0, #0x6c73
000000010002e59c	movk	x0, #0x6361, lsl #16
000000010002e5a0	movk	x0, #0x3a6b, lsl #32
000000010002e5a4	movk	x0, #0x2f2f, lsl #48
000000010002e5a8	mov	x1, #-0x1800000000000000
000000010002e5ac	b	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I37 — Slack team_id / channel_id 查找

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46838–46875`（闭区间）
- VA：`0x10002e610–0x10002e6a4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU13_`

```asm
000000010002e610	ldr	x8, [x20, #0x10]
000000010002e614	cbz	x8, 0x10002e818
000000010002e618	mov	x0, x20
000000010002e61c	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e620	mov	x0, #0x6574
000000010002e624	movk	x0, #0x6d61, lsl #16
000000010002e628	movk	x0, #0x695f, lsl #32
000000010002e62c	movk	x0, #0x64, lsl #48
000000010002e630	mov	x1, #-0x1900000000000000
000000010002e634	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e638	tbz	w1, #0x0, 0x10002e810
000000010002e63c	ldr	x8, [x20, #0x38]
000000010002e640	add	x8, x8, x0, lsl #4
000000010002e644	ldp	x26, x25, [x8]
000000010002e648	mov	x0, x25
000000010002e64c	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e650	mov	x0, x20
000000010002e654	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e658	ldr	x8, [x20, #0x10]
000000010002e65c	cbz	x8, 0x10002e800
000000010002e660	mov	x0, x20
000000010002e664	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e668	mov	x0, #0x6863
000000010002e66c	movk	x0, #0x6e61, lsl #16
000000010002e670	movk	x0, #0x656e, lsl #32
000000010002e674	movk	x0, #0x5f6c, lsl #48
000000010002e678	mov	x1, #0x6469
000000010002e67c	movk	x1, #0xea00, lsl #48
000000010002e680	bl	_$ss22__RawDictionaryStorageC4findys10_HashTableV6BucketV6bucket_Sb5foundtxSHRzlFSS_Tg5
000000010002e684	tbz	w1, #0x0, 0x10002e808
000000010002e688	ldr	x8, [x20, #0x38]
000000010002e68c	add	x8, x8, x0, lsl #4
000000010002e690	ldp	x9, x23, [x8]
000000010002e694	stur	x9, [x29, #-0x78]
000000010002e698	mov	x0, x23
000000010002e69c	bl	0x100089bb4 ; symbol stub for: _swift_bridgeObjectRetain
000000010002e6a0	mov	x0, x20
000000010002e6a4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
```


## I38 — Slack team 部分编码及 id 分隔符

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46883–46921`（闭区间）
- VA：`0x10002e6c4–0x10002e75c`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU13_`

```asm
000000010002e6c4	adrp	x8, 98 ; 0x100090000
000000010002e6c8	add	x8, x8, #0x220 ; literal pool for: "slack://channel?team="   ; "slack://channel?team="
000000010002e6cc	sub	x8, x8, #0x20
000000010002e6d0	orr	x8, x8, #0x8000000000000000
000000010002e6d4	mov	x9, #0x15
000000010002e6d8	movk	x9, #0xd000, lsl #48
000000010002e6dc	stp	x9, x8, [x29, #-0x60]
000000010002e6e0	stp	x26, x25, [x29, #-0x70]
000000010002e6e4	mov	x8, x22
000000010002e6e8	bl	0x1000888a0 ; symbol stub for: _$s10Foundation12CharacterSetV15urlQueryAllowedACvgZ
000000010002e6ec	bl	_$sS2SSysWl
000000010002e6f0	mov	x27, x0
000000010002e6f4	adrp	x1, 114 ; 0x1000a0000
000000010002e6f8	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002e6fc	sub	x20, x29, #0x70
000000010002e700	mov	x0, x22
000000010002e704	mov	x2, x27
000000010002e708	bl	0x100089158 ; symbol stub for: _$sSy10FoundationE21addingPercentEncoding21withAllowedCharactersSSSgAA12CharacterSetV_tF
000000010002e70c	mov	x20, x0
000000010002e710	mov	x28, x1
000000010002e714	ldr	x24, [x24, #0x8]
000000010002e718	mov	x0, x22
000000010002e71c	mov	x1, x21
000000010002e720	blr	x24
000000010002e724	cbz	x28, 0x10002e738
000000010002e728	mov	x0, x25
000000010002e72c	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e730	mov	x26, x20
000000010002e734	mov	x25, x28
000000010002e738	sub	x20, x29, #0x60
000000010002e73c	mov	x0, x26
000000010002e740	mov	x1, x25
000000010002e744	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002e748	mov	x0, x25
000000010002e74c	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e750	mov	w0, #0x6926
000000010002e754	movk	w0, #0x3d64, lsl #16
000000010002e758	mov	x1, #-0x1c00000000000000
000000010002e75c	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
```


## I39 — Slack channel 部分编码与 URL(string:)

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`46922–46951`（闭区间）
- VA：`0x10002e760–0x10002e7d4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LLSDySSSayAC6IntentVGGvpZfi10Foundation3URLVSgSDyS2SGcfU13_`

```asm
000000010002e760	ldur	x26, [x29, #-0x78]
000000010002e764	stp	x26, x23, [x29, #-0x70]
000000010002e768	mov	x8, x22
000000010002e76c	bl	0x1000888a0 ; symbol stub for: _$s10Foundation12CharacterSetV15urlQueryAllowedACvgZ
000000010002e770	adrp	x1, 114 ; 0x1000a0000
000000010002e774	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
000000010002e778	sub	x20, x29, #0x70
000000010002e77c	mov	x0, x22
000000010002e780	mov	x2, x27
000000010002e784	bl	0x100089158 ; symbol stub for: _$sSy10FoundationE21addingPercentEncoding21withAllowedCharactersSSSgAA12CharacterSetV_tF
000000010002e788	mov	x20, x0
000000010002e78c	mov	x25, x1
000000010002e790	mov	x0, x22
000000010002e794	mov	x1, x21
000000010002e798	blr	x24
000000010002e79c	cbz	x25, 0x10002e7b0
000000010002e7a0	mov	x0, x23
000000010002e7a4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e7a8	mov	x26, x20
000000010002e7ac	mov	x23, x25
000000010002e7b0	sub	x20, x29, #0x60
000000010002e7b4	mov	x0, x26
000000010002e7b8	mov	x1, x23
000000010002e7bc	bl	0x100088e7c ; symbol stub for: _$sSS6appendyySSF
000000010002e7c0	mov	x0, x23
000000010002e7c4	bl	0x100089b9c ; symbol stub for: _swift_bridgeObjectRelease
000000010002e7c8	ldp	x0, x20, [x29, #-0x60]
000000010002e7cc	mov	x8, x19
000000010002e7d0	mov	x1, x20
000000010002e7d4	bl	0x1000889d8 ; symbol stub for: _$s10Foundation3URLV6stringACSgSSh_tcfC
```


## I40 — Music open_url 记录存储及 builder 指针

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`45612–45629`（闭区间）
- VA：`0x10002d344–0x10002d388`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LL_WZ`

```asm
000000010002d344	adrp	x1, 127 ; 0x1000ac000
000000010002d348	add	x1, x1, #0xe0
000000010002d34c	mov	x0, x25
000000010002d350	mov	x28, x25
000000010002d354	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
000000010002d358	mov	x8, #0x706f
000000010002d35c	movk	x8, #0x6e65, lsl #16
000000010002d360	movk	x8, #0x755f, lsl #32
000000010002d364	movk	x8, #0x6c72, lsl #48
000000010002d368	mov	x9, #-0x1800000000000000
000000010002d36c	stp	x8, x9, [x22, #0x60]
000000010002d370	mov	x8, #0x3d
000000010002d374	movk	x8, #0x1000, lsl #48
000000010002d378	stp	x8, x24, [x22, #0x70]
000000010002d37c	stp	x0, x20, [x22, #0x80]
000000010002d380	adrp	x8, 2 ; 0x10002f000
000000010002d384	add	x8, x8, #0xed0
000000010002d388	stp	x8, xzr, [x22, #0x90]
```


## I41 — Safari open_url 记录存储及 builder 指针

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`45741–45759`（闭区间）
- VA：`0x10002d548–0x10002d590`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LL_WZ`

```asm
000000010002d548	adrp	x1, 127 ; 0x1000ac000
000000010002d54c	add	x1, x1, #0x1c8
000000010002d550	mov	x0, x28
000000010002d554	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
000000010002d558	mov	x8, #0x706f
000000010002d55c	movk	x8, #0x6e65, lsl #16
000000010002d560	movk	x8, #0x755f, lsl #32
000000010002d564	movk	x8, #0x6c72, lsl #48
000000010002d568	str	x8, [x24, #0x20]
000000010002d56c	mov	x10, #-0x1800000000000000
000000010002d570	mov	x9, #0x19
000000010002d574	movk	x9, #0xd000, lsl #48
000000010002d578	add	x8, x9, #0x18
000000010002d57c	stp	x10, x8, [x24, #0x28]
000000010002d580	stp	x21, x0, [x24, #0x38]
000000010002d584	adrp	x8, 1 ; 0x10002e000
000000010002d588	add	x8, x8, #0x4b4
000000010002d58c	stp	x20, x8, [x24, #0x48]
000000010002d590	str	xzr, [x24, #0x58]
```


## I42 — NetEase song 记录存储及 builder 指针

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`45477–45493`（闭区间）
- VA：`0x10002d128–0x10002d168`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LL_WZ`

```asm
000000010002d128	adrp	x1, 127 ; 0x1000ac000
000000010002d12c	add	x1, x1, #0x38
000000010002d130	mov	x25, x0
000000010002d134	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
000000010002d138	mov	x8, #0x6c70
000000010002d13c	movk	x8, #0x7961, lsl #16
000000010002d140	movk	x8, #0x735f, lsl #32
000000010002d144	movk	x8, #0x6e6f, lsl #48
000000010002d148	mov	x9, #0x67
000000010002d14c	movk	x9, #0xe900, lsl #48
000000010002d150	stp	x8, x9, [x27, #0x60]
000000010002d154	add	x8, x23, #0x1b
000000010002d158	stp	x8, x21, [x27, #0x70]
000000010002d15c	stp	x0, x20, [x27, #0x80]
000000010002d160	adrp	x8, 0 ; 0x10002d000
000000010002d164	add	x8, x8, #0xaa8
000000010002d168	stp	x8, xzr, [x27, #0x90]
```


## I43 — NetEase route 记录存储及 builder 指针

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`45561–45577`（闭区间）
- VA：`0x10002d278–0x10002d2b8`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LL_WZ`

```asm
000000010002d278	adrp	x1, 127 ; 0x1000ac000
000000010002d27c	add	x1, x1, #0xa8
000000010002d280	mov	x0, x25
000000010002d284	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
000000010002d288	mov	x8, #0x706f
000000010002d28c	movk	x8, #0x6e65, lsl #16
000000010002d290	movk	x8, #0x725f, lsl #32
000000010002d294	movk	x8, #0x756f, lsl #48
000000010002d298	mov	x9, #0x6574
000000010002d29c	movk	x9, #0xea00, lsl #48
000000010002d2a0	stp	x8, x9, [x27, #0x160]
000000010002d2a4	add	x8, x21, #0xed
000000010002d2a8	stp	x8, x22, [x27, #0x170]
000000010002d2ac	adrp	x8, 0 ; 0x10002d000
000000010002d2b0	add	x8, x8, #0xe68
000000010002d2b4	stp	x0, x20, [x27, #0x180]
000000010002d2b8	stp	x8, xzr, [x27, #0x190]
```


## I44 — Mail compose 记录存储及 builder 指针

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`45704–45720`（闭区间）
- VA：`0x10002d4b4–0x10002d4f4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LL_WZ`

```asm
000000010002d4b4	adrp	x1, 127 ; 0x1000ac000
000000010002d4b8	add	x1, x1, #0x150
000000010002d4bc	str	x28, [sp, #0x40]
000000010002d4c0	mov	x0, x28
000000010002d4c4	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
000000010002d4c8	mov	x8, #0x6f63
000000010002d4cc	movk	x8, #0x706d, lsl #16
000000010002d4d0	movk	x8, #0x736f, lsl #32
000000010002d4d4	movk	x8, #0x65, lsl #48
000000010002d4d8	mov	x9, #-0x1900000000000000
000000010002d4dc	stp	x8, x9, [x23, #0x20]
000000010002d4e0	ldr	x8, [sp, #0x48]
000000010002d4e4	stp	x8, x24, [x23, #0x30]
000000010002d4e8	stp	x20, x0, [x23, #0x40]
000000010002d4ec	adrp	x8, 1 ; 0x10002e000
000000010002d4f0	add	x8, x8, #0x74
000000010002d4f4	stp	x8, xzr, [x23, #0x50]
```


## I45 — Slack open_channel 参数记录及 builder 指针

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`
- 原文件 SHA-256：`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`
- 版本／架构／强度：`0.4.153 / arm64 / P153（静态控制流）`
- 原始行范围：`45825–45844`（闭区间）
- VA：`0x10002d698–0x10002d6e4`（闭区间）
- 符号：`_$s4main18AppCommandRegistryO7entries33_7A082DD57C63F2D79BADE260B1A1C753LL_WZ`

```asm
000000010002d698	adrp	x1, 127 ; 0x1000ac000
000000010002d69c	add	x1, x1, #0x200
000000010002d6a0	ldr	x0, [sp, #0x40]
000000010002d6a4	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
000000010002d6a8	mov	x8, #0x706f
000000010002d6ac	movk	x8, #0x6e65, lsl #16
000000010002d6b0	movk	x8, #0x635f, lsl #32
000000010002d6b4	movk	x8, #0x6168, lsl #48
000000010002d6b8	mov	x9, #0x6e6e
000000010002d6bc	movk	x9, #0x6c65, lsl #16
000000010002d6c0	movk	x9, #0xec00, lsl #48
000000010002d6c4	stp	x8, x9, [x26, #0x60]
000000010002d6c8	mov	x8, #0x19
000000010002d6cc	movk	x8, #0xd000, lsl #48
000000010002d6d0	add	x8, x8, #0x35
000000010002d6d4	stp	x8, x28, [x26, #0x70]
000000010002d6d8	stp	x0, x20, [x26, #0x80]
000000010002d6dc	adrp	x8, 1 ; 0x10002e000
000000010002d6e0	add	x8, x8, #0x5b0
000000010002d6e4	stp	x8, xzr, [x26, #0x90]
```


## I46 — 静态参数数组原始字节

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/AlmaComputerUse.bin`
- 原文件 SHA-256：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`
- 版本／架构／强度：`0.4.153 / universal 中 arm64 / P153（二进制原字节）`
- 原始行范围：不适用（二进制）；下表逐项给出 VA 与文件 byte-offset 闭区间
- 符号归属：`AppCommandRegistry.entries` 引用的静态 Swift String 数组；不是带名称的独立源变量
- arm64 slice 文件起点：`0x128000`；数组头的 count 在 base+0x10，String 记录在 base+0x20；仅列 count 与有效 String 记录，不复制无关数据

|数组 VA|count VA / 文件 offset / 原始 8 字节|元素 VA / 文件 offset 闭区间|原始元素十六进制|R：small-string 解码|
|---|---|---|---|---|

|`0x1000ac038`|`0x1000ac048` / `0x1d4048–0x1d404f` / `0100000000000000`|`0x1000ac058–0x1000ac067` / `0x1d4058–0x1d4067`|`736f6e675f69640000000000000000e7`|song_id|

|`0x1000ac070`|`0x1000ac080` / `0x1d4080–0x1d4087` / `0100000000000000`|`0x1000ac090–0x1000ac09f` / `0x1d4090–0x1d409f`|`706c61796c6973745f696400000000eb`|playlist_id|

|`0x1000ac0a8`|`0x1000ac0b8` / `0x1d40b8–0x1d40bf` / `0100000000000000`|`0x1000ac0c8–0x1000ac0d7` / `0x1d40c8–0x1d40d7`|`726f75746500000000000000000000e5`|route|

|`0x1000ac0e0`|`0x1000ac0f0` / `0x1d40f0–0x1d40f7` / `0100000000000000`|`0x1000ac100–0x1000ac10f` / `0x1d4100–0x1d410f`|`75726c000000000000000000000000e3`|url|

|`0x1000ac118`|`0x1000ac128` / `0x1d4128–0x1d412f` / `0100000000000000`|`0x1000ac138–0x1000ac147` / `0x1d4138–0x1d4147`|`757269000000000000000000000000e3`|uri|

|`0x1000ac150`|`0x1000ac160` / `0x1d4160–0x1d4167` / `0500000000000000`|`0x1000ac170–0x1000ac1bf` / `0x1d4170–0x1d41bf`|`746f00000000000000000000000000e27375626a6563740000000000000000e7626f64790000000000000000000000e4636300000000000000000000000000e2626363000000000000000000000000e3`|to, subject, body, cc, bcc|

|`0x1000ac1c8`|`0x1000ac1d8` / `0x1d41d8–0x1d41df` / `0100000000000000`|`0x1000ac1e8–0x1000ac1f7` / `0x1d41e8–0x1d41f7`|`75726c000000000000000000000000e3`|url|

|`0x1000ac200`|`0x1000ac210` / `0x1d4210–0x1d4217` / `0200000000000000`|`0x1000ac220–0x1000ac23f` / `0x1d4220–0x1d423f`|`7465616d5f69640000000000000000e76368616e6e656c5f69640000000000ea`|team_id, channel_id|


## I47 — Mail query 参数顺序原始字节

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/AlmaComputerUse.bin`
- 原文件 SHA-256：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`
- 版本／架构／强度：`0.4.153 / arm64 / P153（二进制原字节）`
- 原始行范围：不适用（二进制）；文件 byte-offset：`0x1d4280–0x1d42bf`
- VA：`0x1000ac280–0x1000ac2bf`
- 符号归属：`AppCommandRegistry.entries` 的 Mail builder `…cfU9_` 所引用四项常量；引用见 I33

```text
7375626a6563740000000000000000e7626f64790000000000000000000000e4636300000000000000000000000000e2626363000000000000000000000000e3
```

R：四个 16 字节小字符串依次解为 subject、body、cc、bcc；与 I33 中 4 次循环共同闭合输出顺序。


## I48 — NSWorkspaceOpenConfiguration 绑定纠正 bad class ref 注释

- 原始来源：`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/AlmaComputerUse.bin`
- 原文件 SHA-256：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`
- 版本／架构／强度：`0.4.153 / arm64 / P153（原始绑定字节）+ R（格式解码）`
- 原始行范围：不适用（二进制）；精确范围如下
- 符号：`_OBJC_CLASS_$_NSWorkspaceOpenConfiguration`
- classref VA：`0x1000aa4a0–0x1000aa4a7`，文件 `0x1d24a0–0x1d24a7`，字节 `cb02000000001080`
- chained-fixups import format：`1`；classref bind ordinal：`715`；import record 文件 `0x1d8ba0–0x1d8ba3`，字节 `01c8cd00`
- import-name 文件 `0x1df370–0x1df39a`，字节 `5f4f424a435f434c4153535f245f4e53576f726b73706163654f70656e436f6e66696775726174696f6e00`（含终止 NUL）；这是 linkedit 文件记录，非运行时代码 VA
- R：解码该字符串为 `_OBJC_CLASS_$_NSWorkspaceOpenConfiguration`；I11 从同一 classref 分配配置对象。因此原反汇编的 bad class ref 是注释未解析，并非未知配置类型
