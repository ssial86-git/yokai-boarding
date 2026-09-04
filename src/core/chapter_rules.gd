class_name ChapterRules
extends RefCounted
## 챕터 게이트·뜨내기 승격 순수 로직 (P2-S4). 챕터 게이트 = 병렬 목표 중 gate_required 개 완료 (서사를 읽지 않아도 막히지 않게 — docs/05 7절).
## 승격 = promotable 종족이 방문 누계·평판 조건을 채우면 promotes_to 하숙생으로 장기 계약을 청한다.


static func first(chapters: Dictionary) -> ChapterData:
	var best: ChapterData = null
	for chapter: ChapterData in chapters.values():
		if best == null or chapter.order < best.order:
			best = chapter
	return best


## 완료한 게이트 목표 수 / 전체.
static func gate_progress(chapter: ChapterData, goals_done: Dictionary) -> Vector2i:
	var met := 0
	for goal_id in chapter.gate_goals:
		if goals_done.has(goal_id):
			met += 1
	return Vector2i(met, chapter.gate_goals.size())


## 다음 챕터로 넘어갈 수 있는가. 게이트 목표가 없거나 필요 수가 0 이면 넘어가지 않는다 (마지막·자리표시 챕터).
static func gate_met(chapter: ChapterData, goals_done: Dictionary) -> bool:
	if chapter == null or chapter.gate_goals.is_empty() or chapter.gate_required <= 0 or chapter.next_id.is_empty():
		return false
	return gate_progress(chapter, goals_done).x >= chapter.gate_required


## 승격 조건을 채운 종족의 하숙생 id 들 (id 순). 이미 입주했거나 promotes_to 가 없으면 제외.
static func promotable_yokai(
	species_catalog: Dictionary, ledger: Dictionary, reputation: int, residents: Array[String], visits_needed: int, reputation_needed: int
) -> Array[String]:
	var result: Array[String] = []
	if reputation < reputation_needed:
		return result
	for species: GuestSpeciesData in species_catalog.values():
		if not species.promotable or species.promotes_to.is_empty() or residents.has(species.promotes_to):
			continue
		if int(ledger.get(species.id, 0)) >= visits_needed:
			result.append(species.promotes_to)
	result.sort()
	return result


## promotes_to 가 yokai_id 인 종족. 없으면 null.
static func species_for_yokai(species_catalog: Dictionary, yokai_id: String) -> GuestSpeciesData:
	for species: GuestSpeciesData in species_catalog.values():
		if species.promotes_to == yokai_id:
			return species
	return null
