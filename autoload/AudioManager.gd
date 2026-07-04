## AudioManager 音频管理，支持 BGM 和 SFX 播放。
##
## 使用示例：
##   AudioManager.play_bgm("res://audio/bgm_main.ogg")
##   AudioManager.play_sfx("res://audio/sfx_hit.ogg")
extends Node

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _loop_players: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _bgm_path: String = ""
var _sfx_pool_size: int = 8

func _ready() -> void:
	_rng.randomize()
	# 创建 BGM 播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	# 创建 SFX 池
	for i: int in _sfx_pool_size:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "Master"
		player.volume_db = linear_to_db(GameSettings.get_sfx_volume())
		add_child(player)
		_sfx_pool.append(player)
	# 监听音量变化
	GameSettings.master_volume_changed.connect(_on_master_volume_changed)
	GameSettings.music_volume_changed.connect(_on_music_volume_changed)
	GameSettings.sfx_volume_changed.connect(_on_sfx_volume_changed)

## 播放 BGM（循环）
func play_bgm(audio_path: String, fade_time: float = 0.5) -> void:
	if _bgm_path == audio_path and _bgm_player.playing:
		return
	_bgm_path = audio_path
	_bgm_player.stream = load(audio_path) as AudioStream
	_bgm_player.stream.loop = true
	_bgm_player.volume_db = linear_to_db(GameSettings.get_music_volume())
	_bgm_player.play()

## 停止 BGM
func stop_bgm() -> void:
	_bgm_player.stop()
	_bgm_path = ""

## 播放 SFX（从池中取空闲播放器）
func play_sfx(audio_path: String) -> void:
	if audio_path == "":
		return
	var player: AudioStreamPlayer = _get_free_sfx_player()
	if not player:
		push_warning("AudioManager: SFX pool full, dropping %s" % audio_path)
		return
	player.stream = load(audio_path) as AudioStream
	if player.stream == null:
		return
	player.volume_db = linear_to_db(GameSettings.get_sfx_volume())
	player.play()

## 播放随机 SFX（从路径数组随机选一条）。
func play_sfx_random(paths: Array) -> void:
	if paths.is_empty():
		return
	var pickIndex: int = _rng.randi_range(0, paths.size() - 1)
	var pickedPath: Variant = paths[pickIndex]
	if typeof(pickedPath) != TYPE_STRING:
		return
	var audioPath: String = String(pickedPath)
	if audioPath == "":
		return
	play_sfx(audioPath)

## 启动循环 SFX（同 key 不重复创建）。
func play_sfx_loop(key: String, audio_path: String) -> void:
	if key == "" or audio_path == "":
		return
	var player: AudioStreamPlayer = _loop_players.get(key, null) as AudioStreamPlayer
	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = "LoopSFX_%s" % key
		player.bus = "Master"
		add_child(player)
		_loop_players[key] = player
	var stream: AudioStream = load(audio_path) as AudioStream
	if stream == null:
		return
	stream.loop = true
	player.stream = stream
	player.volume_db = linear_to_db(GameSettings.get_sfx_volume())
	if not player.playing:
		player.play()

## 停止指定 key 的循环 SFX。
func stop_sfx_loop(key: String) -> void:
	if key == "":
		return
	var player: AudioStreamPlayer = _loop_players.get(key, null) as AudioStreamPlayer
	if player == null or not is_instance_valid(player):
		return
	player.stop()

## 获取空闲的 SFX 播放器
func _get_free_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0]  #  fallback：复用最旧的

func _on_master_volume_changed(_new_volume: float) -> void:
	pass  # Master 音量由 bus 统一控制

func _on_music_volume_changed(new_volume: float) -> void:
	_bgm_player.volume_db = linear_to_db(new_volume)

func _on_sfx_volume_changed(new_volume: float) -> void:
	for player: AudioStreamPlayer in _sfx_pool:
		player.volume_db = linear_to_db(new_volume)
	for key in _loop_players.keys():
		var loopPlayer: AudioStreamPlayer = _loop_players[key] as AudioStreamPlayer
		if loopPlayer == null or not is_instance_valid(loopPlayer):
			continue
		loopPlayer.volume_db = linear_to_db(new_volume)
