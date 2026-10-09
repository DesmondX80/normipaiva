# Kylän korkeusmalli: MML 2 m -lehdet -> assets/terrain/korkeus.json + korkeus_mml.i16 (ks. LUEMINUT.md).
# Ajo (Windows PowerShell 5.1):  powershell -File tools\kartta\kyla.ps1 -Lehdet C:\polku\lehtiin
# Sen jälkeen: godot --headless --path . -s tools/bake_terrain.gd
param([Parameter(Mandatory = $true)][string]$Lehdet, [string[]]$Sheets = @("R4132H", "R4134B", "R4141G", "R4143A"))

. "$PSScriptRoot\kehys.ps1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Mosaiikki kattaa kartan (px -320..1940 x -1220..4280) marginaaleineen: E 376..383 km, N 7165..7175 km.
[Mosaic]::Init(376000, 7175000, 3500, 5000)
foreach ($sh in $Sheets) { [void][Tiff]::Info("$Lehdet\$sh.tif"); [Mosaic]::Blit() }

# Ruudukko täsmälleen pelin maastoruudukon pisteisiin (bake_terrain.gd: 5 m, alku w2(MAP_MIN) - 300 = px (-300, -1200)),
# arvo suoraan 2 m mallista (bilineaarinen, ei keskiarvoa): tiet, ojat ja penkat osuvat OSM-teiden kohdalle.
$px0 = -300; $py0 = -1200; $step = 5; $nx = 445; $ny = 1093
$vals = [Mosaic]::Sample($px0, $py0, $step, $nx, $ny, $JK[0], $JK[1], $SC, $ROT, 0)
$nan = 0; $bytes = New-Object byte[] ($vals.Length * 2)
for ($k = 0; $k -lt $vals.Length; $k++) {
	$v = $vals[$k]; if ([float]::IsNaN($v)) { $nan++; $v = 0 }
	$cm = [int16][math]::Round($v * 100)
	[BitConverter]::GetBytes($cm).CopyTo($bytes, 2 * $k)
}
[IO.File]::WriteAllBytes("$root\assets\terrain\korkeus_mml.i16", $bytes)
$meta = '{"source": "Maanmittauslaitoksen korkeusmalli 2 m (CC BY 4.0; lehdet ' + ($Sheets -join ", ") + ', Kapsin peili), N2000", ' +
	'"note": "Korkeudet tiedostossa korkeus_mml.i16: int16 senttimetreinä, rivi kerrallaan (nx arvoa / rivi). Ruudukko karttapikseleissä: px = px0 + i*dx, py = py0 + j*dy; pikselit -> ETRS-TM35FIN tools/kartta/kehys.ps1:n kehyksellä. Arvo suoraan 2 m mallista pelin maastoruudukon pisteissä.", ' +
	'"data": "korkeus_mml.i16", "nx": ' + $nx + ', "ny": ' + $ny + ', "px0": ' + $px0 + ', "py0": ' + $py0 + ', "dx": ' + $step + ', "dy": ' + $step + '}'
[IO.File]::WriteAllText("$root\assets\terrain\korkeus.json", $meta, (New-Object Text.UTF8Encoding $false))
"korkeus_mml.i16: $nx x $ny, puuttuvia $nan"
