> 来源：用户提供的 .164 研究资料 `README.zh-CN.md`；原文件 SHA256 `1308e9e9d3efabc2a7e17ddb414d913e42495622fc55adb125c19067a91b9353`；全文件 1–29 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Alma 0.4.164 Computer Use 独立复刻资料包

这是中文实施手册的机器可读伴随包。所有产品测试均未运行；数据校验结果只证明资料一致性。未包含Alma代码、二进制、反汇编、提示词、真实截图或秘密。

## 阅读顺序

1. 完整实现手册.md是完整文本；chapters/提供可单独输入编程模型的章节
2. 先读chapters/01与07，再按chapters/08的工单零、固定文件地图和DAG推进
3. 先跑analysis/conformance/P0.zh-CN.md说明的关键mock测试，再做授权macOS夹具测试
4. 只给执行模型当前工单、对应contracts与fixture；未知处按STOP记录，不自行发明行为
5. analysis/保留分层原创技术规格；字段schema和source locator不是原代码

## 离线资料检查

解压后在包根运行 python3 validate_bundle.py，使用Python标准库，检查文件hash、JSON语法、基础数量与禁止内容边界，不运行Alma或复刻产品。

更详细的schema/traceability验证入口是analysis/conformance/validate_conformance.py；参数和依赖按同目录README。默认不要求官方原包。若自行合法取得同hash官方样本，可按它的--sample-root模式附加范围hash核对。不要把官方样本复制进本资料包。

## 证据路径

evidence/保存样本身份与提取完整性元数据。contracts/version-comparison.json中的旧版只来自固定旧报告，未重取旧原始样本。analysis中的extracted/...、.asm、*disasm*或Mach-O引用是原样本定位说明，均未分发；以SHA256、VA、section/fat offset或source-locators的byte范围在独立样本复核。不能把缺失的原始分析转储当成复制工程依赖。

## 实现身份和边界

参考项目用独立CUReplica名称及bundle身份，不连接或修改已有Alma socket/data/TCC授权。alma_0_4_164与safe_profile是两种不同验收profile。safe-policy.json全部为原创设计常量，不是Alma配置。工具链候选见reference-dependencies.json，尚未在新仓库构建验收。

## 验证状态

bundle-manifest.json记录本包文件hash。文档/schema/判定器自检与产品测试分别报告。没有macOS事件、焦点、TCC、私有SPI或provider运行通过证明。不要将expected复制为actual获得伪通过。
