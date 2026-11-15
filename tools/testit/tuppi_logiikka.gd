extends SceneTree
## Räsytupin peliaivojen logiikkatesti (scripts/tuppi.gd): koko ilta tekoälyllä useilla siemenillä.
## Ajo: godot --headless --path . -s tools/testit/tuppi_logiikka.gd

const Tuppi := preload("res://scripts/tuppi.gd")


func _init() -> void:
	var viat := 0
	for seed in [1, 2, 3, 7, 42]:
		viat += Tuppi.testi(seed, seed == 1)
	var rami := 0
	var nolo := 0
	var t := Tuppi.new()
	t.rng.seed = 99
	for i in 200:
		t.new_hand()
		while t.next_bidder() >= 0:
			var b := t.next_bidder()
			t.bid(b, t.ai_bid(b))
		if t.mode == "rami":
			rami += 1
		else:
			nolo += 1
	print("TUPPI 200 jaon ilmoitukset: rami %d, nolo %d" % [rami, nolo])
	print("TUPPI valmis, %d vikaa" % viat)
	quit(1 if viat > 0 else 0)
