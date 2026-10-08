> 来源：用户提供的 .164 研究资料 `chapters/06_镜像光标与Appshot.md`；原文件 SHA256 `e26f30cc98445eaf99ea80d054354a7d9187222083e25686640c29ecdd3e1bbc`；全文件 1–125 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# 镜像光标与 Appshot

## 三套视觉系统

必须独立建模：Electron统一PiP stack、native Lens/原生窗口PiP、Appshot。Electron自动镜像通过shot/shot_display采图，不因二进制存在PIPSession就证明用了native stream。Appshot是用户触发的静态截图附上下文，并会主动显示聚焦Alma；它不遵守被动镜像的“不激活窗口”目标。[UI §1]

## 统一 PiP 数据结构

Presentation记录id、kind(browser|computer)、label、threadId、workspace、displayId、targetBundle、targetPid、createdAt、updatedAt。Registry保存items map、activeId、fittedId、completing set和dismissal时间map。dismissal key是(item ID,thread ID或空串)，原实现用NUL连接。Window另存programmaticClose标志与关闭订阅者。

browser条目id为browser:加workspace或sole；computer共享computer:desktop一个条目。按创建时间排列，新增条目成为active；更新已有条目不抢active；当前active删除后选择最新剩余条目。select重置fit并重载HTML。

合并规则不能写成简单Object.assign：label只用truthy新值；thread/workspace/display新值为nullish时保留旧值；若bundle/PID任一属性显式不是undefined，则两项一起覆盖，另一项可变undefined；已有kind不覆盖；upsert清completing标志却不撤销已有删除timer。[UI §2–3；UI实施表]

## 用户关闭后的滑动抑制

原创功能伪代码：

    present(item, automatic):
        if automatic and items中没有item.id:
            key = (item.id, item.threadId或空串)
            if key有关闭时间:
                if now - 关闭时间 > 600000毫秒: 删除该关闭时间
                else: 将关闭时间刷新为now; 返回suppressed
        if not automatic: 删除item.id对应所有thread的关闭时间
        合并或新增item; 清completing; 确保window; 重载HTML
        若隐藏则showInactive

这是10分钟滑动安静期，不是最初关闭后固定10分钟倒计时。自动活动持续到来会持续刷新关闭时间；持续工作不应过10分钟自动重开。换thread会用不同key；手动打开清该item所有thread的tombstone。关闭抑制仅在内存，持久JSON只保存几何。[UI §2]

多个条目时关闭选中项：写tombstone，设completing，重载，420ms后删条目。关闭最后窗口：若不是programmaticClose，给全部活条目记tombstone，再清stack、通知订阅者。程序hide设标志、关闭并清map，不记tombstone，因此后来活动可重开。invalidate也是420ms删除但无tombstone；空stack调用程序hide。

竞态要照实记录：upsert可清completing却没取消旧420ms timer；重现时旧timer仍可能删除重新呈现的条目。关闭判断仅对不存在ID生效，420ms期间自动刷新可能更新仍活着的被关闭条目。safe版本应加generation并取消/废弃旧删除操作；这属于明确修复，不是原已证行为。

## 窗口几何与焦点

默认380×250，最小220×150。保存size用于恢复；已跟踪初始化路径没复用保存的x/y/displayId。优先主窗口，否则最大可见非PiP窗口为anchor。初始位置靠主窗口右下、composer上方，夹到display work area并留16px；无anchor则用硬件cursor邻近显示器右下。anchor move按delta跟随，跟随本身没重新应用初始clamp。

composer测量500ms超时；只有用户尚未移动初始panel时才改y。fit只在active ID未fit且尺寸有效时执行：保宽按比例改高，最多work area一半；请求最低120px，但BrowserWindow min height150可能改变实际结果；保持底边，纵向留8px。

浮动、always-on-top、taskbar隐藏、跨Spaces/fullscreen可见，自动打开用showInactive。这是无焦点意图，不是所有macOS/锁屏/Spaces条件下的保证。显式expand会显示聚焦Alma、导航thread，并可能reveal browser。HTML整图是拖动/观看区，没有pointer事件转发到目标app的控制链。[UI §3]

## computer 采集和 DOM 渲染是两个循环

首次frame HTTP请求才为item建立pump，初始display ID在创建时捕获。目标bundle/PID每次采集重新查询，因此切目标可更新；只改displayId却不重建pump可能继续旧fallback display。

采集timer为333ms。busy且未超过4s则返回；超过4s清busy但不取消旧采集，后续tick可开第二次，晚完成可能竞争同文件和状态。距agent computer activity不足1200ms时跳过；这是agent活动，不是检测人类输入。先尝试目标window shot(max_width1024)，失败或null再shot_display(max_width1024,quality0.5,初始displayId)。把临时JPEG读base64、更新cursor/cache并fit。失败保留此前成功frame；首次和每15次连续失败记日志。endpoint没有检查cached frame年龄。[UI §4]

stop清timer/map并尽力删JPEG，但不取消在途采集，晚完成可重新创建文件。整个stack关闭通知可停全部computer pumps；90s活动结束先停pump再invalidate。单独invalidate但stack仍有其它item时，已跟踪路径不一定停该pump，需验收资源释放。

DOM只poll active item，每次response完成后再等220ms，不是严格4.55fps。JPEG成功更新图像；cursor按top-centered contain-fit映射。设scale=min(panelW/imageW,panelH/imageH)，ox=(panelW-imageW×scale)/2，oy=0；ring位置为ox+u×imageW×scale、v×imageH×scale。ring为22px合成光圈，位置动画0.12s。成功但无cursor则移除ring；success:false时隐藏图并显示idle，未见显式移除既有cursor class；network异常或非OK保留旧显示。completing停止新poll；beforeunload设alive=false，在途请求仍可能排一个下一轮timer，其入口退出。

每次upsert用data URL重建HTML，frame cache仍保留。切source时naturalWidth可能短暂来自上一图，需测试。不能把采集3fps和渲染完成后220ms相乘或合并成一个帧率。

## browser screencast 租约

解析IAB目标，确保共享CDP screencast，将pip=true。stream配置JPEG quality55、max1024×768、everyNthFrame1，每帧必须ACK。frame endpoint读最新cache；第一帧前用Page.captureScreenshot quality55，根据viewport/HD作clip。

普通subscriber、HD subscriber子集、PiP lease分别计数。新subscriber立即收到cache。unsubscribe只有在无PiP且无任何subscriber时停stream，否则重设detail模式。HD另走quality80 captureScreenshot并busy/dirty合并，PiP仍使用baseline55。

stream为页面插入user-origin白背景CSS并在dom-ready重复；teardown移listener，但检查路径未见移除已插CSS。stopPipStreamFor只清PiP lease，有正常subscriber就不断流。browser panel可见抑制自动PiP；panel-visible IPC也隐藏preview并停其lease。导航前后可自动呈现，不能推出每个browser action都呈现。

browser专属hide/toggle显式停lease；普通stack close只找到computer stop订阅，browser可能继续stream，需运行验证。safe版本必须明确lease owner和release条件。[UI §4]

## 活动与开关

Computer PiP enabled默认true，配置读取/解析失败也默认true。活动先记录时间，再看enabled；启用时记可选目标、automatic present并重置90s timer。即便present被tombstone抑制，timer仍重置。无目标活动保留上次bundle/PID，直到90s结束或显式end。disabled活动本身不主动关既有panel，renderer setting处理会invalidate computer item。

middleware列表含get_app_state、click、secondary、drag、type/type_text、press/press_key、set_value、scroll、raise、launch_app；但REST launch_app注册顺序早于该middleware，不能据列表断言实际经过。windows/snap/shot/shot_display/lens不在该列表。[UI §5；HOST补正]

## 原生 Lens 与动作光标

LensOverlay初始化默认enabled=false。showAt先ActionCursor.set(point)，再读取Lens enabled；因此Lens关闭仍可更新Electron JPEG镜像的合成cursor。show_cursor=false在已检查click分支跳过Lens.showAt，但不能以单条路径概括每个动作。Lens hide未见调用ActionCursor.clear。[NATIVE UI §1，0x100041a9c、0x100042330]

ActionCursor保存point+timestamp并加锁；current仅在有效且age≤8s时返回。它不是硬件鼠标当前位置。normalized要求rect正宽高、point在rect内，超界返回nil，不clamp：u=(x-minX)/width，v=(y-minY)/height。shot与shot_display响应调用该归一化。[0x10002a0e4、0x10002a218、0x10007e06c、0x10007e95c]

三种抓图cursor配置不同：window一次性抓图showsCursor=false；display一次性抓图true；native PIPSession连续window stream也true。均禁音频。native stream请求最小间隔1/30s、BGRA、queue depth3，macOS≥14忽略单窗口阴影；一次抓图配置1/60s不代表Electron pump达到60fps。

showAt在enabled后先广播screenPoint/slideMs，再判断目标window在point是否可见；遮挡时桌面Lens fade/hide，但native PiP仍可收到动作广播。桌面显示从AX风格坐标转AppKit坐标并按screen建slot。window透明、忽略鼠标、无阴影；orderFrontRegardless/相对目标window level排序说明显示策略，不足以证明永不抢焦点。可见性watcher检查window on-screen/point可见，失败fade；精确timer间隔和锁屏notification语义仍待验收。

关键边界：Lens遮挡判断属于显示策略，不是输入gate。click的resolveClickWindowID另按PID窗口包含点/首窗口fallback路由；不能把Lens隐藏解释为没发点击。[NATIVE UI §8]

## 原生窗口 PiP

PIPManager按native window ID存session并加锁；已存在则bringToFront，新的通过ScreenCaptureKit shareable cache解析SCWindow，在main queue建session并登记。PIPSession建floater/filter/SCStream/output，开始capture，订阅Lens move/click/type/scroll/hide，并注册目标window销毁AX observer。

frame到来时display layer ready才enqueue，failed状态flush，然后更新frame时间。close移除session并排shutdown；shutdown移notification observer、AX run loop source/notification、停capture、order out。stream error触发shutdown/onClose；window destroyed触发manager.close。未在这些方法发现10分钟tombstone，它属于Electron stack。PIPMinimizeArmer是另一observer能力，完整schema/通知分支现见附录PIP_EXTRA_CONTRACTS：window销毁可disarm，最小化自动open失败仍保留armed；不能把二者混同。[0x1000485e8、0x10004a9a0、0x100049a50、0x1000530a0]

native PiP pointer使用双轴居中aspect fit并翻转y。设scale=min(viewW/sourceW,viewH/sourceH)，fitW=sourceW×scale，fitH=sourceH×scale，fitX=viewMinX+(viewW-fitW)/2，fitY=viewMinY+(viewH-fitH)/2；pointX=fitX+u×fitW；pointY=fitY+(1-v)×fitH。该1-v适配AppKit向上坐标，不能复用到DOM。

算例：source1920×1080、view380×250，fit为(0,18.125,380,213.75)。u=0.5、v=0.25时native坐标(190,178.4375)，换顶部向下为71.5625；Electron顶部对齐则y=53.4375。两个正确结果不同，原因是fit对齐及原点不同。[0x1000538cc–0x100053cb4]

## Appshot 状态机

支持条件是macOS且helper存在。状态含supported、platform、configuredHotkey、isActive、error；isActive仅指subscription存在且hotkey非null，不是持续健康探针。

设置非null hotkey时只建一次monitor/update/disconnect listeners，再start native monitor；成功保存hotkey清error。拒绝记录monitor_refused或ax_not_granted，异常daemon_unreachable，并unsubscribe；失败分支未显式清旧configuredHotkey，因此configured与active可不一致。设null/disarm则unsubscribe、清hotkey/error、尽力stop。断连且仍有hotkey时1500ms后重arm一次，触发时再检查当前hotkey；失败只日志，未见指数重试。

prewarm异步建overlay并ping helper，两者错误独立。restore应用保存的hotkey；退出前disarm并关overlay。[UI §6]

捕获按顺序：

1. manual captureNow和native down共用capturingNow guard；重叠请求返回/丢弃。native down会快门声，manual未走该音效路径
2. 生成request id，先发starting
3. 优先key event携带的frontmost（found且bundle存在）；否则helper查询frontmost并排除Alma bundle
4. target失败分别发frontmost_lookup_failed或no_target；capture失败发capture_failed并附message
5. 按bundle/PID/可选window ID抓图到userData/appshots目录
6. 若有windowFrame、可读图、Alma window，最多5次测composer、间隔80ms；fallback目标132×132、右下inset32；发起不await的1100ms桌面动画
7. 主动restore/show/focus Alma；macOS暂跨workspaces可见，首次blur撤回
8. 若尝试动画，715ms后fire到renderer，否则立即。尝试标志不证明动画真的显示

overlay覆盖所有display bounds的union，透明、不可focus、忽略鼠标、screen-saver级别并showInactive。source/destination全局坐标减union origin。动画promise结束或失败后hide；启动promise有50ms fallback，但总动画完成没有独立超时。composer预测attachment row增长并瞄准56px thumbnail；负坐标/混合DPI需实测。

## Appshot 附件与隐藏上下文

starting设置phase；target=new时从已有chat导航root，否则当前composer。fired设置success、pending capture和单调消费token。failed只在request仍当前时4s后回idle。root和chat composer各按token消费一次：bridge读图、尝试attachment upload、失败fallback dataURL、attach JPEG、focus textarea、按原image path存hidden context，finally清pending。此路径没有auto-send。

context-update只有在hidden context已存在且AX文本为空时填入。过早到达会丢；已有非空AX不覆盖。remove attachment同时删hidden context。序列化遍历附图路径、跳过空AX，每条AX最多4000字符加截断指示，并带source app/title。显示消息时剥离序列化Appshot块。AX文本属于来源数据，不能当可信指令。

starting/fired/failed/context-update是main→renderer IPC，不是macOS桌面notification。单独区分捕获成功、动画尝试、图像读/上传成功、附件已插入和消息已发送。[UI §6]

## UI 验收门槛

完整用例和state-event表在ZIP内保留。必测：持续活动关闭超过10分钟、同/异thread、手动重开；420ms内re-present；4s忙超时后的晚完成；90s end；目标A→B/显示器切换；window失败回退全屏的光标与隐私范围；多个lease释放；混合DPI负坐标；showInactive旁路焦点监测；Appshot重复热键/断连重arm/早晚AX更新/路由切换/附件失败。当前均为需执行的验收，不是已通过结果。

