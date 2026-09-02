class_name Intake
extends RefCounted
## 입주 심사 결정 순수 로직 (docs/07 2절). 받기/거절만 있고 '하룻밤만' 은 슬라이스에서 받기와 같다.

enum Decision { ACCEPT, DECLINE }
enum Outcome { ACCEPTED, DECLINED, NO_BED }


class Params:
	extends RefCounted
	var stay_nights: int = 1
	var accept_reputation_gain: int = 1
	var decline_reputation_penalty: int = 1
	var decline_omen_threshold: int = 2

	static func from_tuning(tuning: TuningData) -> Params:
		var params := Params.new()
		params.stay_nights = tuning.get_int("guest_stay_nights", params.stay_nights)
		params.accept_reputation_gain = tuning.get_int("accept_reputation_gain", params.accept_reputation_gain)
		params.decline_reputation_penalty = tuning.get_int("decline_reputation_penalty", params.decline_reputation_penalty)
		params.decline_omen_threshold = tuning.get_int("decline_omen_threshold", params.decline_omen_threshold)
		return params


class Result:
	extends RefCounted
	var outcome: Outcome = Outcome.DECLINED
	var reputation_delta: int = 0
	var joined_yokai_id: String = ""
	var guest: Dictionary = {}  # 체류 손님 레코드 (guest 유형만)


static func decide(visitor: VisitorRoll.Visitor, decision: Decision, free_beds: int, day: int, params: Params) -> Result:
	var result := Result.new()
	if decision == Decision.DECLINE:
		result.outcome = Outcome.DECLINED
		# 액운이 큰 손님을 돌려보내는 건 정당하다 (docs/07: 정당한 거절은 무해)
		if visitor.omen < params.decline_omen_threshold:
			result.reputation_delta = -params.decline_reputation_penalty
		return result
	if free_beds <= 0:
		result.outcome = Outcome.NO_BED
		return result
	result.outcome = Outcome.ACCEPTED
	result.reputation_delta = params.accept_reputation_gain
	if visitor.kind == "erased":
		result.joined_yokai_id = visitor.yokai_id
	else:
		result.guest = {
			"species_id": visitor.species_id,
			"visitor_id": visitor.visitor_id,
			"arrived_day": day,
			"depart_day": day + params.stay_nights,
			"omen": visitor.omen,
		}
	return result
