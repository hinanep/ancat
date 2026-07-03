# ciga

## 项目结构

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
└── tests/                  # 测试代码
```

## 运行

使用 Godot 4.7（GL Compatibility）打开 `project.godot` 即可运行。
