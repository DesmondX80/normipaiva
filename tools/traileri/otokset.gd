extends RefCounted
## Trailerin otosten lavastus (leikkaus.gd:n id:t). setup() siirtää hahmot paikalleen, asettaa kellonajan ja palauttaa
## otoksen kuvaussuunnitelman:
##   cam   Callable(t) -> [silmä, katsepiste, (kallistus)]; ilman tätä pelin oma kamera jää (minipelit)
##   fov   kuvakulma (luku tai Callable(t)), dof = taustan sumennuksen alkuetäisyys
##   tick  Callable(t) joka ruudulla (ohjaus, repliikit), done = siivous otoksen jälkeen
##   warm  asettumisruudut ennen kuvausta, hud/note = pelin HUD tai Päivin lappu näkyviin
## Kaikki otokset alkavat samasta pelistä (kotipiha, aamu), joten jokainen setup siirtää kaiken tarvitsemansa itse.

const M := preload("res://scripts/map_data.gd")
const T := preload("res://scripts/terrain.gd")
const B := preload("res://scripts/build.gd")






static func setup(main: Node3D, id: String, d: Node) -> Dictionary:
	_reset(main)
	match id:
		# --- Avaus ---------------------------------------------------------------------------------------------------
		"avaus_yo":
			_time(main, 0, 40)
			var h := M.w(M.HOME_BUILDING)
			var f := _dir(M.HOME_YAW_DIR)
			return {"cam": dolly(h + f * 26.0 + _side(f) * 9.0 + Vector3(0, 2.0, 0), h + f * 17.0 + _side(f) * 5.0 + Vector3(0, 1.8, 0),
				h + Vector3(0, 2.2, 0), h + Vector3(0, 2.0, 0)), "fov": 42.0}
		# --- Intro ---------------------------------------------------------------------------------------------------
		"i_ilma":
			_time(main, 8, 30)
			var c := M.w(Vector2(700, 1000))
			return {"cam": dolly(c + Vector3(-160, 170, 200), c + Vector3(-90, 150, 170), c + Vector3(20, 0, 60), c + Vector3(50, 0, 80)),
				"fov": 45.0, "fog": 0.0}
		"i_koti":
			_time(main, 8, 40)
			var h := M.w(M.HOME_BUILDING)
			var f := _dir(M.HOME_YAW_DIR)
			return {"cam": dolly(h + f * 22.0 - _side(f) * 10.0 + Vector3(0, 1.4, 0), h + f * 20.0 + _side(f) * 2.0 + Vector3(0, 1.5, 0),
				h + Vector3(0, 2.0, 0), h + Vector3(0, 2.0, 0)), "fov": 48.0}
		"i_talli":
			_time(main, 8, 50)
			var start := M.w(M.HOME_ZONE)
			var tick := ride(main, start, M.w(M.J_H1), 0.45)
			var dir: Vector3 = -main.bike.global_transform.basis.z
			dir.y = 0.0
			dir = dir.normalized()
			var eye: Vector3 = main.bike.global_position + dir * 14.0 + _side(dir) * 2.6 + Vector3(0, 0.55, 0)
			return {"tick": tick, "cam": func(_t: float) -> Array:
				return [eye, main.bike.global_position + Vector3(0, 1.0, 0)], "fov": 30.0, "dof": 25.0}
		"i_kylatie":
			_time(main, 9, 10)
			var a := M.w(Vector2(640, 1150))
			var tick := ride(main, a, M.w(M.J_T), 0.7)
			return {"tick": tick, "cam": follow(main.bike, Vector3(3.4, 1.0, 0.6), Vector3(3.0, 1.2, -1.5), Vector3(0, 0.9, 0)),
				"fov": 38.0, "dof": 18.0}
		"i_kmarket":
			_time(main, 10, 0)
			var s := M.w(M.SHOP_BUILDING)
			var z := M.w(M.SHOP_ZONE)
			var out := (z - s).normalized()
			out.y = 0
			return {"cam": dolly(z + out * 18.0 + _side(out) * 14.0 + Vector3(0, 6.0, 0), z + out * 14.0 + _side(out) * 6.0 + Vector3(0, 3.0, 0),
				s + Vector3(0, 3.0, 0), s + Vector3(0, 2.5, 0)), "fov": 50.0}
		"i_hyundai":
			_time(main, 16, 10)
			var w: Node3D = _wife(main)
			w.mode = "patrol"
			w.reset_to(main.world.nearest_node(M.w(Vector2(640, 1150))))
			return {"warm": 60, "cam": follow(w, Vector3(-4.5, 1.1, 6.5), Vector3(-2.5, 0.9, 5.0), Vector3(0, 0.8, 0)), "fov": 40.0}
		"i_kuutonen":
			_time(main, 10, 20)
			main.beers = 6
			var z: Vector3 = main.shop_zone
			var out := z - M.w(M.SHOP_BUILDING)
			out.y = 0.0
			out = out.normalized()
			var w := _foot(main, z, out)
			w.set_carrying(true)
			return {"keys": [[0.0, "forward", 99.0]], "cam": func(t: float) -> Array:
				var p := w.global_position
				return [p + out * lerpf(4.2, 3.4, t / 3.0) + _side(out) * 1.2 + Vector3(0, 0.55, 0), p + Vector3(0, 1.0, 0)],
				"fov": 34.0, "dof": 8.0}
		"i_pekka":
			_time(main, 11, 0)
			var pk: Node3D = main.pekka
			_hold(main, pk)
			var pp := pk.global_position
			var f := _out_dir(main, pp)
			var w := _foot(main, pp + f * 1.7, -f)
			pk.rotation.y = B.yaw_to(w.global_position - pp)
			pk._body.play("Idle_Talking", 0.2)
			d.bubble(pk, "Pekka: Paapeliin pääsee, kunhan...", 3.2)
			return {"cam": _two_shot(main, pp, w.global_position, -1.0), "fov": 40.0, "dof": 7.0, "done": func() -> void: _release(pk)}

		# --- Tarina ------------------------------------------------------------------------------------------------
		"t_jemma":
			_time(main, 12, 30)
			main.beers = 6
			var c := M.w(M.COMPOST)
			var f := _dir(M.HOME_YAW_DIR)
			var w := _foot(main, c - f * 1.3, f)
			w.set_carrying(true)
			w._body.play("PickUp_Table", 0.2)
			return {"cam": dolly(c - f * 4.0 + _side(f) * 2.5 + Vector3(0, 1.2, 0), c - f * 3.2 + _side(f) * 1.8 + Vector3(0, 1.0, 0),
				c + Vector3(0, 0.6, 0), c + Vector3(0, 0.6, 0)), "fov": 40.0, "dof": 6.0}
		"t_arto":
			_time(main, 13, 0)
			var ar: Node3D = main.arto
			_hold(main, ar)
			var ap := ar.global_position
			var f := _out_dir(main, ap)
			var w := _foot(main, ap + f * 1.7, -f)
			ar.rotation.y = B.yaw_to(w.global_position - ap)
			ar._body.play("Idle_Talking", 0.2)
			d.bubble(ar, "Arto: Lähekkö puolukkaan? Mää tiiän paikat.", 3.2)
			return {"cam": _two_shot(main, ap, w.global_position, -1.0), "fov": 40.0, "dof": 7.0,
				"done": func() -> void: _release(ar)}
		"t_sienet":
			_time(main, 14, 10)
			var f := _forage(main, ["kantarelli", "herkkutatti"])
			var w := _foot(main, f.pos + Vector3(1.6, 0, 0.4), Vector3(-1, 0, -0.2))
			w._body.play("Crouch_Idle", 0.2)
			var c: Vector3 = f.pos
			var face := c + Vector3(1.6, 1.4, 0.4)
			return {"cam": dolly(c + Vector3(-1.3, 0.3, -0.5), c + Vector3(-0.9, 0.35, -0.3), c + Vector3(0.4, 0.4, 0.1), face), "fov": 42.0,
				"dof": 4.0}
		"t_puolukka":
			_time(main, 14, 40)
			var f := _forage(main, ["puolukka", "mustikka"])
			var w := _foot(main, f.pos + Vector3(0.8, 0, 0), Vector3(-1, 0, 0))
			var keys := [[0.0, "interact"]]
			for i in 14:
				keys.append([0.35 + i * 0.27, "left" if i % 2 == 0 else "right", 0.12])
			var c: Vector3 = f.pos
			return {"warm": 30, "keys": keys, "cam": dolly(c + Vector3(1.0, 0.9, 3.2), c + Vector3(1.0, 0.8, 2.6),
				c + Vector3(0.7, 0.6, 0), c + Vector3(0.7, 0.5, 0)), "fov": 42.0, "dof": 5.0}
		"t_nurmikko":
			_time(main, 15, 30)
			var lw: Node3D = main.lawn
			_foot(main, lw.mower_park + Vector3(1.2, 0, 0.8), Vector3.FORWARD)
			main._start_mowing(lw)
			var w: Node3D = main.walker_out
			var fwd := -w.global_transform.basis.z
			return {"keys": [[0.0, "forward", 99.0]], "cam": func(t: float) -> Array:
				var p := w.global_position
				return [p + fwd * 3.6 + _side(fwd) * 2.0 + Vector3(0, 1.0, 0), p + Vector3(0, 0.6, 0)], "fov": 42.0, "dof": 7.0,
				"done": func() -> void: main._stop_mowing()}
		"t_paivi_nakee":
			_time(main, 15, 50)
			var a := M.w(Vector2(700, 1175))
			var tick := ride(main, a, M.w(M.J_T), 0.85)
			var wf: Node3D = _wife(main)
			var back: Vector3 = -main.bike.global_transform.basis.z
			wf.global_position = main.bike.global_position - back * 12.0
			wf.rotation.y = main.bike.rotation.y
			wf.parked = false
			wf.mode = "chase"
			wf.target = main.bike
			return {"tick": tick, "cam": follow(wf, Vector3(1.2, 1.9, 7.0), Vector3(0.8, 1.6, 5.5), Vector3(0, 1.0, -25.0)),
				"fov": 46.0}
		"t_kota":
			_time(main, 19, 0)
			var k: Node3D = main.world.kota
			k.set_fire(true)
			return {"cam": dolly(k.to_global(Vector3(-9, 4.8, -14)), k.to_global(Vector3(-7, 3.6, -11)), k.to_global(Vector3(-1, 1.2, 1)),
				k.to_global(Vector3(-1, 1.0, 1))), "fov": 50.0}
		"t_lintutorni":
			_time(main, 19, 20)
			var k: Node3D = main.world.kota
			var tw := M.w(M.LINTUTORNI)
			return {"cam": dolly(k.to_global(Vector3(-5, 2.0, -9)), k.to_global(Vector3(-4, 2.6, -8)), tw + Vector3(0, 6, 0), tw + Vector3(0, 8, 0)),
				"fov": 44.0}
		"t_avaimet":
			_time(main, 17, 0)
			var pk: Node3D = main.pekka
			_hold(main, pk)
			var pp := pk.global_position
			var f := _out_dir(main, pp)
			var w := _foot(main, pp + f * 1.4, -f)
			pk.rotation.y = B.yaw_to(w.global_position - pp)
			pk._body.play("Idle_Talking", 0.2)
			d.bubble(pk, "Pekka: MUN AVAIMET! Missä ne oli?!", 3.0)
			return {"cam": _two_shot(main, pp, w.global_position, -1.0), "fov": 40.0, "dof": 6.0,
				"done": func() -> void: _release(pk)}
		"t_volvo":
			_time(main, 17, 20)
			var pk: Node3D = main.pekka
			_hold(main, pk)
			var pp := pk.global_position
			var out := _out_dir(main, pp)
			var w := _foot(main, pp + out * 1.7, -out)
			pk.rotation.y = B.yaw_to(w.global_position - pp)
			pk._body.play("Idle_Talking", 0.2)
			d.bubble(pk, "Pekka: No niin! Hyppää kyytiin.", 3.0)
			return {"cam": _two_shot(main, pp, w.global_position, -1.0), "fov": 40.0, "dof": 6.0, "done": func() -> void: _release(pk)}
		"t_kyyti":
			_time(main, 20, 30)
			var car := _car(main, d, M.w(Vector2(640, 1180)), M.w(M.J_W), 14.0)
			return {"cam": follow(car, Vector3(5.0, 1.4, 9.0), Vector3(2.5, 2.0, 12.0), Vector3(0, 0.8, 0)), "fov": 40.0}
		"t_taksi":
			_time(main, 21, 0)
			var tp: Vector3 = _g(main.world.taxi_pos)
			var w := _foot(main, tp + Vector3(3.0, 0, 2.0), Vector3(-1, 0, -0.5))
			return {"keys": [[0.0, "forward", 1.4]], "cam": dolly(tp + Vector3(7, 1.6, 6), tp + Vector3(6, 1.5, 4.5), tp + Vector3(0, 1.0, 0),
				tp + Vector3(0, 1.0, 0)), "fov": 40.0, "dof": 10.0}

		# --- Sivutehtävät --------------------------------------------------------------------------------------------
		"v_pojat", "v_pallo":
			_time(main, 12, 0)
			var bz := _boys(main)
			var bp := bz.global_position
			if id == "v_pallo":
				bz.play_ball()
				return {"cam": dolly(bp + Vector3(6, 0.5, -5), bp + Vector3(5, 0.6, -4), bp + Vector3(0, 1.4, 0), bp + Vector3(0, 3.0, 0)),
					"fov": 44.0}
			bz.say("Jere potkas pallon aidan yli!", 0, 2.5)
			return {"cam": dolly(bp + Vector3(-4, 1.4, 5), bp + Vector3(-3, 1.3, 4), bp + Vector3(0, 1.0, 0), bp + Vector3(0, 1.0, 0)),
				"fov": 40.0, "dof": 8.0}
		"v_mummot", "p_mummot":
			_time(main, 11, 30)
			var mm: Node3D = main.mummot
			var mp := mm.global_position
			_on_bike(main)
			var bike: Node3D = main.bike
			bike.global_position = mp + Vector3(-12.0, 0.3, 2.5)
			bike.rotation.y = B.yaw_to(Vector3(1, 0, 0))
			bike.speed = 8.0
			mm.target = bike
			var keys := [[0.0, "forward", 99.0]]
			var tick := func(t: float) -> void:
				if t > 0.6 and not mm.is_angry():
					mm.anger()
				for b in mm._bubbles:  # mummojen päällekkäiset repliikit pois (karkit lentävät silti)
					b.text = ""
			if id == "p_mummot":  # "puhelimella kuvattu": käsivaralla heiluva
				return {"keys": keys, "tick": tick, "cam": func(t: float) -> Array:
					var shake := Vector3(sin(t * 7.1) * 0.05, sin(t * 9.3) * 0.04, 0)
					return [mp + Vector3(2.0, 1.5, 6.5) + shake, mp + Vector3(-1.0, 0.9, 0) + shake * 2.0], "fov": 55.0}
			return {"keys": keys, "tick": tick, "cam": dolly(mp + Vector3(4.5, 1.2, 4.0), mp + Vector3(3.5, 1.1, 3.4), mp + Vector3(0, 0.9, 0),
				mp + Vector3(-1, 0.9, 1)), "fov": 42.0, "dof": 7.0}
		"v_vaino", "p_vaino":
			_time(main, 13, 30)
			main._vaino_escape()
			var v: Node3D = main.vaino
			main.pekka.quiet = true  # Pekan omat sienirepliikit eivät jää kuvaan
			if main.pekka.get("_bubble") is Label3D:
				main.pekka._bubble.text = ""
			if id == "p_vaino":  # puhelimella perään: kuvaaja seisoo, koira juoksee ohi
				var at: Vector3 = v.global_position
				var eye0 := _best_eye(main, at + Vector3(0, 0.5, 0), _ring(at, Vector3(1, 0, 1), 5.0, 1.1))
				return {"warm": 2, "cam": func(t: float) -> Array:
					var shake := Vector3(sin(t * 6.3) * 0.06, sin(t * 8.7) * 0.05, 0)
					return [eye0 + shake, v.global_position + Vector3(0, 0.5, 0) + shake], "fov": 50.0}
			return {"warm": 2, "cam": follow(v, Vector3(-2.6, 1.4, -3.6), Vector3(-3.0, 1.5, 1.5), Vector3(0, 0.4, 0), 3.5, main), "fov": 46.0, "dof": 8.0}
		"v_koira":
			_time(main, 16, 0)
			var s: Node3D = main.stray
			var sp := _g(s.global_position)
			_foot(main, sp + Vector3(6.0, 0, 0), Vector3(-1, 0, 0))
			return {"keys": [[0.0, "forward", 1.0]], "cam": dolly(sp + Vector3(1.6, 0.4, 2.2), sp + Vector3(1.3, 0.35, 1.8),
				sp + Vector3(0, 0.45, 0), sp + Vector3(0, 0.45, 0)), "fov": 38.0, "dof": 4.0}
		"v_sulo":
			_time(main, 18, 0)
			var sl: Node3D = main.sulo
			var sp := sl.global_position
			_hold(main, sl)
			var out := _out_dir(main, sp)
			sl.rotation.y = B.yaw_to(out)
			sl._body.play("Idle_Talking", 0.2)
			d.bubble(sl, "Sulo: Kaksikymppiä. Ja sää et oo nähny mitään.", 3.0)
			return {"done": func() -> void: _release(sl),
				"cam": dolly(sp + out * 4.0 + _side(out) * 1.3 + Vector3(0, 1.65, 0), sp + out * 3.3 + _side(out) * 1.0 + Vector3(0, 1.65, 0),
				sp + Vector3(0, 1.75, 0), sp + Vector3(0, 1.75, 0)),
				"fov": 40.0, "dof": 6.0}
		"v_seppo":
			_time(main, 12, 30)
			var sd: Vector3 = main.world.seppo_door
			var sn: Node3D = main.world.seppo_npc
			if sn:
				d.bubble(sn, "Seppo: Hopeanuoli. Isävainaan. Ei oo myynnissä.", 3.0)
			var tarp: Vector3 = main.world.seppo_tarp
			var mid: Vector3 = (tarp + sn.global_position) / 2.0 + Vector3(0, 1.3, 0) if sn else tarp + Vector3(0, 0.8, 0)
			var eye := _best_eye(main, mid, _ring(mid, _out_dir(main, mid), 6.5, 0.5, 16))
			return {"cam": dolly(eye, mid + (eye - mid) * 0.8, mid, mid), "fov": 44.0, "dof": 9.0}
		"v_korjaamo":
			_time(main, 10, 30)
			var kd: Vector3 = _g(main.world.korpela_door)
			var kc := M.w(M.KORPELA)
			var front := kd - kc
			front.y = 0.0
			front = front.normalized()
			var look := kc + Vector3(0, 1.8, 0)
			var eye := kc + front * 17.0 + _side(front) * 6.0 + Vector3(0, 6.5, 0)
			return {"cam": dolly(eye, look + (eye - look) * 0.72, look, look), "fov": 46.0}
		"v_miisu":
			_time(main, 12, 0)
			var aa: Node3D = main.aaro
			_hold(main, aa)
			var ap := aa.global_position
			var out := _out_dir(main, ap)
			aa.rotation.y = B.yaw_to(out)
			aa._body.play("Idle_Talking", 0.2)
			d.bubble(aa, "Aaro: Miisu! Miisu! Onko kukaan nähny Miisua?", 3.0)
			var look := ap + Vector3(0, 1.75, 0)
			var eye := _best_eye(main, look, _ring(look, out + _side(out) * 0.35, 4.0, -0.1))
			return {"cam": dolly(eye, look + (eye - look) * 0.82, look, look), "fov": 40.0, "dof": 6.0,
				"done": func() -> void: _release(aa)}
		"p_siili":
			_time(main, 16, 30)
			var lw: Node3D = main.lawn
			_foot(main, lw.mower_park + Vector3(1.2, 0, 0.8), Vector3.FORWARD)
			main._start_mowing(lw)
			var w: Node3D = main.walker_out
			var eye0 := _best_eye(main, w.global_position + Vector3(0, 1.0, 0), _ring(w.global_position, Vector3(-1, 0, 1), 7.0, 1.8))
			return {"keys": [[0.0, "forward", 99.0]], "cam": func(t: float) -> Array:
				var shake := Vector3(sin(t * 6.1) * 0.05, sin(t * 8.9) * 0.04, 0)
				return [eye0 + shake, w.global_position + Vector3(0, 0.8, 0) + shake * 2.0], "fov": 48.0,
				"done": func() -> void: main._stop_mowing()}

		# --- Kertosäe ja kliimaksi (Saloinen) ------------------------------------------------------------------------
		"k_laavu":
			_time(main, 21, 30)
			main.world.fire.visible = true
			main.guard.mode = "gone"
			main.guard.visible = false
			var l := M.w(M.LAAVU)
			return {"cam": dolly(l + Vector3(-5, 1.4, -7), l + Vector3(-3.5, 1.2, -5), l + Vector3(0, 0.6, 0), l + Vector3(0, 0.7, 0)),
				"fov": 44.0}
		"k_uimaranta":
			_time(main, 14, 0)
			var u := M.w(M.UIMARANTA)
			var dir := _dir(M.UIMARANTA_DIR)
			_foot(main, u - dir * 2.0, dir)
			return {"keys": [[0.0, "forward", 99.0], [0.0, "sprint", 99.0]], "cam": dolly(u + dir * 4.5 + _side(dir) * 1.8 + Vector3(0, 0.7, 0),
				u + dir * 3.8 + _side(dir) * 1.2 + Vector3(0, 0.8, 0), u - dir * 1.5 + Vector3(0, 1.1, 0), u + dir * 1.5 + Vector3(0, 1.0, 0)),
				"fov": 40.0, "dof": 9.0}
		"k_rossi":
			_time(main, 13, 0)
			_on_bike(main)
			main.bike.set_mopo(true)
			var g: Vector3 = main.world.rossi_gate
			var jumps: Array = main.world.rossi_jumps
			var j: Vector3 = jumps[0][0] if jumps.size() > 0 else g + Vector3(20, 0, 0)
			main.bike.global_position = g + Vector3(0, 0.3, 0)
			main.bike.autopilot = true
			main.bike.auto_speed = 1.0
			main.bike.auto_target = j + (j - g).normalized() * 30.0
			return {"cam": follow(main.bike, Vector3(3.0, 0.6, -2.0), Vector3(3.5, 1.0, 1.5), Vector3(0, 0.8, 0)), "fov": 44.0,
				"done": func() -> void: main.bike.set_mopo(false)}
		"k_juntti", "f_tappelu":
			_time(main, 14, 0)
			main.beers = 6
			main.trailer_safe = false
			main._start_fight("juntti", "juntti", Vector3.RIGHT)
			var keys := []
			for i in 8:
				keys.append([0.2 + i * 0.35, "punch" if i % 3 != 2 else "kick"])
			return {"warm": 50, "keys": keys, "lose": true}
		"f_hyundai", "f_hyundai2":
			_time(main, 16, 0)
			var a := M.w(Vector2(470, 1000)) if id == "f_hyundai" else M.w(Vector2(250, 760))
			var tick := ride(main, a, M.w(M.J_T) if id == "f_hyundai" else M.w(M.J_W), 1.0)
			var wf: Node3D = _wife(main)
			var back: Vector3 = -main.bike.global_transform.basis.z
			wf.global_position = main.bike.global_position - back * 14.0
			wf.rotation.y = main.bike.rotation.y
			wf.parked = false
			wf.mode = "chase"
			wf.target = main.bike
			if id == "f_hyundai":
				return {"tick": tick, "cam": follow(main.bike, Vector3(0.8, 1.1, -4.0), Vector3(0.6, 1.0, -3.5), Vector3(0, 1.0, 8.0)), "fov": 50.0}
			return {"tick": tick, "cam": follow(wf, Vector3(2.4, 0.5, -3.5), Vector3(1.6, 0.6, -4.5), Vector3(0, 0.8, 0)), "fov": 40.0}
		"f_poliisi":
			_time(main, 17, 0)
			var a := M.w(Vector2(420, 950))
			var tick := ride(main, a, M.w(M.J_T), 1.0)
			main._call_police("siili")
			var po: Node3D = main.police
			if is_instance_valid(po):
				var wd: Node3D = main.world
				po.setup(wd.graph_nodes, wd.graph_adj, wd.nearest_node(main.bike.global_position + main.bike.global_transform.basis.z * 18.0), main.player)
				po.start_chase()
				return {"tick": tick, "cam": follow(main.bike, Vector3(0.9, 1.2, -4.5), Vector3(0.7, 1.0, -3.8), Vector3(0, 1.0, 10.0)), "fov": 46.0,
					"warm": 10}
			return {"tick": tick, "cam": follow(main.bike, Vector3(2.0, 1.0, 4.0), Vector3(1.5, 1.0, 3.5), Vector3(0, 1.0, 0)), "fov": 46.0}
		"f_traktori":
			_time(main, 14, 30)
			var tr: Node3D = main.tractor
			var tp := tr.global_position
			_foot(main, tp + Vector3(12.0, 0, 0), Vector3(1, 0, 0))
			tr.mode = "chase"
			return {"keys": [[0.0, "forward", 99.0], [0.0, "sprint", 99.0]], "cam": follow(tr, Vector3(-3.0, 1.0, -6.0), Vector3(-2.0, 1.2, -7.5),
				Vector3(0, 1.6, 0)), "fov": 40.0}
		"f_sahkopyora_ajo":
			_time(main, 18, 30)
			var a := M.w(Vector2(830, 1240))
			var tick := ride(main, a, M.w(M.J_KL), 1.0)
			return {"tick": tick, "cam": follow(main.bike, Vector3(-0.5, 0.3, 2.5), Vector3(-0.3, 0.35, 2.0), Vector3(0, 0.9, -4.0)), "fov": 60.0}
		"f_mopo_ajo":
			_time(main, 19, 30)
			_on_bike(main)
			main.bike.set_mopo(true)
			var a := M.w(Vector2(250, 760))
			var tick := ride(main, a, M.w(Vector2(470, 1000)), 1.0)
			return {"tick": tick, "cam": follow(main.bike, Vector3(2.6, 0.7, 1.5), Vector3(2.4, 0.8, -1.0), Vector3(0, 0.8, 0)), "fov": 44.0,
				"done": func() -> void: main.bike.set_mopo(false)}
		"f_kaatuminen":
			_time(main, 15, 0)
			var a := M.w(Vector2(640, 1150))
			var tick := ride(main, a, M.w(M.J_T), 1.0)
			var b: Node3D = main.bike
			var tk := func(t: float) -> void:
				tick.call(t)
				if absf(t - 0.8) < 0.02 and b.has_method("stagger"):
					b.stagger(b.global_transform.basis.x)
			return {"tick": tk, "cam": follow(b, Vector3(3.0, 0.8, -3.0), Vector3(3.2, 0.9, -1.0), Vector3(0, 0.8, 0)), "fov": 44.0}
		"f_drooni":
			_time(main, 13, 0)
			var c := M.w(M.HOME_BUILDING)
			return {"cam": dolly(c + Vector3(-40, 35, 40), c + Vector3(-25, 28, 28), c, c + Vector3(5, 0, 0)), "fov": 50.0}
		"f_kaitasaari":
			_time(main, 21, 50)
			var k := M.w(M.KAITASAARI)
			return {"cam": dolly(k + Vector3(-30, 32, 30), k + Vector3(-18, 28, 20), k + Vector3(60, 0, -40), k + Vector3(70, 2, -40)), "fov": 48.0,
				"fog": 2.0}
		"f_wasted":
			_time(main, 16, 40)
			var a := M.w(Vector2(640, 1150))
			ride(main, a, M.w(M.J_T), 1.0)
			var tk := func(t: float) -> void:
				if absf(t - 0.25) < 0.02:
					main._lose("Päivi nappasi kiinni!", "wife")
			return {"lose": true, "tick": tk}
		"f_auringonlasku":  # pelin oma loppuvälianimaatio: LEGENDAARINEN NORMIPÄIVÄ
			_time(main, 21, 40)
			main.beers = 5
			main.fire_lit = true
			main.sausage_done = true
			main.stash_laavu = 7
			main._win_laavu()
			return {"warm": 40}
		"f_nuotio":  # makkaranpaisto Keskimmäisen laavulla (mökki): hahmo istuu ja kääntelee makkaraa
			var mk: Node3D = _mokki(main)
			_time(main, 21, 50)
			_foot(main, mk.to_global(mk.laavu_fire) + Vector3(2, 0, 2), Vector3.FORWARD)
			var lay: Dictionary = mk.keskimmainen_layout()
			main.cutscene.makkara(mk.to_global(mk.laavu_fire), mk.global_basis * Vector3(lay.d.x, 0, lay.d.y), func() -> void: pass)
			return {"warm": 75, "glow": 0.12, "brightness": 0.92}
		"f_kalja":  # jatkuu samasta makkaravälianimaatiosta (sama ryhmä, ei uutta lavastusta)
			return {"warm": 20}

		# --- Sisätilat ----------------------------------------------------------------------------------------------
		"avaus_paivi":  # yöllä kotiovella: Päivi odottaa ovensuussa, pelaaja tulee pyörällä pihaan
			_time(main, 0, 50)
			var door: Vector3 = _g(main.home_door)
			var f := _dir(M.HOME_YAW_DIR)
			var pv := _person(main, d, Looks().PAIVI, door + f * 0.6, f, "Idle_Talking")
			var tk := func(t: float) -> void:
				if absf(t - 0.8) < 0.02:
					d.bubble(pv, "Päivi: Missä sää oikein olit?!", 4.0, 2.05)
			var look := door + f * 0.6 + Vector3(0, 1.3, 0)
			var eye := door + f * 6.5 + _side(f) * 1.5 + Vector3(0, 3.4, 0)  # pihan autojen katon yli
			return {"tick": tk, "cam": dolly(eye, look + (eye - look) * 0.6, look, look + Vector3(0, 0.15, 0), 5.0), "fov": 38.0, "dof": 6.0,
				"brightness": 0.9}
		"i_kassa":
			_time(main, 10, 10)
			main.beers = 6
			main._enter_shop()
			var si: Node3D = main.interior
			si.has_beer = true
			si.walker.set_carrying(true)
			si.walker.position = si.QUEUE_FRONT + si.QUEUE_STEP * 3
			var q: Vector3 = si.QUEUE_FRONT
			return {"warm": 50, "cam": dolly(si.to_global(q + Vector3(-3.2, 1.5, 1.6)), si.to_global(q + Vector3(-2.6, 1.45, 1.0)),
				si.to_global(q + Vector3(0.4, 1.1, -0.6)), si.to_global(q + Vector3(0.4, 1.1, -1.0))), "fov": 42.0, "dof": 6.0}
		"v_lista":
			_time(main, 10, 30)
			main._enter_shop()
			var si: Node3D = main.interior
			si.walker.position = Vector3(10.3, 0, -5.5)
			si.walker.rotation.y = B.yaw_to(Vector3(1, 0, 0))
			return {"cam": dolly(si.to_global(Vector3(10.2, 1.5, -8.6)), si.to_global(Vector3(10.1, 1.45, -8.1)),
				si.to_global(Vector3(11.2, 1.15, -5.6)), si.to_global(Vector3(11.1, 1.2, -5.4))), "fov": 44.0, "dof": 3.5}
		"k_kulma":
			_time(main, 21, 0)
			if main.state != "in_raahe":
				main._enter_raahe()
			var ri: Node3D = main.raahe_int
			ri.walker.position = Vector3(0.0, 0, 3.5)
			return {"cam": dolly(ri.to_global(Vector3(-4.0, 2.4, 5.0)), ri.to_global(Vector3(-2.5, 2.2, 4.0)), ri.to_global(Vector3(2, 1.0, -1)),
				ri.to_global(Vector3(3, 1.0, -1))), "fov": 52.0}
		"k_vaanto":
			_time(main, 21, 20)
			if main.state != "in_raahe":
				main._enter_raahe()
			var ri: Node3D = main.raahe_int
			ri.walker.position = ri.spots.tero[0]
			for i in 3:
				await main.get_tree().process_frame
			main._on_raahe_acted("tero")
			for i in 50:
				await main.get_tree().process_frame
			await d.tap_now("interact")
			var keys := []
			for i in 16:
				keys.append([0.3 + i * 0.1, "left" if i % 2 == 0 else "right"])
			var bg: Node3D = _find(main, "bar_game.gd")
			if bg == null:
				return {"warm": 95, "keys": keys, "hide_games": ["bar_game.gd"]}
			var ty: float = bg.TABLE_Y
			var grip: Vector3 = bg.to_global(Vector3(0, ty + 0.25, -0.05))
			# Ote heiluu puolelta toiselle (jännite), kamera matalalta sivusta hitaasti otetta kohti.
			var tk := func(t: float) -> void:
				if is_instance_valid(bg) and bg._phase == "wrestle":
					bg._angle = sin(t * 2.4) * 0.45 + sin(t * 5.3) * 0.08
			return {"warm": 95, "keys": keys, "hide_games": ["bar_game.gd"], "tick": tk,
				"cam": dolly(bg.to_global(Vector3(1.25, ty + 0.35, 0.45)), bg.to_global(Vector3(0.8, ty + 0.3, 0.25)), grip + Vector3(0, 0.05, 0), grip),
				"fov": 40.0, "dof": 2.5}
		"k_karaoke", "f_karaoke":
			_time(main, 22, 0)
			var again: bool = id == "f_karaoke" and _find(main, "karaoke_game.gd") != null  # sama laulu jatkuu
			if not again:
				if main.state != "in_raahe":
					main._enter_raahe()
				var ri: Node3D = main.raahe_int
				ri.walker.position = ri.spots.karaoke[0]
				main.money = 50.0
				main._raahe_karaoke()
			var tk := func(_t: float) -> void:  # laulaja osuu nuotteihin
				var g: Node = _find(main, "karaoke_game.gd")
				if g != null:
					var cur: Array = g._note_at(g._t + 0.05)
					if not cur.is_empty():
						g._pitch = float(cur[2])
			var ri2: Node3D = main.raahe_int
			var sw: Node3D = ri2.walker
			var sing := sw.global_position + Vector3(0, 1.5, 0)
			for b in ri2._bubbles.values():  # baarimikon tervehdys pois
				b.text = ""
			var facing := -sw.global_transform.basis.z
			# Kellari on katoton: kamera ylempää alaviistoon, laulajan edestä vähän sivusta.
			var eye := _best_eye(main, sing, _ring(sing, facing + _side(facing) * 0.4, 3.6, 0.7))
			d.bubble(sw, "♪ Ruukin valot syttyy yöhön ♪", 9.0, 2.1)
			return {"warm": 60, "tick": tk, "hide_games": ["karaoke_game.gd"], "cam": dolly(eye, sing + (eye - sing) * 0.75, sing, sing),
				"fov": 46.0, "dof": 6.0}
		"k_huutokauppa", "k_nuija":
			_time(main, 13, 0)
			if main.state != "in_kirppis":
				main._enter_kirppis()
			main.money = 200.0
			if id == "k_huutokauppa":
				main._start_auction()
				var ag: Node = _find(main, "auction_game.gd")
				var keys := [[1.0, "interact"], [3.0, "interact"], [5.0, "interact"]]
				if ag == null:
					return {"warm": 40, "keys": keys, "hide_games": ["auction_game.gd"]}
				var er: Node3D = ag._erkki
				var ef: Vector3 = er.global_position
				var gcam: Vector3 = ag._cam.global_position
				var tow := ((gcam - ef) * Vector3(1, 0, 1)).normalized()
				var look := ef + Vector3(0, 1.5, 0)
				return {"warm": 40, "keys": keys, "hide_games": ["auction_game.gd"],
					"cam": dolly(look + tow * 3.6 + _side(tow) * 1.2 + Vector3(0, -0.3, 0), look + tow * 2.8 + _side(tow) * 0.9 + Vector3(0, -0.3, 0), look, look),
					"fov": 42.0, "dof": 4.0}
			var ki: Node3D = main.kirppis_int
			return {"cam": dolly(ki.to_global(Vector3(-3, 1.8, 4)), ki.to_global(Vector3(-2, 1.7, 3)), ki.to_global(Vector3(0, 1.4, -4)),
				ki.to_global(Vector3(0, 1.5, -4))), "fov": 46.0}
		"k_piirakka", "k_piirakka2":
			_time(main, 15, 0)
			var rw: Vector3 = main.world.reippari_window
			_foot(main, rw, Vector3.FORWARD)
			main._start_piirakka()
			var keys := []
			var t0 := 0.0 if id == "k_piirakka" else 0.1
			for i in 4:
				var b := t0 + i * 0.4
				keys.append([b, "jump"])
				keys.append([b + 0.12, "left"])
				keys.append([b + 0.24, "right"])
			if id == "k_piirakka2":
				keys.append([1.25, "forward"])
			return {"warm": 75 if id == "k_piirakka" else 140, "keys": keys, "hide_games": ["piirakka_game.gd"]}
		"k_keinu":
			_time(main, 14, 0)
			var pg: Dictionary = main.world.playgrounds[0]
			_foot(main, pg.swing if pg.get("swing") is Vector3 else main.home_zone, Vector3.FORWARD)
			main._start_keinu(pg)
			var st := {"last": "back", "jumped": false, "eye": Vector3.ZERO}
			# Vauhti valmiiksi isoksi; pumppaus näkyy, ja hyppy lähtee eteenpäin heilahduksen nousussa (huippuhetki).
			var tk := func(t: float) -> void:
				var g: Node = main._keinu
				if g == null or g._phase != "swing":
					return
				if t == 0.0:
					g._th = -0.95
					g._w = 0.0
				var want := "forward" if g._w > 0.0 else "back"
				if want != st.last and absf(g._th) < 0.3:
					d.tap(want)
					st.last = want
				if t > 1.4 and not st.jumped and g._w > 0.0 and g._th > 0.35 and g._th < 0.6:
					d.tap("jump")
					st.jumped = true
			var cam := func(_t: float) -> Array:
				var g: Node3D = main._keinu
				if g == null:
					return [Vector3.ZERO, Vector3.ZERO]
				var r: Vector3 = g._rider.global_position + Vector3(0, 0.9, 0)
				var side: Vector3 = g.global_basis.x.normalized()
				var fwd: Vector3 = g.global_basis.z.normalized()
				var want: Vector3 = r + side * 5.5 + fwd * 1.0 + Vector3(0, 0.4, 0)
				st.eye = want if st.eye == Vector3.ZERO else st.eye.lerp(want, 0.12)
				return [st.eye, r]
			return {"warm": 150, "tick": tk, "cam": cam, "fov": 46.0, "dof": 7.0, "hide_games": ["keinu_game.gd"]}
		"v_sahkopyora", "v_mopo_potku":
			_time(main, 19, 0)
			if id == "v_mopo_potku":
				main.oma_mopo.owned = true
			if main.state != "in_garage":
				_foot(main, main.world.garage_door, Vector3.FORWARD)
				main._enter_garage()
			if id == "v_mopo_potku":
				main.garage_int.set_mopo(true, false)
				main._start_kick()
				var kg: Node = _find(main, "mopo_kick_game.gd")
				var ks := {"n": 0}
				var ktk := func(t: float) -> void:
					if kg == null or not is_instance_valid(kg) or kg._running:
						return
					var plan := [[0.6, true], [2.0, true], [3.6, false]]  # [aika, rikastin]
					if ks.n < plan.size() and t >= plan[ks.n][0]:
						kg._choke = plan[ks.n][1]
						kg._kick(0.74)
						ks.n += 1
				return {"warm": 40, "tick": ktk, "hide_games": ["mopo_kick_game.gd"]}
			var gi: Node3D = main.garage_int
			gi.set_bike(true)
			gi.walker.position = Vector3(-0.5, 0, -3.4)
			gi.walker.rotation.y = B.yaw_to(Vector3(0, 0, -1))
			# Talli on katoton (peli kuvaa ylhäältä): kamera katsoo alaviistoon, ettei taivas näy seinien yli.
			return {"cam": dolly(gi.to_global(Vector3(3.0, 3.2, 3.6)), gi.to_global(Vector3(2.4, 2.9, 2.6)), gi.to_global(Vector3(-1.2, 0.6, -2.6)),
				gi.to_global(Vector3(-0.9, 0.7, -3.0))), "fov": 50.0, "dof": 7.0}

		# --- Mökki Neittävällä --------------------------------------------------------------------------------------
		"t_mokki_saapuu", "t_paapeli", "m_sauna":
			var mk: Node3D = _mokki(main)
			_time(main, 18, 0) if id != "m_sauna" else _time(main, 21, 40)
			_foot(main, mk.to_global(Vector3(-2, 0, -14)), Vector3.FORWARD)
			var lg := func(x: float, z: float, y: float) -> Vector3:  # mökin paikallinen piste maaston päällä
				return mk.to_global(Vector3(x, mk.h(x, z) + y, z))
			if id == "t_mokki_saapuu":  # puiden latvojen yli, alas pihaan
				return {"cam": dolly(lg.call(-18, -26, 24.0), lg.call(-12, -18, 14.0), lg.call(0, -1, 1.5), lg.call(0, -1, 1.5)), "fov": 52.0}
			if id == "m_sauna":
				mk.set_sauna_fire(true)
				mk.set_tub_fire(true)
				var look: Vector3 = lg.call(3.0, 17.0, 1.2)
				var eye := _best_eye(main, look, [lg.call(-5, 10, 2.4), lg.call(-6, 14, 2.2), lg.call(0, 9, 2.6), lg.call(10, 10, 2.4)])
				return {"cam": dolly(eye, look + (eye - look) * 0.75, look, look), "fov": 55.0}
			return {"cam": dolly(mk.to_global(Vector3(-6, 4, 22)), mk.to_global(Vector3(-3, 3, 20)), mk.to_global(Vector3(7, 1.2, 24)),
				mk.to_global(Vector3(7, 1.2, 22))), "fov": 55.0}
		"m_laituri":
			var mk: Node3D = _mokki(main)
			_time(main, 22, 10)
			var dl: Vector3 = mk.DOCK_LOCAL
			var deck: float = mk.to_global(Vector3(dl.x, mk.h(dl.x, dl.z - 11.6), dl.z)).y  # laiturin kansi (kuten m_kala)
			var w := _foot(main, mk.to_global(Vector3(dl.x, 0, dl.z - 1.5)), mk.global_transform.basis * Vector3(0, 0, 1))
			w.global_position.y = deck + 0.7
			var at := func(x: float, y: float, z: float) -> Vector3:
				var g := mk.to_global(Vector3(dl.x + x, 0, dl.z + z))
				return Vector3(g.x, deck + y, g.z)
			return {"cam": dolly(at.call(-2.6, 1.6, -8.0), at.call(-1.8, 1.5, -6.0), at.call(0, 1.1, -1.5), at.call(0, 1.0, 4.0)), "fov": 44.0,
				"fog": 1.5}
		"m_kala":
			var mk: Node3D = _mokki(main)
			_time(main, 19, 30)
			var dl: Vector3 = mk.DOCK_LOCAL
			_foot(main, mk.to_global(Vector3(dl.x, 0, dl.z)), Vector3.FORWARD)
			main.walker_out.global_position.y = mk.to_global(Vector3(dl.x, mk.h(dl.x, dl.z - 11.6), dl.z)).y + 0.7
			main._start_fishing()
			var fg: Node = _find(main, "fish_game.gd")
			var fst := {"eye": Vector3.ZERO}
			var fcam := func(t: float) -> Array:
				if fg == null or not is_instance_valid(fg):
					return [Vector3.ZERO, Vector3.ZERO]
				var bp: Vector3 = fg._boat.global_position + Vector3(0, 0.9, 0)
				var ang := 0.6 + t * 0.12
				var want := bp + Vector3(cos(ang), 0, sin(ang)) * 4.2 + Vector3(0, 0.5, 0)
				fst.eye = want if fst.eye == Vector3.ZERO else fst.eye.lerp(want, 0.1)
				return [fst.eye, bp]
			return {"warm": 30, "keys": [[0.3, "interact"], [1.2, "forward", 0.8], [2.4, "interact", 0.8]], "hide_games": ["fish_game.gd"],
				"cam": fcam, "fov": 44.0, "dof": 6.0}
		"f_uinti":
			var mk: Node3D = _mokki(main)
			_time(main, 15, 0)
			_foot(main, mk.gpos(mk.beach_pos), Vector3.FORWARD)
			main._swim("Salminen", Vector3.ZERO)
			return {"warm": 150}
		"f_pingis":
			var mk: Node3D = _mokki(main)
			_time(main, 16, 0)
			var pl: Vector3 = mk.PINGIS_LOCAL
			_foot(main, mk.to_global(Vector3(pl.x, 0, pl.z + 2.0)), Vector3.FORWARD)
			main._start_pingis()
			var pg: Node3D = main.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("pingis_game.gd"))[0]
			var PG = pg.get_script()
			var tk := func(_t: float) -> void:
				if not is_instance_valid(pg):
					return
				if pg._phase == "serve" and pg._server == 0:
					pg._serve(0)
				elif pg._phase == "rally" and pg._last == 1 and pg._pl[0].swing_t < 0.0:
					pg._pl[0].x = move_toward(pg._pl[0].x, clampf(pg._land_x(PG.HIT_Y) - 0.45, -PG.X_MAX, -PG.X_MIN), 0.06)
					if pg._ball.distance_to(pg._paddle(0)) < 0.6:
						pg._swing(0, "smash" if pg._ball.y > 1.8 else "normal", 0.0)
			for i in 90:
				tk.call(0.0)
				await main.get_tree().process_frame
			var pst := {"eye": Vector3.ZERO}
			var pcam := func(_t: float) -> Array:
				if not is_instance_valid(pg):
					return [Vector3.ZERO, Vector3.ZERO]
				var a: Vector3 = pg._pl[0].body.global_position
				var b: Vector3 = pg._pl[1].body.global_position
				var mid := a.lerp(b, 0.25) + Vector3(0, 1.2, 0)
				var away: Vector3 = (pg._cam.global_position - mid) * Vector3(1, 0, 1)
				var want := mid + away.normalized() * 3.6 + (b - a).normalized() * -1.2 + Vector3(0, 0.1, 0)
				pst.eye = want if pst.eye == Vector3.ZERO else pst.eye.lerp(want, 0.1)
				return [pst.eye, mid]
			return {"warm": 1, "tick": tk, "hide_games": ["pingis_game.gd"], "cam": pcam, "fov": 42.0, "dof": 5.0}
		"f_jahti":
			var mk: Node3D = _mokki(main)
			_time(main, 7, 0)
			var hl: Vector3 = mk.HUNT_LOCAL
			_foot(main, mk.to_global(Vector3(hl.x + 1.5, 0, hl.z)), Vector3.FORWARD)
			main._start_hunt()
			var hg: Node3D = mk.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("hunt_game.gd"))[0]
			hg._spawn_t = 0.0
			return {"warm": 120, "hide_games": ["hunt_game.gd"], "tick": func(t: float) -> void:
				if absf(t - 1.0) < 0.02 and hg._reload_t <= 0.0:
					hg._shoot()}

		# --- Vaala (mopomatka) ---------------------------------------------------------------------------------------
		"f_mopo_silta":
			_time(main, 20, 0)
			var mt: Node3D = _vaala(main)
			var mp: CharacterBody3D = mt.mopo
			var vl: Node3D = mt.vaala
			for car in mt._cars:
				car.process_mode = Node.PROCESS_MODE_DISABLED
				car.visible = false
			var si := int(vl.data.bridges[0][0]) - 12
			var dr: Vector3 = vl.road_dir(si)
			mp.position = vl.road_pos(si) + Vector3(0, 0.6, 0) + dr.cross(Vector3.UP) * 0.9
			mp.rotation.y = atan2(-dr.x, -dr.z)
			mp.speed = 10.0
			var ms := {"i": si}
			var mtk := func(_t: float) -> void:  # ohjaus tietä pitkin (muuten mopo ajaa suoraan mutkasta ojaan)
				while vl.road_pos(ms.i + 1).distance_to(mp.position) < vl.road_pos(ms.i).distance_to(mp.position):
					ms.i += 1
				var tgt: Vector3 = vl.road_pos(ms.i + 4) + vl.road_dir(ms.i + 4).cross(Vector3.UP) * 0.9
				var v := tgt - mp.position
				mp.rotation.y = lerp_angle(mp.rotation.y, atan2(-v.x, -v.z), 0.2)
			return {"tick": mtk, "keys": [[0.0, "forward", 99.0]], "cam": follow(mp, Vector3(-3.0, 1.0, 3.5), Vector3(-4.0, 2.5, 6.0), Vector3(0, 0.8, 0)),
				"fov": 46.0, "warm": 6}
		"f_lava":
			_time(main, 21, 30)
			var mt: Node3D = _vaala(main)
			var vl: Node3D = mt.vaala
			var c: Vector3 = mt.to_global(vl.lava_center)
			var o: Vector3 = mt.to_global(vl.lava_door + vl.lava_out * 30.0 + Vector3(-25, 18, 30))
			return {"cam": dolly(o, o.lerp(c, 0.2), c, c), "fov": 50.0}
		"f_lava_tanssi":
			_time(main, 22, 0)
			var mt: Node3D = _vaala(main)
			var mp: CharacterBody3D = mt.mopo
			mp.position = mt.vaala.lava_door + Vector3(0, 0.6, 0)
			mp.speed = 0.0
			main.money = 40.0
			for i in 10:
				await main.get_tree().process_frame
			main._lava_gate()
			main._enter_lava(true)
			var lg: Node = _find(main, "lava_game.gd")
			var lst := {"eye": Vector3.ZERO}
			var lcam := func(t: float) -> Array:
				if lg == null or not is_instance_valid(lg):
					return [Vector3.ZERO, Vector3.ZERO]
				var a: Vector3 = lg._me.global_position
				var b: Vector3 = lg._partner.global_position
				var mid := (a + b) / 2.0 + Vector3(0, 1.2, 0)
				var ang := t * 0.35  # hidas kierto parin ympäri
				var want := mid + Vector3(cos(ang), 0, sin(ang)) * 3.4 + Vector3(0, 0.2, 0)
				lst.eye = want if lst.eye == Vector3.ZERO else lst.eye.lerp(want, 0.15)
				return [lst.eye, mid]
			return {"warm": 60, "hide_games": ["lava_game.gd"], "cam": lcam, "fov": 46.0, "dof": 5.0}
		"f_siitari":
			_time(main, 21, 0)
			var mt: Node3D = _vaala(main)
			var mp: CharacterBody3D = mt.mopo
			mp.position = mt.vaala.siitari_park + Vector3(0, 0.5, 0)
			for i in 10:
				await main.get_tree().physics_frame
			mt.stop()
			main._on_mopo_arrived()
			main.money = 30.0
			var sw: Node3D = main.siitari_int.walker
			sw.position = Vector3(0.5, 0, 1.0)
			var sp: Vector3 = sw.global_position
			# Katoton sisätila: kamera alaviistoon, ettei taivas näy.
			return {"warm": 40, "cam": dolly(sp + Vector3(2.8, 3.4, 4.0), sp + Vector3(2.2, 3.0, 3.2), sp + Vector3(-1.0, 0.6, -2.5),
				sp + Vector3(-1.2, 0.7, -2.8)), "fov": 55.0}
		"f_kiihdytys":
			_time(main, 19, 0)
			var mt: Node3D = _vaala(main)
			var vl: Node3D = mt.vaala
			main.money = 30.0
			main._mopo_dismount()
			main.walker_out.global_position = mt.to_global(vl.race_spot + Vector3(0, 0.5, 0) + vl.doors.filter(func(x): return x.id == "kiihdytys")[0].out * 3.0)
			for i in 10:
				await main.get_tree().process_frame
			main._on_vaala_door("kiihdytys")
			main._talk_choose("kisa")
			return {"warm": 90, "keys": [[0.0, "forward", 99.0]], "hide_games": ["mopo_race.gd"]}
		"f_nuoret":
			_time(main, 22, 30)
			var mt: Node3D = _vaala(main)
			var vl: Node3D = mt.vaala
			var pp: Vector3 = mt.to_global(vl.party_pos)
			var look := pp + Vector3(0, 0.8, 0)
			return {"cam": dolly(pp + Vector3(3.4, 1.3, 2.6), pp + Vector3(2.6, 1.15, 2.0), look, look + Vector3(0, 0.15, 0)), "fov": 48.0, "dof": 6.0}
		"m_juna":
			_time(main, 9, 0)
			var sp: Vector3 = main.world.station_pos
			_foot(main, sp + Vector3(0, 0, 1.0), Vector3.FORWARD)
			main.money = 40.0
			main._train_trip("vaala")
			return {"warm": 150}

		# --- Hahmoesittelyt: hahmo omassa ympäristössään, hidas työntö kohti -------------------------------------------
		"h_paivi":
			_time(main, 17, 30)
			var h := M.w(M.HOME_ZONE)
			var f := _dir(M.HOME_YAW_DIR)
			var w: Node3D = _wife(main)
			w.parked = true
			w.global_position = h - f * 3.0 + _side(f) * 4.0 + Vector3(0, 0.3, 0)
			w.rotation.y = B.yaw_to(-f)
			var p := _person(main, d, Looks().PAIVI, h + f * 0.5 + _side(f) * 2.2, -_side(f) * 0.3 + f, "Idle_Talking")
			return _portrait(main, p, f, 1.0)
		"h_pekka":
			_time(main, 16, 0)
			var c := M.w(M.NEIGHBOR_PEKKA)
			var f := _dir(M.HOME_YAW_DIR)
			var p := _person(main, d, Looks().PEKKA, c + f * 9.0, f, "Idle_Talking")
			return _portrait(main, p, f, -1.0)
		"h_arto":
			_time(main, 15, 0)
			var c := M.w(M.NEIGHBOR_ARTO)
			var f := _dir(M.HOME_YAW_DIR)
			var p := _person(main, d, Looks().ARTO, c + f * 9.0, f, "Idle")
			return _portrait(main, p, f, 1.0)
		"h_juntti":
			_time(main, 14, 0)
			var j: Node3D = main.juntti
			var f: Vector3 = -j.global_transform.basis.z
			f.y = 0.0
			return _portrait(main, j, f, -1.0)
		"h_annaliisa":
			_time(main, 11, 0)
			var c := M.w(M.NEIGHBOR_SINIKKA)
			var f := _dir(M.HOME_YAW_DIR)
			var p := _person(main, d, Looks().ANNA_LIISA, c + f * 8.0 - _side(f) * 6.0, f + _side(f) * 0.5, "Idle_Talking")
			return _portrait(main, p, f, 1.0)
		# --- Prologin uudet otokset (PAPERILEIKKAUS.md) ------------------------------------------------------------
		"p_hyundai_lahtee":  # aamu: Päivin Hyundai lähtee pihasta töihin, pelaaja jää pihalle katsomaan
			_time(main, 7, 40)
			var h := M.w(M.HOME_ZONE)
			var f := _dir(M.HOME_YAW_DIR)
			_foot(main, h + f * 2.0 + _side(f) * 2.5, -_side(f))
			var wf: Node3D = _wife(main)
			wf.mode = "patrol"
			wf.reset_to(main.world.nearest_node(h))
			var look := wf.global_position + Vector3(0, 0.9, 0)
			var eye := _best_eye(main, look, _ring(look, f + _side(f), 7.0, 0.3, 16))
			return {"warm": 4, "cam": func(_t: float) -> Array:
				return [eye, wf.global_position + Vector3(0, 0.9, 0)], "fov": 38.0, "dof": 12.0}
		"p_talli":  # tallin ovi auki: pelaaja taluttaa pyörän ulos kohti kameraa (vastavalo)
			_time(main, 8, 10)
			var gd: Vector3 = _g(main.world.garage_door)
			var out: Vector3 = main.world.garage_out
			out.y = 0.0
			out = out.normalized()
			var w := _foot(main, gd - out * 1.2, out)
			main.bike.global_position = gd - out * 1.2 + _side(out) * 0.8 + Vector3(0, 0.3, 0)
			main.bike.rotation.y = B.yaw_to(out)
			var look := gd + Vector3(0, 1.0, 0)
			return {"keys": [[0.4, "forward", 1.6]], "cam": dolly(gd + out * 5.5 + _side(out) * 1.5 + Vector3(0, 0.6, 0),
				gd + out * 4.6 + _side(out) * 1.2 + Vector3(0, 0.6, 0), look, look + out * 1.5), "fov": 40.0, "dof": 7.0}

		# --- Kuvauspaikkojen kierros (leikkaus.gd KIERROS): välianimaatiot ja minipelit pitkinä ottoina ------------
		"s_sauna":  # savusaunan löylyt sisältä (välianimaatio)
			var mk: Node3D = _mokki(main)
			_time(main, 21, 0)
			_foot(main, mk.gpos(mk.SAUNA_LOCAL + Vector3(-2, 0, -2)), Vector3.FORWARD)
			mk.sauna_fixed = true
			main._sauna_cutscene(false)
			return {"warm": 10}
		"s_kyyti":  # Pekan kyyti mökille (välianimaatio)
			_time(main, 17, 30)
			main._hud.visible = false
			main.state = "cutscene"
			main.cutscene.pekka_ride("Naapurin Pekka on menossa Neittävälle kyyhkyjahtiin.", func() -> void: pass)
			return {"warm": 10}
		"s_taksi":  # taksi Raaheen (välianimaatio)
			_time(main, 21, 0)
			main.state = "cutscene"
			main.cutscene.taxi_to_raahe(func() -> void: pass)
			return {"warm": 10}
		"s_mokkibileet":
			var mk: Node3D = _mokki(main)
			_time(main, 22, 30)
			main.state = "cutscene"
			main.cutscene.mokki_party(mk.porch_pos(6.0), mk.global_rotation.y, "Santtu, Sinikka ja Korpi-Kalle", func() -> void: pass)
			return {"warm": 10}
		"s_viinibileet":
			_time(main, 22, 0)
			main.state = "cutscene"
			main.cutscene.wine_party("Pekka, Arto ja Sinikka", func() -> void: pass)
			return {"warm": 10}
		"s_paivi_tv":  # Päivi näkee miehensä tanssivan TV:ssä: ruudulle oikea kuva lavatansseista (kuten pelissä)
			_time(main, 22, 0)
			var mt: Node3D = _vaala(main)
			var mp: CharacterBody3D = mt.mopo
			mp.position = mt.vaala.lava_door + Vector3(0, 0.6, 0)
			mp.speed = 0.0
			main.money = 40.0
			for i in 10:
				await main.get_tree().process_frame
			main._lava_gate()
			main._enter_lava(true)
			var lg: Node = _find(main, "lava_game.gd")
			if lg != null:
				var tvc := Camera3D.new()  # TV-kameran kuva: pari tanssilattialla
				main.add_child(tvc)
				var mid: Vector3 = (lg._me.global_position + lg._partner.global_position) / 2.0 + Vector3(0, 1.2, 0)
				tvc.look_at_from_position(mid + Vector3(3.0, 1.5, 3.0), mid)
				tvc.fov = 45.0
				tvc.current = true
				if lg.get("_layer") is CanvasLayer:
					lg._layer.visible = false
				for n in ["_hud", "_talk_box", "_talk_prompt", "_hint_bar", "_msg"]:  # pelin laatikot pois TV-kuvasta
					var c = main.get(n)
					if c is CanvasItem or c is CanvasLayer:
						c.visible = false
				for i in 90:
					await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
			var img: Image = main.get_viewport().get_texture().get_image()
			main.state = "cutscene"
			main.cutscene.paivi_tv(ImageTexture.create_from_image(img), func() -> void: pass)
			return {"warm": 10}
		"s_halot":  # halonhakkuu kodalla (FPS-minipeli)
			_time(main, 18, 0)
			var k: Node3D = main.world.kota
			_foot(main, k.to_global(preload("res://scripts/kota.gd").CHOP_LOCAL) + Vector3(1.0, 0, 0), Vector3.FORWARD)
			main.kota_polkyt = 5
			main._start_chop()
			var keys := []
			for i in 6:
				keys.append([0.3 + i * 1.4, "interact"])
			return {"warm": 30, "keys": keys, "hide_games": ["chop_game.gd"]}
		"s_drooni":  # drooni nousee kotipihalta ja lentää kylän yli
			_time(main, 9, 30)
			_foot(main, main.home_zone, Vector3.FORWARD)
			main.drone_battery = 1.0
			main._start_drone()
			return {"warm": 20, "keys": [[0.0, "jump", 3.0], [1.5, "forward", 99.0], [1.5, "sprint", 99.0]], "hide_games": ["drone_game.gd"]}
		"s_aarnivalkea":  # sininen liekki yöllä kivikasan päällä
			_time(main, 23, 0)
			var aa = main.aarni
			aa.heard = true
			aa.sulo = true
			aa.poytakirja = true
			aa.found = false
			var ap := M.w(M.AARNI_SPOT)
			_foot(main, ap + Vector3(7, 0, 5), Vector3(-1, 0, -0.7))
			var look := ap + Vector3(0, 0.6, 0)
			return {"warm": 30, "cam": dolly(ap + Vector3(4.5, 1.4, 3.0), ap + Vector3(3.0, 1.1, 2.0), look, look), "fov": 42.0, "dof": 5.0,
				"brightness": 0.85}
		"s_sinikka":  # Sinikka aamu-uinnilla Oravajärvellä
			_time(main, 8, 30)
			var sp: Vector3 = main.world.uimaranta_sinikka_pos
			var dir := _dir(M.UIMARANTA_DIR)
			_foot(main, sp - dir * 9.0, dir)
			var look := sp + Vector3(0, 1.3, 0)
			var fr: Vector3 = (-main.world.uimaranta_sinikka.global_basis.z * Vector3(1, 0, 1)).normalized()  # mallin etupuoli
			return {"warm": 40, "cam": dolly(sp + fr * 4.2 + _side(fr) * 1.6 + Vector3(0, 1.1, 0), sp + fr * 3.2 + _side(fr) * 1.1 + Vector3(0, 1.2, 0),
				look, look), "fov": 40.0, "dof": 6.0}
	push_warning("Otos puuttuu: " + id)
	_time(main, 12, 0)
	var p := _player_pos(main)
	return {"cam": dolly(p + Vector3(6, 3, 6), p + Vector3(4, 3, 7), p, p), "fov": 50.0}


# --- Yhteiset apuvälineet ---------------------------------------------------------------------------------------------

static func Looks() -> GDScript:
	return preload("res://scripts/looks.gd")


## Otoksen oma hahmo (poistetaan otoksen jälkeen ohjaajan siivouksessa): paikka maan pinnalla, katse suuntaan face.
static func _person(main: Node3D, d: Node, look: Dictionary, at: Vector3, face: Vector3, anim := "Idle") -> Node3D:
	var root := Node3D.new()
	main.add_child(root)
	d.props.append(root)
	var p: Node3D = Looks().make(root, look)
	p.global_position = Vector3(at.x, T.h(at.x, at.z), at.z)
	p.rotation.y = B.yaw_to(face)
	p.play(anim, 0.0)
	return p


## Otoksen oma hahmo sisätilaan (paikallisissa koordinaateissa).
static func _person_in(d: Node, parent: Node3D, look: Dictionary, local: Vector3, face: Vector3, anim := "Idle") -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	d.props.append(root)
	var p: Node3D = Looks().make(root, look)
	p.position = local
	p.rotation.y = B.yaw_to(face)
	p.play(anim, 0.0)
	return p


## Maan pinnalle (y = maaston korkeus).
static func _g(p: Vector3) -> Vector3:
	return Vector3(p.x, T.h(p.x, p.z), p.z)


## Näkyykö katsepiste silmästä (ei seinää, puuta, autoa tai maastoa välissä). Hahmon oma törmäysmuoto katsepisteen
## lähellä ei estä.
static func _clear(main: Node3D, eye: Vector3, look: Vector3) -> bool:
	if eye.y < T.h(eye.x, eye.z) + 0.25:
		return false
	var ss: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for c in main.find_children("*", "CharacterBody3D", true, false):  # hahmot ja ajoneuvot eivät ole esteitä
		ex.append((c as CharacterBody3D).get_rid())
	for target in [look, look - Vector3(0, 1.0, 0)]:  # rinta ja polvet: auto edessä peittää jalat
		var q := PhysicsRayQueryParameters3D.create(eye, target)
		q.exclude = ex
		var hit := ss.intersect_ray(q)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(target) > 0.6:
			return false
	return true


## Ensimmäinen ehdokassilmä, josta katsepiste näkyy (muuten ensimmäinen).
static func _best_eye(main: Node3D, look: Vector3, cands: Array) -> Vector3:
	for e in cands:
		if _clear(main, e, look):
			return e
	return cands[0]


## Silmäehdokkaat kehänä katsepisteen ympärillä (alkaen suunnasta first), korkeudella h.
static func _ring(look: Vector3, first: Vector3, r: float, h: float, n := 12) -> Array:
	var out := []
	var f := Vector3(first.x, 0, first.z).normalized()
	for i in n:
		var k := (i + 1) / 2 * (1 if i % 2 == 0 else -1)  # 0, +1, -1, +2, -2 ... kehää molempiin suuntiin
		out.append(look + f.rotated(Vector3.UP, k * TAU / n) * r + Vector3(0, h, 0))
	return out


## Kyläläinen paikalleen otoksen ajaksi: oma liike ja repliikit pois, animaatio jatkuu (AnimationPlayer).
static func _hold(_main: Node3D, v: Node3D) -> void:
	v.set_process(false)
	v.set_physics_process(false)
	if v.get("_bubble") is Label3D:
		v._bubble.text = ""
	if "velocity" in v:
		v.velocity = Vector3.ZERO


static func _release(v: Node3D) -> void:
	v.set_process(true)
	v.set_physics_process(true)


## Suunta pisteestä p lähimmälle tielle (pihoilta kadulle päin: kamera ei jää talon seinän sisään).
static func _out_dir(main: Node3D, p: Vector3) -> Vector3:
	var wd: Node3D = main.world
	var n: Vector3 = wd.graph_nodes[wd.nearest_node(p)]
	var v := n - p
	v.y = 0.0
	return v.normalized() if v.length() > 0.5 else Vector3.FORWARD


## Kahden hahmon keskustelu sivulta (side = kummalta puolelta ensisijaisesti): molemmat profiilissa, hidas työntö.
## Puolta ja etäisyyttä vaihdetaan, jos este (pylväs, pensas, seinä) on edessä. Katse ylempänä, jotta puhekupla
## mahtuu mustien palkkien väliin.
static func _two_shot(main: Node3D, a: Vector3, b: Vector3, side: float) -> Callable:
	var mid := (a + b) / 2.0
	var ab := b - a
	ab.y = 0.0
	var look := mid + Vector3(0, 1.75, 0)
	var cands := []
	for sd in [side, -side]:
		var perp: Vector3 = _side(ab.normalized()) * sd
		for dist in [maxf(ab.length() * 1.6, 4.2), 5.5, 3.4]:
			for tilt in [0.0, 0.35, -0.35]:
				cands.append(look + (perp + ab.normalized() * tilt).normalized() * dist + Vector3(0, -0.05, 0))
	var eye := _best_eye(main, look, cands)
	return dolly(eye, look + (eye - look) * 0.86, look, look)


## Hahmoesittelyn kuva: puolilähikuva hahmon edestä vähän sivusta (side = -1 / 1), hidas työntö kohti, tausta sumea.
static func _portrait(main: Node3D, p: Node3D, face: Vector3, side: float) -> Dictionary:
	var f := face.normalized()
	var s := _side(f) * side
	var c0 := p.global_position
	if not _clear(main, c0 + f * 3.6 + s * 1.6 + Vector3(0, 1.45, 0), c0 + Vector3(0, 1.35, 0)):
		s = -s  # este (puu, pylväs) toisella puolella: kuvataan toiselta
		if not _clear(main, c0 + f * 3.6 + s * 1.6 + Vector3(0, 1.45, 0), c0 + Vector3(0, 1.35, 0)):
			s = Vector3.ZERO
	return {"cam": func(t: float) -> Array:
		var c := p.global_position
		var k := clampf(t / 3.0, 0.0, 1.0)
		var eye := c + f * lerpf(3.6, 2.7, k) + s * lerpf(1.6, 1.2, k) + Vector3(0, 1.45, 0)
		return [eye, c + Vector3(0, 1.35, 0) - s * 0.35], "fov": 38.0, "dof": 6.0}


## Jokaisen otoksen alussa: Päivi parkkiin (ei jahtaa), pelaaja pyörän selkään ja ohjaus pois.
static func _reset(main: Node3D) -> void:
	var mm: Node3D = main.mummot
	if is_instance_valid(mm):  # mummojen repliikit eivät jää muiden otosten taustalle
		for b in mm._bubbles:
			b.text = ""
		mm._chat_t = 999.0
	main.wife.parked = true
	main.wife.mode = "patrol"
	main.bike.autopilot = false
	for a in ["forward", "back", "left", "right", "sprint"]:
		Input.action_release(a)


## Päivin auto liikkeelle (partiovaihe pakotetaan, ettei main._wife_rhythm siirrä tai piilota autoa kesken otoksen).
static func _wife(main: Node3D) -> Node3D:
	var wf: Node3D = main.wife
	main._wife_phase = "partio"
	wf.visible = true
	wf.process_mode = Node.PROCESS_MODE_INHERIT
	wf.parked = false
	return wf


## Pelaaja jalan paikkaan at, katse suuntaan face. Palauttaa jalan kulkijan.
static func _foot(main: Node3D, at: Vector3, face: Vector3) -> Node3D:
	if main.player == main.bike:
		main.bike.speed = 0.0
		main._toggle_mount()
	var w: Node3D = main.walker_out
	w.global_position = Vector3(at.x, T.h(at.x, at.z) + 0.3, at.z)
	w.rotation.y = B.yaw_to(face)
	w.velocity = Vector3.ZERO
	w.set_carrying(main.beers > 0)
	return w


## Ensimmäinen solmu, jonka skripti on annettu tiedosto (esim. minipeli), mistä tahansa puusta.
static func _find(main: Node, script_file: String) -> Node:
	for n in main.get_tree().root.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s != null and s.resource_path.ends_with(script_file):
			return n
	return null


## Mökki rakennettuna (testikohtausten tapaan ilman taksimatkaa).
static func _mokki(main: Node3D) -> Node3D:
	main.mokki.ensure_built()
	return main.mokki


## Mopomatka Vaalaan käynnissä (main._start_mopo); palauttaa mopo_tripin.
static func _vaala(main: Node3D) -> Node3D:
	if not main._in_vaala:
		main.mokki.ensure_built()
		main._start_mopo()
	return main.mopo_trip


## Pelaaja pyörän selkään (pyörä tuodaan kävelijän luo).
static func _on_bike(main: Node3D) -> void:
	if main.player != main.bike:
		main.bike.global_position = main.walker_out.global_position
		main._toggle_mount()
	main.bike.set_mopo(false)


## Lähin poimittava (lajit kinds) kodin seudulta, tai ensimmäinen löytyvä.
static func _forage(main: Node3D, kinds: Array) -> Dictionary:
	var home := M.w(M.HOME_ZONE)
	var best: Dictionary = {}
	var bd := INF
	for f in main.world.forage:
		if f.kind in kinds and not f.taken:
			var dd: float = f.pos.distance_to(home)
			if dd < bd:
				bd = dd
				best = f
	if not best.is_empty():  # world.forage: paikan korkeus 0, maasto lisätään
		best = best.duplicate()
		best.pos = Vector3(best.pos.x, T.h(best.pos.x, best.pos.z), best.pos.z)
	return best


## Jalkapallopojat kotikentälle (main._spawn_boys valitsee kentän päivän mukaan).
static func _boys(main: Node3D) -> Node3D:
	if not is_instance_valid(main.boys):
		main.day = 2
		main._spawn_boys()
	return main.boys


## Otoksen oma auto (liikenneauto), joka ajaa tieverkkoa pisteestä a kohti b:tä.
static func _car(main: Node3D, d: Node, a: Vector3, b: Vector3, cruise: float) -> Node3D:
	var car = load("res://scripts/traffic_car.gd").new()
	car.cruise = cruise
	car.target_fn = func() -> Node3D: return main.player
	main.add_child(car)
	d.props.append(car)
	var wd: Node3D = main.world
	car.setup_graph(wd.graph_nodes, wd.graph_adj, wd.nearest_node(a), wd.graph_fast)
	return car


static func _time(main: Node3D, h: int, m: int) -> void:
	main.clock_min = h * 60.0 + m


static func _player_pos(main: Node3D) -> Vector3:
	return main.player.global_position


static func _dir(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, v.y).normalized()


static func _side(f: Vector3) -> Vector3:
	return Vector3(-f.z, 0, f.x)


## Tieverkon reitti pisteestä a pisteeseen b.
static func _path(main: Node3D, a: Vector3, b: Vector3) -> PackedVector3Array:
	var rd: AStar3D = main.world.ride
	return rd.get_point_path(rd.get_closest_point(a), rd.get_closest_point(b))


## Pyörä ajaa tieverkkoa pitkin pisteestä a pisteeseen b (autopilotti). Palauttaa tick-kutsun.
static func ride(main: Node3D, a: Vector3, b: Vector3, speed: float) -> Callable:
	_on_bike(main)
	var bike: Node3D = main.bike
	var rd: AStar3D = main.world.ride
	var path := rd.get_point_path(rd.get_closest_point(a), rd.get_closest_point(b))
	var start: Vector3 = path[0] if path.size() > 0 else a
	bike.global_position = start + Vector3(0, 0.3, 0)
	if path.size() > 1:
		bike.rotation.y = B.yaw_to(path[1] - path[0])
	bike.autopilot = true
	bike.auto_speed = speed
	var route := Array(path)
	return func(_t: float) -> void:
		var bp: Vector3 = bike.global_position
		while route.size() > 1 and Vector2(route[0].x - bp.x, route[0].z - bp.z).length() < 6.0:
			route.pop_front()
		if route.size() > 0:
			bike.auto_target = route[0]


## Kameran ajo suoraan kahden pisteen välillä pehmeästi (silmä ja katsepiste erikseen).
static func dolly(e0: Vector3, e1: Vector3, l0: Vector3, l1: Vector3, length := 0.0) -> Callable:
	return func(t: float) -> Array:
		var k := _ease(t, length)
		return [e0.lerp(e1, k), l0.lerp(l1, k)]


## Kohdetta seuraava kamera: siirtymä kohteen omassa kehyksessä (x oikealle, z taakse) liukuu off0 -> off1.
## Kohteen suunta pehmennetään, ettei kamera nyi mutkissa.
static func follow(node: Node3D, off0: Vector3, off1: Vector3, look: Vector3, length := 4.0, main: Node3D = null) -> Callable:
	var st := {"yaw": node.global_rotation.y, "last": -1.0, "lift": 0.0}
	return func(t: float) -> Array:
		if not is_instance_valid(node):
			return [Vector3.ZERO, Vector3.ZERO]
		var yaw: float = node.global_rotation.y
		if st.last < 0.0:
			st.yaw = yaw
		else:
			st.yaw = lerp_angle(st.yaw, yaw, 0.08)
		st.last = t
		var k := clampf(t / length, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var off := off0.lerp(off1, k).rotated(Vector3.UP, st.yaw)
		var p := node.global_position
		var tgt := p + look.rotated(Vector3.UP, st.yaw)
		if main != null:  # este (seinä, talo) välissä: kamera nousee pehmeästi yli
			var want := 0.0
			while want < 6.0 and not _clear(main, p + off + Vector3(0, want, 0), tgt + Vector3(0, 0.6, 0)):
				want += 1.0
			st.lift = lerpf(st.lift, want, 0.15)
		return [p + off + Vector3(0, st.lift, 0), tgt]


static func _ease(t: float, length: float) -> float:
	var l := length if length > 0.0 else 4.5
	var k := clampf(t / l, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65  # tasainen liike, pehmeä lähtö


