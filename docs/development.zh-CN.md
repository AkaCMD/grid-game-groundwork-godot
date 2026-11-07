# 开发说明

[English](development.md) | **简体中文** · [README](../README.zh-CN.md)

在仓库根目录运行命令。使用 Godot 标准版和 [project.godot](../project.godot) 配置的 Compatibility 渲染器。以下检查于 2026-10-25 在 Godot 4.7.2（`ed1daf0bf`）上通过。

## 检查

```sh
python3 tools/check.py --godot /path/to/godot
python3 tools/check.py --godot /path/to/godot --editor-smoke
```

[运行器](../tools/check.py)导入并检查脚本类型，随后检查玩法、编辑与保存／加载、选择、笔画、QUACK、运行时、通用模型和翻滚方块示例。`--editor-smoke` 还会在临时项目中检查编辑流程。可执行文件依次取自 `--godot`、`GODOT` 环境变量或 PATH 中的 `godot`。Windows 下使用 `python`；输出编码错误时，设置 `PYTHONUTF8=1`。

截取编辑器画面并检查表面渲染时，需要图形显示环境：

```sh
python3 tools/check.py --godot /path/to/godot --editor-smoke --screenshot artifacts/editor.png
```

无头检查无法验证高亮像素或 shader 覆盖，详见[模型表面支持](editor-surface-coverage.zh-CN.md)。

Paint 专项输入检查使用 [tools/check_editor_input.py](../tools/check_editor_input.py)，通过 `--help` 查看参数。图形输入检查会移动系统光标，需串行运行，期间请勿操作鼠标、键盘或切换焦点。`INPUT_SETUP` 表示环境准备失败。[tests/test_editor_input_runner.py](../tests/test_editor_input_runner.py) 可检查原生窗口运行器，无需原生输入。

## 导出

安装与 Godot 版本匹配的导出模板，然后运行：

```sh
mkdir -p build/linux build/web
godot --headless --path . --export-release "Linux Desktop" build/linux/grid-game.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server --directory build/web 8000
```

在浏览器中打开 [localhost:8000](http://localhost:8000)。[Web 预设](../export_presets.cfg)使用单线程 Compatibility 渲染，需要通过 HTTP 访问。导出其他关卡前，先修改项目主场景。Windows／macOS 预设可在 Godot 导出对话框中添加。

## 重新生成示例

以下命令会覆盖示例资源：

```sh
godot --headless --path . --script tools/create_examples.gd
godot --headless --path . --script tools/create_quack.gd
godot --headless --path . --script tools/create_generality_examples.gd
```

[create_examples.gd](../tools/create_examples.gd) 重建推箱子。[create_quack.gd](../tools/create_quack.gd) 重建 QUACK。[create_generality_examples.gd](../tools/create_generality_examples.gd) 重建翻滚方块示例。随后重新运行检查。精灵图许可证见[第三方声明](../THIRD_PARTY_NOTICES.zh-CN.md#quack-on-ice-精灵图)。

## 移动时序

[GGGame](../addons/grid_game_groundwork/runtime/game.gd) 在动画期间最多缓冲四次新按下的方向输入。`step_duration`（默认 0.12 秒）和 `buffered_step_duration`（默认 0.06 秒）分别控制常速与快速输入动画。长按重复不会填满缓冲；撤销／重做／重开会清空缓冲，并等待当前动作结束后执行。
