class_name CoinPickup
extends Node2D

## 顾客离场后弹出的可收集金币：弹出落地、等待后飞向 HUD 并结算。
## @landWaitSec 落地后等待自动收集的时长（秒）
## @popHeightPx 弹出高度（像素）
## @collectDurationSec 飞向 HUD 的时长（秒）
@export var landWaitSec: float = 2.0
@export var popHeightPx: float = 36.0
@export var collectDurationSec: float = 0.35

const _FRAME_SIZE: int = 16
const _FRAME_COUNT: int = 4

var _amount: int = 0
var _isVip: bool = false
var _coinAnim: AnimatedSprite2D


## 在指定世界坐标生成金币并启动弹出流程。
## @param parentNode 父节点
## @param worldPos 世界坐标
## @param amount 金币数量
## @param displayScale 显示缩放
## @param isVip 是否 VIP 顾客
## @return CoinPickup
static func spawn_at(parentNode: Node, worldPos: Vector2, amount: int, displayScale: Vector2, isVip: bool = false) -> CoinPickup:
	if parentNode == null or amount <= 0:
		return null
	var coin: CoinPickup = CoinPickup.new()
	coin._amount = amount
	coin._isVip = isVip
	coin.scale = displayScale
	coin.z_index = 65
	parentNode.add_child(coin)
	coin.global_position = worldPos
	coin._setup_animation()
	coin._start_spawn_sequence()
	return coin


## 构建旋转金币动画帧。
func _setup_animation() -> void:
	var coinAtlas: Texture2D = ResPath.TEXTURES.COIN
	if coinAtlas == null:
		return
	var spriteFrames: SpriteFrames = SpriteFrames.new()
	spriteFrames.add_animation('spin')
	spriteFrames.set_animation_loop('spin', true)
	for i in range(_FRAME_COUNT):
		var atlasTexture: AtlasTexture = AtlasTexture.new()
		atlasTexture.atlas = coinAtlas
		atlasTexture.region = Rect2(float(i * _FRAME_SIZE), 0.0, float(_FRAME_SIZE), float(_FRAME_SIZE))
		spriteFrames.add_frame('spin', atlasTexture)
	spriteFrames.set_animation_speed('spin', 8.0)
	_coinAnim = AnimatedSprite2D.new()
	_coinAnim.sprite_frames = spriteFrames
	_coinAnim.animation = 'spin'
	add_child(_coinAnim)
	_coinAnim.play('spin')


## 弹出落地后等待，再自动收集。
func _start_spawn_sequence() -> void:
	var startPos: Vector2 = global_position
	var peakPos: Vector2 = startPos + Vector2(0.0, -popHeightPx)
	var tween: Tween = create_tween()
	tween.tween_property(self, 'global_position', peakPos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position', startPos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	await get_tree().create_timer(max(landWaitSec, 0.0)).timeout
	_collect_to_hud()


## 飞向金币 HUD 并结算。
func _collect_to_hud() -> void:
	var sceneRoot: Node = get_tree().current_scene
	if sceneRoot != null:
		var canvasLayer: CanvasLayer = sceneRoot.get_node_or_null('CanvasLayer') as CanvasLayer
		if canvasLayer != null:
			reparent(canvasLayer, true)
	var targetPos: Vector2 = _resolve_hud_target_position()
	var tween: Tween = create_tween()
	tween.tween_property(self, 'global_position', targetPos, max(collectDurationSec, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, 'scale', scale * 0.5, max(collectDurationSec, 0.01))
	await tween.finished
	if GameState.has_method('add_gold'):
		GameState.call('add_gold', _amount)
	EventBus.emit(EventBus.EventType.CUSTOMER_SERVED, {'pay': _amount, 'vip': _isVip})
	queue_free()


## 解析金币 HUD 图标的世界坐标。
## @return Vector2
func _resolve_hud_target_position() -> Vector2:
	var sceneRoot: Node = get_tree().current_scene
	if sceneRoot == null:
		return global_position
	var coinIcon: Node2D = sceneRoot.get_node_or_null('CanvasLayer/CoinHud/AnimatedSprite2D') as Node2D
	if coinIcon != null:
		return coinIcon.global_position
	var coinHud: Control = sceneRoot.get_node_or_null('CanvasLayer/CoinHud') as Control
	if coinHud != null:
		return coinHud.global_position
	return global_position
