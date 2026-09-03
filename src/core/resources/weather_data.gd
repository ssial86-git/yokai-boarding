class_name WeatherData
extends Resource
## 이승 날씨 × 음기 추첨표. data/csv/weather.csv 한 행 = 이 리소스 하나 (P2-S1).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## any 또는 절기 id — 이 절기에만 나오는 날씨
@export var season: String = "any"
## 절기 안 추첨 가중치 (0 이면 나오지 않음)
@export var weight: int = 1
## 이 날씨의 음기 지수 범위 (0~3). 같으면 고정
@export var yin_min: int = 0
@export var yin_max: int = 0
## 손님 종족 가중치 배율 (guest_species.realm 별)
@export var mortal_guest_multiplier: float = 1.0
@export var demon_guest_multiplier: float = 1.0
## 아침에 자라는 칸에 자동으로 주는 물 (1.0 = 하루치). 비 오는 날 텃밭이 절로 젖는다
@export var crop_water_bonus: float = 0.0
