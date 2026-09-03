class_name HintPicker
extends RefCounted
## hints.csv 조건(시간대·날짜·필요 플래그·차단 플래그)을 평가해 지금 보여줄 안내 문구를 고른다.

const TIMEBAND_ANY := "any"


static func is_eligible(hint: HintData, timeband: String, day: int, flags: Dictionary) -> bool:
	if hint.timeband != TIMEBAND_ANY and hint.timeband != timeband:
		return false
	if day < hint.day_min:
		return false
	if hint.day_max > 0 and day > hint.day_max:
		return false
	if not hint.requires_flag.is_empty() and not flags.has(hint.requires_flag):
		return false
	if not hint.blocked_by_flag.is_empty() and flags.has(hint.blocked_by_flag):
		return false
	return true


## priority 내림차순, 같으면 id 순. 없으면 null.
static func pick(hints: Dictionary, timeband: String, day: int, flags: Dictionary) -> HintData:
	var best: HintData = null
	for hint: HintData in hints.values():
		if not is_eligible(hint, timeband, day, flags):
			continue
		if best == null or hint.priority > best.priority or (hint.priority == best.priority and hint.id < best.id):
			best = hint
	return best
