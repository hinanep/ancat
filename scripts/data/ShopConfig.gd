extends RefCounted

## 商店配置：统一定义升级项、价格、档位效果与运行时键名。
## @UPGRADE_IDS 商店展示顺序
## @LEVEL_KEYS 每个升级项对应的 GameState 等级键
## @FINITE_TIERS 有限档位升级数据（每档价格与效果）
class_name ShopConfig

const UPGRADE_ANCHOR_COUNT: StringName = &'anchor_count'
const UPGRADE_ANCHOR_LENGTH: StringName = &'anchor_length'
const UPGRADE_MOVE_SPEED: StringName = &'move_speed'
const UPGRADE_MORE_POT: StringName = &'more_pot'
const UPGRADE_FASTER_PROCESS: StringName = &'faster_process'

const UPGRADE_IDS: Array[StringName] = [
	UPGRADE_ANCHOR_COUNT,
	UPGRADE_ANCHOR_LENGTH,
	UPGRADE_MOVE_SPEED,
	UPGRADE_MORE_POT,
	UPGRADE_FASTER_PROCESS,
]

const LEVEL_KEYS := {
	UPGRADE_ANCHOR_COUNT: &'upgrade_anchor_count_level',
	UPGRADE_ANCHOR_LENGTH: &'upgrade_anchor_length_level',
	UPGRADE_MOVE_SPEED: &'upgrade_move_speed_level',
	UPGRADE_MORE_POT: &'upgrade_more_pot_level',
	UPGRADE_FASTER_PROCESS: &'upgrade_faster_process_level',
}

const FINITE_TIERS := {
	UPGRADE_ANCHOR_LENGTH: [
		{'price': 2000, 'effect': 1.0},
		{'price': 5000, 'effect': 2.0},
	],
	UPGRADE_MOVE_SPEED: [
		{'price': 1000, 'effect': 1.1},
		{'price': 2000, 'effect': 1.2},
		{'price': 4000, 'effect': 1.5},
	],
	UPGRADE_MORE_POT: [
		{'price': 1000, 'effect': 1},
		{'price': 2000, 'effect': 2},
		{'price': 4000, 'effect': 3},
	],
	UPGRADE_FASTER_PROCESS: [
		{'price': 1000, 'effect': 5.0},
		{'price': 3000, 'effect': 10.0},
		{'price': 5000, 'effect': 15.0},
	],
}


## 获取升级项显示名。
## @param upgradeId 升级项ID
## @return String
static func get_display_name(upgradeId: StringName) -> String:
	match upgradeId:
		UPGRADE_ANCHOR_COUNT:
			return '更多锚'
		UPGRADE_ANCHOR_LENGTH:
			return '锚长度'
		UPGRADE_MOVE_SPEED:
			return '移动速度'
		UPGRADE_MORE_POT:
			return '更多锅'
		UPGRADE_FASTER_PROCESS:
			return '更快处理'
		_:
			return String(upgradeId)


## 获取升级项等级键。
## @param upgradeId 升级项ID
## @return StringName
static func get_level_key(upgradeId: StringName) -> StringName:
	return LEVEL_KEYS.get(upgradeId, &'')


## 是否为无限档位升级。
## @param upgradeId 升级项ID
## @return bool
static func is_infinite(upgradeId: StringName) -> bool:
	return upgradeId == UPGRADE_ANCHOR_COUNT


## 获取升级最大档位，-1 表示无限档位。
## @param upgradeId 升级项ID
## @return int
static func get_max_level(upgradeId: StringName) -> int:
	if is_infinite(upgradeId):
		return -1
	var tiers: Array = FINITE_TIERS.get(upgradeId, [])
	return tiers.size()


## 获取下一档价格，不可购买时返回 -1。
## @param upgradeId 升级项ID
## @param currentLevel 当前等级
## @return int
static func get_next_price(upgradeId: StringName, currentLevel: int) -> int:
	var safeLevel: int = max(currentLevel, 0)
	if upgradeId == UPGRADE_ANCHOR_COUNT:
		return 1000 * (safeLevel + 1)
	var tiers: Array = FINITE_TIERS.get(upgradeId, [])
	if safeLevel >= tiers.size():
		return -1
	return int(tiers[safeLevel].get('price', -1))


## 获取指定等级对应的效果值（按最高档覆盖）。
## @param upgradeId 升级项ID
## @param level 升级等级
## @return Variant
static func get_effect_value(upgradeId: StringName, level: int) -> Variant:
	var safeLevel: int = max(level, 0)
	if upgradeId == UPGRADE_ANCHOR_COUNT:
		return safeLevel
	if safeLevel <= 0:
		return _default_effect(upgradeId)
	var tiers: Array = FINITE_TIERS.get(upgradeId, [])
	if tiers.is_empty():
		return _default_effect(upgradeId)
	var index: int = clampi(safeLevel - 1, 0, tiers.size() - 1)
	return tiers[index].get('effect', _default_effect(upgradeId))


## 获取当前等级对应的效果描述文本。
## @param upgradeId 升级项ID
## @param level 升级等级
## @return String
static func get_current_effect_text(upgradeId: StringName, level: int) -> String:
	var safeLevel: int = max(level, 0)
	match upgradeId:
		UPGRADE_ANCHOR_COUNT:
			return '+%d' % int(get_effect_value(upgradeId, safeLevel))
		UPGRADE_ANCHOR_LENGTH:
			return '+%d' % int(get_effect_value(upgradeId, safeLevel))
		UPGRADE_MOVE_SPEED:
			return 'x%.1f' % float(get_effect_value(upgradeId, safeLevel))
		UPGRADE_MORE_POT:
			return '+%d' % int(get_effect_value(upgradeId, safeLevel))
		UPGRADE_FASTER_PROCESS:
			return '-%ds' % int(get_effect_value(upgradeId, safeLevel))
		_:
			return '-'


## 获取下一档效果描述文本，不可升级时返回“已满级”。
## @param upgradeId 升级项ID
## @param currentLevel 当前等级
## @return String
static func get_next_effect_text(upgradeId: StringName, currentLevel: int) -> String:
	var safeLevel: int = max(currentLevel, 0)
	var nextLevel: int = safeLevel + 1
	var maxLevel: int = get_max_level(upgradeId)
	if maxLevel >= 0 and safeLevel >= maxLevel:
		return '已满级'
	match upgradeId:
		UPGRADE_ANCHOR_COUNT:
			return '+%d' % nextLevel
		UPGRADE_ANCHOR_LENGTH:
			return '+%d' % int(get_effect_value(upgradeId, nextLevel))
		UPGRADE_MOVE_SPEED:
			return 'x%.1f' % float(get_effect_value(upgradeId, nextLevel))
		UPGRADE_MORE_POT:
			return '+%d' % int(get_effect_value(upgradeId, nextLevel))
		UPGRADE_FASTER_PROCESS:
			return '-%ds' % int(get_effect_value(upgradeId, nextLevel))
		_:
			return '-'


## 判断当前等级是否已满级。
## @param upgradeId 升级项ID
## @param currentLevel 当前等级
## @return bool
static func is_max_level(upgradeId: StringName, currentLevel: int) -> bool:
	var maxLevel: int = get_max_level(upgradeId)
	if maxLevel < 0:
		return false
	return currentLevel >= maxLevel


## 返回升级项默认效果值。
## @param upgradeId 升级项ID
## @return Variant
static func _default_effect(upgradeId: StringName) -> Variant:
	match upgradeId:
		UPGRADE_MOVE_SPEED:
			return 1.0
		_:
			return 0
