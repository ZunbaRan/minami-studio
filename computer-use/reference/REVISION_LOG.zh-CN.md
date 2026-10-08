> 来源：用户提供的 .164 研究资料 `REVISION_LOG.zh-CN.md`；原文件 SHA256 `106e3a4b7bfb8ddec4f7032b8c53caba6e410937025c5924fb23a3f2421caabe`；全文件 1–12 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# 整合校正记录

分发副本在不改变官方原样本hash或原始source-locator的情况下，按交叉证据修正了早期文字：

- CLI计数统一22canonical功能+help23，另launch别名
- MCP postaction为get_app_state(depth0)，会更新diff；native direct cmd是snap，不是snapshot，且不更新diff
- OCR门槛为成功截图加raw AX元素数不大于1；不是差分条数
- ref销毁标记、descriptor恢复、native并发与mapping陈旧风险按最终算法章描述，移除过时未解码措辞
- 运行profile统一alma_0_4_164/safe_profile；安全常量明确为原创设计
- 内部协调措辞替换为技术报告引用；该历史版本未分发原始代码、反汇编和截图；本次整合新增有界取证代码片段，仍不附完整程序、二进制、真实截图或提示词

上述是资料整合与更正，不是对Alma运行表现的新增验证。官方样本身份/地址/byte范围保持原样；完整locator验证只证明绑定到该样本。
