class_name Clarity
extends RefCounted
## '관심받으면 또렷해짐' (docs/06 어둑이): 호감도를 스프라이트 투명도로 옮기는 순수 계산.
## clarity_by_affinity 가 아닌 요괴는 항상 1.0.


static func alpha_for(yokai: YokaiData, affinity: int, alpha_min: float, affinity_max: int) -> float:
	if yokai == null or not yokai.clarity_by_affinity:
		return 1.0
	if affinity_max <= 0:
		return 1.0
	var t := clampf(float(affinity) / float(affinity_max), 0.0, 1.0)
	return lerpf(alpha_min, 1.0, t)
