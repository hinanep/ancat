extends MovableCargo

## 盘子：用于盛放烹饪完成的食物，加入 Plate 分组供锅识别。
## @emptyPlateTexture 空盘纹理
@export var emptyPlateTexture: Texture2D = ResPath.TEXTURES.PLATE_EMPTY
## 跨层摔碎阈值（像素）。
@export var breakDropHeightPx: float = 300.0

var _foodType: int = -1
var _dropTracking: bool = false
var _dropStartY: float = 0.0
var _isBroken: bool = false
var _airborneTracking: bool = false
var _agentDebugLastDropSampleMs: int = 0

const MAX_PLATE_COUNT: int = 8
const FISH_SCENE: PackedScene = ResPath.PROP_SCENES.FISH_ENTITY

func _ready() -> void:
	super._ready()
	add_to_group('Plate')
	_apply_texture(emptyPlateTexture)


## 设置盘子内食物类型。
## @param foodType 食物类型
## @return void
func set_food_type(foodType: int) -> void:
	_foodType = foodType


## 获取盘子食物类型。
## @return int
func get_food_type() -> int:
	return _foodType


## 清空盘子食物并恢复空盘纹理。
## @return void
func clear_food() -> void:
	_foodType = -1
	_apply_texture(emptyPlateTexture)


## 清空盘子内部存储，不销毁盘子本体。
## @return void
func clear_internal_storage() -> void:
	clear_food()


## 按当前 foodType 应用纹理。
## @return void
func apply_food_texture() -> void:
	if _foodType == -1:
		_apply_texture(emptyPlateTexture)
		return
	var texture: Texture2D = FoodConfig.get_atlas_texture(_foodType)
	if texture != null:
		_apply_texture(texture)


## 应用纹理到盘子精灵。
## @param texture 目标纹理
func _apply_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	var sprite: Sprite2D = get_node_or_null('46_Plate') as Sprite2D
	if sprite == null:
		return
	sprite.texture = texture


## 从携带状态放回世界时，开始追踪坠落高度。
func drop_to_world() -> void:
	super.drop_to_world()
	_dropTracking = true
	_airborneTracking = false
	_dropStartY = global_position.y
	#region agent log
	_agent_debug_emit(
		'H3',
		'PlateCargo.gd:drop_to_world',
		'plate drop tracking started',
		{
			'dropStartY': _dropStartY,
			'airborneTracking': _airborneTracking,
			'currentCabin': current_cabin_name,
			'visible': visible,
			'zIndex': z_index,
			'zAsRelative': z_as_relative,
			'parentPath': String(get_parent().get_path()) if get_parent() != null else ''
		}
	)
	#endregion


## 每物理帧检查是否触发跨层摔碎。
## @param delta 帧间隔（秒）
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _isBroken or not _dropTracking:
		return
	var threshold: float = max(breakDropHeightPx, 1.0)
	if not _airborneTracking:
		if is_on_floor():
			return
		_airborneTracking = true
		_dropStartY = global_position.y
		#region agent log
		_agent_debug_emit(
			'H3',
			'PlateCargo.gd:_physics_process',
			'plate airborne tracking started',
			{
				'startY': _dropStartY,
				'threshold': threshold,
				'currentCabin': current_cabin_name
			}
		)
		#endregion
		return
	if not is_on_floor():
		#region agent log
		if _agent_debug_should_drop_sample():
			_agent_debug_emit(
				'H3',
				'PlateCargo.gd:_physics_process',
				'plate airborne sample',
				{
					'globalY': global_position.y,
					'dropStartY': _dropStartY,
					'deltaY': global_position.y - _dropStartY,
					'threshold': threshold,
					'currentCabin': current_cabin_name
				}
			)
		#endregion
		return
	var dropDy: float = global_position.y - _dropStartY
	_airborneTracking = false
	_dropTracking = false
	if dropDy < threshold:
		#region agent log
		_agent_debug_emit(
			'H3',
			'PlateCargo.gd:_physics_process',
			'plate landed without break',
			{
				'landY': global_position.y,
				'dropStartY': _dropStartY,
				'deltaY': dropDy,
				'threshold': threshold,
				'currentCabin': current_cabin_name
			}
		)
		#endregion
		return
	#region agent log
	_agent_debug_emit(
		'H3',
		'PlateCargo.gd:_physics_process',
		'plate landed and break triggered',
		{
			'globalY': global_position.y,
			'dropStartY': _dropStartY,
			'deltaY': dropDy,
			'threshold': threshold,
			'currentCabin': current_cabin_name
		}
	)
	#endregion
	_break_plate()


## 获取全场盘子数量。
## @return int
static func current_plate_count() -> int:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return 0
	var tree: SceneTree = loop as SceneTree
	if tree == null:
		return 0
	return tree.get_nodes_in_group('Plate').size()


## 是否还能生成新盘子。
## @return bool
static func can_spawn_new_plate() -> bool:
	return current_plate_count() < MAX_PLATE_COUNT


## 触发盘子碎裂逻辑。
func _break_plate() -> void:
	if _isBroken:
		return
	_isBroken = true
	_dropTracking = false
	_spawn_break_result()
	queue_free()


## 根据食物类型生成碎裂结果。
func _spawn_break_result() -> void:
	if _foodType == -1:
		return
	var kind: String = FoodConfig.get_kind(_foodType)
	if kind == 'fish':
		_spawn_dead_fish()
		return
	if kind == 'jam':
		_play_jam_disappear_vfx()


## 鱼类摔碎后生成死鱼实体。
func _spawn_dead_fish() -> void:
	if FISH_SCENE == null:
		return
	var fishNode: Node = FISH_SCENE.instantiate()
	if fishNode == null:
		return
	get_tree().current_scene.add_child(fishNode)
	if fishNode is Node2D:
		(fishNode as Node2D).global_position = global_position
	if fishNode.has_method('mark_out_of_tank'):
		fishNode.call('mark_out_of_tank', global_position)
	if fishNode.has_method('_mark_dead'):
		fishNode.call('_mark_dead')


## 果酱摔碎后播放上跳+淡出特效。
func _play_jam_disappear_vfx() -> void:
	var sprite: Sprite2D = get_node_or_null('46_Plate') as Sprite2D
	if sprite == null:
		return
	if sprite.texture == null:
		return
	var vfx := Sprite2D.new()
	vfx.texture = sprite.texture
	vfx.global_position = global_position
	get_tree().current_scene.add_child(vfx)
	var tween: Tween = vfx.create_tween()
	tween.tween_property(vfx, 'global_position', vfx.global_position + Vector2(0.0, -18.0), 0.16)
	tween.parallel().tween_property(vfx, 'modulate:a', 0.0, 0.16)
	tween.finished.connect(vfx.queue_free)


## 调试日志：下落采样节流。
## @return bool
func _agent_debug_should_drop_sample() -> bool:
	var nowMs: int = Time.get_ticks_msec()
	if nowMs - _agentDebugLastDropSampleMs < 450:
		return false
	_agentDebugLastDropSampleMs = nowMs
	return true
