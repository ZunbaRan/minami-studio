# 来源身份与证据等级

## 输入样本身份

| 样本 | SHA256 | 使用范围 |
|---|---|---|
| 官方 alma-0.4.164-mac-arm64.zip | `2bca9d726ab88e3f68290d0aa82a231cbd0491d2242d6d1ddb638ad7bd236901` | 已验证官方静态样本，不随交付附带安装包 |
| .164 out/main/index.js | `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175` | host/PiP/Appshot原始有界片段 |
| .153 与 .164 alma-computer-use-mcp.mjs | `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976` | 两文件1,367,381字节完全相同；应用层23工具局部原文 |
| .153 universal helper | `b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3` | 用户提供原始二进制的既有反汇编证据；不附二进制、不执行 |
| .164 universal helper | `453d60872ac801f44497b34d2f68edf7d0fee497420ac44c5d05d785c62b8551` | 当前研究契约与局部跨版本字节检查来源；不附二进制 |
| .153 ARM64 slice | `de569c288715c2e12243832aa61a02e671c497784c3d87d6dda9e9fc8d7d3fb4` | 所附 .153 ASM页的架构范围 |
| .164 ARM64 slice | `e35a67ad655c5aec774b68e81795a903696bb01f94b09fb2f2004f5e1f79cce3` | 地址不能与 .153混用 |
| .153 disasm.annot.txt | `543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5` | 140728行，5,975,544字节；只摘相关函数边界，不完整转储 |
| 旧 .164 研究ZIP | `673884cb3adbe2b4ebd1000dfd197712480c52fd5fda21abf12f015508727b29` | 原87文件/14章/733设计语料的来源 |
| 新 .153 reconstruction ZIP | `8ccf75286fb1c732b6433a302bbad397b7a9f3fcf97b821458f4c27c5c18927d` | 16文档、21重建文件、原始证据与作者报告；不作为可编译项目 |
| 旧 .164 DOCX | `72a4e83e80855c3f4cf0fa125aa9c2a6fac971259edb92fe21ea7a96e243c4ac` | 已有内容对照来源，本次未重新渲染或交付DOCX |

官方样本来源为 https://updates.alma.now/alma-0.4.164-mac-arm64.zip 。本包可独立阅读/校验，无需访问该URL，也不自动下载或执行它。

## 证据等级

E1 ORIGINAL_SOURCE：原始JS应用层局部，原路径/全hash/字节或字符半开范围/区间hash明确。minified JS仍是原文；本次未执行。

E2 BINARY_STATIC：已有原始反汇编的有界指令范围，说明样本/架构/VA/函数符号/原行与hash。反汇编注释自身不等于证明，尤其ADRP/ADD自动字符串注释可能残留旧寄存器；裁决应跟踪指令数据流。

E3 DERIVED_CONTRACT：用户已有 .164 契约经整合修订，记录其原文件hash；源定位已保留，但并非本轮对所有指令重新反汇编。新模块将它们与E1/E2对应，不能升级成新运行结果。

E4 AUTHOR_REPORTED：另一研究者的 .153 探测摘要，含省略与叙述，本次不重跑、不是byte-exact trace。已合成化且不带个人窗口/用户名/标识。

E5 DESIGN：独立实现架构、safe_profile、安全改良、工单、734cases、受控验收。没有执行就必须NOT_RUN。profile默认UNSELECTED。

E6 QUARANTINED：有错误或证据不足的重建代码/解释。仅保留模块思想和被拒结论，不能从文件头FULLY VERIFIED等文字自证。

## 跨版本结论范围

MCP整文件byte-identity已成立，工具计数/stdio包装差异不能归因版本。helper两版都是universal x86_64+arm64且两slice都不同；局部分析找出2330共有规范化代码符号、702完全相同函数体，不能从不等字节断言行为改变，也不能从部分同字节断言全程序同义。本包不声称已完整重反汇编 .164 helper。

.164同thread滑动10分钟dismissal保留；.153重建没有此能力不能覆盖 .164。NativeHTTP新增取证主要属 .153；.164控制面七命令的既有契约另在native-snapshot中。每个高级字段按具体证据决定，不“全部移植.153为.164”。

## 定位与完整性

- [所有原有资料映射](BASELINE_FILE_MAP.md)
- [逐函数代码证据](CODE_INDEX.md)
- [旧版作者报告状态](REPORTED_PROBES.md)
- [完整交付文件清单](FILE_MANIFEST.md)

ASM页的原始行区间inclusive；JS字节/字符区间half-open；所有hash按原始UTF-8/二进制字节计算，不含Markdown标题、代码围栏和加的行号。新文档文件hash另见FILE_MANIFEST。源路径是样本内路径，不能作为本机可读路径使用。
