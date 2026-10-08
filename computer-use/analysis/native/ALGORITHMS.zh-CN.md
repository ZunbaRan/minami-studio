> 来源：用户提供的 .164 研究资料 `analysis/native/ALGORITHMS.zh-CN.md`；原文件 SHA256 `8d17305b4bb8a73d1e282ccf9d611d2da74d670b8348b66b0861a442710c5ba9`；全文件 1–672 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# 原生控制内核：可独立实现的算法说明（0.4.164）

## 0. 阅读与实现边界

这是对公开发布的 macOS helper 做静态分析后写出的**独立行为规格与伪代码**，不是源码反编译副本。下列地址均属于 SHA256 `453d60872ac801f44497b34d2f68edf7d0fee497420ac44c5d05d785c62b8551` 的 arm64 slice，基址0x100000000；不能用于0.4.153。

证据等级：A=已查指令/分支/调用；B=符号/类型；C=建议实现，不能声称是 Alma 已有行为。API 失败、系统权限、真正后台效果必须在有授权的 macOS 上验收。本文只分析静态样本，没有运行目标程序。

模块划分：

1. AXAdapter：封装 CopyAttribute/SetAttribute/PerformAction/CopyActions/Observer 与错误转换
2. ElementStore：跨快照引用、销毁标记、描述符恢复
3. RefActions：按 ref 执行点击、文字、按键、滚动
4. KeyboardCodec：组合键解析、当前布局反查、Unicode 编码
5. EventFactory：构造 NSEvent/CGEvent，加入窗口字段与自有标记
6. FocusGuard：拦截激活、观察前台、延迟清理
7. InputDispatcher：点击、拖拽、滚轮、按键、文字
8. SnapshotDiff：按 PID/窗口维护差量基线（快照采集另见 snapshot 报告）

所有error code必须用wire字面值：invalid_arg、internal、ax_not_granted、sc_not_granted、app_not_found、element_not_found、ref_stale、action_unsupported、ax_failure。方法名axDenied/internalError不是wire code。

每个模块都应能在没有真实桌面的单元测试中用 fake AX/event backend 测试。接通真实 API 最后做，以便把算法错误和权限/OS兼容错误分开。

## 1. 数据结构和坐标约定

### 1.1 引用条目

Entry:
- element: AXUIElement（必须保留引用）
- snapshotId: String
- pid: Int32
- descriptor: ElementDescriptor? 
- invalidated: Bool

ElementDescriptor:
- role: String
- subrole: String?
- title: String?
- identifier: String?
- roleDescription: String?
- parentRoles: [String]，根到父节点方向的角色路径

Store:
- table: [String: Entry]
- counter: Int，初始0
- currentSnapshotRefs: Set<String>
- observers: [Int32: AXObserver]
- lock

这不是按快照 ID 分区的引用表。快照 ID 是条目元数据，旧 ref 可保留。不要把 `beginSnapshot()` 实现为清空 table。

### 1.2 坐标

- 输入事件内部使用桌面全局 AX/CG point 坐标
- 截图坐标是输出图像像素；由缓存映射到 point，不能假定固定2倍 Retina
- 某窗口的 event-local point = globalPoint − windowBounds.origin；此处不做 AppKit y 翻转
- 原生 PiP 内容鼠标有独立 y 翻转，不能把该规则套到桌面事件，详见镜像报告
- ref 的点击点使用实时 AXPosition + AXSize 中心，而非 OCR/screenshot 旧矩形

## 2. ElementStore 生命周期（A）

### 2.1 beginSnapshot

地址0x10000a898。

伪代码：

    lock:
        currentSnapshotRefs.clear()
        dead = []
        for (ref, entry) in table:
            err, ignored = AX.copy(entry.element, AXRole)
            if err == invalidUIElement(-25202): dead.append(ref)
        delete dead refs from table
        return "s_" + formatCurrentDate().replace(":", "")

日期格式器来自 Foundation；具体输出精度/时区应按 macOS runtime 验证，不要把 snapshotId 当严格唯一 UUID。

注意：这里只移除明确的 invalidUIElement。超时、暂时不可读等其他错误不能按此算法全部删除。被删除后再 resolve 会变成 element_not_found，未删除但标记失效可走 ref_stale/恢复。

### 2.2 register(element,snapshotId,pid,descriptor)

地址0x10000ad9c；CFEqual0x10000af2c；新 eN0x10000b004。

    lock:
        candidate = first table entry where:
            entry.pid == pid
            and CFEqual(entry.element, element)
            and ref not in currentSnapshotRefs
        if candidate exists:
            ref = candidate.ref
            descriptorToUse = descriptor ?? candidate.descriptor
        else:
            counter += 1
            ref = "e" + decimal(counter)
            descriptorToUse = descriptor
        table[ref] = Entry(element, snapshotId, pid, descriptorToUse, false)
        currentSnapshotRefs.insert(ref)
        if new reference path needs observer:
            ensure one AXObserver for pid
            subscribe element's AXUIElementDestroyed
        return ref

已验证复用路径会更新 snapshotId/element，并把 invalidated 设回 false（0x10000b3a4–b3e4）。新 descriptor 为空时保留旧 descriptor（0x10000b324–b358）。

同一个 AX 对象在同次快照被遍历两次不会复用刚用过的 ref，会产生额外 ref；实现者可以更优地防重复遍历，但那属于 C 级改进，兼容测试不能假定原实现已去重。

### 2.3 销毁通知

register 首次为 PID 创建 AXObserver，添加到 main CFRunLoop（0x10000b210/0x10000b26c），注册 AXUIElementDestroyed（0x10000b2fc）。

handleDestroyed0x10000b734：锁住后扫描 table，CFEqual比较对象（0x10000b8a4），匹配条目的 invalidated=true（0x10000b8b0），写回条目；**不是立刻删除整个条目**。

### 2.4 resolveRef

AXBridge.resolveRef0x100019db4：

    entry = store.resolve(ref)
    if absent: throw element_not_found
    if entry.invalidated:
        repaired = refetchByDescriptor(ref)
        if repaired absent: throw ref_stale
        return repaired
    err = AX.copy(entry.element, AXRole).error
    if err == invalidUIElement:
        repaired = refetchByDescriptor(ref)
        if repaired absent: throw ref_stale
        return repaired
    return entry

第二个检查只对 invalidUIElement 触发恢复，其他 AXRole 错误不是同一路径；实际动作仍可能失败。

### 2.5 bounded descriptor recovery

地址0x10000bb3c。LIFO DFS，不是全树无限搜索，也不依赖旧 snapshot 的节点索引。

    original = table[ref]
    if original.descriptor absent: return nil
    stack = [(AX.application(original.pid), depth=0, ancestors=[])]
    matches = []
    visited = 0
    while stack not empty:
        node, depth, ancestors = stack.popLast()
        visited += 1
        if visited > 200: break
        if descriptorMatches(node, ancestors, original.descriptor):
            matches.append(node)
            if matches.count > 1: break
        if depth < 12:
            role = AX.string(node, AXRole) ?? ""
            for child in AX.children(node) in returned order:
                stack.append((child,depth+1,ancestors+[role]))
    if matches.count != 1: return nil
    repaired = original with element=matches[0], invalidated=false
    table[ref] = repaired
    return repaired

描述符匹配细节：
- role 必须相等，缺失 role 按空串处理
- 原描述符 subrole 非 nil 时，候选必须能读到并相等
- 原 identifier 非空时，候选 identifier 必须相等；原 identifier 为 nil/空串则不要求 identifier
- 原 title 非 nil 时继续比较 title，缺失候选 title 按空串处理；identifier 匹配不免除 title 比较
- 原 roleDescription 非 nil 且候选成功读到 String 时必须相等；候选读不到该字段时，本分支继续，而非直接拒绝（0x10000c108/c130）
- 两条 parentRoles 路径比较共同可用长度与3的最小值对应的后缀；该值为0时不限制祖先；这是近父角色约束，不是全路径唯一 ID

唯一性只在上述200节点/12层观察范围内成立。实现者必须明确这不是全应用唯一的数学保证。两个匹配即拒绝；不能挑第一个冒险操作。

### 2.6 clear

0x10000cb64 清空 table，counter重设0（0x10000cbbc），对所有 observer 移除 main runloop source（0x10000cca4），清空 observers。该函数没有看到清空 currentSnapshotRefs 的写入；下次 beginSnapshot 才清。

C级建议：对外若允许 clear，响应加 storeEpoch/instanceID 可避免旧 `e1` 与新 `e1` 混淆。但原协议未证明有此字段，不能作为已有能力描述。

## 3. ref 操作的目标与优先级（A）

click(ref) 的函数签名没有 bundle/PID/window 参数。resolveRef 的 entry.pid 决定合成事件的目标，entry.element 决定 AX 动作。调用方传给截图或审批的 app 名不会覆盖 ref 所属 app。

### 3.1 click(ref,strategy,button,count,showCursor)

入口0x100013f24。策略编码及rawValue已核对0x100013ce4：auto0/physical1/ax2；native没有synth这个raw字符串。缺失或无效策略字符串在daemon回退auto，无效button回退left（见snapshot WIRE_SCHEMA）。forceSynth来自环境变量ALMA_CU_FORCE_SYNTH，首次读取后缓存；值小写后为1/true/yes/on才为true，缺失/其他值false。ALMA_CU_LOG_DLSYM同样解析，控制动态符号诊断日志。

    entry = resolveRef(ref)
    point = centerOfAXBounds(entry.element) or nil
    if showCursor and point exists: overlay.showAt(point)
    mayUseAX = not forceSynth and strategy != physical and button == left and count <= 1
    if mayUseAX:
        actions = AX.actions(entry.element)
        action = first present of [AXPress, AXPick, AXConfirm]
        if action exists:
            AX.performOrThrow(entry.element,action)
            if showCursor: overlay.clickPulse()
            return
        if strategy == ax: throw action_unsupported
    if point absent: throw action_unsupported
    EventDispatch.click(point,button,count,entry.pid,modifiers=0)

精确分支：右键/多击/forceSynth会直接进入合成分支，即使 strategy=ax。不要简单实现“ax模式绝不合成”而称完全兼容。

AX动作在可用但执行失败时直接报错，并不再合成补点。因此不会因为 AX 返回错误自动双重执行。

### 3.2 secondary(ref)

0x100014614附近：有 AXShowMenu 则执行；否则有 bounds 则 EventDispatch.secondaryClick(point,entry.pid)；无 AXShowMenu 且无 bounds 报 action_unsupported。AXShowMenu执行失败不自动改成右击。

### 3.3 type(ref,text,replace)

0x1000153bc：

1. resolve ref
2. 可选显示定位/typing badge
3. 尝试 AXFocused=true，未发现对该设置结果立即抛错
4. replace=true：直接 AXValue=text，按 AX错误映射返回
5. replace=false：若 AXSelectedText 可写，设置为 text（语义是替换当前选择/插入光标处），执行失败报错
6. 若 AXSelectedText 不可写：读 AXValue 为 String（不能转 String 时用空串），设置 AXValue=old+text

这个 ref 路径不是逐字符 CGEvent，也不是通用剪贴板粘贴。append fallback会把文本追加到整个值末尾，不保证光标处插入。

### 3.4 press(ref,key) 与 scroll(ref,...)

AXBridge.press0x100015880用 AX动作集合，不等同于无 ref 的组合键输入。已确认支持 Enter/Return、Escape、Space、Increment、Decrement、ShowMenu 等有限语义；未支持键返回 action_unsupported。完整别名表：enter/return→AXConfirm；escape/esc→AXCancel；space→AXPress；increment/up→AXIncrement；decrement/down→AXDecrement；showmenu/menu→AXShowMenu。输入先小写化，动作必须出现在元素动作列表，否则action_unsupported。不要把任意Cmd组合映射过去。

AXBridge.scroll0x100016068按方向选择 AXScrollUpByPage/DownByPage/LeftByPage/RightByPage，重复页数次；动作缺失直接报 unsupported，不自动转坐标滚轮。

## 4. 事件构造和窗口选择（A）

### 4.1 选择窗口

resolveClickWindowID0x100022c38：

    windows = WindowList.windows(pid)
    for w in windows:
        if CGRectContainsPoint(w.bounds,screenPoint): return w.id
    return windows.first?.id

列表排序/过滤由 WindowList 控制。选定某 PID 后，不扫描别的应用来决定是否允许点击。WindowList.isWindowVisibleAtPoint仅查到 Lens 显示/计时器调用；不能把视觉遮挡检查说成输入拦截。

### 4.2 makeMouseEvent

NSEvent构造调用0x10001bc38；补字段0x10001bc68 onward。

    event = NSEvent.mouseEvent(
        type = phase/button specific,
        location=(0,0), modifierFlags=0,
        timestamp=ProcessInfo.systemUptime,
        windowNumber=windowID or0, context=nil,
        eventNumber=nextCounter() & 0x7fffffff,
        clickCount=ordinal, pressure=1 for down/drag else0)
    cg = event.CGEvent
    cg.integerField(3) = buttonIndex
    cg.integerField(7) = 3
    if windowID exists:
        cg.integerField(91) = windowID
        cg.integerField(92) = windowID
    cg.location = screenPoint
    if windowID and bounds exist:
        SetWindowLocation(cg, cg.location - bounds.origin)
    if flags !=0: cg.flags = flags
    cg.integerField(42) = syntheticSentinel
    return cg

NSEvent类型数组（0x10008f898/8b0/8c8）：
- left: down1/up2/drag6
- right: down3/up4/drag7
- other: down25/up26/drag27

字段编号为已见数值；91/92依赖私有/未公开语义，不应写成Apple稳定API保证。field42是 eventSourceUserData，内部标记0x414c4d414e4f464c。

动态解析：
- dlopen CoreGraphics 后 dlsym CGEventPostToPid，实际间接调用可定位0x10001bec0/1bedc
- dlsym CGEventSetWindowLocation（0x100021558）；失败选 no-op 函数0x100021648/164c，仍可继续走全局位置流程。日志仅在logDlsym开关打开时输出

### 4.3 click(point,button,count,pid,modifiers)

0x10001b440→body0x10001ba60。

- 进入 FocusGuard
- 选择窗口、读取bounds、读取目标isActive
- 若非active，flags = modifiers OR0x100000；active则原modifiers。0x100000是Command位，因此后台合成点击并非“无修饰点击”
- 轮数 max(1,count)
- 第i轮分别构造 down 和 up，clickCount=i
- 两个事件都成功构造后才发 down再up
- 每轮之间usleep40000微秒；同轮down/up没有显式等待
- 事件创建失败抛 internal；up预构造降低了 down已发但up无法创建的风险
- 无实际光标warp调用在该路径；合成点与用户物理鼠标位置独立，Lens是额外可视反馈

### 4.4 drag(from,to,button,pid,steps=12)

入口0x10001efa4；默认12来自0x10001ef9c。

    guard = FocusGuard(pid)
    window = resolveClickWindowID(pid,from)
    flags = target.isActive ? 0 :0x100000
    post(down at from)
    n = max(2,steps)
    for i in1..<n:
        p = from + (to-from)*(i/n)
        if canConstructDragEvent(p): post(event); sleep8ms
        else: continue
    construct and post up at to
    finish guard

中间事件失败会跳过当前步继续（0x10001f754/1f768→1f668→1f6c8），不是立即中断；最终up创建失败仍可能抛错。已见清理只清FocusGuard，没有找到无条件再次发up的finally。**不能宣称不会卡住按键/鼠标状态**。C级实现建议维护pressed state并在异常/取消时补up，独立列为改进。

### 4.5 scroll(point,direction,pages,pid)

0x10001e440：delta=max(1,pages)*10，方向小写。
- up: vertical=+delta,horizontal=0
- down: vertical=−delta,horizontal=0
- left: vertical=0,horizontal=+delta
- right: vertical=0,horizontal=−delta

创建CGEventSource(state0)，CGEventCreateScrollWheelEvent2(units1,wheelCount2,v,h,0)，设置global location与sentinel，经postToPid投递。该路径没有点击事件的91/92窗口字段或window-local setter。非法方向路径需要接入上层参数验证；不要假定它是AX逐页滚动，虽然输入参数叫pages。

## 5. KeyboardCodec 与文本投递（A）

### 5.1 key组合字符串

KeyParser.parse0x100023148先使用 `+` 分割并省略空段，再对每段trim Foundation CharacterSet.whitespaces（0x100023278/23294，非whitespacesAndNewlines）；前面的段当modifier，最后一段当主键。modifier不区分大小写。单Character主键先小写查ANSI，未命中再小写查named；未知键报invalid_arg。已有映射文件`keycode-contract.json`包含48 ANSI按键和56命名别名，来自功能常量表而非源码。

确认modifier aliases与位：
- cmd/command/meta/super →0x100000
- ctrl/control →0x40000
- shift →0x20000
- alt/option →0x80000
- fn/function →0x800000

未知modifier与未知key返回invalid_arg。仅写大写字母不应假定自动Shift；按键名查表是小写化路径。加号本身因为分隔符规则需明确选择kp_plus或带Shift的物理键组合，别把“+”误当单键。

### 5.2 动态布局反查，用于physical文字模式

KeyboardLayoutTranslator0x100023ea8：

1. TISCopyCurrentKeyboardLayoutInputSource
2. 取Unicode keyboard layout data，失败报internal
3. 逐Swift Character处理；换行/回车→keyCode36，Tab→48
4. 其余字符按keyCode0..<128的顺序，内部遍历4种modifier候选：
   - Carbon0 / CGFlags0
   - Carbon2 / CGFlags0x20000（Shift）
   - Carbon8 / CGFlags0x80000（Option）
   - Carbon10 / CGFlags0xa0000（Shift+Option）
5. 每次UCKeyTranslate(action3,keyboardType=LMGetKbdType(),options0,deadKeyState初始0,输出容量8 UTF16)
6. 成功且输出长度>0，把输出UTF16解码成String，与当前Character精确比较；第一个匹配记录keyCode/flags
7. 任一字符无匹配则整个转换抛action_unsupported；转换完整个字符串后才开始physical投递

这样auto模式的“无法映射字符”降级不会在已打半段physical文字后再把整段Unicode打一次。

### 5.3 按键事件路由

pressKey0x1000203c4：

    key = parse(combo)
    enterFocusGuard(pid)
    firstHasKeyWindow = hasKeyWindow(pid)
    active = firstHasKeyWindow ? true : runningApp(pid)?.isActive
    if active:
        status = hasKeyWindow(pid) ? key_window : active_app
        down,up = keyboardEvents(key.code,key.flags)
        mark and postToPid(down)
        mark and postToPid(up)
        return status
    for shortcut in MenuShortcuts.collect(pid):
        if not shortcut.enabled: continue
        parsed = try parse(shortcut.combo), otherwise continue
        if parsed.keyCode==key.keyCode and
           ((parsed.flags XOR key.flags) AND0x1e0000)==0:
            return AXPress(shortcut.element) succeeds ? menu_ax_press : suppressed
    return suppressed

返回状态编码在0x100020020：0 key_window、1 active_app、2 menu_ax_press、3 suppressed。suppressed不是“已成功按键”；上层必须呈现未投递/受限状态。

hasKeyWindow0x10002d6b0的精确实现：AXFocusedWindow读取成功且非nil AND app.isActive。与调用处的OR isActive在稳定状态下约等于active，但由于重复采样不能优化描述为一个原子检查。

### 5.4 无ref auto文本

EventDispatch.typeText0x10002102c：

    if typeViaFocusedAXElement(text,pid): return
    try:
        presses = layoutTranslateWholeText(text)
    catch:
        typeUnicodeText(text,pid)
        return
    typePhysicalPresses(presses,pid)

注意catch只覆盖layout翻译失败。physical投递已经开始后再失败，不会自动整段Unicode重试。

typeViaFocusedAXElement0x100023b60：
- 找app的AXFocusedUIElement，失败返回false
- 若AXSelectedText可写且写text成功，返回true
- 否则若AXValue可写，读String值（读失败/非String视为空）并追加text，AXValue设置成功则true
- 否则false

它与ref文本路径不同：focused辅助函数在AXSelectedText写失败后会尝试AXValue fallback；ref路径则抛错。

### 5.5 physical文字投递

在FocusGuard内，为每个KeyPress创建down/up，设置各自flags与sentinel，经postToPid连续发，随后usleep4000微秒（0x10001c510）。不额外逐一发modifier down/up事件，而是在主按键事件flags里表达。

### 5.6 Unicode文字投递

0x10001cb20 specialized body：先转Unicode scalar数组，按最多20 scalar切块（0x10001cee4），每块重建String，再转UTF16。创建keyCode0 down/up，把相同UTF16数组通过CGEventKeyboardSetUnicodeString设到两者（0x10001d0fc/1d10c），mark后postToPid。分块单位不是UTF16 code unit，不会在高低代理对中间切分。未看到块间显式sleep。

这一行为不保证所有app/输入法接收Unicode；必须实测emoji、组合字符、中文、密码输入框、终端与Electron。

## 6. FocusGuard 的真实边界（A）

### 6.1 建立与结束

点击示例0x10001b5d0–1b774；generic/text类似。

    oldFront = NSWorkspace.frontmostApplication?.pid or0
    preservingOther = oldFront>0 and oldFront!=targetPid
    optional AXEnablementAssertion(targetPid)  // text/scroll等路径有；click/drag未见
    preventer.begin()
    globalDisallowed.insert(targetPid)
    victimObserver(targetPid).begin()
    if preservingOther:
        globalOnlyAllow = oldFront
        frontmostWatcher(oldFront).begin()
    pump main runloop until now+0.001seconds
    try perform action
    finally:
        if preservingOther and currentFront==oldFront:
            makeWindowKeyWithoutActivating(oldFront)
        schedule +5seconds on main queue:
            repeat above conditional key-window repair
            if preservingOther: globalOnlyAllow=nil
            globalDisallowed.remove(targetPid)
            preventer.end()
            watcher?.end()
            victimObserver.end()

+5秒在正常及错误路径均可见（例如0x10001d9e8、1d368）。因此动作响应返回不等于保护已经卸载。全局set/onlyAllow可能存在并发动作交互；未经运行不能说已引用计数隔离。

makeWindowKeyWithoutActivating使用GetProcessForPID→SetFrontProcessWithOptions(option1)（0x100026c0c/26c24）；不要按名称自行替换为无条件activate()。

### 6.2 事件过滤

CGEventTapCreate参数：location2、placement0、options0、mask0x6000（0x100027f90–7fa4），只含13/14类型位。

    shouldDrop(target):
        lock
        if temporaryAllowance[target] unexpired: false
        else if target in disallowed: true
        else if onlyAllow exists and target != onlyAllow: true
        else false

callback：
- tapDisabledByTimeout/userInput通知时重新启用
- sentinel事件直接放行
- NSEvent类型13，或类型14且subtype8，取data1作为targetPid
- shouldDrop为true则返回nil丢弃，其他原样返回

保护失败时记录失败计数/日志；未见行动前强制失败关闭。不能以“FATAL”日志文字推断进程真的exit。

### 6.3 辅助进程与观测

VictimObserver扫描运行app：与目标bundle同前缀，后缀以`.`开头，后缀小写含helper、.xpc、service时，把辅助进程PID也加入disallowed；结束时移除。

可选CGEventTapCreateForPid通过dlsym解析（0x10002e814），安装参数placement0/options1/mask0x640a（0x10002e52c–e53c）。其callback对13/14且非sentinel事件计数，并返回原事件（0x10002eef8–2ef70）。这是观测tap，不是第二个已证明的阻断器。stats不能当作完整“动作成功”验收。

## 7. 失败处理与不能伪称已解决的事情

A：
- 不存在ref→element_not_found
- 存在但不可恢复→ref_stale
- 不支持的AX动作/键/无法映射physical字符→action_unsupported
- AX权限拒绝→ax_not_granted，其他AX失败→ax_failure
- event/source创建失败→internal
- 纯CGEventPostToPid没有同步“目标已响应”确认
- key delivery的suppressed应作为非成功输入处理
- Unix socket关闭不会中断当前同步native dispatch；teardown发生在处理返回后

C级建议，不能冒充原行为：
1. 对每次动作保存targetPid/windowID/storeEpoch，审批目标和ref目标交叉核对
2. 用串行事务队列或按PID锁防止共享onlyAllow互相覆盖
3. 维护按下键/鼠标状态，取消/异常finally补释放
4. 显式定义cancel协议与可取消任务token；不要只销毁socket
5. SPI缺失时把能力降级暴露给调用方，不只静默no-op
6. 截图缓存加时间戳与windowID验证；移动窗口后重截图再点
7. 动作后验证UI变化，而不是把postToPid返回当成功

## 8. 逐步实现顺序与验收

### T1：无桌面纯算法

完成Entry/Descriptor、KeyParser、Diff、坐标映射。全部用fake数据测试。禁止先连接真实鼠标来代替单元测试。

### T2：只读AX

实现读属性与错误适配、running apps/windows、快照。确认权限来源是helper自身Bundle身份。不得靠反复权限请求掩盖失败。

### T3：ref稳定性与销毁

最小窗口里反复snapshot，按钮ref保持；同次重复节点不冲突；销毁触发invalidated；唯一描述符可恢复；两个同名按钮拒绝恢复；201节点边界/深度12停止；clear后epoch风险明确。

### T4：AX语义动作

在测试应用验证AXPress/AXPick/AXConfirm优先级、AXShowMenu、AXSelectedText插入/AXValue append/replace、AX滚动页。可用但失败的AX动作不得自动再合成点击。

### T5：事件工厂fake捕获

检查down/up类型、field3/7/42/91/92、local/global点、eventNumber单调与31bit mask、非active Command位。count0→一次；双击两对事件clickCount1/2，相隔40ms。

### T6：可控macOS窗口

在自建测试应用先测试前台input，再测试后台input；屏幕放置多个同PID窗口、遮挡窗口、负坐标显示器、Retina与非Retina，核对目标窗口和实际收到事件的字段。

### T7：键与文字矩阵

- hasKeyWindow=true/false + active=true/false + 前台变化race
- 后台菜单快捷键成功、disabled菜单、找不到菜单、AXPress失败
- ANSI+Shift/Option、布局切换、无法映射中文→Unicode
- 21 scalars→20+1两块；emoji不拆代理对
- physical第k字符event创建失败不可整串Unicode重打
- focused AXSelectedText失败→AXValue fallback；ref同样失败应报错

### T8：焦点与中断

验证1ms预运行、5s保护尾期、tap失效重新启用、helper进程激活、用户手动切换应用、重叠两次动作。观测焦点是否被错误拉回；明确“静态有防护”与“不会偷焦点”差别。

拖拽途中模拟motion创建失败应继续，up创建失败必须暴露失败并触发你自己的安全补up设计；这项补救要单列偏离原行为。

### T9：端到端契约

wrapper发ref与错误bundle时，拒绝混淆目标；post-action depth0截图引发diff基线变化按snapshot报告处理；连接关闭后不能重复重试有副作用动作，先查询实际结果。

## 9. 仍需动态或额外静态验证

- macOS不同版本对字段91/92、SetWindowLocation和activation事件的处理
- command位对不同app后台单击语义的副作用
- 何时系统会把AXFocusedWindow保留但app不是active
- helper扫描能否覆盖所有Electron/XPC进程，是否误纳入同bundle前缀组件
- 真实事件丢失、Secure Input、输入法、沙盒/TCC组合
- 精确AppStateDiff对非String/嵌套Any值的Swift文本格式跨系统版本稳定性
- 硬中止进程/电源睡眠时按键释放和observer解除不可由静态正常路径保证


## 10. 补齐 set_value 与 select_text（A）

### 10.1 set_value(ref,value)

入口0x100014a08。value在该层为Swift Any；请求JSON如何进入Any另见native-snapshot协议说明。

    element = resolveRef(ref).element
    error,settable = AXIsAttributeSettable(element,AXValue)
    if error != success or settable == false:
        throw action_unsupported
    if value can cast to String:
        cfValue = bridge String to NSString
    else if value can cast to NSNumber:
        cfValue = that NSNumber
    else if value can cast to Bool:
        cfValue = bridge Bool to NSNumber
    else:
        cfValue = NSString(String(describing:value))
    error = AXSetAttributeValue(element,AXValue,cfValue)
    mapAXError(error,context="setting AXValue",ref)

不是对所有值先JSON.stringify；NSNumber保留数值/布尔桥接语义。对象/数组/null如果走到兜底，会变成Swift描述字符串而非标准JSON。公共工具若仅允许标量应在wrapper验证；勿默默宣称原native拒绝复杂值。

证据：settable0x100014a8c；String cast0x100014b38；NSNumber cast0x100014b8c（LIEF绑定确认class pointer0x1000ae470为NSNumber）；Bool cast0x100014bb4；描述兜底0x100014ca4；设置0x100014bf0。此路径不主动set AXFocused，也没有鼠标/键盘副作用兜底。

### 10.2 select_text(ref,text,prefix?,suffix?,selectionType)

入口0x100014cb4，String.range调用0x100014f4c。

    element = resolveRef(ref).element
    raw = AXCopyAttributeValue(element,AXValue)
    if raw is String: content=raw
    else if raw is NSAttributedString: content=raw.string
    else: throw action_unsupported
    contextNeedle = (prefix ?? "") + text + (suffix ?? "")
    match = content.range(of:contextNeedle, options:[], range:nil, locale:nil)
    if match absent: throw internal
    start = UTF16distance(content.startIndex,match.lowerBound)
            + (prefix ?? "").utf16.count
    length = text.utf16.count
    if selectionType == "cursor_before": length=0
    else if selectionType == "cursor_after": start+=length; length=0
    // any other string takes the full text range, no local enum rejection
    focused = try? AXCopyAttributeValue(element,AXFocused) as? Bool
    if focused != true: AXSetAttributeValue(element,AXFocused,true) // ignore result
    value = AXValueCreate(type:CFRange=4, CFRange(start,length))
    if value absent: throw internal
    error = AXSetAttributeValue(element,AXSelectedTextRange,value)
    mapAXError(error,context="setting AXSelectedTextRange",ref)

匹配规则：第一次Foundation标准搜索结果；没有第二次搜索判断重复，也没有模糊匹配或大小写忽略。prefix/suffix必须紧邻text，且只用于搜索定位，最终选择范围不含prefix/suffix。文字出现多次且不带上下文时选择首次出现，不能写成“重复就拒绝”。

UTF16单位明确：例如content=`😀AB`、text=`A`，start=2,length=1；cursor_after位置3。对于组合字符，按Swift String.range后映射UTF16位置；不要用Unicode scalar数或UTF8字节数替代。

读取AXValue失败/不可用/类型不是String或NSAttributedString都归action_unsupported；未找到needle归internal；构造AXRange失败归internal；写入AXSelectedTextRange失败用下面AX映射。该函数不保存/恢复之前selection，也不自动还原AXFocused。

### 10.3 共用AX错误映射

0x10001a22c：
- 0：成功
- −25202 invalidUIElement：ref_stale
- −25205 attributeUnsupported / −25206 actionUnsupported：action_unsupported
- −25211 apiDisabled：ax_not_granted
- 其他非0：ax_failure，消息包含AX错误名称与动作context

某些先验读取分支（settable检查、select_text读取）会先归action_unsupported，而非统一直接映射；必须遵守上文各自顺序。

## 11. SPI连接边界与状态验证（A）

### 11.1 ABI与失败策略

Swift声明对应C ABI：

    SynthPostFn = @convention(c) (Int32, CGEvent) -> Void
    SetWindowLocationFn = @convention(c) (CGEvent, CGPoint) -> Void

CGPoint在arm64为两个CGFloat/Double；必须让Swift/Clang按照目标平台C ABI传参，不能手写把两个double强转成整数参数。CGEvent是保留的CoreFoundation对象，函数不返回投递确认。

实际解析路径：`/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics`，dlopen flags9。CGEventPostToPid找不到会走Swift assertionFailure/fatalError（0x1000214fc），**没有**安全CGEventPost全局广播兜底。CGEventSetWindowLocation找不到则是no-op stub，不退出；能力会退化。

C级替代产品建议：改成显式capability error而非崩溃，并在任何真实输入前运行feature probe；若没通过则STOP，让用户获知限制。这是安全改进，不是原程序已经有的保护。

### 11.2 文本验证不是精确内容验证

TypeVerification.baseline0x10002d464：读取AXFocusedUIElement且检查CFTypeID为AXUIElement，保存该对象及其AXValue可读String。

TypeVerification.check0x10002d590：

    if typed.isEmpty: return landed
    if baseline.element missing: return unverifiable(reason)
    if baseline.value missing: return unverifiable(reason)
    after = readAXValueString(baseline.element)
    if after missing: return unverifiable(reason)
    if after == baseline.value: return failed
    return landed

不会重新寻找另一focused element，不检查after含typed，也不比较预期编辑结果。任何不相关值变化都能判landed；相同字符串替换也可能判failed。这里的pid参数未在已查主体用于重新定位。

### 11.3 并发与快照副作用

native-snapshot分析确认handleQueue.concurrent，多连接可并发；每个连接内部同步dispatch。ElementStore各方法有锁，但未发现整次snapshot跨begin/register/finish的一把事务锁。两个连接交错调用beginSnapshot会共享currentSnapshotRefs；这应列为运行验证/改进点。

必须区分两条路径：直接原生`cmd=snap`走dispatch0x10007735c→plain snapToDict0x100077380，不调用AppStateDiff；但MCP wrapper的post-action补图实际调用`get_app_state`，depth=0、interactive_only=true、include_screenshot=true，不传disable_diff（MCP源码M35930–35976）。因此它既触碰ElementStore，也会走get_app_state的Diff+capture，可能把该PID/窗口的diff基线改成浅层元素集合。后续消费者不能把这次补图视为无状态读取。此前把wrapper补图等同于native snap的推论已纠正。

## 12. Diff指纹的可直接实现表达（A）

不要把指纹算法替换成JSON序列化、哈希所有字段或递归深比较。以下是原创规格伪代码，采用Swift是为了保留原生Any描述语义：

    fixed = [role,subrole,title,value,description,role_description,
             enabled,focused,children_count,actions]
    parts=[]
    for key in fixed:
        if let optionalSlot = element[key], let actualValue = optionalSlot:
            parts.append(key + "=" + String(describing:actualValue))
    if let bounds = element["bounds"] as? [String:Any]:
        numbers=[]
        for key in [x,y,w,h]:
            number = (bounds[key] as? Double) ?? Double(bounds[key] as? Int ?? 0)
            numbers.append(String(Int(number.rounded())))
        parts.append("bounds="+numbers.joined(separator:","))
    return parts.joined(separator:"|")

指纹cache按ref保存这个字符串；不会保存原元素对象的全部字段。String(describing:["AXPress"])等集合的括号/引号属于Swift标准描述；跨语言实现应先用该规则生成golden fixtures，再确定规范化策略。nil字段跳过；缺失bounds子字段取0（数值转换的具体桥接行为见ARM64动态cast，Swift实现最接近）。NaN/∞转Int可能触发trap，公共输入/AX数据应在替代实现中验证有限数。

Diff结果只发变化元素，但总快照元数据仍独立更新；必须用完整旧cache作delta合并。`disable_diff=true`并非“不要触碰cache”，而是重置为当前完整元素后返回完整结果。


### 12.1 AXEnablementAssertion补充

0x100027370先保存目标app的AXEnhancedUserInterface与AXManualAccessibility旧Bool（读失败按false），再尝试都设true。析构0x10002749c区域恢复所保存值。其写入结果未见强制失败处理。这是AX树启用/恢复层，不是目标前台激活；不能以该层存在证明所有Electron应用都能读到完整树。

### 12.2 不应把保留符号当活动策略

样本有AXBridge.isTargetForeground符号，但当前全量直接branch/call catalog未发现其调用者。不要把它的内部窗口判断塞进已经核对的click/pressKey路径。call catalog仅证明直接调用，不覆盖无法静态解析的所有间接路径，因此也不能断言此函数永远不会被调用。
