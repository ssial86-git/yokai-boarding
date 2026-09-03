class_name SeasonEventData
extends Resource
## 소절기 이벤트. data/csv/season_events.csv 한 행 = 이 리소스 하나 (P2-S1: 장마 시작·만월).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## 절기 id
@export var season: String = "spring"
## 절기 안 시작 날짜 (1~length)
@export var day_of_season: int = 1
@export var duration_days: int = 1
## 진행 중인 날의 날씨를 이 id 로 고정 (비우면 평소 추첨)
@export var weather_override: String = ""
## 채집 개수 배율 (1.0 = 그대로)
@export var gather_multiplier: float = 1.0
## 마계 손님 가중치 배율 (1.0 = 그대로)
@export var demon_guest_multiplier: float = 1.0
## 시작 날 메시지 로그에 나오는 안내
@export var hint_ko: String = ""
