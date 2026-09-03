class_name Combat
extends RefCounted
## 자동 전투 순수 계산 (docs/01 v3 2.1: 전투는 동료가 자동, 플레이어는 이동·회피·부적 투척·후퇴).
## 능력치 → 체력·피해·간격, 적 → 플레이어 스태미너 피해, 전리품 추첨, 미니보스 재도전 체력. 수치는 전부 tuning(companion_*, enemy_*).


class Params:
	extends RefCounted
	var companion_hp_base: int = 20
	var companion_hp_per_courage: int = 4
	var companion_damage_base: int = 1
	var companion_attack_interval: float = 1.0
	var companion_skill_interval_bonus: float = 0.08
	var enemy_hit_stamina_per_attack: float = 6.0
	var boss_rematch_multiplier: float = 1.5

	static func from_tuning(tuning: TuningData) -> Params:
		var params := Params.new()
		params.companion_hp_base = tuning.get_int("companion_hp_base", params.companion_hp_base)
		params.companion_hp_per_courage = tuning.get_int("companion_hp_per_courage", params.companion_hp_per_courage)
		params.companion_damage_base = tuning.get_int("companion_damage_base", params.companion_damage_base)
		params.companion_attack_interval = tuning.get_float("companion_attack_interval_seconds", params.companion_attack_interval)
		params.companion_skill_interval_bonus = tuning.get_float("companion_skill_interval_bonus", params.companion_skill_interval_bonus)
		params.enemy_hit_stamina_per_attack = tuning.get_float("enemy_hit_stamina_per_attack", params.enemy_hit_stamina_per_attack)
		params.boss_rematch_multiplier = tuning.get_float("boss_rematch_multiplier", params.boss_rematch_multiplier)
		return params


## 동료 전투 체력 = 기본 + 담력 × 계수.
static func companion_hp(courage: int, params: Params) -> int:
	return maxi(params.companion_hp_base + courage * params.companion_hp_per_courage, 1)


## 동료 한 방 피해 = 기본 + 힘 (배식 버프 포함한 오늘 값).
static func companion_damage(strength: int, params: Params) -> int:
	return maxi(params.companion_damage_base + strength, 1)


## 동료 공격 간격 = 기본 - 솜씨 × 보너스 (최소 0.2초).
static func companion_attack_interval(skill: int, params: Params) -> float:
	return maxf(params.companion_attack_interval - float(skill) * params.companion_skill_interval_bonus, 0.2)


## 적 공격 1회가 플레이어 스태미너를 깎는 양.
static func enemy_stamina_damage(enemy: EnemyData, params: Params) -> float:
	return maxf(float(enemy.attack) * params.enemy_hit_stamina_per_attack, 0.0)


## 미니보스 체력. 이미 한 번 이겼고 재도전이 열렸으면 배율만큼 세다.
static func enemy_hp(enemy: EnemyData, rematch: bool, params: Params) -> int:
	if enemy.tier == "boss" and rematch:
		return maxi(int(ceil(enemy.hp * params.boss_rematch_multiplier)), 1)
	return maxi(enemy.hp, 1)


## 전리품. 떨어지지 않으면 "".
static func roll_drop(enemy: EnemyData, rng: RandomNumberGenerator) -> String:
	if enemy.drop_material.is_empty() or enemy.drop_chance <= 0.0:
		return ""
	return enemy.drop_material if rng.randf() < enemy.drop_chance else ""


## 적을 놓을 x 자리를 구역 폭 안에 고르게 편다.
static func spawn_positions(width_px: float, count: int, from_ratio: float, to_ratio: float) -> Array[float]:
	var result: Array[float] = []
	if count <= 0:
		return result
	var x0 := width_px * from_ratio
	var x1 := width_px * to_ratio
	for k in count:
		result.append(x0 + (x1 - x0) * (float(k) + 0.5) / float(count))
	return result
