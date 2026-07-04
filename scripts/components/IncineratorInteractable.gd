extends InteractableBase

## 焚化炉交互参数：控制可销毁目标、处理时长与锚合法性兜底规则。
## 可销毁物品标签白名单。
@export var acceptedTags: PackedStringArray = PackedStringArray(['food'])
## 不可销毁分组名（在该分组中的物品一律拒绝）。
@export var nonIncinerableGroup: StringName = 'NonIncinerable'
## 焚化处理时长（秒）。
@export var processDurationSec: float = 10.0
## 处理中的物品相对焚化炉位置偏移。
@export var processItemOffset: Vector2 = Vector2(0.0, -14.0)
## 当前交互点是否允许“锚合法”分支。
@export var allowAnchorInteract: bool = false

var _processingItem: Node
var _processingRemainingSec: float = 0.0
var _isProcessing: bool = false


## 判断物品是否可焚化（白名单 + 非不可销毁组）。
## @param item 携带物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	if item.is_in_group(nonIncinerableGroup):
		return false
	return true


## 处理前状态校验：焚化期间拒绝新请求。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return bool
func _can_interact_now(player: Node, item: Node, anchorController: Node) -> bool:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController
	if _isProcessing:
		_log_interact('interact rejected: busy')
		return false
	return true


## 锚合法性判定：由本焚化炉开关控制。
## @param anchorController 锚控制器
## @return bool
func _is_anchor_valid(anchorController: Node) -> bool:
	return allowAnchorInteract and anchorController != null


## 物品合法时启动焚化计时，不立即销毁。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchorController: Node = anchorController
	_processingItem = item
	_processingRemainingSec = max(processDurationSec, 0.0)
	_isProcessing = true
	if item != null and item.has_method('drop_to_world'):
		item.call('drop_to_world')
	if item is Node2D:
		(item as Node2D).global_position = global_position + processItemOffset
	if item != null and item.has_method('set_physics_process'):
		item.call('set_physics_process', false)
	_log_interact('interact accepted: item processing started')


## 锚合法分支回调。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_anchor_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController
	_log_interact('interact accepted: anchor valid branch')


## 每帧推进焚化计时并在完成时销毁物品。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	if not _isProcessing:
		return
	_processingRemainingSec = max(_processingRemainingSec - delta, 0.0)
	if _processingRemainingSec > 0.0:
		return
	var item: Node = _processingItem
	_processingItem = null
	_processingRemainingSec = 0.0
	_isProcessing = false
	if item == null or not is_instance_valid(item):
		_log_interact('processing finish: item already gone')
		return
	_consume_item(item)
	_log_interact('processing finish: item destroyed')
