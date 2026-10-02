extends RefCounted
## Kova humala pyörällä ja jalan (päivän tila humala yli LIMIT, main.gd _stats_tick): ohjaus vaeltaa hitaasti
## sivulta toiselle ja välillä nykäisee. Lievempi kuin mopon känniohjaus (mopo.gd _drunk_steer).

const LIMIT := 0.8

var _t := 0.0
var _yank := 0.0
var _yank_t := 0.0


## Ohjauksen lisä (-1..1 -asteikolla) humalan ja liikkeen (0..1) mukaan.
func steer(drunk: float, moving: float, delta: float) -> float:
	if drunk <= LIMIT:
		_yank = 0.0
		return 0.0
	var d := lerpf(0.5, 1.0, clampf((drunk - LIMIT) / (1.0 - LIMIT), 0.0, 1.0))
	_t += delta
	_yank_t -= delta
	if _yank_t <= 0.0:
		_yank_t = randf_range(2.5, 6.0)
		_yank = randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0) * d
	_yank = move_toward(_yank, 0.0, 1.8 * delta)
	var drift := (sin(_t * 0.7) * 0.6 + sin(_t * 1.9 + 1.3) * 0.4) * 0.45 * d
	return (drift + _yank) * moving
