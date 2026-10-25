# 扩展指南

[English](extending.md) | **简体中文** · [README](../README.zh-CN.md) · [用户指南](designer-guide.zh-CN.md)

扩展 [addons/grid_game_groundwork/](../addons/grid_game_groundwork/) 中的资源和规则，可添加玩法或替换表现。将可变玩法状态保存在 `GGSession` 中，撤销与重做才能恢复它们。

## 模块边界

[data/](../addons/grid_game_groundwork/data/) 定义 `GGLevel`、`GGEntityDefinition` 和 `GGEntityPlacement`。放置记录引用共享定义，并保存位置、朝向和显式覆盖。[GGSession](../addons/grid_game_groundwork/core/session.gd) 结算整数网格移动，不依赖场景变换或物理模拟。游玩操作使用 `start`、`act`、`move`、`undo`、`redo`、`restart` 和 `snapshot`。

[rules/](../addons/grid_game_groundwork/rules/) 提供玩法，[runtime/](../addons/grid_game_groundwork/runtime/) 渲染快照并处理输入。[GGLevelAuthoring](../addons/grid_game_groundwork/editor/level_authoring.gd) 提供编辑和保存／加载操作。插件独立于示例游戏。

## 创建玩法规则

继承 `GGGameRule`，命名类并添加 `@tool`，然后在关卡的 **Game rule** 选择器中指定实例。

[GGGameRule](../addons/grid_game_groundwork/rules/game_rule.gd) 的钩子默认行为如下：

| 钩子 | 默认行为 | 用途 |
| --- | --- | --- |
| `resolve_action(session, command, arguments)` | 分发 `move` 指令。 | 在共享动作事务中处理游戏指令。 |
| `initial_state(level)` | 提供向下／关闭重力和掉落高度。 | 初始化快照包含的机制状态。 |
| `allows_direction(direction)` | 接受 XZ 四向。 | 允许其他移动方向。 |
| `gravity_direction(session)` | 读取 `mechanic_state.gravity_direction`。 | 选择当前全局重力方向。 |
| `resolve_gravity(session)` | 调用 `session.fall(direction)`。 | 替换重力结算。 |
| `supports_entity(session, actor_id, support_id, direction)` | 使用 `blocks_entity`。 | 独立定义运行时支撑。 |
| `is_outside(session, entity_id, direction)` | 完整形状越过沿重力方向投影的掉落界限。 | 定义活动边界。 |
| `on_fall_out(session, entity_id)` | 玩家失败并移除该实体。 | 定义掉落后果。 |
| `validate_state(session)` | 拒绝实心实体在终点被阻挡。 | 提交历史前检查动作结果。 |
| `validate_level(level)` | 检查设计布局的边界和碰撞。 | 校验玩法布局。 |
| `authored_cell_allowed(level, cell)` | 要求 Y 高于 `void_height`。 | 提供玩法的编辑边界。 |
| `blocks_placement(level, actor, other)` | 拒绝实心布局重叠。 | 定义设计布局的碰撞策略。 |
| `authoring_gravity(level)` | 返回向下。 | 提供编辑器支撑方向。 |
| `supports_placement(level, actor, other, direction)` | 接受实心支撑。 | 筛选吸附工具的支撑面。 |
| `resolve_move(session, actor_id, direction)` | 调用一次 `session.step(...)`。 | 将多个步骤组合成一个动作。 |
| `allows_push(session, actor_id, moving_ids, direction)` | 使用指定的推动规则，未指定则使用 `GGPushRule`。 | 判断是否允许推动计划，不修改状态。 |
| `carried_entities(session, actor_id, direction)` | 返回空数组。 | 返回本步同行实体 ID。 |
| `blocks_entity(session, actor_id, obstacle_id, direction)` | 实心实体阻挡。 | 定义因角色而异的障碍与支撑。 |
| `after_step(session)` | 无操作。 | 处理每次网格位移、每格下落及初始重力结算前的交互。 |
| `after_action(session)` | 无操作。 | 初始化或动作接受后，检查结算完成的棋盘。 |

```gdscript
@tool
class_name MyPuzzleRule
extends GGGameRule

func after_action(session: GGSession) -> void:
    if session.status == &"failed":
        return
    # Evaluate your conditions from the resolved session state.
    var activated: int = session.mechanic_state.get("activated", 0)
    if activated >= 3:
        session.status = &"won"
```

机制需要自行更新 `session.mechanic_state["activated"]`，此示例只检查数值。实现开关时，通过 `GGGrid.index(session.entities)` 查询同格实体。撤销／重做直接恢复快照，不重新运行钩子；被阻挡的指令不新增历史。

可变状态使用值、数组和字典，保存在 `session.mechanic_state` 或各实体的 `state` 中。快照同时记录位置、朝向、属性、移除结果和胜负状态。规则资源与外观节点不在历史中。

实体记录包含 `cell`、`turns`、`mirror`、`shape`、`properties` 和 `state`。形状使用局部 `Vector3i` 偏移，`GGGrid.cells(entity)` 返回世界占格。`after_action` 修改占格时，必须留下合法且已完成重力结算的棋盘；会话不会递归结算该钩子的修改。

## 自定义推动

继承 `GGPushRule`，重写 `allows(session, actor_id, moving_ids, direction)`。会话先构建完整移动计划，由推动策略批准或拒绝，判定过程应无副作用。

```gdscript
@tool
class_name ColorPushRule
extends GGPushRule

func allows(session: GGSession, actor_id: StringName,
        moving_ids: Array, direction: Vector3i) -> bool:
    if not super.allows(session, actor_id, moving_ids, direction):
        return false
    var actor_color = session.entities[actor_id].properties.get("team", "blue")
    for id in moving_ids:
        if id != actor_id and session.entities[id].properties.get("team") != actor_color:
            return false
    return true
```

将资源指定给玩法规则的 **Push Rule**；需要玩法配置时，可重写 `GGGameRule.allows_push`。

[GGPushRule](../addons/grid_game_groundwork/rules/push_rule.gd) 要求角色具有 `can_push`，被推实体具有 `pushable`。`transmits_push=false` 阻止被推实体继续推动前方实体。[GGStrengthPushRule](../addons/grid_game_groundwork/rules/strength_push_rule.gd) 还要求角色 `strength` 覆盖全部被推实体的总 `weight`。单实体覆盖可修改这些属性。

## 外观与生命周期

给定义的 `visual_scene` 指定 `PackedScene`；未指定时，渲染器生成彩色格子模型和非实心标记。实现 `configure_entity(definition, properties)` 和 `apply_entity_state(state)` 可自定义外观。渲染器按快照定位根节点，玩法坐标应从会话读取。

给 `Node3D` 挂上 [GGGame](../addons/grid_game_groundwork/runtime/game.gd) 并指定 `level`，即可获得摄像机、灯光、控制和简易界面。连接 `level_completed` 和 `level_failed` 可切换关卡。自定义表现时，分别使用 `GGSession` 和 [GGBoardView](../addons/grid_game_groundwork/runtime/board_view.gd)。持久进度由接入项目管理。

自定义外观可实现 `apply_entity_selection(selected: bool)`。`GGBoardView.set_selected(id)` 调用该钩子，并在状态变化后恢复选择；`select_actor(id)` 还会显示通用选择环。编辑器使用独立的[模型表面反馈](editor-surface-coverage.zh-CN.md)。

## 原生资源与导出

[GGLevel](../addons/grid_game_groundwork/data/level.gd) 接受版本 1 和 2，由 `GGLevelAuthoring` 打开时迁移至版本 2。定义可内嵌或外置，属性覆盖保持显式记录。`GGLevelAuthoring.save(path)` 先检查结构并保存外部配置，再通过临时文件替换关卡；多资源保存不是单个事务。

命令见[开发检查](development.zh-CN.md#检查)、[导出](development.zh-CN.md#导出)和[重新生成示例](development.zh-CN.md#重新生成示例)。玩法通过 `GGSession` 测试，存储修改通过真实的 `GGLevelAuthoring` 保存／重载检查。设计决策见 [docs/adr/](adr/)。

## 编辑器选择与笔画

[GGEditorSelection](../addons/grid_game_groundwork/editor/selection.gd) 和 [GGEditorStroke](../addons/grid_game_groundwork/editor/stroke.gd) 共用同一 `GGLevelAuthoring`。选择模块通过 `begin_move`、`preview_move`、`finish_move` 暂存整组移动。笔画模块通过 `begin`、`preview`、`sample`、`finish` 接收摄像机射线，保持初始表面和已访问放置点稳定。

放置规则由这些模块处理，输入代码提供射线并绘制预览。模块行为直接测试，摄像机投影、焦点和输入传递通过[编辑器测试框架](../tests/editor_harness/plugin.gd)检查。

## 角色选择与组合移动

`session.select_actor(id)` 接受具有 `player=true` 的现存实体。`player_id()` 返回选中角色或第一个剩余玩家。实体仍存在时，撤销／重做／重开保留选择；新关卡会清空选择。运行时按占格拾取，动画期间禁用拾取。

重写 `resolve_move` 可组合移动。仅在解析器中调用 `session.step(...)`：它结算一个 XYZ 轴向步骤、推动和重力，并追加动画阶段，不创建历史，也不调用 `after_action`。返回 true 记录一个完整动作；返回 false 恢复之前的状态与阶段，并保留重做。结算期间拒绝递归 `act`、`move` 和历史操作。仅在结算期间调用 `step`。

`carried_entities` 返回每步可移动的同行实体 ID。实体不存在或被计划外实体阻挡时，整步拒绝；同行实体不能推动障碍。重力继续前必须处理的交互应放在 `after_step`，例如吃掉下落途中的面包。保持合法占格，将修改存入会话；外观变化需要独立动画时，追加快照阶段。

解析器面对异常布局也必须终止。[QUACK 规则](../examples/rules/quack_rule.gd)展示了有界多步滑行，并会整体拒绝无界移动。

## 指令、字段与试玩场景

`session.act(command, arguments)` 开始一次事务。解析器返回 false、重力结算失败或最终状态非法时，恢复先前快照与动画阶段，并保留重做。接受的动作运行 `after_action` 并仅记录一次历史。游玩期间保持规则配置不变，将重力方向、门状态和传送门锁存状态放在会话或实体状态中。[翻滚](../examples/rules/rolling_rule.gd)、[重力](../examples/rules/gravity_rule.gd)和[关联机关](../examples/rules/links_rule.gd)规则使用此接口。

默认 `move` 指令仍为水平移动。`step` 在结算期间接受任一轴的单位方向；`settle()` 应用当前重力策略。默认下落求解在整个动作中共用 `resolution_limit` 预算，无法终止时拒绝动作。自定义解析器须限制自己的循环；重力结算期间递归调用 `settle` 会拒绝动作。

[GGGrid](../addons/grid_game_groundwork/core/grid.gd) 提供 `orientation_basis(index, mirror)`、`rotated(index, axis, turns)` 和 `transform_cell(cell, index, mirror)`。朝向 0-3 保留原有 Y 旋转，4-23 表示其他正交姿态。放置记录以 `orientation` 为准，`quarter_turns` 保留兼容访问，运行时记录继续使用 `turns` 键。世界坐标和编辑平面独立于游戏重力。

在定义的 `fields` 列表中声明 [GGPropertyField](../addons/grid_game_groundwork/data/property_field.gd) 资源。字段包含 `key`、`label`、`kind`、`default_value`、`choices` 和 `required`。类型为 BOOLEAN、INTEGER、FLOAT、TEXT、CHOICE、ENTITY、ENTITIES、CELL。缺省值分别使用 false、零、空文本／引用／列表、首个选项或零坐标。`required` 要求引用或引用列表非空。启用显式覆盖前，实体持续继承默认值；可变默认值会复制到各实体。

ENTITY 和 ENTITIES 值是实体 ID，提供编辑选择器与引用校验。整组复制会重映射组内引用，包括继承的默认引用，同时保留组外引用。删除目标后保留缺失引用，生成身份不依赖当前实体数量。`validate_structure()` 检查类型和资源结构，`validate_placement()` 加入规则检查，`validate()` 再加入引用检查。保存草稿要求结构合法，试玩要求完整校验。编辑态碰撞与支撑策略应和运行时对应策略保持一致。

指定 `GGLevel.playtest_scene` 可使用专用控制和表现。其根节点须提供 `level` 属性或 `configure_level(level)`，启动器在加入场景树前注入隔离关卡。`GGLevelAuthoring.prepare_playtest(directory)` 写入临时快照与启动场景。快照包含规则资源字段和实体引用；脚本与外观场景保留为外部资源。[重力运行场景](../examples/runtime/gravity_game.gd)展示了自定义指令输入，并复用共享历史。
