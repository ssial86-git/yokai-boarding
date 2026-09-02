class_name DialogueGraph
extends RefCounted
## dialogue.csv 노드 그래프의 파싱과 진행. 효과 적용은 호출자(StorySystem) 몫이라 노드에 효과 목록만 실어 둔다.

const END := "end"
const START := "start"
const SPEAKER_PLAYER := "player"


class DialogueNode:
	extends RefCounted
	var id: String = ""
	var speaker: String = ""
	var text: String = ""
	var portrait: String = ""
	var next: String = ""
	var options: Array[Dictionary] = []  # {"text": String, "next": String}
	var effects: Array[Dictionary] = []  # {"kind": String, "target": String, "amount": int}

	func has_options() -> bool:
		return not options.is_empty()


class Runner:
	extends RefCounted
	var _nodes: Dictionary = {}
	var current: DialogueNode = null
	var finished: bool = false

	func _init(nodes: Dictionary) -> void:
		_nodes = nodes

	func start() -> DialogueNode:
		finished = false
		current = _nodes.get(START)
		if current == null:
			finished = true
		return current

	## 선택지가 없는 노드에서 다음으로. END 면 null 을 돌려주고 finished.
	func advance() -> DialogueNode:
		if current == null or current.has_options():
			return current
		return _go(current.next)

	func choose(index: int) -> DialogueNode:
		if current == null or index < 0 or index >= current.options.size():
			return current
		return _go(str(current.options[index]["next"]))

	func _go(target: String) -> DialogueNode:
		if target == END or target.is_empty() or not _nodes.has(target):
			current = null
			finished = true
			return null
		current = _nodes[target]
		return current


static func parse(data: DialogueData) -> Dictionary:
	var nodes: Dictionary = {}
	for raw: Dictionary in data.nodes:
		var node := DialogueNode.new()
		node.id = str(raw.get("node", ""))
		node.speaker = str(raw.get("speaker", ""))
		node.text = str(raw.get("text_ko", ""))
		node.portrait = str(raw.get("portrait", ""))
		node.next = str(raw.get("next", ""))
		for i in [1, 2]:
			var text := str(raw.get("option%d_ko" % i, ""))
			var target := str(raw.get("option%d_next" % i, ""))
			if not text.is_empty():
				node.options.append({"text": text, "next": target})
		node.effects = parse_effects(str(raw.get("effect", "")))
		nodes[node.id] = node
	return nodes


## "affinity:+1;item:record_piece:-1;flag:clue;money:+50" -> [{kind, target, amount}, ...]
static func parse_effects(spec: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part in spec.split(";", false):
		var fields := part.strip_edges().split(":")
		if fields.is_empty() or fields[0].is_empty():
			continue
		match fields[0]:
			"affinity", "money":
				if fields.size() >= 2:
					result.append({"kind": fields[0], "target": "", "amount": int(fields[1])})
			"item":
				if fields.size() >= 3:
					result.append({"kind": "item", "target": fields[1], "amount": int(fields[2])})
			"flag":
				if fields.size() >= 2:
					result.append({"kind": "flag", "target": fields[1], "amount": 1})
			_:
				push_warning("DialogueGraph: 알 수 없는 효과 %s" % part)
	return result
