class_name FestivalRules
extends RefCounted
## 명절 채점 순수 로직 (P2-S2 동지). 점수 = 충족한 준비 목표 × score_per_goal + min(손님, guest_target) × score_per_guest
## + min(나눈 그릇, dish_target) × score_per_dish. 만점 = 셋을 다 채운 값. 노드·씬 의존 없음.


class Tally:
	extends RefCounted
	var goals_met: int = 0
	var guests: int = 0
	var dishes: int = 0


static func is_today(festival: FestivalData, season_id: String, day_of_season: int) -> bool:
	return festival.season == season_id and festival.day_of_season == day_of_season


static func max_score(festival: FestivalData) -> int:
	return festival.goal_ids.size() * festival.score_per_goal \
		+ festival.guest_target * festival.score_per_guest \
		+ festival.dish_target * festival.score_per_dish


static func score(festival: FestivalData, tally: Tally) -> int:
	return mini(tally.goals_met, festival.goal_ids.size()) * festival.score_per_goal \
		+ mini(tally.guests, festival.guest_target) * festival.score_per_guest \
		+ mini(tally.dishes, festival.dish_target) * festival.score_per_dish


static func is_perfect(festival: FestivalData, value: int) -> bool:
	return value >= max_score(festival)


## 이 절기의 명절을 날짜 순으로.
static func in_season(festivals: Dictionary, season_id: String) -> Array[FestivalData]:
	var result: Array[FestivalData] = []
	for festival: FestivalData in festivals.values():
		if festival.season == season_id:
			result.append(festival)
	result.sort_custom(func(a: FestivalData, b: FestivalData) -> bool:
		if a.day_of_season != b.day_of_season:
			return a.day_of_season < b.day_of_season
		return a.id < b.id)
	return result
