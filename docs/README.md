# docs 索引

本目录只维护三类文档：活跃的产品与开发计划、面向具体能力的说明手册、已归档的一次性验证记录。规格与实现冲突时，以代码为准并回写文档。

| 文档                                                                             | 类型   | 内容                                                | 维护时机                     |
|--------------------------------------------------------------------------------|------|---------------------------------------------------|--------------------------|
| [keepass-harmonyos-development-plan.md](keepass-harmonyos-development-plan.md) | 活跃   | 唯一的产品范围、架构约束、分阶段任务清单、里程碑、人工验收流程和风险决策记录            | 每个阶段开发、验收或范围变更后更新        |
| [password-generator-and-strength.md](password-generator-and-strength.md)       | 说明手册 | 密码生成三种模式的默认值与约束、强度评分算法、强度指示器与生成器界面行为              | 生成规则、评分阈值或生成器界面行为变化时更新   |
| [arkui-segment-tabs-animation.md](arkui-segment-tabs-animation.md)             | 说明手册 | 分段按钮与 Tabs 联动切换动画的状态接线约束、症状排查表、参考实现位置             | 新增或改动这类切换界面时对照；接线约束变化时更新 |
| [stage-0-technical-validation.md](stage-0-technical-validation.md)             | 归档   | 阶段 0 的技术验证结论：kdbxweb 评估、系统能力决策、模拟器人工验收明细、待复验的平台限制 | 不再更新；仅当相关平台限制在真实设备复验后补记  |
