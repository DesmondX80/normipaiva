extends Control
## Päivän kolme tilaa HUD:n oikeassa yläkulmassa: nimi ja palkki, jonka nolla on keskellä.
## Negatiivinen arvo punaisena vasemmalle, positiivinen vihreänä oikealle (-1..+1; humalatila 0..1).

const ROW := 30.0
const BAR_W := 150.0
const BAR_H := 12.0
const NAME_W := 120.0

var stats: RefCounted  # day_stats.gd

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(NAME_W + BAR_W, ROW * 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if stats == null:
		return
	var y := 0.0
	for k in stats.chosen:
		var v: float = stats.value(k)
		var name: String = stats.STATS[k].name
		draw_string_outline(_font, Vector2(0, y + 17), name, HORIZONTAL_ALIGNMENT_LEFT, NAME_W - 6, 16, 5, Color.BLACK)
		draw_string(_font, Vector2(0, y + 17), name, HORIZONTAL_ALIGNMENT_LEFT, NAME_W - 6, 16, Color.WHITE)
		var bx := NAME_W
		var by := y + 6
		draw_rect(Rect2(bx - 1, by - 1, BAR_W + 2, BAR_H + 2), Color(0, 0, 0, 0.6))
		var mid := bx + BAR_W / 2.0
		var w := v * BAR_W / 2.0
		var col := Color(0.3, 0.85, 0.35) if v >= 0.0 else Color(0.9, 0.25, 0.2)
		draw_rect(Rect2(minf(mid, mid + w), by, absf(w), BAR_H), col)
		draw_line(Vector2(mid, by - 3), Vector2(mid, by + BAR_H + 3), Color.WHITE, 2.0)
		y += ROW
