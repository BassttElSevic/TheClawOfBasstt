# TheClawOfBasstt - Parrot Minidrone 视觉巡线

这是一个 MathWorks Parrot Minidrone 竞赛 Simulink 工程。无人机在固定的 4 m x 4 m 场地内，使用摄像头识别地面红色折线，并在终点圆盘上方对准后降落。

## 适用范围

控制器是视觉闭环，不按预先记录的航点导航：

- `competitionScene.m` 从工程根目录的 `initData.mat` 创建线段和终点圆盘。
- `createMask` 提取红色像素；`LineFeatures` 用质心和 PCA 主轴计算图像误差、线方向和形状指标。
- `pathStateMachine` 根据这些视觉量和估计位置生成位置参考。
- `trackWPs/trackNSeg` 由 `loadTrackForController.m` 生成，当前仅保留为地图元数据/兼容接口，`pathStateMachine` 不读取它们，因此不存在按单张地图写死航点的路径。

这意味着同一场地内的不同折线地图可以复用同一个控制器，但不能据此保证任意尺寸、颜色、断线或视场条件下都能成功飞行。

## 控制逻辑（当前分支）

状态机位于 `MinidroneCompetition/controller/flightControlSystem.slx` 的 `Control System/Path Planning/pathStateMachine`：

`0 起飞 -> 1 悬停收敛 -> 2 可信巡线 -> 3 终点盘降落 -> 4 完成`

针对“拐弯时继续向前冲出红线”的修改增加了两个状态：

- `5 CORNER_GUARD`：检测到 PCA 形状突变、面积突变或方向突变时，冻结 XY 前向参考，保存实际位置，并等待新方向连续确认。
- `6 ANCHOR_SEARCH`：确认拐角后从锚点开始逐渐扩大的螺旋搜索；拒绝过早的旧方向重捕获，超时后才允许同方向恢复。

巡线、拐角保护和搜索都使用视觉方向，不使用地图坐标。位置参考仍限制在 `[0.1, 3.9]` m，给场地边界留出余量。

## 不同地图的必要条件

用 `drone_track_builder.mlapp` 绘图时请遵守以下约束：

1. 至少设置两个按飞行顺序排列的航点，线段必须首尾相接；推荐不超过 20 段。工具和场景坐标范围是 `0 <= X,Y <= 4` m。
2. 赛道颜色必须保持纯红或接近纯红，建议颜色码使用 `#FF0000`。当前掩膜固定为 `R >= 120, G <= 131, B <= 112`，把颜色改成紫色、蓝色等会导致“看不见线”。
3. 终点圆盘必须由最后一段生成并保持在相机可见范围内。工具默认圆盘直径为 0.2 m；控制器依靠圆盘的面积和圆度判定终点，不读取圆盘坐标。
4. 首段起点应位于无人机初始位置附近，并在起飞后的相机视场内。相机水平视场约 38°、朝向固定；转角过大或线段过短时可能先丢线。
5. 相邻线段之间不要留空隙，也不要使用过密的小折线。拐角保护会冻结参考并从锚点搜索，但搜索半径上限约 0.75 m，不能替代任意距离的断线恢复。
6. 线宽由场景固定为 0.1 m；地图应保证在约 0.45-0.50 m 的视觉高度上仍能产生足够的红色像素。过细、过短、严重遮挡或光照改变都可能低于检测阈值 800 像素。

场景的地板和围墙仍固定为 4 m x 4 m 竞赛场地；超出该边界的地图不在当前工程的支持范围内。

## 换图运行

1. 使用 MATLAB R2026a 打开项目：

   ```matlab
   openProject('MinidroneCompetition/MinidroneCompetition.prj')
   startVars
   ```

2. 打开 `MinidroneCompetition/utilities/drone_track_builder.mlapp`（或运行 `openTrackBuilder`）。按顺序绘制航点，颜色保持 `#FF0000`，确认终点圆盘标记可见。
3. 点击 **Update Virtual World**，把新的 `initData.mat` 保存到工程根目录。该文件包含 `Lines`、`Circle`、`Color` 和 `posNED` 字段。
4. 重新运行 `startVars`，再运行 `MinidroneCompetition/mainModels/parrotMinidroneCompetition.slx`。不要只修改表格后直接继续旧的仿真，否则场景和初始位置可能仍使用旧数据。

个人地图属于运行数据；提交代码时不要把个人 `initData.mat` 当作控制器逻辑的一部分覆盖到分支中。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `MinidroneCompetition/mainModels/parrotMinidroneCompetition.slx` | 主模型 |
| `MinidroneCompetition/controller/flightControlSystem.slx` | 飞控和视觉巡线状态机 |
| `MinidroneCompetition/support/competitionScene.m` | 4 m x 4 m 场景及地图绘制 |
| `MinidroneCompetition/utilities/drone_track_builder.mlapp` | 航点/终点圆盘绘制工具 |
| `MinidroneCompetition/utilities/loadTrackForController.m` | 从 `initData.mat` 生成兼容地图元数据 |
| `MinidroneCompetition/libraries/dynamicsLibrary.slx` | 无人机动力学库 |
| `MinidroneCompetition/libraries/environmentLibrary.slx` | 环境库 |

## 验证状态

在本分支使用 MATLAB R2026a 完成了控制器静态检查、Stateflow lint、模型结构检查和合成视觉输入行为测试：正常巡线、拐角保护、新方向确认、搜索超时和新方向重捕获均覆盖。两个动力学/环境库也可加载。

完整主模型仿真尚未宣称通过：当前 R2026a 环境缺少 `parrotlib`、`asbBusHeaderFile` 和 Simulink Support Package for Parrot Minidrones，因此无法完成依赖硬件支持包的端到端验证。这里的验证结论是“控制器逻辑和地图数据流满足上述约束”，不是“所有地图和真实硬件均已验证”。

## 开发约束

- 修改 `pathStateMachine` 时，更新 Stateflow MATLAB Function 的 `Script` 后保存模型；不要在图形界面中留下未记录的手工改动。
- 不增加航点导航或单地图坐标特判；需要地图适配时优先改视觉检测和状态机证据链。
- `createMask`、`LineFeatures` 是用户编写的视觉处理逻辑，修改阈值前应保留固定输入的 A/B 证据。
- 不要把低空光流门控改回置零旁路；这会冻结位置估计并破坏降落阶段的参考跟踪。

## License

MIT，见 [LICENSE](LICENSE)。
