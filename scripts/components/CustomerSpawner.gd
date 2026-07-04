extends Node

## 顾客刷新管理：按阶段需求池定时刷客，频率随进度加快。
## @customerScene 顾客预制体
## @diningCabinNames 就餐区舱室名（基础名）
## @vipCabinName VIP舱室基础名
## @spawnIntervalSec 初始刷新间隔（秒）
## @minSpawnIntervalSec 最小刷新间隔（秒）
## @spawnAccelFactor 每次刷新后的间隔倍率（<1 逐渐加快）
## @maxCustomers 最大同时顾客数
@export var customerScene: PackedScene = ResPath.PROP_SCENES.CUSTOMER_ENTITY
@export var diningCabinNames: PackedStringArray = PackedStringArray(['Cabin6', 'Cabin8', 'Cabin9'])
@export var vipCabinName: StringName = 'Cabin8'
@export var spawnIntervalSec: float = 60.0
@export var minSpawnIntervalSec: float = 20.0
@export var spawnAccelFactor: float = 0.95
@export var maxCustomers: int = 6
@export var midStageStartServedCount: int = 3
@export var lateStageStartServedCount: int = 8
@export var debugSpawnerLog: bool = true

const _DEFAULT_DINING_CABIN_NAMES: Array[String] = ['Cabin6', 'Cabin8', 'Cabin9']
const _DEFAULT_VIP_CABIN_NAME: StringName = 'Cabin8'

var _spawnTimer: float = 0.0
var _currentIntervalSec: float = 60.0
var _servedCustomerCount: int = 0
var _activeCustomers: Array[Node] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
const _AGENT_DEBUG_LOG_PATH: String = 'C:/Users/nep/Desktop/mao/debug-aaf6f7.log'
const _AGENT_DEBUG_SESSION_ID: String = 'aaf6f7'
const _AGENT_DEBUG_RUN_ID: String = 'run-1'


## 初始化刷新器。
func _ready() -> void:
	_rng.randomize()
	if customerScene == null:
		customerScene = ResPath.PROP_SCENES.CUSTOMER_ENTITY
	if diningCabinNames.is_empty():
		diningCabinNames = PackedStringArray(_DEFAULT_DINING_CABIN_NAMES)
	if String(vipCabinName).is_empty():
		vipCabinName = _DEFAULT_VIP_CABIN_NAME
	_currentIntervalSec = max(spawnIntervalSec, 1.0)
	EventBus.subscribe(_on_event)
	#region agent log
	_agent_debug_emit(
		'H5',
		'CustomerSpawner.gd:_ready',
		'spawner initialized',
		{
			'spawnIntervalSec': spawnIntervalSec,
			'minSpawnIntervalSec': minSpawnIntervalSec,
			'maxCustomers': maxCustomers,
			'customerSceneNull': customerScene == null,
			'diningCabinNames': diningCabinNames,
			'vipCabinName': String(vipCabinName)
		}
	)
	#endregion


## 退出时取消订阅。
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 每帧推进刷新计时。
## @param delta 帧间隔（秒）
func _process(delta: float) -> void:
	_cleanup_customers()
	if _activeCustomers.size() >= max(maxCustomers, 1):
		return
	_spawnTimer += delta
	if _spawnTimer < _currentIntervalSec:
		return
	_spawnTimer = 0.0
	_try_spawn_customer()
	_currentIntervalSec = max(minSpawnIntervalSec, _currentIntervalSec * clampf(spawnAccelFactor, 0.5, 1.0))


## 尝试生成顾客。
func _try_spawn_customer() -> void:
	#region agent log
	_agent_debug_emit(
		'H5',
		'CustomerSpawner.gd:_try_spawn_customer',
		'try spawn start',
		{
			'activeCustomers': _activeCustomers.size(),
			'servedCount': _servedCustomerCount,
			'customerSceneNull': customerScene == null
		}
	)
	#endregion
	if customerScene == null:
		#region agent log
		_agent_debug_emit('H5', 'CustomerSpawner.gd:_try_spawn_customer', 'spawn blocked customerScene null', {})
		#endregion
		return
	var cabins: Array[Cabin] = _resolve_dining_cabins()
	if cabins.is_empty():
		#region agent log
		_agent_debug_emit('H6', 'CustomerSpawner.gd:_try_spawn_customer', 'spawn blocked no dining cabins', {})
		#endregion
		return
	var targetCabin: Cabin = cabins[_rng.randi_range(0, cabins.size() - 1)]
	var customer: Node2D = customerScene.instantiate() as Node2D
	if customer == null:
		#region agent log
		_agent_debug_emit('H5', 'CustomerSpawner.gd:_try_spawn_customer', 'spawn blocked instantiate null', {})
		#endregion
		return
	targetCabin.add_child(customer)
	customer.global_position = targetCabin.global_position + Vector2(_rng.randf_range(-120.0, 120.0), 20.0)
	var demandTemplate: Array[int] = _pick_demand_template()
	var cabinBaseName: String = _to_base_cabin_name(targetCabin.name)
	var isVip: bool = cabinBaseName == String(vipCabinName)
	if customer.has_method('initialize_customer'):
		customer.call('initialize_customer', demandTemplate, isVip)
	_activeCustomers.append(customer)
	EventBus.emit(EventBus.EventType.CUSTOMER_SPAWNED, {
		'cabin': targetCabin.name,
		'vip': isVip,
		'demands': demandTemplate
	})
	AudioManager.play_sfx_random(ResPath.AUDIO.CAT_MEOW)
	_debug_log('spawn customer in %s, vip=%s, interval=%.2f' % [targetCabin.name, str(isVip), _currentIntervalSec])
	#region agent log
	_agent_debug_emit(
		'H5',
		'CustomerSpawner.gd:_try_spawn_customer',
		'spawn success',
		{
			'cabin': targetCabin.name,
			'isVip': isVip,
			'activeAfterSpawn': _activeCustomers.size()
		}
	)
	#endregion


## 根据已服务顾客数挑选需求模板。
## @return Array[int]
func _pick_demand_template() -> Array[int]:
	var pool: Array[Array] = FoodConfig.DEMAND_POOL_EARLY
	if _servedCustomerCount >= lateStageStartServedCount:
		pool = FoodConfig.DEMAND_POOL_LATE
	elif _servedCustomerCount >= midStageStartServedCount:
		pool = FoodConfig.DEMAND_POOL_MID
	if pool.is_empty():
		return [FoodConfig.FoodType.RAW_FISH]
	var picked: Array = pool[_rng.randi_range(0, pool.size() - 1)]
	var result: Array[int] = []
	for v in picked:
		result.append(int(v))
	return result


## 解析就餐区舱室列表。
## @return Array[Cabin]
func _resolve_dining_cabins() -> Array[Cabin]:
	var result: Array[Cabin] = []
	for node in get_tree().get_nodes_in_group('Cabin'):
		if not (node is Cabin):
			continue
		var cabin: Cabin = node as Cabin
		if diningCabinNames.has(_to_base_cabin_name(cabin.name)):
			result.append(cabin)
	#region agent log
	_agent_debug_emit(
		'H6',
		'CustomerSpawner.gd:_resolve_dining_cabins',
		'resolved dining cabins',
		{
			'configuredCabins': diningCabinNames,
			'resolvedCount': result.size()
		}
	)
	#endregion
	return result


## 将舱室节点名转换为基础名（去掉“-用途”后缀）。
## @param nodeName 节点名
## @return String
func _to_base_cabin_name(nodeName: String) -> String:
	var index: int = nodeName.find('-')
	if index == -1:
		return nodeName
	return nodeName.substr(0, index)


## 清理失效顾客引用。
func _cleanup_customers() -> void:
	for i in range(_activeCustomers.size() - 1, -1, -1):
		var customer: Node = _activeCustomers[i]
		if customer == null or not is_instance_valid(customer):
			_activeCustomers.remove_at(i)


## 处理全局事件。
## @param eventType 事件类型
## @param data 数据
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	if eventType != EventBus.EventType.CUSTOMER_LEFT:
		return
	if bool(data.get('satisfied', false)):
		_servedCustomerCount += 1


## 调试日志输出。
## @param message 日志文本
func _debug_log(message: String) -> void:
	if not debugSpawnerLog:
		return
	print('[CustomerSpawner] %s' % message)


## 调试日志写入。
## @param hypothesisId 假设编号
## @param location 位置
## @param message 消息
## @param data 数据
## @return void
func _agent_debug_emit(hypothesisId: String, location: String, message: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		'sessionId': _AGENT_DEBUG_SESSION_ID,
		'runId': _AGENT_DEBUG_RUN_ID,
		'hypothesisId': hypothesisId,
		'location': location,
		'message': message,
		'data': data,
		'timestamp': Time.get_unix_time_from_system() * 1000.0
	}
	var file: FileAccess = null
	if FileAccess.file_exists(_AGENT_DEBUG_LOG_PATH):
		file = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
