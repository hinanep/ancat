---
name: ciga-project-framework-setup-v2
overview: 根据 godot.md 规范搭建项目框架，修正所有文件名为 PascalCase 命名规范，并将 godot.md 注册为 CodeBuddy 项目规则（.codebuddy/rules/）。包含完整文件夹结构、6个 Autoload 工具、ResPath、MainMenu 和 GameWorld 场景。
todos:
  - id: register-rules
    content: 将 rules/godot.md 注册为 .codebuddy/rules/ 强制性约束规则
    status: completed
  - id: create-dirs
    content: 创建完整文件夹结构（addons, assets, scenes, scripts, resources, audio, fonts, tests）
    status: completed
    dependencies:
      - register-rules
  - id: event-bus
    content: 实现 EventBus 全局事件总线（autoload/EventBus.gd）
    status: completed
    dependencies:
      - create-dirs
  - id: game-settings
    content: 实现 GameSettings 游戏设置管理（autoload/GameSettings.gd）
    status: completed
    dependencies:
      - create-dirs
  - id: save-manager
    content: 实现 SaveManager 存档管理（autoload/SaveManager.gd）
    status: completed
    dependencies:
      - game-settings
  - id: audio-manager
    content: 实现 AudioManager 音频管理（autoload/AudioManager.gd）
    status: completed
    dependencies:
      - game-settings
  - id: game-state
    content: 实现 GameState 全局游戏状态（autoload/GameState.gd）
    status: completed
    dependencies:
      - event-bus
      - save-manager
  - id: scene-manager
    content: 实现 SceneManager 场景切换管理（autoload/SceneManager.gd + SceneManager.tscn）
    status: completed
    dependencies:
      - event-bus
      - game-state
  - id: res-path
    content: 实现 ResPath 资源路径常量（scripts/data/ResPath.gd）
    status: completed
    dependencies:
      - create-dirs
  - id: main-menu
    content: 创建 MainMenu 主菜单场景（scenes/ui/screens/MainMenu.tscn + MainMenu.gd）
    status: completed
    dependencies:
      - scene-manager
      - res-path
  - id: game-world
    content: 创建 GameWorld 基础关卡场景（scenes/levels/GameWorld.tscn + GameWorld.gd）
    status: completed
    dependencies:
      - scene-manager
      - res-path
  - id: configure-project
    content: 配置 project.godot Autoload 加载顺序，设置主场景为 MainMenu
    status: completed
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

- 将 `rules/godot.md` 注册为 `.codebuddy/rules/` 强制性约束规则，确保后续所有代码生成自动遵循规范
- 按规范创建完整的项目文件夹结构（scripts、scenes、resources、assets 等）
- 实现 6 个 Autoload 基础工具（全部使用 PascalCase 命名）：EventBus、GameSettings、SaveManager、AudioManager、GameState、SceneManager
- 实现资源路径常量管理（ResPath.gd）
- 创建可运行的主菜单场景（MainMenu），包含开始/设置/退出按钮
- 创建基础 2D 关卡场景（GameWorld），包含摄像机、UI 层、场景切换集成
- 配置 project.godot 的 Autoload 加载顺序和主场景设置

## Tech Stack

- 引擎：Godot 4.7
- 语言：GDScript
- 项目类型：2D

## 实现方案

### 整体策略

按照规范中的架构原则（组件化、数据驱动、信号解耦）搭建框架。Autoload 按依赖顺序加载，脚本与场景分离存放，所有代码严格遵循规范中的命名规范和代码风格（强制类型注解、snake_case 方法/变量、**PascalCase 类名/文件名**）。

**重要更正**：所有文件名、类名、场景名必须使用 PascalCase（规范 三、3.1），原计划错误使用了 snake_case。

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

#### SceneManager 场景切换流程

淡出（ColorRect + AnimationPlayer）→ 卸载旧场景 → 加载新场景 → 添加到当前树 → 淡入

### 路径常量设计

在 `scripts/data/ResPath.gd` 中定义：

```
class_name ResPath
extends RefCounted

const SCENES := {
    MAIN_MENU = "res://scenes/ui/screens/MainMenu.tscn",
    GAME_WORLD = "res://scenes/levels/GameWorld.tscn",
}
```

### 基础场景设计

#### MainMenu 节点结构

```
MainMenu (Control)
├── Background (ColorRect)
├── CenterContainer
│   └── VBoxContainer
│       ├── Label [标题]
│       ├── Button [开始游戏]
│       ├── Button [设置]
│       └── Button [退出]
└── MainMenu.gd
```

#### GameWorld 节点结构

```
GameWorld (Node2D)
├── WorldCamera (Camera2D)
├── CanvasLayer [UI层]
│   └── MarginContainer [HUD占位]
└── GameWorld.gd
```

## 实现注意事项

- 所有变量/参数/返回值必须显式声明类型（规范 4.1）
- 信号必须带类型参数，使用 past_tense 语义（规范 4.3）
- 脚本存 scripts/，场景存 scenes/，不混置（规范二关键约定）
- Autoload 访问直接使用全局类名，避免硬编码路径（规范 6.3）
- **所有文件名必须使用 PascalCase**（规范 三、3.1）

## 架构设计

### 系统架构

- Autoload 层：EventBus → GameSettings → SaveManager → AudioManager → GameState → SceneManager
- 场景层：MainMenu ↔ SceneManager ↔ GameWorld
- 通信方式：跨模块通过 EventBus 信号，模块内通过直接调用或 @onready 引用

### 数据流

用户操作 → UI 脚本 → SceneManager/GameState → EventBus（通知其他模块）→ AudioManager/SaveManager 响应

## 目录结构

### 目录结构说明

本实现为 Godot 4.7 2D 项目搭建符合规范的基础框架。创建完整的文件夹结构、6 个 Autoload 工具脚本（**全部 PascalCase 命名**）、资源路径管理脚本，以及 MainMenu 和 GameWorld 两个基础场景。

```
res://
├── .codebuddy/                    # [NEW] CodeBuddy 项目配置
│   └── rules/                     # [NEW] 强制性约束规则目录
│       └── godot.md               # [COPY] 从 rules/godot.md 复制
├── addons/                        # [目录] 第三方插件目录
├── assets/                        # [目录] 原始美术资源
│   ├── textures/                  # [目录] 贴图源文件
│   ├── audio/                     # [目录] 音频源文件
│   └── fonts/                     # [目录] 字体源文件
├── autoload/                      # [目录] 全局单例脚本
│   ├── EventBus.gd               # [NEW] 全局事件总线
│   ├── GameSettings.gd           # [NEW] 游戏设置管理
│   ├── SaveManager.gd            # [NEW] 存档管理
│   ├── AudioManager.gd           # [NEW] 音频管理
│   ├── GameState.gd              # [NEW] 全局游戏状态
│   ├── SceneManager.gd           # [NEW] 场景切换管理
│   └── SceneManager.tscn         # [NEW] SceneManager 场景节点
├── scenes/                        # [目录] 场景文件
│   ├── ui/
│   │   ├── components/            # [目录] 可复用 UI 组件
│   │   └── screens/              # [目录] 全屏 UI 场景
│   │       ├── MainMenu.tscn     # [NEW] 主菜单场景
│   │       ├── MainMenu.gd       # [NEW] 主菜单脚本
│   │       ├── SettingsMenu.tscn # [NEW] 设置菜单场景
│   │       └── SettingsMenu.gd   # [NEW] 设置菜单脚本
│   ├── levels/                    # [目录] 关卡场景
│   │   ├── GameWorld.tscn       # [NEW] 基础 2D 关卡场景
│   │   └── GameWorld.gd         # [NEW] 基础关卡脚本
│   ├── actors/                    # [目录] 角色/实体场景
│   ├── props/                     # [目录] 道具场景
│   └── effects/                   # [目录] 视觉特效场景
├── scripts/                       # [目录] 独立 GDScript 脚本
│   ├── components/                # [目录] 可复用组件脚本
│   ├── systems/                   # [目录] 系统逻辑脚本
│   ├── data/                      # [目录] 数据定义脚本
│   │   └── ResPath.gd            # [NEW] 资源路径常量管理
│   └── interfaces/                # [目录] 接口/抽象基类脚本
├── resources/                     # [目录] Godot 资源文件
├── audio/                         # [目录] 最终音频资源
├── fonts/                         # [目录] 字体资源
├── tests/                         # [目录] 测试目录
└── project.godot                  # [MODIFY] 配置 Autoload 加载顺序和主场景
```

## Agent Extensions

### SubAgent

- **code-explorer**
- 用途：在创建文件前探索现有项目结构，确认无冲突
- 预期结果：验证所有目标路径不存在同名文件，确保新建文件不覆盖现有内容