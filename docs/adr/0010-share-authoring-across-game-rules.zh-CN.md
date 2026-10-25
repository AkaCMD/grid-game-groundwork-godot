# 不同离散规则共用关卡编辑

[English](0010-share-authoring-across-game-rules.md) | **简体中文**

游戏共用整数立方网格、24 种正交朝向、类型化设计字段和实体引用。规则提供碰撞、支撑、活动边界和指令结算，共享会话负责完整动作历史。编辑平面保持独立于游戏重力。游戏可提供专用试玩场景，无需修改编辑器或关卡格式。

这扩展了 [ADR 0002](0002-preserve-three-dimensional-grid-gameplay.md)、[ADR 0005](0005-use-explicit-ground.md) 和 [ADR 0008](0008-share-entity-definitions-with-overrides.md) 中的默认支撑与掉落策略，原有行为保留为默认策略。继续使用原生资源与隔离试玩，并自动迁移至版本 2。保存草稿要求结构合法；试玩还要求引用有效且玩法布局合法。

代价是更广的数据模型，以及显式区分编辑态和运行时的策略钩子。翻滚方块、六向重力和关联机关与现有示例共同提供验收场景。已确认的要求见 [issue 14](https://github.com/AkaCMD/grid-game-groundwork-godot/issues/14)。
