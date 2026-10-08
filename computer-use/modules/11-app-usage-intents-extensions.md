# 应用目录意图与原生扩展

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

AppUsage汇合运行应用与metadata历史；AppCommandRegistry表达支持的应用意图元数据及dispatch，不能据symbols或recipe推所有app已实测。native扩展命令独立于stdio工具目录。

## 2 输入与默认

AppUsage行9字段：bundle/name/pid/active/running/path/use_count/last_used_at/intents；不是重建bundle_id/last_used_seconds_ago。days与metadata过滤按既有契约；native intent工具从HTTP registry显式映射，不能任意透传daemoncmd。

## 3 状态与所有权

先以running apps seed，再按bundle合并历史；无历史运行app仍保留。metadata查询main queue调度、2秒预算，超时可running-only成功fallback。意图目录与实际执行注册表必须分别记录。

## 4 逐分支执行

1. 获取运行列表并生成基础行→metadata查询匹配bundle→合并同bundle→构建intents
2. stable排序active优先、running优先、use_count比较、lowercased name；不要改成lastUsedAt排序
3. intent按app与name参数匹配已支持动作，再调用openQuietly等目标函数；重建外层再open可能重复副作用，禁止照抄
4. permissions/grant仅说明AX/ScreenCapture状态与请求；安装helper、应用ledger、OS TCC是独立层
5. remote_input/lens/raise/shot_display/native PiP/MCP controls按45命令表逐项决定可达入口；不因host client存在就自动造同名REST
6. 禁止目标规则只有特定PID/bundle分支，不能称全面保护系统UI；safe target policy应在所有mutation adapter统一执行并标偏离

## 5 输出与错误

意图参数、app未运行、launch结果、URL打开与未知intent必须按对应命令contract记录。safe只允许明确fixture目标、禁未知URI scheme、日志不存真实内容；不得把这些额外策略写成Alma原行为。

## 6 清理取消与竞争

metadata query结束/超时的stop与回调必须完整记录，不能Thread.cancel代替CFRunLoop或NSMetadataQuery生命周期。原生HTTP扩展属于可选高级模块，不应阻塞最小read-act-verify链。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [APP_USAGE_CONTRACT.md](../analysis/native-snapshot/APP_USAGE_CONTRACT.md)
- [APP_INTENTS_METADATA.md](../analysis/native-snapshot/APP_INTENTS_METADATA.md)
- [UTILITY_COMMANDS.md](../analysis/native-snapshot/UTILITY_COMMANDS.md)
- [REMOTE_LENS_EXTRA_CONTRACTS.md](../analysis/native-snapshot/REMOTE_LENS_EXTRA_CONTRACTS.md)
- [MCP_CONTROL_EXTRA_CONTRACTS.md](../analysis/native-snapshot/MCP_CONTROL_EXTRA_CONTRACTS.md)
- [12_附录原生命令清单.md](../chapters/12_附录原生命令清单.md)
- [13_附录原生扩展契约.md](../chapters/13_附录原生扩展契约.md)

对应代码/函数：

- [app-usage](../code-evidence/native/app-usage.md)
- [action-cursor](../code-evidence/native/action-cursor.md)

## 8 依赖与实现步骤

CU-36 AppUsage纯merge/sort→CU-37 metadata timeout fake→CU-38 intent目录/分发隔离测试→CU-39可选HTTP MCP模块。用户数据查询与URL打开运行阶段需单独授权。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

running无history、同bundle合并、countnil、大小写稳定排序、2秒timeout fallback、unknownintent、重复open防线、native扩展未注册stdio、真实来源数据禁止写进fixture。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
