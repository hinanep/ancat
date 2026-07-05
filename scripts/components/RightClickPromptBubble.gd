class_name RightClickPromptBubble
extends Node2D

## 右键交互提示气泡：显示右键图标与上下弹跳动画，自行检测玩家距离并更新显隐。

enum PromptMode {
	PICKUP,
	INTERACT
}

var _mode: PromptMode = PromptMode.PICKUP
var _targetNode: Node2D
var _interactable: Node
var _cookPreviewBubble: Node

@onready var _promptIcon: Sprite2D = $PromptContainer/PromptIcon
@onready var _floatPlayer: AnimationPlayer = $PromptFloatPlayer


## 配置为拾取提示并启用每帧检测。
## @param target 可拾取目标
## @return void
func configure_pickup(target: Node2D) -> void:
	_mode = PromptMode.PICKUP
	_targetNode = target
	_interactable = null
	_cookPreviewBubble = null
	hide_prompt()
	set_process(true)


## 配置为交互提示并启用每帧检测。
## @param interactable 可交互范围组件
## @param cookPreviewBubble 烹饪预览气泡（显示时隐藏右键提示）
## @return void
func configure_interact(interactable: Node, cookPreviewBubble: Node = null) -> void:
	_mode = PromptMode.INTERACT
	_targetNode = null
	_interactable = interactable
	_cookPreviewBubble = cookPreviewBubble
	hide_prompt()
	set_process(true)


## 每帧根据玩家距离更新显隐。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	var _unusedDelta: float = delta
	var resolved: Dictionary = _resolve_anchor_and_player(get_tree())
	var anchorController: Node = resolved.get('anchor', null)
	var playerNode: Node2D = resolved.get('player', null) as Node2D
	var shouldShow: bool = false
	match _mode:
		PromptMode.PICKUP:
			shouldShow = _should_show_pickup_prompt(_targetNode, anchorController, playerNode)
		PromptMode.INTERACT:
			var cookPreviewVisible: bool = _cookPreviewBubble != null and _cookPreviewBubble.visible
			var blockEmptyHandInteract: bool = _has_nearby_pickup_target(anchorController, playerNode)
			shouldShow = _should_show_interact_prompt(
				_interactable,
				anchorController,
				playerNode,
				cookPreviewVisible,
				blockEmptyHandInteract
			)
		_:
			shouldShow = false
	if shouldShow:
		show_prompt()
	else:
		hide_prompt()


## 显示提示并播放弹跳动画。
## @return void
func show_prompt() -> void:
	visible = true
	if _floatPlayer != null and _floatPlayer.current_animation != 'float':
		_floatPlayer.play('float')


## 隐藏提示并停止弹跳动画。
## @return void
func hide_prompt() -> void:
	visible = false
	if _floatPlayer != null:
		_floatPlayer.stop()


## 从场景树解析锚控制器与玩家节点。
## @param tree 场景树
## @return Dictionary {anchor: Node, player: Node2D}
func _resolve_anchor_and_player(tree: SceneTree) -> Dictionary:
	var anchorController: Node = tree.get_first_node_in_group('AnchorController')
	if anchorController == null:
		return {'anchor': null, 'player': null}
	var playerNode: Node2D = null
	if anchorController.has_method('get_player_node'):
		playerNode = anchorController.call('get_player_node') as Node2D
	return {'anchor': anchorController, 'player': playerNode}


## 判断附近是否存在可拾取物。
## @param anchorController 锚控制器
## @param playerNode 玩家节点
## @return bool
func _has_nearby_pickup_target(anchorController: Node, playerNode: Node2D) -> bool:
	if anchorController == null or playerNode == null:
		return false
	var carriedItem: Node = null
	if anchorController.has_method('get_top_carried_item'):
		carriedItem = anchorController.call('get_top_carried_item') as Node
	if carriedItem != null:
		return false
	var promptRadius: float = _resolve_prompt_radius(anchorController)
	for node in get_tree().get_nodes_in_group('Hitable'):
		if not (node is Node2D):
			continue
		if node.has_method('can_be_hooked') and not bool(node.call('can_be_hooked')):
			continue
		var body: Node2D = node as Node2D
		if body.global_position.distance_to(playerNode.global_position) <= promptRadius:
			return true
	return false


## 判断是否应显示拾取提示。
## @param target 可拾取目标
## @param anchorController 锚控制器
## @param playerNode 玩家节点
## @return bool
func _should_show_pickup_prompt(target: Node2D, anchorController: Node, playerNode: Node2D) -> bool:
	if target == null or anchorController == null or playerNode == null:
		return false
	if target.has_method('can_be_hooked') and not bool(target.call('can_be_hooked')):
		return false
	var promptRadius: float = _resolve_prompt_radius(anchorController)
	return target.global_position.distance_to(playerNode.global_position) <= promptRadius


## 判断是否应显示交互提示。
## @param interactable 可交互范围组件
## @param anchorController 锚控制器
## @param playerNode 玩家节点
## @param cookPreviewVisible 烹饪预览是否正在显示
## @param blockEmptyHandInteract 空手时是否存在可拾取物
## @return bool
func _should_show_interact_prompt(
	interactable: Node,
	anchorController: Node,
	playerNode: Node2D,
	cookPreviewVisible: bool,
	blockEmptyHandInteract: bool
) -> bool:
	if cookPreviewVisible:
		return false
	if interactable == null or anchorController == null or playerNode == null:
		return false
	if interactable.has_method('should_show_right_click_prompt'):
		return bool(interactable.call('should_show_right_click_prompt', anchorController, blockEmptyHandInteract))
	return false


## 解析拾取提示显示半径。
## @param anchorController 锚控制器
## @return float
func _resolve_prompt_radius(anchorController: Node) -> float:
	if anchorController == null:
		return 96.0
	if anchorController.has_method('get_prompt_radius'):
		return max(float(anchorController.call('get_prompt_radius')), 0.0)
	var promptRadiusValue: Variant = anchorController.get('promptRadius')
	if typeof(promptRadiusValue) == TYPE_FLOAT or typeof(promptRadiusValue) == TYPE_INT:
		return max(float(promptRadiusValue), 0.0)
	var pickupRadius: float = 52.0
	var pickupRadiusValue: Variant = anchorController.get('pickupRadius')
	if typeof(pickupRadiusValue) == TYPE_FLOAT or typeof(pickupRadiusValue) == TYPE_INT:
		pickupRadius = float(pickupRadiusValue)
	return max(pickupRadius, 0.0)
