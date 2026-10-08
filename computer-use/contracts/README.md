# 结构化契约与设计数据目录

为遵循全部文档Markdown要求，schema/JSON保留独立机器文件，研究脚本以Markdown阅读页保留；这些是数据与设计，不是已实现应用。可阅读或经后续批准提取到独立工程；不要直接运行历史参考脚本。

- [contract-vectors.json](../analysis/conformance/contract-vectors.json)
- [contract-vectors.schema.json](../analysis/conformance/contract-vectors.schema.json)
- [evidence-registry.json](../analysis/conformance/evidence-registry.json)
- [fixture-specifications.json](../analysis/conformance/fixture-specifications.json)
- [module-handoffs.json](../analysis/conformance/module-handoffs.json)
- [oracle-selftest.json](../analysis/conformance/oracle-selftest.json)
- [p0-critical-subset.json](../analysis/conformance/p0-critical-subset.json)
- [portable-validation-report.json](../analysis/conformance/portable-validation-report.json)
- [requirements-traceability.json](../analysis/conformance/requirements-traceability.json)
- [runtime-result.schema.json](../analysis/conformance/runtime-result.schema.json)
- [staged-plan.json](../analysis/conformance/staged-plan.json)
- [validation-report.json](../analysis/conformance/validation-report.json)
- [cli-command-catalog.json](../analysis/mcp/cli-command-catalog.json)
- [protocol-catalog.json](../analysis/mcp/protocol-catalog.json)
- [source-locators.json](../analysis/mcp/source-locators.json)
- [synthetic-conformance-vectors.json](../analysis/mcp/synthetic-conformance-vectors.json)
- [tool-inventory.json](../analysis/mcp/tool-inventory.json)
- [app-usage-row.schema.json](../contracts/app-usage-row.schema.json)
- [coverage-matrix.json](../contracts/coverage-matrix.json)
- [intent-metadata.json](../contracts/intent-metadata.json)
- [native-envelope.schema.json](../contracts/native-envelope.schema.json)
- [normalized-state.schema.json](../contracts/normalized-state.schema.json)
- [reference-dependencies.json](../contracts/reference-dependencies.json)
- [safe-policy.json](../contracts/safe-policy.json)
- [serialized-element.schema.json](../contracts/serialized-element.schema.json)
- [version-comparison.json](../contracts/version-comparison.json)

## Native帧schema范围

native-envelope.schema.json只描述request/reply，不声称所有socket帧都在此union。push事件有evt:true/topic/payload，appshot.monitor与appshot.update的topic-specific字段以APPSHOT_EXTRA_CONTRACTS及host-contracts为准；不要将事件送入replyid匹配器。
