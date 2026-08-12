# TheClawOfBasstt — Parrot Minidrone 竞赛无人机（视觉巡线）

MathWorks Parrot Minidrone 竞赛 Simulink 工程。四旋翼在 4m×4m 场地内，沿用户自绘红色赛道（折线 + 终点圆）飞行，降落到终点圆。

## 项目说明

- 赛道不固定：用户用 `MinidroneCompetition/utilities/drone_track_builder.mlapp` 手绘红线，存 `initData.mat`，重新仿真即可。飞机自适应任意赛道，不做单图硬编码。
- 纯视觉导航：控制回路无航点、无赛道坐标。摄像头识别红线，光流 + IMU 估算位置，视觉判定终点圆。
- 面向硬件部署：最终运行在真实 Parrot Minidrone（仅摄像头、光流、IMU），控制逻辑不依赖地图坐标。

## 当前状态（2026-08-12，v5.5）

状态机：`起飞 → 悬停收敛 → 视觉巡线 → 终点盘对准 → 降落完成`。

- 相机水平视场约 38°，固定朝世界 +X，不随机头转。拐角转角超过视场时必然丢线。
- 丢线后螺旋轨道搜索：围绕丢线点（估计位置）渐扩螺旋（半径 0.35→0.90m），扫过拐角区域找回延续线。
- v5.5 修复：
  - 拐角飞出去：拐角双线同框时掩膜特征失真，原逻辑不减速、方向记忆不更新，导致冲过拐角后丢线、螺旋圆心偏离。改为拐角缓爬、方向记忆加入"新线夹角大则更新"、终点盘判定加居中校验。
  - 直线摇晃：5Hz 视觉更新与位置环滞后的欠阻尼摆动，加横向微分阻尼，实测摆动降约 10 倍（真值 Y std 0.022→0.004m）。
- 验证（2026-08-12 新图：3 段折线，拐角 +23.8°/−69.7°，终点盘贴近右边界）：两轮 60s 3D 仿真一致通过，落盘距盘心 1.6cm（盘半径 10cm），未越界，最大水平速度 0.368m/s。

## 目录结构

| 路径 | 说明 |
|---|---|
| `MinidroneCompetition/mainModels/parrotMinidroneCompetition.slx` | 主模型 |
| `MinidroneCompetition/controller/flightControlSystem.slx` | 飞控；核心在 `Control System/Path Planning/pathStateMachine`（Stateflow） |
| `MinidroneCompetition/support/competitionScene.m` | 3D 场景（红线/终点圆，数据来自 initData.mat） |
| `MinidroneCompetition/utilities/drone_track_builder.mlapp` | 赛道绘制工具 |
| `MinidroneCompetition/initData.mat` | 当前赛道数据（用户绘制，不入库） |

## 运行

环境：MATLAB R2026a，Simulink/Stateflow/Simulink 3D Animation；3D 引擎用自带 VehicleSimulation（场景配置已指向，勿改）。

1. `openProject('MinidroneCompetition/MinidroneCompetition.prj')`
2. `startVars`
3. 运行 `MinidroneCompetition/mainModels/parrotMinidroneCompetition.slx`，在 3D 场景中观察
4. 换赛道：`drone_track_builder.mlapp` 画图 → Save Waypoints → Update Virtual World → 重新仿真

## 开发约束

- 修改 `pathStateMachine`：用脚本替换 `Stateflow.EMChart` 的 `Script` 字段后 `save_system`，勿在界面手工修改。
- 写死数值必须有实测/推导依据，commit 注明来源。例：`createMask` 红阈值 120 来自 3D 实测渲染色 RGB≈[137,0,3]。
- 禁止航点/地图坐标导航、禁止单图硬编码。`trackWPs` 仅用于场景与估计器初值。
- `createMask`/`LineFeatures` 为用户编写，改动前需用户同意。
- 低空光流门控关闭时，速度估计旁路原始光流测量。置零会导致位置估计冻结、积分偏置、落地跑飞，勿改回。
- 不提交 `initData.mat`。

## License

MIT，见 [LICENSE](LICENSE)。