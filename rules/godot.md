一、总体目标与原则

目标
可维护：脚本职责单一、模块边界清晰，便于修改和扩展。
可测试：核心逻辑可脱离场景运行，便于单元测试（如 GUT）。
可复用：通过信号、接口、依赖注入降低耦合，重用组件。
可观测：日志、断言、调试面板，便于排错和性能分析。

架构原则
场景树即组合：优先用节点组合与信号解耦，少用深继承。
脚本轻 UI、重数据：把纯逻辑从节点移至纯脚本或 Autoload 单例管理。
数据驱动：资源（.tres/.res）、JSON、Scriptable Data（Godot 资源）驱动行为。
明确边界：按层分离 输入/表现/领域/基础设施。
依赖倒置：高层（规则）不依赖低层（实现），用接口或信号对接。

---

二、文件夹结构

项目根目录采用以下标准结构：

```
res://
├── addons/                 # 第三方插件（由 Godot 资产管理器管理）
├── assets/                 # 原始美术资源
│   ├── textures/           # 贴图
│   ├── audio/              # 音频
│   └── fonts/              # 字体
├── autoload/               # 全局单例 / Manager 脚本
├── scenes/                 # 场景文件（.tscn）
│   ├── ui/                 # UI 场景（菜单、HUD、弹窗）
│   │   ├── components/     # 可复用的 UI 组件（按钮、进度条、面板）
│   │   └── screens/        # 全屏 UI（主菜单、设置、结算画面）
│   ├── levels/             # 关卡场景
│   ├── actors/             # 角色/实体场景（玩家、敌人、NPC）
│   ├── props/              # 道具/可交互物体场景
│   └── effects/            # 视觉特效场景（粒子、动画序列）
├── scripts/                # 独立 GDScript 脚本（不依附 .tscn 的纯脚本）
│   ├── components/         # 可复用组件脚本（生命值、拾取、移动等）
│   ├── systems/            # 系统逻辑脚本（生成器、回合管理、评分等）
│   ├── data/               # 数据定义脚本（枚举、常量、DataClass）
│   └── interfaces/         # 接口/抽象基类脚本
├── resources/              # Godot 资源文件
│   ├── materials/          # 材质资源
│   ├── shaders/            # 着色器（.gdshader）
│   ├── themes/             # UI 主题资源（.theme）
│   ├── data/               # 数据资源（武器数据、角色属性、关卡配置）
│   ├── curves/             # Curve 资源
│   └── animations/         # AnimationLibrary 资源
├── project.godot           # 项目配置文件
├── README.md               # 项目说明文档
└── icon.svg                # 项目图标
```

关键约定：
- 所有场景文件统一在 `scenes/` 下管理，避免散落在根目录。
- 所有脚本存放于 `scripts/`，不在 `scenes/` 内混置脚本文件。
- `tests/` 目录结构与源码结构镜像对应，便于定位测试文件。

---

三、命名规范

3.1 PascalCase（大驼峰）
适用于：类名、节点名（推荐）、文件名、场景名、资源名。

- 文件：`PlayerController.gd`、`HealthBar.tscn`、`SwordData.tres`
- 类名：`class_name PlayerController`
- 场景根节点名：`Player`、`MainMenu`
- 资源：`SwordData`、`FireMaterial`

3.2 snake_case（小写下划线）
适用于：信号名、方法名、变量名、常量枚举 key。

- 方法：`func take_damage(amount: float) -> void:`
- 变量：`var max_health: float`
- 信号：`signal health_changed(new_health: float)`
- 常量：`const MAX_SPEED: float = 400.0`

3.3 前缀约定
| 前缀 | 适用 | 示例 |
|------|------|------|
| 无前缀 | 公共成员/方法 | `var health: float` |
| `_` 前缀 | 私有成员/方法（@onready 变量） | `@onready var _animation_player: AnimationPlayer` |
| `_` 前缀 | 虚方法回调（`_ready()`、`_process()`） | `func _ready() -> void:` |
| `on_` 前缀 | 信号回调处理函数 | `func _on_health_changed(new_health: float):` |
| `is_` / `has_` / `can_` | 布尔变量/方法 | `var is_dead: bool`、`func can_jump():` |

3.4 枚举命名
```gdscript
enum PlayerState { IDLE, RUN, JUMP, ATTACK }   # 枚举 key 用全大写
var state: PlayerState = PlayerState.IDLE
```

3.5 组（Groups）命名
使用 snake_case 命名组，避免与类名冲突：
```gdscript
group "enemy"       # ✅
group "pickup"      # ✅
group "EnemyGroup"  # ❌ 禁止 PascalCase
```

---

四、代码风格

4.1 类型注解（强制）
所有变量、参数、返回值必须显式声明类型。
```gdscript
# ✅ 正确
var health: float = 100.0
func apply_damage(amount: float) -> void:
    pass

# ❌ 错误（缺少类型）
var health = 100.0
func apply_damage(amount):
    pass
```

4.2 可选成员与空安全
使用 `@export` 控制暴露到编辑器的变量，为可能为空的引用提供默认值。
```gdscript
@export var attack_cooldown: float = 0.5
@export var target: NodePath          # 编辑器赋值，可为空检查
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
```

4.3 信号声明
信号必须带类型参数，保持 `past_tense` 语义（表示"已发生的事件"）。
```gdscript
signal health_changed(new_health: float, old_health: float)
signal item_collected(item_id: StringName)
signal player_died()
```

4.4 安全调用与静态函数
```gdscript
# 全局单例引用前加 @onready 或校验
@onready var _event_bus: EventBus = get_node("/root/EventBus")

# 静态函数优先用于纯工具方法
static func clamp_angle(angle: float) -> float:
    return fmod(angle + PI, TAU) - PI
```

4.5 类文档注释（强制）
每个 `class_name` 脚本顶部必须写文档注释。
```gdscript
## HealthComponent 管理实体的生命值、伤害、死亡。
## 支持最大生命值、临时护盾、无敌帧。
class_name HealthComponent
extends Node
```

---

五、场景与节点结构规范

5.1 节点树结构
```
Player (CharacterBody2D)       # 根节点 = 场景名，PascalCase
├── CollisionShape2D            # 碰撞体
├── AnimatedSprite2D            # 表现层
├── AnimationPlayer             # 动画控制
├── AudioStreamPlayer2D         # 音效
├── HealthComponent             # 组件化逻辑
├── HurtboxComponent            # 受击判定
└── HitboxComponent             # 攻击判定
```

5.2 场景与脚本一对多关系
场景的根节点脚本只负责协调子组件，不上万行代码。
复杂逻辑拆分为独立 Component 脚本，通过 `@export` 挂载到子节点。
```gdscript
# Player.gd —— 根脚本，只做协调
class_name Player
extends CharacterBody2D

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    _health.health_depleted.connect(_on_health_depleted)
    _hurtbox.hurt.connect(_on_hurt)

func _on_hurt(amount: float) -> void:
    _health.take_damage(amount)

func _on_health_depleted() -> void:
    _anim_player.play("die")
```

5.3 组件化原则
- 每个 Component 脚本只做一件事（单一职责）。
- Component 之间通过父节点转发或 EventBus 信号通信，不直接依赖彼此。
- Component 使用 `class_name` 暴露为可挂载组件。

---

六、Autoload 管理规范

6.1 Autoload 分类
| 类型 | 示例 | 职责 |
|------|------|------|
| EventBus | `EventBus` | 全局信号总线，解耦跨模块事件 |
| 系统管理器 | `GameManager`, `AudioManager`, `SaveManager` | 管理单一子系统 |
| 数据容器 | `GameState`, `Settings` | 运行时全局状态/配置 |

6.2 Autoload 加载顺序
在 `project.godot` 中按依赖关系排序（`autoload/` 列表从上到下顺序加载）：
1. `EventBus`（最先加载，无依赖）
2. `GameSettings`（依赖最小）
3. `SaveManager`
4. `AudioManager`
5. `GameManager`

6.3 Autoload 访问规范
```gdscript

# ✅ 直接使用全局类名（需 class_name 声明）
# AudioManager.play_sfx("hit")

# ❌ 避免：大量使用硬编码字符串路径
# get_node("/root/AudioManager").play_sfx("hit")   # 不推荐，分散使用
```

---

七、资源管理规范

7.1 数据资源（Data Resource）
所有静态数据（武器属性、角色参数、关卡配置）定义为自定义 Resource 类。
```gdscript
## SwordData 定义剑类武器的配置参数
class_name SwordData
extends Resource

@export var display_name: String = "铁剑"
@export var attack_power: float = 10.0
@export var attack_speed: float = 1.0
@export var icon: Texture2D
@export var hit_effect: PackedScene
```

7.2 资源加载
```gdscript
# ✅ preload 用于频繁使用的资源（编译时加载）
const SWORD_DATA: SwordData = preload("res://resources/data/sword_iron.tres")

# ✅ load 用于运行时动态加载
var data := load("res://resources/data/level_%d.tres" % level_id) as LevelData

# ❌ 禁止在 _process() 中 load/preload
```

7.3 路径常量
在 `scripts/data/` 下集中管理资源路径常量，避免硬编码散布各处。
```gdscript
## ResPath 集中定义项目资源路径
class_name ResPath
extends RefCounted

const SCENES := {
    MAIN_MENU = "res://scenes/ui/screens/main_menu.tscn",
    GAME_WORLD = "res://scenes/levels/game_world.tscn",
}

const DATA := {
    SWORD_IRON = "res://resources/data/sword_iron.tres",
    LEVEL_001  = "res://resources/data/level_001.tres",
}
```

---

八、日志与调试规范

8.1 日志规范
```gdscript
# 使用 Godot 内置日志，禁止用 print() 裸写
func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    print_debug("HealthComponent: took %f damage, remaining %f" % [amount, health])  # 仅 Debug 构建输出

    if health <= 0.0:
        push_warning("HealthComponent: health depleted for %s" % owner.name)         # 警告
```

8.2 断言
```gdscript
func apply_damage(amount: float) -> void:
    assert(amount >= 0.0, "Damage amount must be non-negative, got %f" % amount)
    # ...
```

8.3 条件断点辅助
```gdscript
if OS.is_debug_build():
    # 仅在 Debug 构建执行的逻辑、调试绘制等
    pass
```

---

九、测试规范

- 使用 GUT 作为测试框架。
- 纯逻辑脚本（`scripts/systems/`、`scripts/data/`）必须有单元测试。
- 涉及场景实例化的放在集成测试。
- 测试文件命名：`test_<被测文件名>.gd`，如 `test_health_component.gd`。
- CI 流程中必须运行 `gut -gdir=res://tests`。

---

十、版本控制规范（Git）

- `.godot/` 目录加入 `.gitignore`（Godot 自动生成）。
- 所有 `.import` 文件**需要**提交（Godot 4.x 的确定性导入）。
- `addons/` 目录提交到仓库（锁定插件版本）。
- 二进制资源（.png, .ogg, .glb）使用 Git LFS 管理（如项目较大）。

`.gitignore` 模板：
```
.godot/
export/
*.translation
```

---

十一、文件头模板

每个新脚本文件应包含如下文件头注释：
```gdscript
## [简短描述脚本职责]
##
## 详细说明（可选）：
## - 所属模块
## - 关键信号和依赖
## - 使用示例
extends Node
```

