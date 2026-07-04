extends InteractableBase

## 果树可交互：空手右键采摘水果直接放入手中，带冷却与摇晃动画反馈。
## @fruitType 果树产物类型（苹果/桃子/梨）
## @fruitScene 产出的水果预制体
## @cooldownSec 采摘冷却时长（秒）
@export var fruitType: FoodConfig.FoodType = FoodConfig.FoodType.APPLE
@export var fruitScene: PackedScene = ResPath.PROP_SCENES.FRUIT_CARGO
@export var cooldownSec: float = 4.0

var _cooldownRemaining: float = 0.0

@onready var _treeAnim: AnimatedSprite2D = get_node_or_null('TreeAnim') as AnimatedSprite2D
@onready var _fruitMarkLeft: Sprite2D = get_node_or_null('FruitMarkLeft') as Sprite2D
@onready var _fruitMarkRight: Sprite2D = get_node_or_null('FruitMarkRight') as Sprite2D


## 初始化果树显示、动画连接与分组。
func _ready() -> void:
	super._ready()
	interactLogPrefix = 'FruitTree'
	if _treeAnim != null:
		if not _treeAnim.animation_finished.is_connected(_on_tree_animation_finished):
			_treeAnim.animation_finished.connect(_on_tree_animation_finished)
		_treeAnim.play('default')
	_apply_fruit_mark()


## 每帧更新冷却倒计时。
## @param delta 帧间隔（秒）
func _process(delta: float) -> void:
	if _cooldownRemaining > 0.0:
		_cooldownRemaining = max(_cooldownRemaining - delta, 0.0)


## 前置校验：冷却中或锚控制器不可用时拒绝交互。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
## @return bool
func _can_interact_now(player: Node, item: Node, anchorController: Node) -> bool:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	#region agent log
	_agent_debug_emit(
		'H1',
		'FruitTreeInteractable.gd:_can_interact_now',
		'enter can_interact',
		{
			'cooldownRemaining': _cooldownRemaining,
			'hasAnchorController': anchorController != null,
			'hasTryAddMethod': anchorController != null and anchorController.has_method('try_add_carried_cargo'),
			'hasCarriedItem': item != null
		}
	)
	#endregion
	if anchorController == null:
		return false
	if _cooldownRemaining > 0.0:
		return false
	if not anchorController.has_method('try_add_carried_cargo'):
		return false
	return true


## 仅允许空手采摘（有携带物时不响应）。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	#region agent log
	_agent_debug_emit(
		'H2',
		'FruitTreeInteractable.gd:_is_item_valid',
		'item valid check',
		{
			'itemIsNull': item == null,
			'itemName': item.name if item != null else ''
		}
	)
	#endregion
	return item == null


## 生成水果并直接放入玩家手中，播放摇晃动画。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedItem: Node = item
	if fruitScene == null:
		return
	var fruitNode: Node = fruitScene.instantiate()
	if fruitNode == null:
		return
	if fruitNode.has_method('set'):
		fruitNode.set('fruitType', fruitType)
	#region agent log
	_agent_debug_emit(
		'H1',
		'FruitTreeInteractable.gd:_on_item_valid',
		'fruit before add_child',
		{
			'treeFruitType': int(fruitType),
			'nodeFruitTypeBeforeAdd': int(fruitNode.get('fruitType'))
		}
	)
	#endregion
	get_tree().current_scene.add_child(fruitNode)
	if fruitNode is Node2D and player is Node2D:
		(fruitNode as Node2D).global_position = (player as Node2D).global_position
	#region agent log
	_agent_debug_emit(
		'H1',
		'FruitTreeInteractable.gd:_on_item_valid',
		'fruit after set',
		{
			'treeFruitType': int(fruitType),
			'nodeFruitTypeAfterSet': int(fruitNode.get('fruitType'))
		}
	)
	#endregion
	var added: bool = bool(anchorController.call('try_add_carried_cargo', fruitNode))
	#region agent log
	_agent_debug_emit(
		'H3',
		'FruitTreeInteractable.gd:_on_item_valid',
		'try_add_carried_cargo result',
		{
			'added': added,
			'cooldownBeforeSet': _cooldownRemaining
		}
	)
	#endregion
	if not added:
		fruitNode.queue_free()
		return
	_cooldownRemaining = max(cooldownSec, 0.0)
	_play_pick_animation()
	_log_interact('fruit picked: type=%d' % fruitType)


## 空手交互不消耗携带物。
## @param item 携带物
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	var _unusedItem: Node = item
	return false


## 播放采摘摇晃动画。
func _play_pick_animation() -> void:
	if _treeAnim == null:
		return
	_treeAnim.play('cut')


## 应用果树顶部水果标识贴图。
func _apply_fruit_mark() -> void:
	var texture: Texture2D = FoodConfig.get_atlas_texture(fruitType)
	if _fruitMarkLeft != null:
		_fruitMarkLeft.texture = texture
	if _fruitMarkRight != null:
		_fruitMarkRight.texture = texture


## 帧动画结束后从 cut 回到 default。
func _on_tree_animation_finished() -> void:
	if _treeAnim == null:
		return
	if _treeAnim.animation == 'cut':
		_treeAnim.play('default')
