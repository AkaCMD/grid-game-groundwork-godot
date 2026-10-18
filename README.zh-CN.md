# Grid Game Groundwork for Godot

[English](README.md) | **简体中文**

用于制作 3D 网格解谜游戏的 Godot 插件。通过可视化编辑器绘制关卡、试玩，并用 GDScript 扩展玩法。附带推箱子和管道连接示例。

**Godot 4.6+ 标准版 · Compatibility 渲染器 · 已在 4.7.2 验证**

![移动、普通与 L 形箱子推动、下落、撤销和重做演示](docs/media/gameplay.gif)

## 快速开始

1. 在 Godot 中导入 `project.godot`。
2. 点击顶部的 **Grid Levels**。若未显示，在 **项目 → 项目设置 → 插件** 中启用 **Grid Game Groundwork**。
3. 点击 **Open…**，打开 `examples/levels/sokoban.tres` 或同目录的 `pipes.tres`。
4. 选择 **Paint**（绘制）、**Erase**（擦除）或 **Select**（选择），在棋盘上点击或拖动。点击 **Save** 保存，再点击 **Playtest ▶** 试玩。

按 **F5** 直接运行推箱子；打开 `examples/pipes.tscn` 后按 **F6** 运行管道示例。推箱子关卡从起点按两次 **S**，可将箱子推落到下层平台。

![拖动绘制箱子、擦除箱子，以及选择实体查看属性的演示](docs/media/authoring.gif)

按 **1**（Paint 绘制）、**2**（Erase 擦除）、**3**（Select 选择）切换工具。拖动绘制或擦除，点击选择实体并查看属性。

## 功能

- 可视化关卡编辑：绘制、堆叠、形状编辑和 `.tres` 保存。
- 网格移动、多格实体、连锁推动和重力下落。
- 整步撤销与重做，涵盖下落及重新开始。
- 可复用实体定义、单个实体属性覆盖和自定义游戏规则。

## 操作

| 输入 | 功能 |
| --- | --- |
| 左键点击 / 拖动 | 使用当前编辑工具 |
| 右键 | 在编辑器中拾取实体 |
| Ctrl/Cmd+S | 保存关卡 |
| WASD / 方向键 | 试玩时移动 |
| Z / Y / R | 试玩时撤销 / 重做 / 重新开始 |
| 中键拖动 / Shift + 中键拖动 | 旋转视角 / 平移 |
| 滚轮 / F | 缩放 / 将关卡居中显示 |

## 用于自己的项目

将 `addons/grid_game_groundwork/` 复制到项目的 `addons/` 目录并启用插件。运行关卡时，为 `Node3D` 挂载 `addons/grid_game_groundwork/runtime/game.gd`，并指定 **Level** 资源。

## 文档

以下详细文档目前为英文。

- [关卡设计指南](docs/designer-guide.md)：制作关卡和配置实体。
- [扩展指南](docs/extending.md)：添加玩法和推动规则。
- [开发说明](docs/development.md)：运行检查和导出构建。
- [领域术语](CONTEXT.md) · [设计决策](docs/adr)

灵感来自 Corey Martin 的 [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork)。参见[第三方许可声明](THIRD_PARTY_NOTICES.md)。
