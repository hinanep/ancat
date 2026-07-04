extends Control

## 局内商店面板：负责展示升级项、执行扣款购买并即时应用升级效果。
## @potSpawnSpacing 新增锅横向间距
## @potSpawnYOffset 新增锅纵向偏移
@export var potSpawnSpacing: float = 72.0
@export var potSpawnYOffset: float = 0.0

const POT_SCENE: PackedScene = preload('res://scenes/props/Interactable/PotCargo.tscn')

@onready var _anchorCountButton: Button = $ShopRoot/Rows/AnchorCountRow/BuyButton
@onready var _anchorCountPriceLabel: Label = $ShopRoot/Rows/AnchorCountRow/PriceLabel
@onready var _anchorLengthButton: Button = $ShopRoot/Rows/AnchorLengthRow/BuyButton
@onready var _anchorLengthPriceLabel: Label = $ShopRoot/Rows/AnchorLengthRow/PriceLabel
@onready var _moveSpeedButton: Button = $ShopRoot/Rows/MoveSpeedRow/BuyButton
@onready var _moveSpeedPriceLabel: Label = $ShopRoot/Rows/MoveSpeedRow/PriceLabel
@onready var _morePotButton: Button = $ShopRoot/Rows/MorePotRow/BuyButton
@onready var _morePotPriceLabel: Label = $ShopRoot/Rows/MorePotRow/PriceLabel
@onready var _fasterProcessButton: Button = $ShopRoot/Rows/FasterProcessRow/BuyButton
@onready var _fasterProcessPriceLabel: Label = $ShopRoot/Rows/FasterProcessRow/PriceLabel

var _rowDataByUpgradeId: Dictionary = {}
var _player: Node
var _anchorController: Node
var _cabinsNode: Node2D
var _baseAnchorCount: int = 1
var _baseAnchorLength: float = 520.0
var _baseMoveSpeed: float = 240.0
var _basePotCount: int = 0
var _basePotCookSec: float = 30.0
var _baseFryingCookSec: float = 20.0
var _baseBoardProcessSec: float = 5.0
var _currentProcessReductionSec: float = 0.0
var _potSpawnBaseGlobalPos: Vector2 = Vector2.ZERO


## 初始化商店 UI、构建条目并应用当前升级状态。
## @return void
func _ready() -> void:
	_resolve_runtime_nodes()
	_capture_base_values()
	_cache_upgrade_rows()
	if not GameState.value_changed.is_connected(_on_game_state_value_changed):
		GameState.value_changed.connect(_on_game_state_value_changed)
	_apply_all_upgrades()
	_refresh_all_rows()


## 退出场景时取消信号连接。
## @return void
func _exit_tree() -> void:
	if GameState.value_changed.is_connected(_on_game_state_value_changed):
		GameState.value_changed.disconnect(_on_game_state_value_changed)


## 处理 GameState 值变化，刷新受影响的 UI。
## @param key 状态键
## @param _value 新值
## @return void
func _on_game_state_value_changed(key: StringName, _value: Variant) -> void:
	if key == GameState.GOLD_KEY:
		_refresh_all_rows()


## 缓存场景中预置的升级条目节点，并绑定点击回调。
## @return void
func _cache_upgrade_rows() -> void:
	_rowDataByUpgradeId.clear()
	_register_upgrade_row(ShopConfig.UPGRADE_ANCHOR_COUNT, _anchorCountButton, _anchorCountPriceLabel)
	_register_upgrade_row(ShopConfig.UPGRADE_ANCHOR_LENGTH, _anchorLengthButton, _anchorLengthPriceLabel)
	_register_upgrade_row(ShopConfig.UPGRADE_MOVE_SPEED, _moveSpeedButton, _moveSpeedPriceLabel)
	_register_upgrade_row(ShopConfig.UPGRADE_MORE_POT, _morePotButton, _morePotPriceLabel)
	_register_upgrade_row(ShopConfig.UPGRADE_FASTER_PROCESS, _fasterProcessButton, _fasterProcessPriceLabel)


## 注册升级条目节点。
## @param upgradeId 升级项ID
## @param buyButton 购买按钮
## @param priceLabel 价格标签
## @return void
func _register_upgrade_row(upgradeId: StringName, buyButton: Button, priceLabel: Label) -> void:
	if buyButton == null or priceLabel == null:
		return
	buyButton.set_meta('upgrade_id', upgradeId)
	buyButton.pressed.connect(_on_buy_button_pressed.bind(buyButton))
	_rowDataByUpgradeId[upgradeId] = {
		'buy_button': buyButton,
		'price_label': priceLabel,
	}


## 处理某个升级项购买按钮点击。
## @param buyButton 被点击按钮
## @return void
func _on_buy_button_pressed(buyButton: Button) -> void:
	if buyButton == null or not buyButton.has_meta('upgrade_id'):
		return
	var upgradeId: StringName = buyButton.get_meta('upgrade_id', &'')
	_try_purchase_upgrade(upgradeId)


## 尝试购买升级：校验价格、金币与等级后写入并应用。
## @param upgradeId 升级项ID
## @return void
func _try_purchase_upgrade(upgradeId: StringName) -> void:
	var levelKey: StringName = ShopConfig.get_level_key(upgradeId)
	if levelKey == &'':
		return
	var currentLevel: int = GameState.get_upgrade_level(levelKey)
	if ShopConfig.is_max_level(upgradeId, currentLevel):
		return
	var nextPrice: int = ShopConfig.get_next_price(upgradeId, currentLevel)
	if nextPrice < 0:
		return
	if not GameState.spend_gold(nextPrice):
		return
	GameState.set_upgrade_level(levelKey, currentLevel + 1)
	AudioManager.play_sfx(ResPath.AUDIO.BUY_ITEM)
	_apply_upgrade(upgradeId)
	_refresh_all_rows()


## 刷新全部条目显示状态。
## @return void
func _refresh_all_rows() -> void:
	for upgradeId in ShopConfig.UPGRADE_IDS:
		_refresh_upgrade_row(upgradeId)


## 刷新单个升级条目文本与按钮状态。
## @param upgradeId 升级项ID
## @return void
func _refresh_upgrade_row(upgradeId: StringName) -> void:
	if not _rowDataByUpgradeId.has(upgradeId):
		return
	var rowData: Dictionary = _rowDataByUpgradeId[upgradeId]
	var buyButton: Button = rowData.get('buy_button', null) as Button
	var priceLabel: Label = rowData.get('price_label', null) as Label
	if priceLabel == null or buyButton == null:
		return
	var levelKey: StringName = ShopConfig.get_level_key(upgradeId)
	var currentLevel: int = GameState.get_upgrade_level(levelKey)
	var nextPrice: int = ShopConfig.get_next_price(upgradeId, currentLevel)
	var currentText: String = ShopConfig.get_current_effect_text(upgradeId, currentLevel)
	var nextText: String = ShopConfig.get_next_effect_text(upgradeId, currentLevel)
	var isMaxLevel: bool = ShopConfig.is_max_level(upgradeId, currentLevel)
	var displayName: String = ShopConfig.get_display_name(upgradeId)
	buyButton.text = '%s  Lv.%d  %s → %s' % [displayName, currentLevel, currentText, nextText]
	if isMaxLevel:
		buyButton.disabled = true
		priceLabel.text = '已满级'
		return
	buyButton.disabled = not GameState.can_afford(nextPrice)
	priceLabel.text = '%d' % nextPrice


## 应用所有已购升级到当前场景对象。
## @return void
func _apply_all_upgrades() -> void:
	for upgradeId in ShopConfig.UPGRADE_IDS:
		_apply_upgrade(upgradeId)


## 应用单个升级效果（按最高档覆盖生效）。
## @param upgradeId 升级项ID
## @return void
func _apply_upgrade(upgradeId: StringName) -> void:
	var levelKey: StringName = ShopConfig.get_level_key(upgradeId)
	var level: int = GameState.get_upgrade_level(levelKey)
	match upgradeId:
		ShopConfig.UPGRADE_ANCHOR_COUNT:
			_apply_anchor_count_upgrade(level)
		ShopConfig.UPGRADE_ANCHOR_LENGTH:
			_apply_anchor_length_upgrade(level)
		ShopConfig.UPGRADE_MOVE_SPEED:
			_apply_move_speed_upgrade(level)
		ShopConfig.UPGRADE_MORE_POT:
			_apply_more_pot_upgrade(level)
		ShopConfig.UPGRADE_FASTER_PROCESS:
			_apply_faster_process_upgrade(level)
		_:
			pass


## 应用锚数量升级。
## @param level 升级等级
## @return void
func _apply_anchor_count_upgrade(level: int) -> void:
	if _player == null:
		return
	var bonusCount: int = int(ShopConfig.get_effect_value(ShopConfig.UPGRADE_ANCHOR_COUNT, level))
	var targetCount: int = max(_baseAnchorCount + bonusCount, 1)
	_player.set('anchorCount', targetCount)
	if _anchorController != null:
		_anchorController.set('fallbackAnchorCount', targetCount)


## 应用锚长度升级。
## @param level 升级等级
## @return void
func _apply_anchor_length_upgrade(level: int) -> void:
	if _anchorController == null:
		return
	var bonusLength: float = float(ShopConfig.get_effect_value(ShopConfig.UPGRADE_ANCHOR_LENGTH, level))
	_anchorController.set('maxAnchorLength', max(_baseAnchorLength + bonusLength, 0.0))


## 应用移动速度升级。
## @param level 升级等级
## @return void
func _apply_move_speed_upgrade(level: int) -> void:
	if _player == null:
		return
	var speedMultiplier: float = float(ShopConfig.get_effect_value(ShopConfig.UPGRADE_MOVE_SPEED, level))
	_player.set('moveSpeed', max(_baseMoveSpeed * speedMultiplier, 1.0))


## 应用更多锅升级，按目标数量补齐锅实例。
## @param level 升级等级
## @return void
func _apply_more_pot_upgrade(level: int) -> void:
	var bonusPotCount: int = int(ShopConfig.get_effect_value(ShopConfig.UPGRADE_MORE_POT, level))
	var targetPotCount: int = max(_basePotCount + bonusPotCount, _basePotCount)
	_ensure_pot_count(targetPotCount)


## 应用更快处理升级（锅/煎锅/菜板）。
## @param level 升级等级
## @return void
func _apply_faster_process_upgrade(level: int) -> void:
	var reductionSec: float = float(ShopConfig.get_effect_value(ShopConfig.UPGRADE_FASTER_PROCESS, level))
	_currentProcessReductionSec = max(reductionSec, 0.0)
	_apply_processing_time_reduction(_currentProcessReductionSec)


## 补齐锅数量到目标值。
## @param targetCount 目标锅数量
## @return void
func _ensure_pot_count(targetCount: int) -> void:
	if _cabinsNode == null or POT_SCENE == null:
		return
	var currentCount: int = get_tree().get_nodes_in_group('Pot').size()
	while currentCount < targetCount:
		var potNode: Node = POT_SCENE.instantiate()
		if potNode == null:
			return
		_cabinsNode.add_child(potNode)
		if potNode is Node2D:
			var potNode2D: Node2D = potNode as Node2D
			potNode2D.z_index = 6
			potNode2D.scale = Vector2(2.0, 2.0)
			potNode2D.global_position = _next_spawn_pot_position(currentCount - _basePotCount)
		if potNode.has_method('apply_cook_total_sec'):
			potNode.call('apply_cook_total_sec', max(_basePotCookSec - _currentProcessReductionSec, 0.0))
		currentCount = get_tree().get_nodes_in_group('Pot').size()


## 计算新锅生成位置，基于初始锅位置向右平移。
## @param extraIndex 额外锅索引（从0开始）
## @return Vector2
func _next_spawn_pot_position(extraIndex: int) -> Vector2:
	return _potSpawnBaseGlobalPos + Vector2(potSpawnSpacing * float(extraIndex + 1), potSpawnYOffset)


## 把“减秒”效果应用到锅、煎锅、菜板处理总时长。
## @param reductionSec 缩减秒数
## @return void
func _apply_processing_time_reduction(reductionSec: float) -> void:
	var targetPotSec: float = max(_basePotCookSec - reductionSec, 0.0)
	var targetFryingSec: float = max(_baseFryingCookSec - reductionSec, 0.0)
	var targetBoardSec: float = max(_baseBoardProcessSec - reductionSec, 0.0)
	for node in get_tree().get_nodes_in_group('Pot'):
		if node == null:
			continue
		if node.has_method('apply_cook_total_sec'):
			node.call('apply_cook_total_sec', targetPotSec)
		else:
			node.set('totalCookSec', targetPotSec)
	for node in get_tree().get_nodes_in_group('FryingPan'):
		if node == null:
			continue
		if node.has_method('apply_cook_total_sec'):
			node.call('apply_cook_total_sec', targetFryingSec)
		else:
			node.set('totalCookSec', targetFryingSec)
	for node in get_tree().get_nodes_in_group('CuttingBoard'):
		if node == null:
			continue
		if node.has_method('apply_process_total_sec'):
			node.call('apply_process_total_sec', targetBoardSec)
		else:
			node.set('totalProcessSec', targetBoardSec)


## 定位场景中的玩家、锚控制器与舱室根节点。
## @return void
func _resolve_runtime_nodes() -> void:
	var currentScene: Node = get_tree().current_scene
	if currentScene == null:
		return
	_player = currentScene.get_node_or_null('Cabins/TestPlayer')
	_cabinsNode = currentScene.get_node_or_null('Cabins') as Node2D
	if _player != null:
		_anchorController = _player.get_node_or_null('AnchorController')


## 捕获运行时基线参数，作为升级覆盖计算的起点。
## @return void
func _capture_base_values() -> void:
	if _player != null:
		_baseAnchorCount = max(int(_player.get('anchorCount')), 1)
		_baseMoveSpeed = max(float(_player.get('moveSpeed')), 1.0)
	if _anchorController != null:
		_baseAnchorLength = max(float(_anchorController.get('maxAnchorLength')), 0.0)
	_basePotCount = get_tree().get_nodes_in_group('Pot').size()
	_basePotCookSec = _read_group_property_as_float('Pot', 'totalCookSec', 30.0)
	_baseFryingCookSec = _read_group_property_as_float('FryingPan', 'totalCookSec', 20.0)
	_baseBoardProcessSec = _read_group_property_as_float('CuttingBoard', 'totalProcessSec', 5.0)
	_potSpawnBaseGlobalPos = _resolve_base_pot_position()


## 从指定分组读取首个节点的属性值（float）。
## @param groupName 分组名
## @param propertyName 属性名
## @param fallback 兜底值
## @return float
func _read_group_property_as_float(groupName: StringName, propertyName: StringName, fallback: float) -> float:
	for node in get_tree().get_nodes_in_group(groupName):
		if node == null:
			continue
		var value: Variant = node.get(propertyName)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return fallback


## 获取初始锅基准位置（用于新增锅摆放）。
## @return Vector2
func _resolve_base_pot_position() -> Vector2:
	for node in get_tree().get_nodes_in_group('Pot'):
		if node is Node2D:
			return (node as Node2D).global_position
	if _cabinsNode != null:
		return _cabinsNode.global_position
	return Vector2.ZERO
