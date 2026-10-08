# 受控 macOS 验收方案

状态：未运行。本包没有启动原产品、重建源码、二进制、桌面输入或实际账户；下面是后续授权实现的验收设计。原39项P0子集与734正式cases全部保持NOT_RUN。

## 0 进入条件与停止

必须已有明确profile（alma_0_4_164 compatibility或safe_profile）；默认UNSELECTED。说明目标是兼容哪一版本、选择哪些能力、哪些安全修复是偏离。准备独立测试应用和旁路前台应用，仅合成文本/窗口/文件；TCC、签名、安装、运行与系统设置操作按当时授权办理，本页不授予权限。

需要真实个人窗口内容、credentials、真实profile、外发消息、付款、系统保护绕过时STOP。未经确认的private SPI ABI、未知point/pixel单位、无法配对up、无法判断实际target时STOP依赖的输入阶段。可以继续纯算法设计。

## 1 观测记录

每run保存run_id/op_id、独立实现commit、profile、目标样本hash（如比较）、macOS完整build、arm64/x86_64、签名身份、AX/ScreenCapture权限状态、显示布局/scale/Spaces、fixture版本、capability选择。严禁记录真实用户secret。

同时保留：原始request/reply/event（脱敏）、dispatch_count、receiver事件/逻辑effect、前台与focusedWindow事件日志、旁路输入接收日志、hardware cursor轨迹、ActionCursor/Lens轨迹、capture_id与图像hash/尺寸、模型最终输入/可见输出、资源owner生命周期。

## 2 六层 oracle

L0 schema接受；L1 adapter cmd/args/gate/补图；L2 daemon接受/超时/断线；L3目标receiver真实effect；L4旁路前台/硬件cursor无意外影响；L5 UI/模型准确表述。每层独立PASS/FAIL/NOT_RUN/INCONCLUSIVE，不允许跨层推断。

- ok:true≠点击有效；delivered≠应用执行；isError缺省≠成功；MCP完成≠native停止
- 抓到图片≠fresh；show_cursor=false≠硬件cursor没动；showInactive≠不存在瞬时激活
- 资料schema检查≠产品单测；mock success≠macOS行为保证

## 3 夹具分层

A. FakeTransport：chunk边界、UTF8、短写、坏JSON、EOF、两peer、timeout、late reply、epoch
B. FakeAX：稳定identity、重复标题、销毁/重建、attribute类型错误、两个匹配候选、深树与分支预算
C. AppKitReceiver：按钮/文本框/滚动区/菜单/多window，明确event counter与UTF16内容
D. ForegroundWitness：持续键入合成字符、记录激活/focus事件，发现瞬时抢焦点和旁路输入丢失
E. CaptureFixture：四角与中心marker、frame计数、同尺寸换代、1x/2x/负坐标screen
F. RaceHarness：fakeclock/任务阻塞/4秒释放/420msretire/earlyAX更新/owner关闭

## 4 必测矩阵

前台/后台/遮挡/最小化；单窗/多窗；AXrich/AXempty；1x/2x/mixed-DPI；单screen/负坐标外屏；nil/授权/拒绝权限；首snapshot/full/diff/disabled；store清空/PID重用；可用/失效ref/歧义恢复；AX动作有/无/报错；输入source0/菜单/Unicode；down后异常/取消；nativeHTTP staticbearer/OAuth/过期/未知工具。

每个场景只证明本次配置。锁屏/Secure Input/protected media等独立标supported/unsupported/unverified，不绕过保护来提高通过率。

## 5 时序规则

UI.cooldown：lastActivity=10000，ticks=10333/10666/10999/11332，仅11332不受1200ms限制。另case lastActivity=0意味着age=Infinity，第一tick不受cooldown限制；仍受active pump/busy/source前提；enabled由activity/presentation流程处理，不是pump每tick直接gate。

PiP：tombstone<=600000刷新、严格>清；420ms旧retiretimer；333ms采集与response后220ms渲染独立；4s watchdog不取消原任务；90s活动end。FocusGuard：正常/异常皆有5s尾期。Appshot：nativeimage先返回，AX另事件，3s timeout不取消worker；tap排队返回与ready分开；host1500ms重arm/715msfired/1100msanimation分别验。

## 6 反重放和重跑

每op mutation_dispatch_count只能0或1。timeout/cancel/断线后未知结局先观察，不重发；需要独立新实验必须先处理旧请求状态、复位fixture、生成新run/op并记录原因。补图失败不重放原动作。

## 7 发布出口

被承诺能力所需L0–L5全部满足，资源、输入释放、privacy范围和错误呈现无未闭合P0；所有原竞态在compat记录真实观察，safe验证修复，不能混用oracle。报告保留失败/缺测，产品总体不得用单次演示或39个mock结果替代。
