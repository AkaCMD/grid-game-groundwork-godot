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

## 接入其他语言的规则

在关卡的 **Game rule** 选择器中选择 **New GGDelegatedGameRule**，然后在 Inspector 中把 Godot `Resource` 赋给 **Implementation**。使用导出属性保存规则配置，并确保编辑器和试玩进程都能调用实现代码。[适配器](../addons/grid_game_groundwork/rules/delegated_game_rule.gd) 按 Godot 中的准确方法名调用以下方法。

| 方法 | 约定 |
| --- | --- |
| `resolve_command(session: RefCounted, command: StringName, arguments: Dictionary) -> bool` | 处理自定义指令。返回 true 接受动作，返回 false 回滚。 |
| `resolve_move(session: RefCounted, actor_id: StringName, direction: Vector3i) -> bool` | 结算通过方向检查的 `move` 指令。调用 `session.step` 可将多步合为一次动作。返回 true 接受动作，返回 false 回滚。 |
| `after_step(session: RefCounted) -> void` | 在初始重力结算前及每次网格位移后运行，包括每一格下落。 |
| `after_action(session: RefCounted) -> void` | 在初始重力结算完成后运行，也在解析器接受动作后、最终校验和记录历史前运行。 |
| `validate_layout(level: Resource) -> PackedStringArray` | 检查候选 `GGLevel`，返回额外的布局错误。返回空数组表示通过。将关卡及其资源视为只读。 |

至少实现一个钩子。省略 `resolve_move` 时，`move` 使用默认单步移动。省略 `resolve_command` 时，自定义指令会被拒绝。缺少实现资源或资源未公开任何约定方法时，关卡校验会报告错误。自定义碰撞、推动或重力策略仍可通过 `GGGameRule` 钩子实现。

在回调中同步调用会话方法。`step` 或 `settle` 返回前，可能在同一个规则资源上调用 `after_step`。保持规则配置只读，并允许这种嵌套调用。

规则实现可使用以下 [GGSession](../addons/grid_game_groundwork/core/session.gd) 方法。将可变机制状态保存在会话中，使动作历史能够恢复它。

| 方法 | 约定 |
| --- | --- |
| `entities_at(cell: Vector3i) -> Array[StringName]` | 返回占据该世界格子的全部实体 ID，包括非实心实体，以及形状中任一部分占据该格子的多格实体。 |
| `has_entity(entity_id: StringName) -> bool` | 检查当前会话中是否存在该实体。 |
| `get_entity_cells(entity_id: StringName) -> Array[Vector3i]` | 返回该实体占据的世界格子。实体缺失时返回空数组。 |
| `get_entity_property(entity_id: StringName, key: StringName, fallback: Variant = null) -> Variant` | 返回解析后的实体属性。实体或键缺失时返回备用值。 |
| `get_entity_state(entity_id: StringName, key: StringName, fallback: Variant = null) -> Variant` | 返回实体的机制状态值。实体或键缺失时返回备用值。 |
| `set_entity_state(entity_id: StringName, key: StringName, value: Variant) -> bool` | 在结算期间写入实体的机制状态。实体缺失或无法写入时返回 false。 |
| `get_mechanic_state(key: StringName, fallback: Variant = null) -> Variant` | 返回当前机制状态值。键缺失时返回备用值。 |
| `set_mechanic_state(key: StringName, value: Variant) -> bool` | 在结算期间写入会话级机制状态。无法写入时返回 false。 |
| `set_outcome(outcome: StringName) -> bool` | 在结算期间把会话状态设为 `won` 或 `failed`。在结算之外调用或传入其他结果时返回 false。 |

两个状态写入方法都接受 null、bool、int、float、String、StringName 和 Vector3i。在结算之外调用或传入不支持的类型时返回 false。读取方法递归复制数组和字典，值中的对象引用仍然共享。[规则适配测试](../tests/test_delegated_rule.gd) 覆盖资源保存重载、试玩准备和动作历史。

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

自定义控件可调用 `GGGame.submit_command(command, arguments = {})`。动作获接受后，棋盘会播放动画。用 `is_animating()` 查询棋盘是否仍在呈现动作。`undo()`、`redo()` 和 `restart()` 在执行或排队时返回 true。动画期间，最后一个历史请求会清空待执行的移动，并在当前动画结束后执行。规则结算期间发出的历史请求返回 false。

自定义外观可实现 `apply_entity_selection(selected: bool)`。`GGBoardView.set_selected(id)` 调用该钩子，并在状态变化后恢复选择；`select_actor(id)` 还会显示通用选择环。编辑器使用独立的[模型表面反馈](editor-surface-coverage.zh-CN.md)。

## 原生资源与导出

[GGLevel](../addons/grid_game_groundwork/data/level.gd) 接受版本 1 和 2，由 `GGLevelAuthoring` 打开时迁移至版本 2。定义可内嵌或外置，属性覆盖保持显式记录。`GGLevelAuthoring.save(path)` 先检查结构并保存外部配置，再通过临时文件替换关卡；多资源保存不是单个事务。

编辑预览、绘制、移动、复制和实体编辑在候选关卡上验证，实体放置记录及覆盖值使用副本，共享定义、规则配置与试玩场景保留资源身份。验证钩子应保持只读：通过验证的编辑仅提交一次，拒绝的候选布局保持实时实体与历史不变。[编辑测试](../tests/test_authoring.gd)检查规则执行期间的隔离及重做分支保留。

命令见[开发检查](development.zh-CN.md#检查)、[导出](development.zh-CN.md#导出)和[重新生成示例](development.zh-CN.md#重新生成示例)。玩法通过 `GGSession` 测试，存储修改通过真实的 `GGLevelAuthoring` 保存／重载检查。设计决策见 [docs/adr/](adr/)。

## 编辑器选择与笔画

使用 [GGEditorInteraction](../addons/grid_game_groundwork/editor/interaction.gd) 和一个 `GGLevelAuthoring` 管理工具切换、形状编辑上下文与预览失效处理，其 `selection` 和 `stroke` 共用该关卡编辑模块。输入适配器调用 `set_mode`、`set_shape_mode`、`configure_brush`、`set_plane` 和 `open`，由 `height_target` 选择 Q/E 的动作。渲染 `refreshed_level()` 返回的关卡，使选择状态先于视图重建完成协调，包括 Inspector 编辑后的刷新。窗口失焦或编辑器隐藏时调用 `cancel()`。

[GGEditorSelection](../addons/grid_game_groundwork/editor/selection.gd) 通过 `begin_move`、`preview_move`、`finish_move` 暂存整组移动。[GGEditorStroke](../addons/grid_game_groundwork/editor/stroke.gd) 通过 `begin`、`preview`、`sample`、`finish` 接收摄像机射线，保持初始表面和已访问放置点稳定。两者也可直接配合同一 `GGLevelAuthoring` 使用。

切换规则由交互模块处理，输入代码提供射线并绘制预览。[交互测试](../tests/test_interaction.gd)检查工具切换与预览失效，摄像机投影、焦点和输入传递通过[编辑器测试框架](../tests/editor_harness/plugin.gd)检查。

## 角色选择与组合移动

`session.select_actor(id)` 接受具有 `player=true` 的现存实体。`player_id()` 返回选中角色或第一个剩余玩家。实体仍存在时，撤销／重做／重开保留选择；新关卡会清空选择。运行时按占格拾取，动画期间禁用拾取。

重写 `resolve_move` 可组合移动。仅在解析器中调用 `session.step(...)`：它结算一个 XYZ 轴向步骤、推动和重力，并追加动画阶段，不创建历史，也不调用 `after_action`。返回 true 记录一个完整动作；返回 false 恢复之前的状态与阶段，并保留重做。结算期间拒绝递归 `act`、`move` 和历史操作。仅在结算期间调用 `step`。

`carried_entities` 返回每步可移动的同行实体 ID。实体不存在或被计划外实体阻挡时，整步拒绝；同行实体不能推动障碍。重力继续前必须处理的交互应放在 `after_step`，例如吃掉下落途中的面包。保持合法占格，将修改存入会话；外观变化需要独立动画时，追加快照阶段。

解析器面对异常布局也必须终止。[QUACK 规则](../examples/rules/quack_rule.gd)展示了有界多步滑行，并会整体拒绝无界移动。

## 指令、字段与试玩场景

`session.act(command, arguments)` 开始一次事务。解析器返回 false、重力结算失败或最终状态非法时，恢复先前快照与动画阶段，并保留重做。接受的动作运行 `after_action` 并仅记录一次历史。游玩期间保持规则配置不变，将重力方向、门状态和传送门锁存状态放在会话或实体状态中。翻滚方块规则提供了自定义移动解析器。[翻滚方块规则](../examples/rules/rolling_rule.gd)

`session.act_with_result(command, arguments = {})` 和 `GGGame.submit_command` 返回字典，其中 `code` 是 `StringName`，`errors` 是 `PackedStringArray`。只需要布尔结果时可使用 `session.act`。

| 结果码 | 含义 |
| --- | --- |
| `accepted` | 动作已记录到历史。 |
| `rejected` | 规则拒绝了指令。 |
| `invalid_state` | 动作已回滚，`errors` 包含规则返回的最终校验错误。 |
| `resolution_failed` | 结算失败，动作已回滚，`errors` 描述失败情况。 |
| `unavailable` | 当前没有生效规则、会话正在结算，或关卡已有胜负结果。`GGGame` 尚未就绪或不在场景树中时也返回此结果。 |
| `busy` | `GGGame` 仍在呈现动作，呈现结束后可以重试该指令。 |

默认 `move` 指令仍为水平移动。`step` 在结算期间接受任一轴的单位方向；`settle()` 应用当前重力策略。默认下落求解在整个动作中共用 `resolution_limit` 预算，无法终止时拒绝动作。自定义解析器须限制自己的循环；重力结算期间递归调用 `settle` 会拒绝动作。

[GGGrid](../addons/grid_game_groundwork/core/grid.gd) 提供 `orientation_basis(index, mirror)`、`rotated(index, axis, turns)` 和 `transform_cell(cell, index, mirror)`。朝向 0-3 保留原有 Y 旋转，4-23 表示其他正交姿态。放置记录以 `orientation` 为准，`quarter_turns` 保留兼容访问，运行时记录继续使用 `turns` 键。世界坐标和编辑平面独立于游戏重力。

在定义的 `fields` 列表中声明 [GGPropertyField](../addons/grid_game_groundwork/data/property_field.gd) 资源。字段包含 `key`、`label`、`kind`、`default_value`、`choices` 和 `required`。类型为 BOOLEAN、INTEGER、FLOAT、TEXT、CHOICE、ENTITY、ENTITIES、CELL。缺省值分别使用 false、零、空文本／引用／列表、首个选项或零坐标。`required` 要求引用或引用列表非空。启用显式覆盖前，实体持续继承默认值；可变默认值会复制到各实体。

ENTITY 和 ENTITIES 值是实体 ID，提供编辑选择器与引用校验。整组复制会重映射组内引用，包括继承的默认引用，同时保留组外引用。删除目标后保留缺失引用，生成身份不依赖当前实体数量。`validate_structure()` 检查类型和资源结构，`validate_placement()` 加入规则检查，`validate()` 再加入引用检查。保存草稿要求结构合法，试玩要求完整校验。编辑态碰撞与支撑策略应和运行时对应策略保持一致。

指定 `GGLevel.playtest_scene` 可使用专用控制和表现。其根节点须提供 `level` 属性或 `configure_level(level)`，启动器在加入场景树前注入隔离关卡。`GGLevelAuthoring.prepare_playtest(directory)` 写入临时快照与启动场景。快照包含规则资源字段和实体引用；脚本与外观场景保留为外部资源。
