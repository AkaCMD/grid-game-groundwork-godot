# 扩展指南

[English](extending.md) | **简体中文** · [README](../README.zh-CN.md) · [用户指南](designer-guide.zh-CN.md)

扩展 [addons/grid_game_groundwork/](../addons/grid_game_groundwork/) 中的资源和规则，可添加玩法或替换表现。将可变玩法状态保存在 `GGSession` 中，撤销与重做才能恢复它们。

## 模块边界

[data/](../addons/grid_game_groundwork/data/) 定义 `GGLevel`、`GGEntityDefinition` 和 `GGEntityPlacement`。放置记录引用共享定义，并保存位置、朝向和显式覆盖。[GGSession](../addons/grid_game_groundwork/core/session.gd) 结算整数网格移动，不依赖场景变换或物理模拟。游玩操作使用 `start`、`move`、`undo`、`redo`、`restart` 和 `snapshot`。

[rules/](../addons/grid_game_groundwork/rules/) 提供玩法，[runtime/](../addons/grid_game_groundwork/runtime/) 渲染快照并处理输入。[GGLevelAuthoring](../addons/grid_game_groundwork/editor/level_authoring.gd) 提供编辑和保存／加载操作。插件独立于示例游戏。

## 创建玩法规则

继承 `GGGameRule`，命名类并添加 `@tool`，然后在关卡的 **Game rule** 选择器中指定实例。

[GGGameRule](../addons/grid_game_groundwork/rules/game_rule.gd) 的钩子默认行为如下：

| 钩子 | 默认行为 | 用途 |
| --- | --- | --- |
| `resolve_move(session, actor_id, direction)` | 调用一次 `session.step(...)`。 | 将多个步骤组合成一个动作。 |
| `allows_push(session, actor_id, moving_ids, direction)` | 使用指定的推动规则，未指定则使用 `GGPushRule`。 | 判断是否允许推动计划，不修改状态。 |
| `carried_entities(session, actor_id, direction)` | 返回空数组。 | 返回本步同行实体 ID。 |
| `blocks_entity(session, actor_id, obstacle_id, direction)` | 实心实体阻挡。 | 定义因角色而异的障碍与支撑。 |
| `after_step(session)` | 无操作。 | 处理每次水平位移、每格下落及初始重力结算前的交互。 |
| `after_action(session)` | 无操作。 | 初始化或成功移动后，检查结算完成的棋盘。 |

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

[GGLevel](../addons/grid_game_groundwork/data/level.gd) 使用 `schema_version=1`，通过 `validate()` 校验资源。定义可内嵌或外置，属性覆盖保持显式记录。`GGLevelAuthoring.save(path)` 先校验并保存外部配置，再通过临时文件替换关卡；多资源保存不是单个事务。

命令见[开发检查](development.zh-CN.md#检查)、[导出](development.zh-CN.md#导出)和[重新生成示例](development.zh-CN.md#重新生成示例)。玩法通过 `GGSession` 测试，存储修改通过真实的 `GGLevelAuthoring` 保存／重载检查。设计决策见 [docs/adr/](adr/)。

## 编辑器选择与笔画

[GGEditorSelection](../addons/grid_game_groundwork/editor/selection.gd) 和 [GGEditorStroke](../addons/grid_game_groundwork/editor/stroke.gd) 共用同一 `GGLevelAuthoring`。选择模块通过 `begin_move`、`preview_move`、`finish_move` 暂存整组移动。笔画模块通过 `begin`、`preview`、`sample`、`finish` 接收摄像机射线，保持初始表面和已访问放置点稳定。

放置规则由这些模块处理，输入代码提供射线并绘制预览。模块行为直接测试，摄像机投影、焦点和输入传递通过[编辑器测试框架](../tests/editor_harness/plugin.gd)检查。

## 角色选择与组合移动

`session.select_actor(id)` 接受具有 `player=true` 的现存实体。`player_id()` 返回选中角色或第一个剩余玩家。实体仍存在时，撤销／重做／重开保留选择；新关卡会清空选择。运行时按占格拾取，动画期间禁用拾取。

重写 `resolve_move` 可组合移动。仅在解析器中调用 `session.step(...)`：它结算一个 XZ 四向步骤、推动和重力，并追加动画阶段，不创建历史，也不调用 `after_action`。返回 true 记录一个完整动作；返回 false 恢复之前的状态与阶段，并保留重做。禁止在解析器或钩子中递归调用 `move`。

`carried_entities` 返回每步可移动的同行实体 ID。实体不存在或被计划外实体阻挡时，整步拒绝；同行实体不能推动障碍。重力继续前必须处理的交互应放在 `after_step`，例如吃掉下落途中的面包。保持合法占格，将修改存入会话；外观变化需要独立动画时，追加快照阶段。

解析器面对异常布局也必须终止。[QUACK 规则](../examples/rules/quack_rule.gd)展示了有界多步滑行，并会整体拒绝无界移动。
