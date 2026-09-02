# CSV 스키마 v1 (yokai / guest_species / rooms / tuning)
날짜: 2026-09-02
결정: M0 데이터 파이프라인의 4개 CSV 스키마와 .tres 생성 규칙을 아래와 같이 고정한다. 컬럼 추가는 허용(빌더의 TABLES 에 Column 추가 + Resource 클래스에 @export 추가), 컬럼 이름 변경·삭제는 본 ADR 개정 선행.

## 공통 규칙
- 인코딩 UTF-8(BOM 허용), 첫 줄 헤더, 키 컬럼은 소문자 snake_case. 빈 줄은 무시.
- bool 은 `true/false`. enum 은 빌더 `ENUMS` 의 허용값만. 참조 컬럼은 빈 문자열이면 "없음".
- 행 테이블(yokai·guest_species·rooms)은 행마다 `data/resources/<table>/<id>.tres` 한 개. tuning 은 `data/resources/tuning.tres` 한 개(Dictionary).
- .tres 는 `src/core/resources/*_data.gd` 를 script 로 참조하는 `Resource`. `DataRegistry` 가 폴더를 스캔해 `id` 로 색인한다.
- 검증 순서: 필수 컬럼 → 타입/enum → 키 중복 → 참조 무결성. 실패 시 `파일 N행 컬럼` 형태로 출력하고 종료 코드 1.

## yokai.csv (장기 하숙생) → YokaiData
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | str, PK | `y01_ttukttagi` 형식 (docs/06 번호 + 로마자) |
| name_ko, species_ko | str | 표시 이름·종족 |
| preferred_room | ref rooms.id | 배치 시 work_bonus 적용 방 |
| work_bonus | float | preferred_room 배치 시 생산 보너스 비율 |
| noise | int 0~3 | 옆방 수면 방해 정도 (배치 퍼즐 제약) |
| night_worker | bool | 밤 페이즈 전용 일꾼 |
| rent_type | enum money/items/errand/buff/info/none | 하숙비 지불 형태 |
| rent_note_ko | str | 지불 내용 설명(플레이버) |
| stat_strength / stat_skill / stat_sight / stat_courage | int | 힘·재주·눈·담력 (docs/06 파견 4스탯) |
| sprite_size | enum 16/32 | 스프라이트 규격 |
| in_slice | bool | 슬라이스 등장 여부 (Y04~Y06 은 false 로 데이터만 준비) |

## guest_species.csv (뜨내기 손님 종족) → GuestSpeciesData
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | str, PK | `g_<로마자>` |
| name_ko | str | |
| rarity | enum common/uncommon/rare | 명부 희귀도 |
| flavor_ko | str | 플레이버 1~2줄 |
| rent_type, rent_note_ko | 위와 동일 | |
| appear_condition | str | 등장 조건 키 (빈 값 = 무조건, `rain` 등). 해석은 M3 방문자 시스템 |
| weight | int | 방문자 추첨 가중치 |
| promotable | bool | 장기 계약 승격 가능 여부 (Tier 2) |
| sprite_size | enum 16/32 | 소형종 16 허용 |

## rooms.csv (방 종류) → RoomData
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | str, PK | guest_room / kitchen / workshop / gate / storage / empty_lot |
| name_ko | str | |
| kind | enum lodging/production/service/gate/storage/empty | |
| build_cost | int | 증축 비용 |
| capacity | int | 거주(객실) 또는 근무 슬롯 수 |
| spirit_id | str | 담당 가택신 id. spirits.csv 는 M3 에서 추가되며 그때 ref 로 승격 |
| quiet | bool | 소음 민감 방 |
| requires_room | ref rooms.id | 선행 방 조건 (빈 값 = 없음) |

## tuning.csv → TuningData.values
| 컬럼 | 타입 | 설명 |
|---|---|---|
| key | str, PK | |
| value | str | type 에 따라 변환 |
| type | enum int/float/bool/string | |
| description | str | 사람용 설명 |

초기 키: phase_{morning,day,evening,night}_seconds (0 이하 = 수동 진행), grid_floors=3, grid_columns=4, start_money, slice_target_days.

이유:
- 행 단위 .tres 는 Godot 인스펙터에서 열어 볼 수 있고, 요괴 1명 추가 = 파일 1개 추가라 파이프라인 가설(docs/01 1절 2번) 검증에 직접 대응한다.
- 능력치 컬럼을 `str/dex` 대신 `stat_strength` 등으로 둔 것은 GDScript 내장 함수 `str` 과의 충돌 회피.
- tuning 을 Dictionary 하나로 둔 것은 키가 자주 늘어나는 테이블이라 Resource 클래스 수정 없이 CSV 행 추가만으로 끝나게 하기 위함.
- 페이즈 길이 0 = 수동 진행 규칙은 아침·저녁·밤이 플레이어 결정 페이즈(docs/00 4절)이기 때문. 낮만 240초 자동 진행.

대안과 기각 사유:
- 테이블당 .tres 하나에 Array 로 묶기: 인스펙터 가독성이 떨어지고 diff 가 커짐. 기각.
- 런타임에 CSV 직접 파싱: Godot 이 .csv 를 번역 파일로 임포트하려 들고, 검증이 런타임으로 밀림. 기각. (data/csv 에 `.gdignore` 를 두어 Godot 스캔에서 제외)
- JSON 중간 포맷: 툴이 하나 더 늘 뿐 이점 없음. 기각.

영향받는 파일/문서: data/csv/*.csv, tools/data/build_resources.py, src/core/resources/*_data.gd, src/autoload/data_registry.gd, test/integration/test_data_build.gd
