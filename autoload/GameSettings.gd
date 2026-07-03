## GameSettings 游戏设置管理，持久化到 user://settings.tres。
##
## 使用示例：
##   GameSettings.set_master_volume(0.8)
##   var vol: float = GameSettings.get_master_volume()
extends Node

const SAVE_PATH: String = "user://settings.tres"

## 设置信号
signal master_volume_changed(new_volume: float)
signal music_volume_changed(new_volume: float)
signal sfx_volume_changed(new_volume: float)
signal fullscreen_toggled(enabled: bool)

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var is_fullscreen: bool = false

func _ready() -> void:
	load_settings()

## 设置主音量 (0.0 ~ 1.0)
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	master_volume_changed.emit(master_volume)
	save_settings()

## 获取主音量
func get_master_volume() -> float:
	return master_volume

## 设置音乐音量 (0.0 ~ 1.0)
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	music_volume_changed.emit(music_volume)
	save_settings()

## 获取音乐音量
func get_music_volume() -> float:
	return music_volume

## 设置音效音量 (0.0 ~ 1.0)
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	sfx_volume_changed.emit(sfx_volume)
	save_settings()

## 获取音效音量
func get_sfx_volume() -> float:
	return sfx_volume

## 切换全屏
func toggle_fullscreen(enabled: bool = !is_fullscreen) -> void:
	is_fullscreen = enabled
	if is_fullscreen:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
	fullscreen_toggled.emit(is_fullscreen)
	save_settings()

## 保存设置到磁盘
func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", is_fullscreen)
	config.save(SAVE_PATH)

## 从磁盘加载设置
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 0.8)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
	is_fullscreen = config.get_value("video", "fullscreen", false)
	if is_fullscreen:
		get_window().mode = Window.MODE_FULLSCREEN
