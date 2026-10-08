# 2026年10月7日整合修订

## 文档结构

新增统一START_HERE、11个模块主线与原生HTTP高级模块；每模块包含架构、输入/状态、关键分支、输出错误、清理、原代码、工单、验收与Agent提示。保留原14章和结构化契约，21个重建源码文件按文件审查并隔离错误，不构建新应用。全部叙述为Markdown；JSON/schema为独立机器数据，少量Python只校验资料。

## 已修正的既有资料

1. UI.cooldown从activity0改为10000，tick10333/10666/10999/11332，expected capture_start11332；另加UI.cooldown.zero_sentinel，0意味着Infinity。正式语料733→734；453schema、113authored、168runtime；551static/183runtime未知；所有NOT_RUN，原39P0保留。HTTP/Intent高级模块另有79条Markdown设计用例，不并入主734-case harness；合计813个设计条目
2. 镜像实施计划同步非零clock；主行为段直接限定launch_app成功REST handler早于后置middleware，不以路径名单断言实际经过
3. 章节03和native快照报告移除已过期的encode fallback/element optional/AXWindows blanket unknown；保留真正未闭合的容器/CG fallback/OS语义
4. version-comparison升级 .153 MCP/native已获得原bytes的来源状态；不升级未提供的 .153 host/CLI/registration原文件

## 合并时裁决

保留长期eN/CFEqual、200节点12层唯一恢复、20Unicode scalar、ref/focused SelectedText不同失败语义、active key-window、5秒focus尾期、directsnap≠diff、窗口capture<14错误、display cursor、Appshot image-first/AX-later、nativePiP真实status与arm回调。这些均不照搬新重建错误。

nativeHTTP补code60秒/access3600秒、authorize可选alma_arm_pid、staticbearer并行路径、静态tool目录gate、换码不写启动token文件等 .153证据。签名验证不证明真实HTTPcaller身份。完整目录细节以高级模块逐字段原证据为准。

## 资料质量修订

新模块descriptor字段对齐原契约：role/subrole/title/identifier/roleDescription/parentRoles，不把value/description塞进descriptor。pump watchdog严格>4000ms才清busy，清flag的同tick仍return。armer解除仅指最小化通知已有session/自动open成功，不是pip_arm命令成功立即解除。

文档验证和产品测试分开：当前checker只读资料；原历史733-case校验报告移作参考，不作为本包现状。任何文件数与hash以最终manifest和VALIDATION页为准。
