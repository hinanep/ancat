## SaveManager 存档管理，使用 ConfigFile 读写 user://savegame.cfg。
##
## 使用示例：
##   SaveManager.save_game()
##   SaveManager.load_game()
extends Node

const SAVE_PATH: String = "user://savegame.cfg"

signal save_completed()
signal load_completed()
signal load_failed()

## 保存当前游戏状态到磁盘
func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	# 从 GameState 读取数据
	var state: Dictionary = GameState.to_dict()
	for key: String in state:
		config.set_value("game", key, state[key])
	var err: int = config.save(SAVE_PATH)
	if err == OK:
		save_completed.emit()
		print_debug("SaveManager: save succeeded")
	else:
		push_warning("SaveManager: save failed with error %d" % err)

## 从磁盘加载游戏状态
func load_game() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SAVE_PATH)
	if err != OK:
		push_warning("SaveManager: load failed with error %d" % err)
		load_failed.emit()
		return false
	var data: Dictionary = {}
	for section: String in config.get_sections():
		for key: String in config.get_section_keys(section):
			data[key] = config.get_value(section, key)
	GameState.from_dict(data)
	load_completed.emit()
	print_debug("SaveManager: load succeeded")
	return true

## 检查是否存在存档
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 删除存档
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print_debug("SaveManager: save deleted")
