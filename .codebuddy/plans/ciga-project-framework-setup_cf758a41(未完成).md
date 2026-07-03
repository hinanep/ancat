---
name: ciga-project-framework-setup
overview: 根据 godot.md 规范，搭建 ciga 项目的完整框架，包括文件夹结构、Autoload 基础工具（EventBus/SceneManager/AudioManager/SaveManager/GameState/GameSettings）、路径常量管理、以及可运行的基础 UI 场景（MainMenu + Level）。
todos:
  - id: create-dirs
    content: 创建完整文件夹结构（addons, assets, scenes, scripts, resources, audio, fonts, tests）
    status: pending
  - id: event-bus
    content: 实现 EventBus 全局事件总线（autoload/event_bus.gd）
    status: pending
    dependencies:
      - create-dirs
  - id: game-settings
    content: 实现 GameSettings 游戏设置管理（autoload/game_settings.gd）
    status: pending
    dependencies:
      - create-dirs
  - id: save-manager
    content: 实现 SaveManager 存档管理（autoload/save_manager.gd）
    status: pending
    dependencies:
      - game-settings
  - id: audio-manager
    content: 实现 AudioManager 音频管理（autoload/audio_manager.gd）
    status: pending
    dependencies:
      - game-settings
  - id: game-state
    content: 实现 GameState 全局游戏状态（autoload/game_state.gd）
    status: pending
    dependencies:
      - event-bus
      - save-manager
  - id: scene-manager
    content: 实现 SceneManager 场景切换管理（autoload/scene_manager.gd + .tscn）
    status: pending
    dependencies:
      - event-bus
      - game-state
  - id: res-path
    content: 实现 ResPath 资源路径常量（scripts/data/res_path.gd）
    status: pending
    dependencies:
      - create-dirs
  - id: main-menu
    content: 创建 MainMenu 主菜单场景（scenes/ui/screens/main_menu.tscn + .gd）
    status: pending
    dependencies:
      - scene-manager
      - res-path
  - id: game-world
    content: 创建 GameWorld 基础关卡场景（scenes/levels/game_world.tscn + .gd）
    status: pending
    dependencies:
      - scene-manager
      - res-path
  - id: configure-project
    content: 配置 project.godot Autoload 加载顺序，设置主场景为 MainMenu
    status: pending
    dependencies:
      - event-bus
      - game-settings
      - save-manager
      - audio-manager
      - game-state
      - scene-manager
---

## 产品概述

为 Godot 4.7 2D 项目搭建符合 `rules/godot.md` 规范的基础框架，包括完整的文件夹结构、Autoload 基础工具系统、资源路径管理，以及可运行的主菜单和基础关卡场景脚手架。

## 核心功能

- 按规范创建完整的项目文件夹结构（scripts、scenes、resources、assets 等）
- 实现 6 个 Autoload 基础工具：EventBus、GameSettings、SaveManager、AudioManager、GameState、SceneManager
- 实现资源路径常量管理（ResPath）
- 创建可运行的主菜单场景（MainMenu），包含开始/设置/退出按钮
- 创建基础 2D 关卡场景（GameWorld），包含摄像机、UI 层、场景切换集成
- 配置 project.godot 的 Autoload 加载顺序和主场景设置

## 技术栈

- 引擎：Godot 4.7
- 语言：GDScript
- 项目类型：2D

## 实现方案

### 整体策略

按照规范中的架构原则（组件化、数据驱动、信号解耦）搭建框架。Autoload 按依赖顺序加载，脚本与场景分离存放，所有代码严格遵循规范中的命名规范和代码风格（强制类型注解、snake_case 方法/变量、PascalCase 类名/文件名）。

### Autoload 设计

#### 加载顺序（在 project.godot 中配置）

1. **EventBus** — 无依赖，最先加载，继承 RefCounted，通过 class_name 全局访问
2. **GameSettings** — 继承 Node，管理音量/全屏等设置，持久化到 user://settings.tres
3. **SaveManager** — 继承 Node，使用 ConfigFile 实现存档读写
4. **AudioManager** — 继承 Node，含 AudioStreamPlayer（BGM）+ SFX 池，读取 GameSettings 音量
5. **GameState** — 继承 RefCounted，运行时全局状态，提供 reset() 方法
6. **SceneManager** — 继承 CanvasLayer，管理场景切换 + 淡入淡出过渡动画

#### EventBus 核心设计

```
## EventBus 全局事件总线，解耦跨模块事件通信
class_name EventBus
extends RefCounted

signal event_triggered(event_name: StringName, data: Dictionary)

static func emit(event_name: StringName, data: Dictionary = {}) -> void:
    var bus: EventBus = Engine.get_singleton("EventBus") as EventBus
    if bus:
        bus.event_triggered.emit(event_name, data)
```

为让 RefCounted 的信号能正常工作，EventBus 需同时在 Autoload 中注册一个 Node 子类实例（event_bus_node.tscn），信号通过该 Node 发射。

#### SceneManager 场景切换流程

淡出（ColorRect + AnimationPlayer）→ 卸载旧场景 → 加载新场景 → 添加到当前树 → 淡入

### 路径常量设计

在 `scripts/data/res_path.gd` 中定义：

```
class_name ResPath
extends RefCounted

const SCENES := {
    MAIN_MENU = "res://scenes/ui/screens/main_menu.tscn",
    GAME_WORLD = "res://scenes/levels/game_world.tscn",
}
```

### 基础场景设计

#### MainMenu 节点结构

```
MainMenu (Control) [主菜单根节点]
├── Background (ColorRect) [背景]
├── CenterContainer [居中布局]
│   └── VBoxContainer [按钮纵向排列]
│       ├── Label [标题]
│       ├── Button [开始游戏]
│       ├── Button [设置]
│       └── Button [退出]
└── main_menu.gd [脚本]
```

#### GameWorld 节点结构

```
GameWorld (Node2D) [关卡根节点]
├── WorldCamera (Camera2D) [摄像机]
├── CanvasLayer [UI层]
│   └── MarginContainer [HUD占位]
└── game_world.gd [脚本]
```

## 实现注意事项

- 所有变量/参数/返回值必须显式声明类型（规范 4.1）
- 信号必须带类型参数，使用 past_tense 语义（规范 4.3）
- 脚本存 scripts/，场景存 scenes/，不混置（规范二关键约定）
- Autoload 访问直接使用全局类名，避免硬编码路径（规范 6.3）
- 资源加载：频繁使用 preload，动态加载用 load，禁止在 _process() 中加载（规范 7.2）

## 架构设计

### 系统架构

- Autoload 层：EventBus → GameSettings → SaveManager → AudioManager → GameState → SceneManager
- 场景层：MainMenu ↔ SceneManager ↔ GameWorld
- 通信方式：跨模块通过 EventBus 信号，模块内通过直接调用或 @onready 引用

### 数据流

用户操作 → UI 脚本 → SceneManager/GameState → EventBus（通知其他模块）→ AudioManager/SaveManager 响应

## 目录结构

### 目录结构说明

本实现为 Godot 4.7 2D 项目搭建符合规范的基础框架。创建完整的文件夹结构、6 个 Autoload 工具脚本、资源路径管理脚本，以及 MainMenu 和 GameWorld 两个基础场景。

```
res://
├── addons/                                         # [目录] 第三方插件目录
├── assets/                                         # [目录] 原始美术资源
│   ├── textures/                                   # [目录] 贴图源文件
│   ├── audio/                                      # [目录] 音频源文件
│   └── fonts/                                      # [目录] 字体源文件
├── autoload/                                       # [目录] 全局单例脚本
│   ├── event_bus.gd                                # [NEW] 全局事件总线，继承 RefCounted，提供 event_triggered 信号和 emit() 静态方法
│   ├── game_settings.gd                            # [NEW] 游戏设置管理，继承 Node，管理音量/全屏，持久化到 user://settings.tres
│   ├── save_manager.gd                             # [NEW] 存档管理，继承 Node，使用 ConfigFile 读写 user://savegame.cfg
│   ├── audio_manager.gd                            # [NEW] 音频管理，继承 Node，BGM + SFX 池，读取 GameSettings 音量
│   ├── game_state.gd                               # [NEW] 全局游戏状态，继承 RefCounted，管理运行时状态，提供 reset()
│   ├── scene_manager.gd                            # [NEW] 场景切换管理，继承 CanvasLayer，淡入淡出过渡
│   └── scene_manager.tscn                          # [NEW] SceneManager 场景节点，含 ColorRect + AnimationPlayer 过渡组件
├── scenes/                                         # [目录] 场景文件
│   ├── ui/
│   │   ├── components/                             # [目录] 可复用 UI 组件
│   │   └── screens/                                # [目录] 全屏 UI 场景
│   │       ├── main_menu.tscn                      # [NEW] 主菜单场景，Control 根节点，含标题和按钮
│   │       ├── main_menu.gd                        # [NEW] 主菜单脚本，连接按钮到 SceneManager
│   │       ├── settings_menu.tscn                  # [NEW] 设置菜单场景（占位）
│   │       └── settings_menu.gd                    # [NEW] 设置菜单脚本（占位）
│   ├── levels/                                     # [目录] 关卡场景
│   │   ├── game_world.tscn                         # [NEW] 基础 2D 关卡场景，Node2D 根节点，含 Camera2D 和 UI 层
│   │   └── game_world.gd                           # [NEW] 基础关卡脚本，处理关卡基础逻辑
│   ├── actors/                                     # [目录] 角色/实体场景
│   ├── props/                                      # [目录] 道具场景
│   └── effects/                                    # [目录] 视觉特效场景
├── scripts/                                        # [目录] 独立 GDScript 脚本
│   ├── components/                                 # [目录] 可复用组件脚本
│   ├── systems/                                    # [目录] 系统逻辑脚本
│   ├── data/                                       # [目录] 数据定义脚本
│   │   └── res_path.gd                             # [NEW] 资源路径常量管理，集中定义场景/数据/音频路径
│   └── interfaces/                                 # [目录] 接口/抽象基类脚本
├── resources/                                      # [目录] Godot 资源文件
│   ├── materials/                                  # [目录] 材质资源
│   ├── shaders/                                    # [目录] 着色器
│   ├── themes/                                     # [目录] UI 主题
│   ├── data/                                       # [目录] 数据资源
│   ├── curves/                                     # [目录] Curve 资源
│   └── animations/                                 # [目录] AnimationLibrary 资源
├── audio/                                          # [目录] 最终音频资源
├── fonts/                                          # [目录] 字体资源
├── tests/                                          # [目录] 测试目录
│   ├── unit/                                       # [目录] 单元测试
│   └── integration/                                # [目录] 集成测试
└── project.godot                                    # [MODIFY] 配置 Autoload 加载顺序和主场景
```

## 关键代码结构

### EventBus

```
## EventBus 全局事件总线，解耦跨模块事件通信
## 使用 EventBus.emit("event_name", {"key": "value"}) 发射事件
## 使用 EventBus.event_triggered.connect(func) 监听事件
class_name EventBus
extends RefCounted

signal event_triggered(event_name: StringName, data: Dictionary)

static var _instance: EventBus

static func get_instance() -> EventBus:
    if not _instance:
        _instance = new()
    return _instance

static func emit(event_name: StringName, data: Dictionary = {}) -> void:
    get_instance().event_triggered.emit(event_name, data)
```

### SceneManager

```
## SceneManager 场景切换管理，支持淡入淡出过渡动画
## 使用 SceneManager.change_scene_to(ResPath.SCENES.MAIN_MENU) 切换场景
class_name SceneManager
extends CanvasLayer

signal scene_changed(new_scene: Node)
signal scene_change_started(scene_path: String)

var _current_scene: Node = null

func change_scene_to(scene_path: String, transition: bool = true) -> void:
    pass  # 实现淡出→卸载→加载→添加→淡入流程
```

## Agent Extensions

### SubAgent

- **code-explorer**
- 用途：在创建文件前探索现有项目结构，确认无冲突
- 预期结果：验证所有目标路径不存在同名文件，确保新建文件不覆盖现有内容