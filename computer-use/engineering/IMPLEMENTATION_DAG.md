# 实现依赖与工单交付DAG

本轮交付技术方案，不执行下列产品开发。profile未选择时可阅读/设计/纯规格校验，不能以本页为真实桌面权限授权。旧手册19张总工单完整保留在 [第08章](../chapters/08_独立实现工程手册.md)，本页把它们拆成模块级先后依赖。

## 分阶段依赖

G0 证据/版本/profile决定 → G1 wire+fake backend → G2 refs/snapshot/diff → G3 capture/mapping/OCR → G4 AX动作 → G5 pointer/keyboard/focus → G6 host/MCP/CLI/model结果 → G7 镜像/Appshot → G8 受控全链报告。

G6的适配纯mock可在G1后并行；G7的纯registry和fake frame可在G1后并行；真实UI消费必须等G3和G6。native HTTP/OAuth为G9高级可选，不是最小链必需，不得因它有14工具就在默认启动时开放监听。

| 票 | 输入依赖 | 输出artifact | Exit证据 |
|---|---|---|---|
| CU-00 | SOURCE_MANIFEST与STOP | profile决策记录/能力范围/未知表 | 不含默认真实profile、不能把unknown当已证 |
| CU-01…03 | 模块01 | WireKernel、fake流、ping-onlydaemon | partialread/write/id/EOF/并发/断连观测 |
| CU-04…06 | CU-01 | ElementStore+boundedRecovery | CFEqual、200/12/unique、代际不重置 |
| CU-07…09 | CU-04 | serializer/wakeup/diff | full→delta→disabled→delta黄金数据 |
| CU-10…13 | CU-07 | capture/cache/mapping/visualindex | 几何纯公式+真实夹具四角marker |
| CU-14…16 | CU-04,10 | AXrouter/eventfactory/pointer | 真实receiver一次effect、旁路不变、up释放 |
| CU-17…20 | CU-14 | key/text/focus backends | 20scalar、UTF16、5秒lease、焦点事件见证 |
| CU-21…23 | CU-01（mock）；真实需G5 | 23stdio+CLI适配 | schema/payload/output分别断言 |
| CU-24…27 | CU-21 | HTTP/model/stop/audit | 30route注册、isError、图像与压缩、迟到回复 |
| CU-28…31 | CU-10,24 | PiP+framelease+native展示 | 非零时钟、关闭抑制、晚完成资源归属 |
| CU-32…35 | CU-10,24 | Appshot image/AX/附件 | 早晚事件、nilhotkey、无auto-send |
| CU-36…38 | CU-01 | AppUsage/intent/extensions | merge/sort/2秒fallback/明确allowlist |
| CU-39 | CU-01,38+高级范围选择 | nativeHTTP隔离模块 | registry/TTL/token路径/未知身份边界 |
| CU-40 | 被选能力全部Exit | 受控macOS验收报告 | OS/架构/TCC/receiver/focus/cursor/capture完整 |

## 每票必须交回

1. 修改文件与模块API；来源链接、原样本hash和对照分支
2. requirements/cases对应；纯单测与真实运行分别记录
3. 实际执行命令、返回码、artifact位置；未运行项不能写预计通过
4. profile与安全偏离；compa​​t和safe的不同oracle不得串用
5. 资源owner、teardown顺序、晚完成处理、mutation dispatch次数
6. STOP：缺失事实、影响、暂时拒绝策略、下一观察、负责人

## 允许并行与禁止并行

允许：wire schema测试与PiP fakeclock；MCP mock与AppUsage纯排序；文档/代码证据补证。禁止：多个worker共用真实用户桌面发输入；同时改共享owner；未证明全局串行便将click/type并发；超时后另worker重新执行同mutation。

阶段完成不是代码生成完毕，而是其Exit证据成立。若缺macOS或权限，保留阶段NOT_RUN，交付已完成的纯测试证据，不迁移到真实个人app凑结果。
