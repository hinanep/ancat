## ResPath 集中定义项目资源路径，避免硬编码散布各处。
##
## 使用示例：
##   load(ResPath.SCENES.MAIN_MENU) as PackedScene
extends RefCounted

class_name ResPath

const SCENES := {
	MAIN_MENU = "res://scenes/ui/screens/MainMenu.tscn",
	SETTINGS_MENU = "res://scenes/ui/screens/SettingsMenu.tscn",
	GAME_WORLD = "res://scenes/levels/GameWorld.tscn",
}

const DATA := {
	# 示例：SWORD_IRON = "res://resources/data/sword_iron.tres",
}

const AUDIO := {
	# 示例：BGM_MAIN = "res://audio/bgm_main.ogg",
}
