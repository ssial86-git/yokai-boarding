"""AI 생성 프롬프트 표 (tools/art/ai_batch.py 가 읽는다). 게임 콘텐츠가 아니라 아트 발주서이므로 data/ 가 아니라 tools/ 에 둔다.

키 규칙은 art_assets.csv 와 같다. 각 항목:
  kind   sprite(캐릭터 정지 1장 → 18프레임 합성) / room(64x48) / sky(320x192) / far(544x160, 가로 반복, 위 투명)
         / ground(32x32 가로 반복) / prop(프레임 목록) / illust(1024 초상) / strip(가로 띠, 반복)
  size   목표 크기 (prop 은 프레임 크기)
  refs   스타일 레퍼런스 컨셉 파일 (assets/art/concepts/)
  prompt 영어. 스타일 공통 문구는 STYLE_* 에 있고 ai_batch 가 앞에 붙인다.
"""
from __future__ import annotations

SHEET = "concept_yokai_sheet.png"
HOUSE = "concept_house.png"
KITCHEN = "concept_kitchen.png"
DINNER = "concept_dinner.png"

STYLE_COMMON = (
    "Match the art style of the reference images exactly: Korean folk picture-book look, bold black ink outlines, "
    "muted paper-toned palette (indigo, ochre, brick red, moss green, cream), rounded silhouettes, big round eyes, "
    "chibi proportions 2 heads tall. Side view, orthographic, no perspective. "
)
STYLE_SPRITE = (
    STYLE_COMMON
    + "One single character, full body, standing, facing the viewer slightly to the right, feet at the bottom, "
    "centered, filling 85% of the canvas height. Flat colors, thick outlines, NO paper texture, NO shading gradients, "
    "NO background, NO ground shadow, NO text. This will be shrunk to a tiny game sprite so keep shapes simple and readable. "
)
STYLE_ROOM = (
    STYLE_COMMON
    + "A single room of a Korean hanok boarding house seen straight-on as a dollhouse cross-section: back wall with "
    "wooden posts at both edges, wooden floor along the bottom edge, furniture and props inside. 4:3 framing filling the "
    "whole canvas edge to edge — NO roof, NO outer border, NO characters, NO text. Flat colors, thick outlines, minimal texture, "
    "warm lamplight tone. "
)
STYLE_ILLUST = (
    STYLE_COMMON
    + "Bust portrait for a character encyclopedia: head and shoulders, looking at the viewer, gentle expression, "
    "soft paper texture allowed, plain cream paper background, no text. "
)
STYLE_LAYER = STYLE_COMMON + "Flat colors, thick outlines, minimal texture, no text, no characters. "

CHAR_ANIMS = "idle:0-3:6;walk:4-9:10;work:10-13:8;joy:14-15:4;sad:16-17:2"

CHARACTERS: dict[str, str] = {
    "char.player": "the young human innkeeper girl from the kitchen reference: short black bob hair with a white headband bow, white jeogori jacket, indigo chima skirt, white apron, rosy cheeks, holding a small tray",
    "char.y01_ttukttagi": "Ttukttagi, a baby dokkaebi goblin: round chubby body, one short horn on the forehead, messy dark hair, cocky grin, red wrestling sash (satba) tied around the waist, holding a small wooden club",
    "char.y02_eoduki": "Eoduki, a shy shadow spirit: a smoky pitch-black blob with soft blurry edges like the black silhouette in the reference sheet, two huge round white eyes with black pupils, no mouth, tiny stubby arms",
    "char.y03_dalgael": "Dalgael, an egg ghost: a smooth cream-colored egg body with absolutely no facial features, a faint fog of condensation on the shell, two tiny stub arms, wearing a small pale blue cloth wrap",
    "char.y04_bari": "Bari, a baby iron serpent (imugi): short coiled dragon-snake with steel-blue scales, two small horns, cream belly, proud narrow eyes, a tiny wisp of dry heat around the head",
    "char.y05_geumjuri": "Geumjuri, a straw-rope yokai: a twisted golden straw rope coiled into a small body, white paper strips (hanji) hanging from it, two little eyes peeking out",
    "char.y06_aheop": "Aheop, an apprentice nine-tailed fox: small cream fox in a red-and-white hanbok, fox ears, only three fluffy tails, mischievous smile",
    "char.y07_museo": "Museo, a bulgasari beast: bear-sized round creature with dark iron scales, elephant-like short trunk, tiger paws, small friendly eyes, chewing a horseshoe",
    "char.y08_ongi": "Ongi, an onggi jar spirit: brown clay jar body with a round face painted on it, a lid worn like a hat, little arms and feet",
    "char.y09_daltokki": "Daltokki, a moon rabbit: small white rabbit in a pale yellow vest holding a wooden pestle beside a tiny mortar",
    "char.y10_geuseundae": "Geuseundae, a tall dark shadow yokai: a narrow tall black pillar-like silhouette that seems to stretch upward, two glowing pale eyes high up, no other features",
    "guest.g_mongdanggwi": "a pencil-stub yokai: a short worn-down pencil with a face, tiny arms, eraser hat",
    "guest.g_ibulnang": "a blanket lump yokai: a padded floral quilt draped over an unknown shape, only two eyes peeking from under the edge",
    "guest.g_usanson": "an old umbrella yokai: a tattered paper umbrella with one eye and a single hand growing from the handle",
    "guest.g_geumjuri": "a straw-rope yokai: twisted golden straw rope coiled into a small body with white paper strips hanging from it, two little eyes",
    "guest.g_ongi": "an onggi jar ghost: brown clay jar with a face and a lid hat, tiny feet",
    "guest.g_bobusang": "a peddler ghost: small round figure with a huge cloth bundle on the back, wide straw hat, ghostly pale face",
    "guest.g_baram": "a wind puff yokai: a small fluffy grey-white cloud with a cheeky face and streaks of wind",
    "guest.g_moon_rabbit": "a moon rabbit: small white rabbit with a pale yellow vest holding a pestle",
    "guest.g_snow_child": "a snow child: tiny child made of snow with a red scarf and coal eyes",
    "guest.g_ink_sprite": "an ink sprite: a glossy black ink blob with big white eyes and a drip on top, holding a tiny brush",
    "guest.g_lantern_fish": "the fish-hat yokai from the reference sheet, final colored version: cream chibi wearing an indigo carp-shaped hood with fins, patterned scales, small bow tie, holding a tiny lantern",
    "guest.g_stone_mireuk": "a stone mireuk statue spirit: a squat grey stone buddha statue with moss patches and a calm smiling face, hands folded",
    "npc.seongju": "Seongju, the elderly house spirit: tiny old grandpa with a long white beard, grey-green robe, dozing with eyes closed, sitting cross-legged",
    "npc.jowang": "Jowang, the kitchen hearth spirit: plump middle-aged woman in a brown hanbok with a white apron and a headscarf, holding a wooden ladle, warm smile",
    "npc.mundori": "Mundori, the gate spirit: a small round puppy-like guardian with a red collar, holding a paper name card in its mouth",
    "npc.gray_merchant": "the gray market merchant: a hooded figure in a grey cloak with only a pale mask face visible, carrying a bundle of goods on a pole",
    "npc.collector": "the collector, a demon bureaucrat: thin figure in a black official robe and tall gat hat, carrying a huge ledger book and a red seal stamp, stern",
    "npc.village_grocer": "the village grocer: sturdy man in a brown vest and headband, sleeves rolled, holding a sack of grain",
    "npc.herb_granny": "the herb granny: small hunched old woman in a grey hanbok with a basket of herbs on her back, sharp knowing eyes",
    "enemy.e_ash_wisp": "an ember wisp enemy: small floating flame of grey ash with an orange core and one angry eye",
    "enemy.e_cinder_hound": "a cinder hound enemy: lean dark grey dog with cracks glowing orange, bared teeth",
    "enemy.e_ash_warden": "an ash warden boss: hulking armored figure made of grey ash and charred wood, glowing orange eyes, holding a heavy staff",
    "enemy.e_marsh_leech": "a marsh leech enemy: fat dark green leech with a round mouth and tiny eyes",
    "enemy.e_bog_lantern": "a bog lantern enemy: pale blue floating will-o-wisp inside a broken paper lantern",
    "enemy.e_marsh_wraith": "a marsh wraith enemy: draped grey-green ghost with long drooping arms and hollow eyes",
    "enemy.e_marsh_mother": "the marsh mother boss: large mud-and-reed creature shaped like a hunched woman with a lily pad on her head, many small eyes",
    "enemy.e_clerk_shade": "a clerk shade enemy: a flat black shadow of an office clerk holding a writing brush and paper",
    "enemy.e_stamp_golem": "a stamp golem enemy: blocky golem built from stacked red official seal stamps, ink dripping",
    "enemy.e_ledger_wisp": "a ledger wisp enemy: a small flame made of burning ledger paper with columns of numbers",
    "enemy.e_auditor": "the auditor boss: tall demon bureaucrat in a black robe and gat hat with a giant open ledger, red seal stamp raised, cold stare",
}

ROOMS: dict[str, str] = {
    "room.guest_room": "guest bedroom: folded padded quilts stacked in a corner, a low wooden table, a paper lattice window on the back wall, a small hanging lantern",
    "room.kitchen": "kitchen: a clay stove (agungi) with a big black iron cauldron on the left, shelves of clay jars and bundles of dried herbs on the back wall, a hanging lantern",
    "room.workshop": "workshop: a wall of hanging hand tools, a workbench with a small anvil and hammer, wooden crates, a hanging lantern",
    "room.gate": "entrance hall (gate room): a large wooden double door on the back wall with iron rings, a hanging lantern, a pair of straw shoes on the floor, a wooden bench",
    "room.storage": "storage room: stacked wooden chests, big clay jars, sacks of grain, shelves with bundles, dim lantern",
    "room.empty_lot": "IGNORE the room framing for this one: an EMPTY outdoor lot — no walls, no posts, no floor boards, no furniture, no lantern. Only flat packed brown earth along the bottom third with a single green sprout and three pebbles, and plain pale sky filling the rest",
    "room.study": "study: tall bookshelves full of books and scrolls on the back wall, a low writing desk with a brush and ink stone, a hanging scroll painting, a lantern",
    "room.ondol_room": "ondol bedroom: a sleeping mat with a blue quilt laid on the warm floor, a small chest, a paper window, a hanging lantern, cozy",
}

ILLUSTS: dict[str, str] = {f"illust.{k.split('.')[1]}": v for k, v in CHARACTERS.items() if k.startswith(("char.y", "npc."))}

# 구역: (sky 설명, far 설명, ground 설명)
REGIONS: dict[str, tuple[str, str, str]] = {
    "r_house": ("pale daytime sky with soft washed clouds", "a row of layered blue-grey mountains with a dark pine forest silhouette in front, rooftops of a small village at the bottom", "green grass tuft edge on packed brown earth"),
    "r_yard": ("pale daytime sky with soft washed clouds", "layered blue-grey mountains with a dark pine forest silhouette in front", "green grass tuft edge on packed brown earth"),
    "r_back_hill": ("pale misty daytime sky, sky only, no trees", "dense forest of tall dark tree trunks and foliage", "mossy forest floor with roots and fallen leaves"),
    "r_stream": ("pale sky with light mist", "willow trees and reeds along a stream bank, distant hills", "pebbly river bank with grass"),
    "r_well": ("dark stone ceiling of an underground shaft, deep indigo", "old mossy stone brick wall with dripping water", "wet grey stone floor"),
    "r_ash_field": ("hazy grey-purple overcast sky", "dead grey plains with charred bare trees and drifting ash", "cracked grey ash ground with embers"),
    "r_ash_field_deep": ("dark grey-purple sky with drifting smoke", "charred forest of blackened trees and ruined shrines", "cracked black ash ground with glowing cracks"),
    "r_gray_market": ("dim violet dusk sky", "a crooked row of shadowy market stalls with grey lanterns and hanging signs", "worn grey flagstones"),
    "r_village": ("bright pale daytime sky", "a row of tiled-roof hanok shop houses with signboards and a persimmon tree", "packed dirt village road with grass edges"),
    "r_moon_marsh": ("deep blue night sky with a huge pale moon", "misty swamp with dead reeds, twisted trees and floating pale lights", "dark muddy ground with reeds and puddles"),
    "r_archive_gate": ("charcoal sky with drifting paper sheets", "giant stone gate and endless shelves of ledgers fading into the dark", "grey stone tiles with scattered paper"),
}

# 소품: 프레임별 설명 (한 프레임 = 한 장 생성)
PROPS: dict[str, tuple[tuple[int, int], list[str], str]] = {
    "prop.gather_point": ((16, 16), ["a small bush of wild herbs with white flowers, ready to pick", "the same bush after picking: bare stems, no flowers"], ""),
    "prop.farm_plot": ((16, 16), ["a small patch of flat dry dirt seen from the side", "a small patch of freshly tilled dark soil with furrows", "a small patch of dark soil with a green sprout growing", "a small patch of dark soil with a fully grown radish plant with big leaves"], ""),
    "prop.door": ((32, 32), ["an open wooden hanok gate door with a lantern, welcoming", "the same wooden gate closed and locked with a wooden bar"], ""),
    "prop.water": ((32, 16), ["a strip of calm blue river water surface with a few white ripples, side view, seamless horizontally"], "idle:0-1:2"),  # 2번째 프레임은 ai_batch 가 8px 밀어 만든다
    "prop.merchant": ((32, 32), ["a small market stall table with a grey awning and hanging lanterns"], ""),
    "prop.house_deco_left": ((144, 64), ["a wide side-view garden scene group: two leafy trees, a wooden fence, and a few mushrooms, all standing on the same ground line, transparent background"], ""),
    "prop.house_deco_right": ((144, 64), ["a wide side-view yard scene group: a stack of brown onggi clay jars, a stone well with a wooden bucket, a wooden signpost and a small round tree, all on the same ground line, transparent background"], ""),
}

# 반복 띠 (가로 seamless): 지붕 64x32, 기둥 16x48, 주춧돌 64x16
STRIPS: dict[str, tuple[tuple[int, int], str]] = {
    "prop.house_roof": ((64, 32), "a horizontal strip of dark blue-grey Korean giwa roof tiles seen from the front, two rows of curved tiles with a wooden beam at the bottom edge, seamless horizontally, transparent above"),
    "prop.house_pillar": ((16, 48), "a single vertical wooden hanok pillar, dark brown wood grain, front view, transparent background"),
    "prop.house_base": ((64, 16), "a horizontal strip of grey foundation stones with a wooden floor beam on top, seamless horizontally"),
}

# 하늘 양자화 전 색 곱 (RRGGBB, 세기): 팔레트에 연한 하늘색이 적어 낮 하늘이 연두로 눌리는 것을 막는다
SKY_TINT: dict[str, tuple[str, float]] = {
    "r_house": ("9fc4ff", 0.55), "r_yard": ("9fc4ff", 0.55), "r_village": ("9fc4ff", 0.55),
    "r_stream": ("b8d4ff", 0.45), "r_back_hill": ("b8d4ff", 0.45),
}
