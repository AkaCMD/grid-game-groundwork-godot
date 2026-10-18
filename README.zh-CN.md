# Grid Game Groundwork for Godot

[English](README.md) | **简体中文**

用于制作 3D 网格解谜游戏的 Godot 插件。可视化绘制关卡、即时试玩，并用 GDScript 扩展玩法。附带推箱子、管道连接和 QUACK!!! on ICE 三个示例。

**Godot 标准版 · Compatibility 渲染器**。项目声明使用 Godot 4.7，文档记录的测试版本为 4.7.2。

![移动、推动、下落、撤销和重做](docs/media/gameplay.gif)

## 快速开始

1. 在 Godot 中导入 `project.godot`，打开顶部的 **Grid Levels**。若未显示，在 **项目 → 项目设置 → 插件** 中启用 **Grid Game Groundwork**。
2. 点击 **Open…**，打开 `examples/levels/sokoban.tres`、`pipes.tres` 或 `quack.tres`。
3. 在左侧选择实体。按 **1 / 2 / 3** 切换绘制、擦除、选择；拖动选中实体的轴或平面手柄可按格移动，单选时按 **End** 向下贴地。
4. 点击 **Save** 保存，再点击 **Playtest ▶** 试玩；**Stop ■** 返回编辑。试玩不会改变设计好的关卡，未保存的编辑仍需保存。

直接运行项目可玩推箱子；打开 `examples/pipes.tscn` 或 `examples/quack.tscn` 后运行当前场景可玩其他示例。推箱子开局按两次 **S**，可将箱子推落到下层平台。

![关卡绘制、选择、移动、贴地和撤销](docs/media/authoring.gif)

## 功能一览

| 类别 | 已包含功能 |
| --- | --- |
| 关卡编辑 | 新建、打开、保存、另存为 `.tres`；记住上次保存的关卡；未保存提示；校验；隔离试玩及停止。 |
| 绘制 | 拖动绘制／擦除、表面吸附、自动堆叠、高度平面、画笔旋转／镜像、右键吸管、矩形地面填充。 |
| 选择与移动 | Shift 多选；XYZ 轴及 XY/XZ/YZ 平面手柄；整格吸附；单选 End 贴地；整组复制／删除；非法位置反馈与取消。 |
| 实体配置 | 可复用定义；新建／导入／保存资源；Inspector 默认值；单实体类型化属性覆盖；可视化三维占格编辑；自定义模型场景。 |
| 视图 | 模型表面蓝色选择／红色擦除反馈；考虑遮挡与透明度的拾取；环绕、平移、缩放、取景；自由飞行及速度调节。 |
| 关卡工具 | 标题、重力、掉落边界和规则资源；整关旋转／镜像；编辑撤销与重做。 |
| 玩法 | XZ 四向移动、多格形状、显式地面、刚性悬挑、堆叠、重力、掉出关卡及连锁推动；推动权限与力量／重量规则预设。 |
| 历史与输入 | 完整动作撤销／重做、可撤销的重开、胜负后回退、点击切换角色、分阶段动画及快速输入缓冲。 |
| 扩展与导出 | 自定义移动、交互、障碍、胜利条件和外观；完成／失败信号；Linux 与单线程 Web 导出预设。 |

各项编辑功能及限制见 [用户指南](docs/designer-guide.zh-CN.md)，编程接口见 [扩展指南](docs/extending.md)。

## 常用操作

| 场景 | 操作 |
| --- | --- |
| 编辑 | **1 / 2 / 3**：绘制／擦除／选择 · **Shift+点击**：增减选择 · **End**：单实体向下贴地 · **Esc**：取消移动 |
| 编辑摄像机 | **WASD**：飞行 · **Q/E**：下降／上升 · 右键拖动：转向 · 右键+滚轮：速度 · **Page Up/Down**：放置高度 |
| 编辑历史 | **Ctrl/Cmd+S**：保存 · **Ctrl/Cmd+Z**：撤销 · **Ctrl/Cmd+Shift+Z** 或 **Ctrl/Cmd+Y**：重做 |
| 游玩 | **WASD／方向键**：移动 · 点击：选角色 · **Z / Y / R**：撤销／重做／重开 |
| 编辑与游玩摄像机 | 中键拖动：环绕 · **Shift+中键拖动**：平移 · 滚轮：缩放 · **F**：完整取景 |

先点击视口或游戏窗口获取焦点。编辑快捷键不会干扰文本或属性输入。形状编辑和导航细节见 [完整操作表](docs/designer-guide.zh-CN.md#操作速查)。

## 示例

| 示例 | 玩法 |
| --- | --- |
| [推箱子](examples/sokoban.tscn) | 将普通箱子和 L 形箱子推到全部目标上；支持连推、高低平台与下落回退。 |
| [管道连接](examples/pipes.tscn) | 推动直管和弯管，通过方向匹配的端口把全部终点接到源头；连通管道会亮起。 |
| [QUACK!!! on ICE](examples/quack.tscn) | 点击切换三只鸭子，滑行吃面包、从上层落到下层，利用吃饱的鸭子挡停其他鸭子。[完整规则与七步解法](docs/quack-example.md)。 |

![QUACK!!! on ICE：双层平台上的三只鸭子](docs/media/quack.png)

## 用于自己的项目

将 `addons/grid_game_groundwork/` 复制到项目的 `addons/` 中并启用插件。给 `Node3D` 挂上 `addons/grid_game_groundwork/runtime/game.gd`，指定 **Level** 后运行场景。示例规则、模型和素材单独存放在 `examples/`；复用示例内容时需一并复制所引用的依赖。

插件面向独立关卡。战役菜单、解锁、持久进度、游戏内关卡编辑器、社区分享及 Unity 关卡导入不在当前范围内。

## 文档

- [中文用户指南](docs/designer-guide.zh-CN.md) · [English designer guide](docs/designer-guide.md)
- [扩展指南](docs/extending.md)：规则、外观与运行时接入。
- [开发说明](docs/development.md)：检查、导出与示例重新生成。
- [编辑器模型表面支持](docs/editor-surface-coverage.md)：自定义材质支持与限制。
- [领域术语](CONTEXT.md) · [设计决策](docs/adr/)

灵感来自 Corey Martin 的 [Grid Game Groundwork for Unity](https://github.com/corey-martin/grid-game-groundwork)。QUACK 基于 [QUACK!!! on ICE 原作](https://akacmd.itch.io/quack-on-ice)（[源码](https://github.com/AkaCMD/Bevy_Jam_4)）。参见 [第三方声明](THIRD_PARTY_NOTICES.md)。
