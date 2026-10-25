# 编辑器模型表面支持

[English](editor-surface-coverage.md) | **简体中文** · [README](../README.zh-CN.md) · [用户指南](designer-guide.zh-CN.md#高亮与拾取)

Select 和 Erase 通过[模型三角面拾取](../addons/grid_game_groundwork/editor/entity_surfaces.gd)查找可见表面，透明像素可露出后方几何体。高亮使用附加表面，不修改设计材质或运行时选择钩子。

`StandardMaterial3D` 拾取在 CPU 上以最近邻或双线性方式采样基础层级 alpha。拾取与高亮遵循 UV 缩放／偏移、重复模式、基础 alpha、剔除和 alpha scissor。

`ShaderMaterial` 高亮派生自源 shader，保留 uniform、采样提示、顶点阶段、include 和 alpha／discard 逻辑。Alpha scissor 在反馈强度生效前执行。源材质与实例 uniform 每帧同步，反馈参数避开已有名称。

Shader 拾取依据最终渲染覆盖，因此 QUACK 白底在精灵图透明处仍不透明。Alpha／discard 和依赖预处理的剔除需要图形渲染器及同步 GPU 回读。没有 alpha／discard 和预处理的 shader 使用不透明几何拾取，覆盖结果不会跨次缓存。

依赖场景的屏幕／深度纹理、视口坐标、顶点位移后的拾取几何、条件化片段入口和自定义混合方程，需要专门集成。隔离探测无法复现场景缓冲。标准材质 CPU 拾取不计算 mip 层级导数。这些限制不改变逻辑占格或玩法。

使用图形渲染器运行[表面测试](../tests/test_editor_surfaces.gd)，检查覆盖与像素。[编辑器测试框架](../tests/editor_harness/plugin.gd)检查 Select／Erase 和移动。命令见[开发检查](development.zh-CN.md#检查)。
