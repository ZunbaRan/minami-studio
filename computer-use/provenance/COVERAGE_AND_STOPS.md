# 覆盖范围与未闭合项

## 合并覆盖

原14章与相关AX/host/MCP/native扩展/镜像/验收深度均保留；新增11个模块主线和独立nativeHTTP高级模块。原21代码文件逐一记录模块思想、hash、错误与替代资料；不提供未经核验的可编译代码。局部原JS/ASM直接链接关键分支，代码证据量不是完整行为验证量。

| 范围 | 已可用依据 | 必须保留的未知 |
|---|---|---|
| stdio23+CLI+hostREST | .164契约；stdio两版同字节；局部host源 | provider最终模型行为、真实异常时序 |
| nativewire/AX/ref/diff | .164地址级契约；.153关键分支ASM | 多peer事务交错、CF/AX实际异常、跨语言极值 |
| 捕获/mapping/OCR | .164契约和.153关键gate/TTL/cursor | mixedDPI、锁屏/最小化/Spaces、取消完成顺序 |
| 输入/FocusGuard | 路由/20scalar/5s/唯一恢复已静态闭合 | 私有SPI与每OS兼容、接收effect、零抢焦点/释放 |
| PiP/Lens/Appshot | .164host原码、native契约、.153反证 | 晚完成race实际次序、浏览器lease释放、真实热键tap健康 |
| AppUsage/intent | native契约+排序/2s原指令 | 所有app/intent当前运行支持、不明URL副作用 |
| nativeHTTP/OAuth | .153原始函数/目录数据深入取证；.164七控制命令 | actualcaller身份绑定、所有HTTP边界/.164一一等同性 |

## 必须先停下的条件

1. 证据指向不同版本/不同入口却被当同一行为
2. 原始代码与重建Swift冲突，未完成原分支定位
3. profile未选择却要执行输入；真实应用/权限/账户未经选择
4. 目标PID/ref/window/capture generation不能绑定，或想fallback到前台
5. 私有ABI签名、事件字段、point/pixel单位不明
6. dispatch后结果未知却准备重放mutation
7. 缺receiver、焦点事件或cursor证据，却想宣称可靠后台操作
8. 整屏fallback扩大私密范围而未做明确设计和范围控制
9. nativeHTTP签名核nominatedPID被宣传为已证明HTTPcaller身份
10. 文件/源码hash不匹配；不能把不同样本地址硬套

每个STOP输出：requirement_id、证据、缺失事实、行为影响、临时拒绝策略、下一观察、owner、status。原已闭合encode fallback、SerializedElement omission和AXWindows原序不再列入未闭合；剩余是SnapshotResult容器逐字段、CG fallback完整选择、OS动态行为等独立问题。

## 已完成与未做

本次完成的是资料整合、静态源定位、文档/JSON一致性与本包验证；没有执行产品、没有运行原binary、没有访问真实profile或凭证。没有利用nativeHTTP做攻击或越权测试，不给安全漏洞结论。下一阶段只有获得明确实现/运行范围后才能按DAG推进。
