# Godot 技术设计

## 1. 技术基线

| 项目 | 选择 |
|---|---|
| 引擎 | Godot 4.x 当前稳定版，立项时锁定小版本 |
| 脚本 | MVP 使用强类型 GDScript；性能热点确认后再评估 C#、GDExtension 或 Server API |
| 渲染 | 3D Forward+（目标 PC）；低配模式再评估 Mobile 渲染器 |
| 物理 | Godot Physics 3D，固定物理帧 60 Hz 起测 |
| 导航 | `NavigationServer3D` / `NavigationAgent3D` + 导航层 + 模块化导航块 |
| 数据 | 自定义 `Resource`（`.tres`）作为物种、技能、关卡、生态区配置 |
| 存档 | `ConfigFile` 或 JSON 保存轻量进度；复杂运行快照使用版本化 Resource/二进制 |
| 版本控制 | Git，文本场景 `.tscn`、文本资源 `.tres`，提交导入元数据约定统一 |

Godot 官方建议让场景保持单一职责、低耦合，并由拥有者管理外部关系；自定义 Resource 可直接序列化、在 Inspector 编辑且适合版本控制。因此本项目采用“场景负责行为组合，Resource 负责数据”的结构。

### 1.1 当前可玩版移动 UI 基线（V1.16）

- 逻辑设计尺寸为 1280×720，使用 `canvas_items + expand` 兼容 16:9、超宽手机和 4:3 平板横屏。
- Android/iOS 通过 `DisplayServer.get_display_safe_area()` 把物理安全区域换算为 Godot 逻辑边距；首页内容、HUD、弹窗和触控层共用同一套边距。
- 手机 Web 无法依赖原生方向锁定，因此竖屏时由最高层 `OrientationGuard` 拦截输入并通知主流程暂停生态模拟。
- 触控动作保持在右下两列，动态摇杆仍可在左侧下半区任意位置唤醒；普通可选控件至少 52 逻辑像素高，主要动作按钮保持 96–150 逻辑像素。
- 扣除安全区后，高度不超过 760 或宽度不超过 1120 逻辑像素时启用手机紧凑 HUD；更高的平板保持舒展布局，桌面继续使用原有信息密度。
- 紧凑 HUD 只压缩状态框、信息框、排行榜、战报和弹窗的留白，不缩小生命、耐力、饱腹、经验的数值字号，也不缩小 96–150 逻辑像素的主要触控按钮。
- 紧凑模式隐藏非关键的世界种子，并限制弹窗最多占安全区域的 94% 宽、92% 高；教学与物种攻略仍位于触控区域上方。
- 安全区域每 0.45 秒复核一次，以覆盖不改变视口尺寸的 180 度横屏翻转，同时也监听视口尺寸变化。

## 2. 推荐项目目录

```text
res://
├── autoload/
│   ├── save_service.gd
│   ├── data_registry.gd
│   └── audio_service.gd
├── core/
│   ├── events/
│   ├── state_machine/
│   ├── utilities/
│   └── debug/
├── actors/
│   ├── base/
│   ├── components/
│   ├── species/
│   └── visuals/
├── ai/
│   ├── consideration/
│   ├── actions/
│   ├── perception/
│   ├── groups/
│   └── simulation/
├── combat/
├── skills/
├── world/
│   ├── generation/
│   ├── chunks/
│   ├── biomes/
│   ├── navigation/
│   └── weather/
├── levels/
├── data/
│   ├── species/
│   ├── skills/
│   ├── behaviors/
│   ├── biomes/
│   └── levels/
├── ui/
├── audio/
├── vfx/
├── tests/
└── main/
```

不要为每个物种复制完整脚本目录。差异优先来自 Resource 配置、视觉场景和可复用技能组件。

## 3. 主场景和状态流

### 3.1 主场景

```text
Main (Node)
├── GameFlow (Node)
├── FrontendLayer (CanvasLayer)
├── WorldHost (Node3D)
│   └── [运行时实例化 LevelRuntime]
├── UILayer (CanvasLayer)
│   ├── HUD
│   ├── TutorialOverlay
│   ├── PauseMenu
│   └── ResultScreen
└── TransitionLayer (CanvasLayer)
```

`GameFlow` 是当前主场景拥有的协调者，不做全局 Autoload。它管理：

```text
Boot → MainMenu → LoadingLevel → Playing
Playing → PlayerDead → LoadingLevel
Playing → LevelComplete → LoadingLevel / CampaignComplete
Playing ↔ Paused
```

### 3.2 Autoload 边界

只把确实跨场景存续的服务设为 Autoload：

- `SaveService`：读取、迁移、写入玩家存档；
- `DataRegistry`：索引物种与关卡 Resource，不保存本局动态状态；
- `AudioService`：跨场景音乐与总线控制。

不要建立万能 `GameManager` 或全局事件总线承载所有逻辑。本局状态由 `LevelRuntime` 和 `RunState` 拥有，场景内通信优先使用直接注入、分组接口和信号。

## 4. 运行时关卡场景

```text
LevelRuntime (Node3D)
├── LevelCoordinator
├── GenerationRoot
│   ├── ChunkRoot
│   ├── NavigationRoot
│   └── DecorationRoot
├── RuntimeSystems
│   ├── PopulationRegistry
│   ├── AIScheduler
│   ├── SpatialIndex
│   ├── StimulusSystem
│   ├── GroupRegistry
│   ├── CorpseRegistry
│   ├── ResourceDirector
│   ├── HabitatPressureDirector
│   ├── TimeOfDaySystem
│   └── WeatherSystem
├── EntityRoot
├── CorpseRoot
├── EffectsRoot
├── PlayerCameraRig
└── WorldEnvironment
```

`LevelCoordinator` 在实例化时注入 `LevelData`、`RunState` 和各自独立的随机数流。系统之间通过窄接口通信，例如死亡由 Actor 发信号给 `PopulationRegistry`，Registry 更新人口后发出 `population_changed`，关卡协调者据此判断胜利。

## 5. Actor 场景

```text
Actor (CharacterBody3D)
├── VisualRoot (Node3D)
│   ├── Model
│   ├── AnimationTree
│   └── SpeciesVFX
├── CollisionShape3D
├── NavigationAgent3D
├── Components (Node)
│   ├── HealthComponent
│   ├── StaminaComponent
│   ├── HungerComponent
│   ├── LocomotionComponent
│   ├── CombatComponent
│   ├── SkillComponent
│   ├── PerceptionComponent
│   └── StatusEffectComponent
├── Brain (Node)
│   ├── Blackboard
│   ├── UtilityBrain
│   └── ActionStateMachine
├── InteractionArea3D
├── HurtboxArea3D
├── HitboxRoot
└── AudioRoot
```

玩家和 AI 使用同一个 `Actor` 场景。区别只在控制器：

- AI 由 `UtilityBrain` 向移动与技能组件提交意图；
- 玩家由 `PlayerController` 提交意图；
- 两者共用攻击冷却、耐力、碰撞、技能和伤害代码。

`CharacterBody3D` 负责可预测的角色移动，命中用短时启用的 `Area3D` 或形状查询。不要在动画回调里直接扣血；动画只通知攻击窗口，实际命中仍由战斗组件产生一次性 `DamageEvent`。

## 6. 数据驱动 Resource

### 6.1 SpeciesData

```gdscript
class_name SpeciesData
extends Resource

@export var id: StringName
@export var display_name: String
@export var actor_visual_scene: PackedScene
@export var body_size: int = 1
@export var locomotion_tags: Array[StringName]
@export var diet_tags: Array[StringName]
@export var habitat_tags: Array[StringName]

@export_group("Vitals")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var hunger_rate: float = 1.0
@export var armor: float = 0.0

@export_group("Movement")
@export var move_speed: float = 5.0
@export var sprint_multiplier: float = 1.5
@export var turn_speed: float = 8.0

@export_group("Combat")
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.0
@export var attack_range: float = 1.5
@export var base_attack: AttackData
@export var active_skill: SkillData
@export var passive_feature: PassiveData

@export_group("AI")
@export var behavior_profile: BehaviorProfile
@export var sense_profile: SenseProfile
```

### 6.2 LevelData

```gdscript
class_name LevelData
extends Resource

@export var id: StringName
@export var level_index: int
@export var map_extent: Vector2
@export var combatant_count: int
@export var allowed_biomes: Array[BiomeData]
@export var species_pool: Array[SpeciesData]
@export var species_type_range: Vector2i
@export var trophic_quotas: TrophicQuotaData
@export var generation_rules: MapGenerationRules
@export var time_rules: TimeOfDayData
@export var weather_pool: Array[WeatherData]
@export var pressure_rules: HabitatPressureData
@export var target_duration_seconds: Vector2
```

### 6.3 其他 Resource

- `SkillData`：冷却、耐力、距离、前后摇、效果列表、AI 评分曲线；
- `BehaviorProfile`：攻击性、勇气、贪食、耐心、群居、领地权重；
- `SenseProfile`：视距、视角、听距、嗅觉和各环境修正；
- `BiomeData`：模块池、资源表、视觉环境、允许物种标签；
- `ChunkData`：连接口、导航域、出生/资源槽、场景引用；
- `WorldModifierData`：威胁触发等级和属性/行为/资源修正；
- `RunState`：当前关、总死亡、当前威胁、已发现图鉴、本轮统计。

Resource 默认可能被多个实例共享。任何运行时会变化的状态都不得直接写回静态 `SpeciesData`；实例化 Actor 时复制所需数值到组件，或显式 `duplicate(true)` 运行时资源。

## 7. 地图生成管线

### 7.1 阶段

1. `SeedService` 派生布局、人口、天气、装饰等独立 RNG；
2. 纯数据生成生态区图；
3. 选择并摆放 Chunk 场景；
4. 主线程实例化 SceneTree 节点；
5. 连接/启用预烘焙导航区域和链接；
6. 生成资源与阵容数据；
7. 实例化个体，执行出生校验；
8. 等待至少一个物理帧让 NavigationServer 同步；
9. 运行最终可达性抽样，淡入关卡。

### 7.2 导航块

优先为地块场景预烘焙简化导航数据，再用对齐接口拼接 `NavigationRegion3D`。Godot 的导航更新通常在物理帧末同步，因此生成完成后不能同帧立即假定路径有效。

必须运行时烘焙时：

- 使用简单物理形状作为源，避免从复杂视觉 Mesh 解析；
- 按地块异步烘焙，不重烘整图；
- 主线程完成 SceneTree 几何解析，后台执行支持的烘焙阶段；
- 显示加载状态，不在正常战斗帧同步烘焙大区域。

### 7.3 飞行和水生

- 陆地与两栖主要使用 NavigationMesh 导航层；
- 深水使用独立的 3D 水域点图/体积航路，避免把陆地 NavMesh 强行复用；
- 飞行首版使用稀疏 `AStar3D` 航点 + 局部 steering，分巡航和低空战斗高度；
- `NavigationAgent3D` 的避障速度不是物理保证，最终移动仍通过角色碰撞和自己的防卡逻辑处理。

## 8. AI 调度实现

`AIScheduler` 统一分配思考预算：

- 注册 AI 后按实体 ID 分桶错峰；
- 每物理帧只更新到期的感知和效用决策；
- 战斗动作状态机可每物理帧推进，但高层决策 10–15 Hz 即可；
- 空间查询先从共享 `SpatialIndex` 获取候选，不做 100×100 全量配对；
- 远景 C 层不实例化所有高成本感知节点，使用区域人口模型推进；
- 进入近景时由快照恢复生命、饥饿、位置、目标摘要和群体关系。

建议初始预算：每帧最多 8 个完整视觉更新、4 个新路径请求、16 个效用重算。根据性能采样调整，不把数值散落在 Actor 脚本中。

## 9. 事件与信号

定义轻量值对象或字典结构：

- `DamageEvent`；
- `DeathEvent`；
- `SoundStimulus`；
- `FoodConsumedEvent`；
- `TargetSpottedEvent`；
- `PopulationChangedEvent`；
- `WeatherChangedEvent`。

跨大量实体的高频事件不使用“所有 Actor 连接一个全局信号”的广播风暴。声音、气味等写入共享空间系统，由附近订阅者按范围查询；低频状态变化才适合信号。

## 10. 人口与胜利判定

`PopulationRegistry` 是唯一人口真相源：

- Actor 完成生成后注册唯一 ID、物种、群组和移动域；
- `HealthComponent` 首次死亡时发出事件；
- Registry 立即把该实体标记死亡并递减存活数；
- 尸体与 Actor 生命周期分开，尸体保留不影响人口；
- 玩家死亡优先进入死亡流程；
- 玩家存活且总存活数为 1 时发出关卡胜利信号。

必须处理同一物理帧的相互击杀。如果玩家和最后一个 AI 同帧死亡，则玩家死亡、关卡不胜利；规则在伤害批次结算后统一判断。

## 11. 存档设计

### 11.1 保存内容

- 存档版本；
- 最高解锁关卡、已完成轮回次数；
- 图鉴发现与统计；
- 辅助选项、音画与输入设置；
- 当前战役：当前关卡、威胁等级、总死亡数、轮回种子；
- 不保存运行中每个 AI 的逐帧状态，退出战斗默认回到该关新世界。

### 11.2 安全写入

写入临时文件，校验完成后替换正式存档；保留一个上次成功版本。存档带 `schema_version`，每次字段变化提供迁移函数。调试构建允许导出可读 JSON，但正式版不依赖隐藏数值防作弊。

## 12. 确定性与回放

固定种子保证地图、阵容、天气和初始出生可复现，但 Godot 物理、浮点和线程时序不保证跨平台逐帧完全确定。结算中的“生态时间线”保存关键事件和少量位置采样，不做输入级确定性回放。

若未来开发每日排行榜，应校验规则与种子一致，而不要假设客户端模拟结果可完全复算。

## 13. 性能预算

目标：推荐 PC 1080p 60 FPS，第十关 100 战斗个体。

| 模块 | 16.67ms 帧预算建议 |
|---|---:|
| 渲染提交与 GPU | 7.0ms |
| 物理与角色移动 | 3.0ms |
| AI 感知/决策/路径 | 3.0ms |
| 游戏系统与脚本 | 2.0ms |
| UI、音频、余量 | 1.67ms |

这不是引擎保证值，而是性能审查目标。原型阶段从第一关开始持续记录，不等到第十关才优化。

### 13.1 优化顺序

1. 用 Profiler 找真实热点；
2. 降低 AI 更新频率并错峰；
3. 减少物理查询和导航重算；
4. 植被用 `MultiMeshInstance3D`、自动 LOD、可见范围和遮挡；
5. 尸体、特效、音源和临时命中区对象池化；
6. 远景 Actor 切简化模拟；
7. 仍不足时，把特定大批量对象改用低层 Server API 或 GDExtension。

不要一开始把所有对象改成 Server RID。节点结构更利于开发和调试，只有实测到数千高频实例等明确瓶颈时再下沉。

## 14. 多线程边界

适合后台线程：

- 纯数据区域图生成；
- 无 SceneTree 访问的阵容评分和快速生态模拟；
- 已准备好源数据后的支持型导航烘焙；
- 统计汇总和部分存档序列化准备。

必须谨慎或留在主线程：

- SceneTree 节点创建、删除和多数节点属性访问；
- 从场景节点解析导航源几何；
- 直接控制可视节点和物理节点；
- 共享数据无锁读写。

线程在加载期创建，退出时正确 `wait_to_finish()`；共享数据使用 Mutex，但优先通过不可变输入和结果队列避免锁争用。

## 15. 测试策略

### 15.1 单元/数据测试

- 伤害、耐力、饥饿和世界威胁公式；
- Resource ID 唯一、引用存在、范围合法；
- 每物种食性和生态标签完整；
- 每关人口配额能精确合计到目标个体数。

### 15.2 场景测试

- Actor 玩家/AI 控制器互换；
- 技能只命中一次并正确消耗；
- 同帧互杀规则；
- 尸体进食中断和腐败；
- 导航区域启停、洞口与水陆切换。

### 15.3 模拟测试

- 无玩家批量运行；
- 固定种子回归；
- 第十关 100 个体压力场景；
- 每种移动域出生和最终收束可达；
- 极端天气和最高威胁叠加。

## 16. 官方技术参考

- [Godot Resources：自定义数据资源与序列化](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
- [Godot 场景组织最佳实践](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)
- [NavigationServer 使用与同步](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationservers.html)
- [导航网格、运行时烘焙与分块](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html)
- [Godot 多线程与线程安全提示](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)
- [使用低层 Servers 优化大量对象](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)
- [使用 MultiMesh 优化大量重复实例](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
