# 防误复刻关键反例

这些是对734正式case之外的模块阅读检查索引，未另计正式case数量，也未执行。请先找现有对应case；必要时后续加case应更新数量与traceability。

| 反例 | 错误实现会发生什么 | 正确 oracle与来源 |
|---|---|---|
| snapshotA后snapshotB都从e1编号 | 旧ref投到不同元素 | 长期counter+同PID CFEqual复用；模块02 |
| descriptor命中两个同标题按钮 | first-match误点 | 唯一candidate才可恢复；200节点/12层/最近3祖先 |
| 31BMP后emoji的UTF16边界 | 切开代理对 | 先20 Unicode scalar分组再UTF16；模块06 |
| SelectedText setter失败 | ref/focused路线混同 | ref可写但失败直接error；focused可fallback AXValue |
| inactiveapp仍有AXFocusedWindow | raw key投错 | hasKeyWindow还需active |
| 动作返回即拆FocusGuard | 尾期焦点保护缺失 | 正常/异常都有+5秒清理 |
| 连续native snap | 错把第二次标diff | snapToDict plain；get_app_state独立diff |
| disabled diff后再次diff | 基线没刷新 | disabled仍更新fullbaseline |
| unchanged第二次snapshot | isDifffalse | 已有baseline时即使0变化仍delta |
| macOS13 captureWindow | 造不存在fallback | 该路径报错；Electronpump displayfallback是另层 |
| display图像cursor | 一概false | display为true，windowfalse，nativePiPtrue |
| visualbox center直接当point | Retina/窗口偏移误点 | pixel→mapping→desktop；目标明确 |
| UI clock=0 | 错认活动冷却 | 0=never-active Infinity，单独测试 |
| Appshot capture带非空AX同步返回 | 错堵塞或错归因 | 普通response空AX，后台事件更新 |
| monitor starttrue | 错认tapready | runloop排队成功与tap健康独立 |
| Appshot AX格式用bounds | 数组基址偏移误读 | role/title/value/description grammar |
| native PiP status size/streaming/frames | schema不一致 | has_first_frame/nullableage/floater_frame |
| OAuth code300s/accessnil | 失去TTL边界 | .153原code60s/access3600s |
| tokenform必填pid | 错认证流程 | authorize optional alma_arm_pid保存至PendingCode |
| signature核nominatedPID | 虚构HTTP调用者绑定 | 静态证据未证明实际caller身份 |
| arbitrary nativeHTTP toolname passthrough | 重建扩大可达面 | 原callTool先静态目录gate |
| launch REST自动activity | 忽略注册顺序 | 成功handler早于后置middleware |
| stop→立即新capture | 旧任务写回新generation | compat记race，safegeneration隔离 |
| viewer点击=PiP输入 | 把观看层当control | Electron PiP无此输入转发链 |
