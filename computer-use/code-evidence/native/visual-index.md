# 原始反汇编节选 visual-index

样本：用户提供 .153 universal helper；本页只用ARM64反汇编。helper SHA256 `b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`；ARM64 slice SHA256 `de569c288715c2e12243832aa61a02e671c497784c3d87d6dda9e9fc8d7d3fb4`。原文档路径 `alma-computer-use-0.4.153/evidence/disasm.annot.txt`；全文件SHA256 `543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`。

证据强度：原始二进制的既有带注释反汇编文本（STATIC、NOT_EXECUTED），不是厂商Swift源码，也不是本次运行结果。保留原注释便于复核，但自动字符串注释可能使用陈旧寄存器，结论必须从指令与分支推导。此页不能单独证明 .164 同行为；对应 .164 研究契约与跨版本局部核验分开引用。代码前的行号为原文件行号。

## L50041

### Vision recognition raw1

原行范围 `50041–50078`（inclusive）；VA `0000000100031700–0000000100031794`；最近函数符号 `_$s4main11VisualIndexO5index9imagePath10maxResultsSayAC6RegionVGSS_SitFZ:`；原区间SHA256 `652738571a15cffb3866f2a542fa3f32b39bab49aa8452f59906d6bdd439de82`。

```asm
050041  0000000100031700	mov	x1, #0x0
050042  0000000100031704	bl	0x100089830 ; symbol stub for: _CGImageSourceCreateWithDataProvider
050043  0000000100031708	cbz	x0, 0x100031928
050044  000000010003170c	stur	x0, [x29, #-0x100]
050045  0000000100031710	mov	x1, #0x0
050046  0000000100031714	mov	x2, #0x0
050047  0000000100031718	bl	0x100089824 ; symbol stub for: _CGImageSourceCreateImageAtIndex
050048  000000010003171c	cbz	x0, 0x100031930
050049  0000000100031720	mov	x19, x0
050050  0000000100031724	adrp	x8, 121 ; 0x1000aa000
050051  0000000100031728	ldr	x0, [x8, #0x4d8] ; Objc class ref: bad class ref
050052  000000010003172c	bl	0x100089aac ; symbol stub for: _objc_allocWithZone
050053  0000000100031730	bl	_objc_msgSend$init
050054  0000000100031734	mov	x20, x0
050055  0000000100031738	mov	w2, #0x1
050056  000000010003173c	bl	"_objc_msgSend$setRecognitionLevel:"
050057  0000000100031740	mov	x0, x20
050058  0000000100031744	mov	w2, #0x0
050059  0000000100031748	bl	"_objc_msgSend$setUsesLanguageCorrection:"
050060  000000010003174c	adrp	x0, 121 ; 0x1000aa000
050061  0000000100031750	add	x0, x0, #0xaf0
050062  0000000100031754	adrp	x1, 91 ; 0x10008c000
050063  0000000100031758	add	x1, x1, #0xe80   ; "d\"
050064  000000010003175c	bl	___swift_instantiateConcreteTypeFromMangledNameV2
050065  0000000100031760	adrp	x1, 123 ; 0x1000ac000
050066  0000000100031764	add	x1, x1, #0x428
050067  0000000100031768	bl	0x100089d40 ; symbol stub for: _swift_initStaticObject
050068  000000010003176c	adrp	x1, 111 ; 0x1000a0000
050069  0000000100031770	ldr	x1, [x1, #0x9c0] ; literal pool symbol address: _$sSSN
050070  0000000100031774	bl	0x100088f54 ; symbol stub for: _$sSa10FoundationE19_bridgeToObjectiveCSo7NSArrayCyF
050071  0000000100031778	mov	x21, x0
050072  000000010003177c	mov	x0, x20
050073  0000000100031780	mov	x2, x21
050074  0000000100031784	bl	"_objc_msgSend$setRecognitionLanguages:"
050075  0000000100031788	mov	x0, x21
050076  000000010003178c	bl	0x100089ad0 ; symbol stub for: _objc_release
050077  0000000100031790	mov	x0, x19
050078  0000000100031794	bl	0x100089adc ; symbol stub for: _objc_retain
```
