# 本包资料校验结果

日期：2026-10-07。结论：PASS_DOCUMENT_PACKAGE_ONLY；产品构建/原程序执行/真实macOS验收仍为0次、NOT_RUN。

## 实际执行的检查

1. 主734条设计向量均通过自身JSON Schema；全部execution_status=NOT_RUN，ID唯一、evidence与requirement双向引用完整
2. 453条schema排列与本包静态转录工具schema一致；此检查比较资料，不调用真实tools/list或daemon
3. 原39条P0的expected_observation与主语料完全一致；没有伪造actual observation
4. UI.cooldown精确检查activity10000/ticks10333,10666,10999,11332/expected11332；zero_sentinel独立保留0→Infinity
5. Advanced目录另有79条设计条目（AU24/RP22/LC10/IT23），全部DESIGNED_NOT_RUN；未并入734条机器harness，总813条设计记录不能当813次测试
6. 全部JSON解析、schema结构、默认UNSELECTED/live_input=false、相对文档链接和已使用章节锚点检查
7. 独立临时文件夹复制本包，不带任何原ZIP/二进制/外部路径，再跑conformance checker通过
8. 新附原生函数有52个有界ASM段逐行与原 .153 文本比对；HTTP/Intent补充107段由专题取证逐行核对，相关区间hash已复算。stdio应用层按原区间hash核对，host摘录精确匹配官方源区间
9. 查无原始个人probe的窗口标题、用户目录和标识；未包含Mach-O、完整vendor SDK、完整prompt、真实profile或凭证
10. 最终FILE_MANIFEST列每文件字节数和SHA256；再由validate_package.py --verify-manifest读取核验

## 本包执行方式

在解压后的computer-use目录执行：

```sh
python3 validate_package.py --verify-manifest
python3 analysis/conformance/validate_conformance.py
```

Python验证器只读本包资料；第二条会重写同内容的资料validation-report.json，不执行vendor脚本、应用、daemon或OS输入。JSON Schema依赖见analysis/conformance/requirements.txt，当前环境已有依赖，本次未安装软件。旧build_*.py以Markdown参考页保留，尚非734条的完整重生成入口，不应用其覆盖当前语料。

## 数量与边界

219个文件：173个Markdown文档、42个JSON数据、3个仅资料用途Python、1个依赖文本；88个code-evidence页面含原文或证据索引。数量是资料库存，不是能力覆盖率。代码证据按E1/E2、契约按E3、设计按E5分层；不是所有原始指令都重新审过。

主语料734=453schema+113authored+168runtime；551 STATIC_EXPECTATION，183 UNKNOWN_REQUIRE_RUNTIME；39P0未运行。高级79只给未来独立实现作验收设计。未完成真实receiver/focus/cursor/OS验证，不宣布产品parity、无抢焦点或HTTP安全身份保证。
