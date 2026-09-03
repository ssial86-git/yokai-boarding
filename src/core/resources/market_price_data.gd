class_name MarketPriceData
extends Resource
## 회색 시장 시세 행. data/csv/market_prices.csv 한 행 = 이 리소스 하나 (P2-S3).
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## items.csv id (= id)
@export var item_id: String = ""
## 판매가 배율 (대문간 가격 = base_value × sell_price_ratio 기준)
@export var sell_mult: float = 1.0
## 구매가 배율 (base_value 기준). 0 이면 팔지 않는다
@export var buy_mult: float = 0.0
## 하루 시세 흔들림 폭 (0.2 = ±20%)
@export var swing: float = 0.0
## 하루 구매 재고. 0 이면 사기 줄에 나오지 않는다
@export var stock: int = 0
@export var note_ko: String = ""
