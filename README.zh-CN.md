# Grid Game Groundwork for Godot

[English](README.md) | **简体中文**

用于制作 3D 网格解谜游戏的 Godot 插件。通过可视化编辑器绘制关卡、试玩，并用 GDScript 扩展玩法。附带推箱子和管道连接示例。

**Godot 4.6+ 标准版 · Compatibility 渲染器 · 已在 4.7.2 验证**

![移动、普通与 L 形箱子推动、下落、撤销和重做演示](docs/media/gameplay.gif)

## 快速开始

1. 在 Godot 中导入 `project.godot`。
2. 点击顶部的 **Grid Levels**。若未显示，在 **项目 → 项目设置 → 插件** 中启用 **Grid Game Groundwork**。
3. 点击 **Open…**，打开 `examples/levels/sokoban.tres` 或同目录的 `pipes.tres`。
4. 按 **1 / 2 / 3** 切换 Paint 绘制 / Erase 擦除 / Select 选择。在 Select 下拖动 XYZ 箭头或平面手柄可按格移动，按 **End** 向下贴地。
5. 点击 **Save** 保存，再点击 **Playtest ▶** 试玩。

按 **F5** 直接运行推箱子；打开 `examples/pipes.tscn` 后按 **F6** 运行管道示例。推箱子关卡从起点按两次 **S**，可将箱子推落到下层平台。

![绘制与擦除、选中实体、拖动 XYZ 手柄按格移动、End 贴地，以及整体撤销和重做的演示](docs/media/authoring.gif)

按 **1**（Paint 绘制）、**2**（Erase 擦除）、**3**（Select 选择）切换工具。拖动绘制或擦除，点击选择实体并查看属性。

在 **Select** 中选中实体后，可拖动 **XYZ 箭头**沿单轴移动，或拖动 **XY／XZ／YZ 平面手柄**在平面内移动。移动时按 **1 格吸附**，多格实体整体移动，右侧坐标同步更新。无效位置标红，松开时恢复原位；**Esc** 取消，一次拖拽可整体撤销／重做。坐标沿用 Godot 约定：**Y 为高度**。

选中或拖拽实体时按 **End**，可沿 Y 轴向下贴到最近的实心支撑面（地面、箱子或墙顶）。拖拽中贴地后可继续移动，整次操作合并为一次撤销，**Esc** 恢复拖拽前的位置。下方无支撑或当前位置非法时保持原位并显示单行提示。

## 功能

- 可视化关卡编辑：绘制、堆叠、形状编辑和 `.tres` 保存。
- 网格移动、多格实体、连锁推动和重力下落。
- 整步撤销与重做，涵盖下落及重新开始。
- 可复用实体定义、单个实体属性覆盖和自定义游戏规则。

## 操作

| 场景 | 输入 | 功能 |
| --- | --- | --- |
| 关卡编辑 | **1 / 2 / 3**（主键盘或小键盘） | Paint 绘制 / Erase 擦除 / Select 选择 |
| 关卡编辑 | 左键点击 / 拖动 | 使用当前工具绘制或擦除；Select 下点击实体查看属性 |
| Select | 左键拖动 **XYZ 箭头**或 **XY／XZ／YZ 方形手柄** | 沿单轴或平面移动，按整数格吸附 |
| Select，选中或拖拽中 | **End** | 向下贴到最近的实心支撑面，之后可继续拖动 |
| 实体拖拽中 | **Esc** | 取消整次拖拽，包括其中的 End 贴地 |
| 关卡编辑 | 右键 | 拾取实体的定义、旋转和镜像作为画笔 |
| 形状编辑 | **1 / 2**，左键点击 / 拖动 | 添加 / 移除占用格子；**3** 不生效 |
| 形状编辑 | 右键 | 移除占用格子 |
| 关卡编辑 | **Ctrl/Cmd+S** | 保存关卡 |
| 关卡编辑 | **Ctrl/Cmd+Z** | 撤销上一次编辑操作 |
| 关卡编辑 | **Ctrl/Cmd+Shift+Z** 或 **Ctrl/Cmd+Y** | 重做上一次编辑操作 |
| 编辑视口或试玩 | 中键拖动 | 旋转视角 |
| 编辑视口或试玩 | **Shift+中键拖动** | 平移视角 |
| 编辑视口或试玩 | 滚轮 | 放大 / 缩小 |
| 编辑视口或试玩 | **F** | 将关卡居中显示 |
| 试玩 | **WASD / 方向键** | 按格移动 |
| 试玩 | **Z / Y / R** | 撤销 / 重做 / 重新开始 |
| Godot 编辑器 | **F5**（macOS：**Cmd+B**） | 运行项目 |
| Godot 编辑器 | **F6**（macOS：**Cmd+R**） | 运行当前场景 |
| Godot 编辑器 | **F8**（macOS：**Cmd+.**） | 停止运行项目或场景 |

**1/2/3** 和 **End** 需要焦点位于 Grid Levels 内，且不能带修饰键；在文本、坐标、Inspector 属性输入框或弹窗中不生效。鼠标绘制或拖拽结束后才能切换工具；**End** 仅在 Select 下生效。使用视口快捷键前先点击棋盘，试玩时先点击游戏窗口取得键盘焦点。Godot 的运行／停止键采用[默认编辑器键位](https://docs.godotengine.org/en/4.6/tutorials/editor/default_key_mapping.html)，可在编辑器设置中自定义。

## 用于自己的项目

将 `addons/grid_game_groundwork/` 复制到项目的 `addons/` 目录并启用插件。运行关卡时，为 `Node3D` 挂载 `addons/grid_game_groundwork/runtime/game.gd`，并指定 **Level** 资源。

## 文档

以下详细文档目前为英文。

- [关卡设计指南](docs/designer-guide.md)：制作关卡和配置实体。
- [扩展指南](docs/extending.md)：添加玩法和推动规则。
- [开发说明](docs/development.md)：运行检查和导出构建。
- [领域术语](CONTEXT.md) · [设计决策](docs/adr)

灵感来自 Corey Martin 的 [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork)。参见[第三方许可声明](THIRD_PARTY_NOTICES.md)。
