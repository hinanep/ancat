extends CharacterBody2D

## 鱼实体参数：游动、钩取携带、离缸死亡与动画状态。
## 活鱼精灵图（帧动画图集）。
@export var aliveTexture: Texture2D = ResPath.TEXTURES.FISH_ALIVE
## 死鱼精灵图（帧动画图集）。
@export var deadTexture: Texture2D = ResPath.TEXTURES.FISH_DEAD
## 烹饪完成后装盘整体图集。
@export var cookedTexture: Texture2D = ResPath.TEXTURES.DISH_ATLAS
## 从图集中提取的帧区域（默认取左上角 32x29）。
@export var cookedAtlasRegion: Rect2 = Rect2(0.0, 0.0, 32.0, 29.0)
## 活鱼帧数（按单行切分）。
@export var aliveFrameCount: int = 2
## 死鱼帧数（按单行切分）。
@export var deadFrameCount: int = 1
## 活鱼动画 FPS。
@export var aliveFps: float = 4.0
## 死鱼动画 FPS。
@export var deadFps: float = 2.0
## 刷新渐入时长（秒）。
@export var spawnFadeInSec: float = 0.35
## 游动最小速度（像素/秒）。
@export var swimSpeedMin: float = 20.0
## 游动最大速度（像素/秒）。
@export var swimSpeedMax: float = 55.0
## 游动转向间隔（秒）。
@export var swimTurnIntervalSec: float = 1.2
## 离缸后死亡时长（秒）。
@export var outOfTankDeathSec: float = 60.0
## 非水中/非鱼缸状态下的重力加速度（像素/秒^2）。
@export var gravityAccel: float = 980.0
## 自由移动时的摩擦系数（越大越不易滑动）。
@export var freeMoveFriction: float = 42.0
## 自由移动时的斜面驱动强度。
@export var freeMoveSlideAccelScale: float = 520.0
## 自由移动时的最大横向滑动速度（像素/秒）。
@export var freeMoveMaxSlideSpeed: float = 140.0
## 投掷后无碰撞持续时间（秒）。
@export var throwNoCollisionSec: float = 0.12
## 调试日志开关。
@export var debugFishLog: bool = false

enum FishState {
	SWIMMING,
	HOOKED,
	CARRIED,
	IN_TANK,
	SPILLING,
	OUT_TANK,
	DEAD
}

var _state: FishState = FishState.SWIMMING
var _carrier: Node2D
var _carryOffset: Vector2 = Vector2.ZERO
var _collisionIgnored: bool = false
var _savedCollisionLayer: int = 0
var _savedCollisionMask: int = 0
var _swimDir: Vector2 = Vector2.RIGHT
var _swimSpeed: float = 30.0
var _swimTurnTimer: float = 0.0
var _swimBounds: Rect2 = Rect2(Vector2(-2000.0, -2000.0), Vector2(4000.0, 4000.0))
var _tankSwimBounds: Rect2 = Rect2(Vector2(-2000.0, -2000.0), Vector2(4000.0, 4000.0))
var _deadTimerRemaining: float = 0.0
var _freeMoveEnabled: bool = false
var _slideSpeed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spriteFrames: SpriteFrames
var _spawnFadeRemaining: float = 0.0
var _spillStartPos: Vector2 = Vector2.ZERO
var _spillEdgePos: Vector2 = Vector2.ZERO
var _spillTargetPos: Vector2 = Vector2.ZERO
var _spillToEdgeDuration: float = 0.0
var _spillOutDuration: float = 0.0
var _spillElapsed: float = 0.0
var _spillArcHeight: float = 0.0
var _spillPhase: int = 0
var _throwNoCollisionRemaining: float = 0.0
var _throwCollisionBypassActive: bool = false
var _rightClickPromptBubble: Node2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


## 初始化：分组、动画与初始游动状态。
## @return void
func _ready() -> void:
	_rng.randomize()
	add_to_group('Hitable')
	add_to_group('Fish')
	add_to_group('Cookable')
	_setup_sprite_frames()
	_enter_swimming()
	_bind_right_click_prompt_bubble()


## 每帧更新：游动/携带跟随/离缸死亡倒计时。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_update_spawn_fade(delta)
	match _state:
		FishState.SWIMMING:
			_update_swimming(delta)
		FishState.IN_TANK:
			_update_tank_swimming(delta)
		FishState.CARRIED:
			_update_carried_follow()
		FishState.SPILLING:
			_update_spill_animation(delta)
		FishState.OUT_TANK:
			_update_out_of_tank_timer(delta)
		_:
			pass


## 物理帧更新：离水/离缸时受重力影响。
## @param delta 物理帧间隔（秒）
## @return void
func _physics_process(delta: float) -> void:
	_update_throw_no_collision(delta)
	if _freeMoveEnabled and (_state == FishState.OUT_TANK or _state == FishState.DEAD):
		_update_free_move_slide(delta)
		velocity.y += max(gravityAccel, 0.0) * delta
		move_and_slide()
		return
	_slideSpeed = 0.0
	velocity = Vector2.ZERO


## 是否可被锚勾取。
## @return bool
func can_be_hooked() -> bool:
	return _state == FishState.SWIMMING or _state == FishState.OUT_TANK or _state == FishState.DEAD


## 绑定场景中预置的右键提示气泡。
## @return void
func _bind_right_click_prompt_bubble() -> void:
	_rightClickPromptBubble = get_node_or_null('RightClickPromptBubble') as Node2D
	if _rightClickPromptBubble == null:
		return
	if _rightClickPromptBubble.has_method('configure_pickup'):
		_rightClickPromptBubble.call('configure_pickup', self)


## 获取当前鱼可交付的食物类型。
## @return int
func get_food_type() -> int:
	if _state == FishState.DEAD:
		return -1
	return FoodConfig.FoodType.RAW_FISH


## 标记为被锚勾取。
## @param byAnchor 锚控制器
## @return void
func set_hooked(byAnchor: Node) -> void:
	var _unusedByAnchor: Node = byAnchor
	_state = FishState.HOOKED
	_carrier = null
	_freeMoveEnabled = false
	_throwNoCollisionRemaining = 0.0
	_throwCollisionBypassActive = false
	_set_collision_ignored(true)


## 标记为被玩家携带。
## @param byPlayer 玩家节点
## @param carryOffset 携带偏移
## @return void
func set_carried(byPlayer: Node2D, carryOffset: Vector2) -> void:
	_state = FishState.CARRIED
	_carrier = byPlayer
	_carryOffset = carryOffset
	_freeMoveEnabled = false
	_throwNoCollisionRemaining = 0.0
	_throwCollisionBypassActive = false
	_set_collision_ignored(true)


## 从携带/勾取状态回到世界（离缸在地面状态）。
## @return void
func drop_to_world() -> void:
	if _state == FishState.DEAD:
		_state = FishState.DEAD
	else:
		_state = FishState.OUT_TANK
		_deadTimerRemaining = max(outOfTankDeathSec, 0.0)
	_set_collision_ignored(false)
	_carrier = null
	_freeMoveEnabled = true
	_throwNoCollisionRemaining = 0.0
	_throwCollisionBypassActive = false
	velocity = Vector2.ZERO


## 应用投掷速度（丢弃时给予初速度）。
## @param throwVel 投掷速度向量
## @return void
func apply_throw(throwVel: Vector2) -> void:
	_slideSpeed = throwVel.x
	velocity = throwVel
	_throwNoCollisionRemaining = max(throwNoCollisionSec, 0.0)
	if _throwNoCollisionRemaining > 0.0:
		_throwCollisionBypassActive = true
		_set_collision_ignored(true)


## 标记进入鱼缸（停更新、隐藏、不可交互）。
## @return void
func mark_in_tank() -> void:
	_state = FishState.IN_TANK
	_deadTimerRemaining = 0.0
	_carrier = null
	_freeMoveEnabled = false
	_throwNoCollisionRemaining = 0.0
	_throwCollisionBypassActive = false
	_set_collision_ignored(true)
	visible = true
	velocity = Vector2.ZERO
	_play_anim('alive')


## 标记进入鱼缸并设置缸内游动范围。
## @param boundsGlobal 鱼缸内部游动边界
## @return void
func mark_in_tank_with_bounds(boundsGlobal: Rect2) -> void:
	_tankSwimBounds = boundsGlobal
	mark_in_tank()
	global_position = Vector2(
		clampf(global_position.x, _tankSwimBounds.position.x, _tankSwimBounds.end.x),
		clampf(global_position.y, _tankSwimBounds.position.y, _tankSwimBounds.end.y)
	)


## 从鱼缸滑出到地面（可再次被交互）。
## @param dropPos 滑出落点
## @return void
func mark_out_of_tank(dropPos: Vector2) -> void:
	global_position = dropPos
	visible = true
	if _state == FishState.DEAD:
		_state = FishState.DEAD
		_deadTimerRemaining = 0.0
	else:
		_state = FishState.OUT_TANK
		_deadTimerRemaining = max(outOfTankDeathSec, 0.0)
	_set_collision_ignored(false)
	_carrier = null
	_freeMoveEnabled = true
	_throwNoCollisionRemaining = 0.0
	_throwCollisionBypassActive = false
	velocity = Vector2.ZERO


## 从鱼缸开始溢出动画，结束后落地出缸。
## @param dropPos 落地目标点
## @param durationSec 动画时长
## @param arcHeight 抛物线峰值高度
## @return void
func start_spill_from_tank(dropPos: Vector2, durationSec: float, arcHeight: float) -> void:
	start_spill_from_tank_with_edge(global_position, dropPos, 0.0, durationSec, arcHeight)


## 从鱼缸开始两段溢出动画：先到边缘点，再飞出到落点。
## @param edgePos 第一段终点（鱼缸上沿角点）
## @param dropPos 第二段落地目标点
## @param toEdgeDurationSec 第一段时长
## @param outDurationSec 第二段时长
## @param arcHeight 第二段抛物线峰值高度
## @return void
func start_spill_from_tank_with_edge(
	edgePos: Vector2,
	dropPos: Vector2,
	toEdgeDurationSec: float,
	outDurationSec: float,
	arcHeight: float
) -> void:
	_state = FishState.SPILLING
	_spillStartPos = global_position
	_spillEdgePos = edgePos
	_spillTargetPos = dropPos
	_spillToEdgeDuration = max(toEdgeDurationSec, 0.0)
	_spillOutDuration = max(outDurationSec, 0.05)
	_spillElapsed = 0.0
	_spillArcHeight = max(arcHeight, 0.0)
	_spillPhase = 0
	visible = true
	_freeMoveEnabled = false
	_set_collision_ignored(true)
	velocity = Vector2.ZERO


## 设置游动边界（钓鱼区分配）。
## @param boundsGlobal 全局边界
## @return void
func set_swim_bounds(boundsGlobal: Rect2) -> void:
	_swimBounds = boundsGlobal
	if _state == FishState.SWIMMING:
		global_position = Vector2(
			clampf(global_position.x, _swimBounds.position.x, _swimBounds.end.x),
			clampf(global_position.y, _swimBounds.position.y, _swimBounds.end.y)
		)


## 是否为死鱼。
## @return bool
func is_dead_fish() -> bool:
	return _state == FishState.DEAD


## 是否处于游动态（用于钓鱼区补鱼统计）。
## @return bool
func is_swimming_fish() -> bool:
	return _state == FishState.SWIMMING


## 交付标签：活鱼 fish，死鱼 dead_fish。
## @return String
func get_delivery_tag() -> String:
	return 'dead_fish' if _state == FishState.DEAD else 'fish'


## 启动游动状态。
## @return void
func _enter_swimming() -> void:
	_state = FishState.SWIMMING
	_deadTimerRemaining = 0.0
	_freeMoveEnabled = false
	_slideSpeed = 0.0
	_set_collision_ignored(false)
	_roll_swim_dir_and_speed()
	_swimTurnTimer = max(swimTurnIntervalSec, 0.2)
	_play_anim('alive')


## 更新游动逻辑：随机游动 + 边界反弹。
## @param delta 帧间隔（秒）
## @return void
func _update_swimming(delta: float) -> void:
	_swimTurnTimer -= delta
	if _swimTurnTimer <= 0.0:
		_roll_swim_dir_and_speed()
		_swimTurnTimer = max(swimTurnIntervalSec, 0.2)
	var nextPos: Vector2 = global_position + _swimDir * _swimSpeed * delta
	if nextPos.x < _swimBounds.position.x or nextPos.x > _swimBounds.end.x:
		_swimDir.x *= -1.0
		nextPos.x = clampf(nextPos.x, _swimBounds.position.x, _swimBounds.end.x)
	if nextPos.y < _swimBounds.position.y or nextPos.y > _swimBounds.end.y:
		_swimDir.y *= -1.0
		nextPos.y = clampf(nextPos.y, _swimBounds.position.y, _swimBounds.end.y)
	global_position = nextPos
	if _sprite != null and not is_zero_approx(_swimDir.x):
		_sprite.flip_h = _swimDir.x < 0.0


## 更新鱼缸内游动（在鱼缸范围中可见游泳）。
## @param delta 帧间隔（秒）
## @return void
func _update_tank_swimming(delta: float) -> void:
	_swimTurnTimer -= delta
	if _swimTurnTimer <= 0.0:
		_roll_swim_dir_and_speed()
		_swimTurnTimer = max(swimTurnIntervalSec * 1.25, 0.25)
	var tankSpeed: float = _swimSpeed * 0.55
	var nextPos: Vector2 = global_position + _swimDir * tankSpeed * delta
	if nextPos.x < _tankSwimBounds.position.x or nextPos.x > _tankSwimBounds.end.x:
		_swimDir.x *= -1.0
		nextPos.x = clampf(nextPos.x, _tankSwimBounds.position.x, _tankSwimBounds.end.x)
	if nextPos.y < _tankSwimBounds.position.y or nextPos.y > _tankSwimBounds.end.y:
		_swimDir.y *= -1.0
		nextPos.y = clampf(nextPos.y, _tankSwimBounds.position.y, _tankSwimBounds.end.y)
	global_position = nextPos
	if _sprite != null and not is_zero_approx(_swimDir.x):
		_sprite.flip_h = _swimDir.x < 0.0


## 更新溢出动画（抛物线），结束后落地出缸。
## @param delta 帧间隔（秒）
## @return void
func _update_spill_animation(delta: float) -> void:
	if _spillPhase == 0:
		if _spillToEdgeDuration <= 0.0:
			_spillPhase = 1
			_spillElapsed = 0.0
		else:
			_spillElapsed += delta
			var toEdgeT: float = clampf(_spillElapsed / _spillToEdgeDuration, 0.0, 1.0)
			global_position = _spillStartPos.lerp(_spillEdgePos, toEdgeT)
			if toEdgeT >= 1.0:
				_spillPhase = 1
				_spillElapsed = 0.0
			return
	_spillElapsed += delta
	var outT: float = clampf(_spillElapsed / max(_spillOutDuration, 0.05), 0.0, 1.0)
	var basePos: Vector2 = _spillEdgePos.lerp(_spillTargetPos, outT)
	var arc: float = 4.0 * _spillArcHeight * outT * (1.0 - outT)
	global_position = basePos + Vector2(0.0, -arc)
	if outT >= 1.0:
		mark_out_of_tank(_spillTargetPos)


## 更新自由移动下的横向滑动（受船体倾斜与摩擦影响）。
## @param delta 帧间隔（秒）
## @return void
func _update_free_move_slide(delta: float) -> void:
	var tiltRad: float = _ship_tilt_rad()
	var gravityFactor: float = max(gravityAccel, 0.0) / 980.0
	var slopeAccel: float = sin(tiltRad) * freeMoveSlideAccelScale * gravityFactor
	_slideSpeed += slopeAccel * delta
	_slideSpeed = move_toward(_slideSpeed, 0.0, max(freeMoveFriction, 0.0) * delta)
	_slideSpeed = clampf(_slideSpeed, -freeMoveMaxSlideSpeed, freeMoveMaxSlideSpeed)
	velocity.x = _slideSpeed


## 读取船体当前倾斜角（弧度）。
## @return float
func _ship_tilt_rad() -> float:
	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Node2D):
			continue
		var cabinNode: Node2D = node as Node2D
		if cabinNode.get_parent() is Node2D:
			return (cabinNode.get_parent() as Node2D).rotation
	return 0.0


## 更新携带跟随。
## @return void
func _update_carried_follow() -> void:
	if _carrier == null:
		return
	global_position = _carrier.global_position + _carryOffset


## 更新离缸死亡倒计时。
## @param delta 帧间隔（秒）
## @return void
func _update_out_of_tank_timer(delta: float) -> void:
	if _deadTimerRemaining <= 0.0:
		_mark_dead()
		return
	_deadTimerRemaining = max(_deadTimerRemaining - delta, 0.0)
	if _deadTimerRemaining <= 0.0:
		_mark_dead()


## 烹饪完成回调：切换为装盘贴图，移除 Cookable 分组。
func set_cooked() -> void:
	if is_in_group('Cookable'):
		remove_from_group('Cookable')
	if _sprite == null or _spriteFrames == null:
		return
	if not _spriteFrames.has_animation('cooked'):
		_spriteFrames.add_animation('cooked')
		_spriteFrames.set_animation_speed('cooked', 1.0)
		if cookedTexture != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = cookedTexture
			atlas.region = cookedAtlasRegion
			_spriteFrames.add_frame('cooked', atlas)
	_sprite.play('cooked')
	#region agent log
	_agent_debug_emit(
		'H3',
		'FishEntity.gd:set_cooked',
		'fish cooked visual applied',
		{
			'regionX': cookedAtlasRegion.position.x,
			'regionY': cookedAtlasRegion.position.y,
			'regionW': cookedAtlasRegion.size.x,
			'regionH': cookedAtlasRegion.size.y
		}
	)
	#endregion
	_debug_log('set cooked')


## 标记死鱼并切换动画。
## @return void
func _mark_dead() -> void:
	_state = FishState.DEAD
	_deadTimerRemaining = 0.0
	if is_in_group('Cookable'):
		remove_from_group('Cookable')
	_play_anim('dead')
	_debug_log('mark dead')


## 随机游动方向与速度。
## @return void
func _roll_swim_dir_and_speed() -> void:
	var angle: float = _rng.randf_range(0.0, PI * 2.0)
	_swimDir = Vector2(cos(angle), sin(angle)).normalized()
	_swimSpeed = _rng.randf_range(min(swimSpeedMin, swimSpeedMax), max(swimSpeedMin, swimSpeedMax))


## 配置动画帧资源（活鱼/死鱼）。
## @return void
func _setup_sprite_frames() -> void:
	if _sprite == null:
		return
	_spriteFrames = SpriteFrames.new()
	_spriteFrames.add_animation('alive')
	_spriteFrames.set_animation_speed('alive', max(aliveFps, 0.1))
	_append_frames('alive', aliveTexture, max(aliveFrameCount, 1))
	_spriteFrames.add_animation('dead')
	_spriteFrames.set_animation_speed('dead', max(deadFps, 0.1))
	_append_frames('dead', deadTexture, max(deadFrameCount, 1))
	_sprite.sprite_frames = _spriteFrames


## 将单行图集切分后写入动画。
## @param animName 动画名
## @param texture 图集
## @param frameCount 帧数
## @return void
func _append_frames(animName: StringName, texture: Texture2D, frameCount: int) -> void:
	if texture == null:
		return
	var count: int = max(frameCount, 1)
	var texW: int = texture.get_width()
	var texH: int = texture.get_height()
	if texW <= 0 or texH <= 0:
		return
	var frameW: int = max(int(floor(float(texW) / float(count))), 1)
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(i * frameW), 0.0, float(frameW), float(texH))
		_spriteFrames.add_frame(animName, atlas)


## 播放指定动画（存在时）。
## @param animName 动画名
## @return void
func _play_anim(animName: StringName) -> void:
	if _sprite == null or _spriteFrames == null:
		return
	if not _spriteFrames.has_animation(animName):
		return
	_sprite.play(animName)


## 启动刷新渐入动画（alpha 从 0 到 1）。
## @return void
func start_spawn_fade_in() -> void:
	_spawnFadeRemaining = max(spawnFadeInSec, 0.01)
	modulate.a = 0.0


## 更新刷新渐入过程。
## @param delta 帧间隔（秒）
## @return void
func _update_spawn_fade(delta: float) -> void:
	if _spawnFadeRemaining <= 0.0:
		if modulate.a < 1.0:
			modulate.a = 1.0
		return
	_spawnFadeRemaining = max(_spawnFadeRemaining - delta, 0.0)
	var ratio: float = 1.0 - (_spawnFadeRemaining / max(spawnFadeInSec, 0.01))
	modulate.a = clampf(ratio, 0.0, 1.0)


## 设置/恢复碰撞，避免回收时被阻挡。
## @param ignored 是否忽略碰撞
## @return void
func _set_collision_ignored(ignored: bool) -> void:
	if ignored and not _collisionIgnored:
		_savedCollisionLayer = collision_layer
		_savedCollisionMask = collision_mask
		collision_layer = 0
		collision_mask = 0
		_collisionIgnored = true
		return
	if (not ignored) and _collisionIgnored:
		collision_layer = _savedCollisionLayer
		collision_mask = _savedCollisionMask
		_collisionIgnored = false


## 更新投掷后的短暂无碰撞窗口。
## @param delta 帧间隔（秒）
## @return void
func _update_throw_no_collision(delta: float) -> void:
	if not _throwCollisionBypassActive:
		return
	_throwNoCollisionRemaining = max(_throwNoCollisionRemaining - delta, 0.0)
	if _throwNoCollisionRemaining > 0.0:
		return
	_throwCollisionBypassActive = false
	if _state == FishState.HOOKED or _state == FishState.CARRIED or _state == FishState.IN_TANK:
		return
	_set_collision_ignored(false)


## 输出调试日志。
## @param message 日志内容
## @return void
func _debug_log(message: String) -> void:
	if not debugFishLog:
		return
	print('[FishEntity] %s' % message)


const _AGENT_DEBUG_LOG_PATH: String = 'C:/Users/nep/Desktop/mao/debug-d44187.log'


func _agent_debug_emit(hypothesisId: String, location: String, message: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		'sessionId': 'd44187',
		'hypothesisId': hypothesisId,
		'location': location,
		'message': message,
		'data': data,
		'timestamp': Time.get_unix_time_from_system() * 1000.0
	}
	var file: FileAccess = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(_AGENT_DEBUG_LOG_PATH) else FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
