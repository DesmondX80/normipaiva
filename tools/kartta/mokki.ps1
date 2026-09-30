# Mökin kartta (assets/mokki/kartta.json) samoilla työkaluilla kuin kylä (ks. LUEMINUT.md):
# - OSM-kohteet (vedet, pellot, suot, hiekka, metsät, tiet, rakennukset, purot) otteesta -Osm (2 x 2 km, esim.
#   https://api.openstreetmap.org/api/0.6/map?bbox=26.64531,64.49602,26.68914,64.51488), osm.cs:n muuntimella;
#   ilman -Osm:ia nykyiset kohteet säilyvät ja vain korkeudet ja pinnat lasketaan uudelleen.
# - Korkeudet MML:n 2 m mallista (lehti R4333D kattaa koko alueen): pihan tarkka ruudukko "dem" (300 x 300 m, 2 m)
#   ja kaukoalue "dem_far" (2 x 2 km, 8 m = mökin kaukomaaston ruutu).
# - Vesistöjen pinnat ("level"): mallin tasoitettu vedenpinta järven sisältä.
# Ajo (Windows PowerShell 5.1):  powershell -File tools\kartta\mokki.ps1 -Lehdet C:\polku\lehtiin [-Osm C:\polku\map.osm]
# Python-versio: python tools/kartta/mokki.py --lehdet C:\polku\lehtiin [--osm C:\polku\map.osm]
param([Parameter(Mandatory = $true)][string]$Lehdet, [string]$Osm = "", [string[]]$Sheets = @("R4333D"))

[System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
Add-Type -Path "$PSScriptRoot\tiff.cs", "$PSScriptRoot\tm35.cs", "$PSScriptRoot\mosaic.cs", "$PSScriptRoot\mokki_dem.cs", `
	"$PSScriptRoot\osm.cs" -ReferencedAssemblies System.Xml, System.Core
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$path = "$root\assets\mokki\kartta.json"

[Mosaic]::Init(482000, 7158000, 3000, 3000)
foreach ($sh in $Sheets) { [void][Tiff]::Info("$Lehdet\$sh.tif"); [Mosaic]::Blit() }

function GridJson([double]$x0, [double]$step, [int]$n, [string]$extra) {
	$vals = [MokkiDem]::Grid($x0, $x0, $step, $n)
	$sb = New-Object System.Text.StringBuilder
	for ($k = 0; $k -lt $vals.Length; $k++) {
		if ($k) { [void]$sb.Append(',') }
		[void]$sb.Append([math]::Round($vals[$k], 2).ToString())
	}
	return '{"x0":' + $x0 + ',"z0":' + $x0 + ',"step":' + $step + ',"n":' + $n + $extra + ',"values":[' + $sb.ToString() + ']}'
}

$level = [Func[[double[]], [double[]], double]] { param($xs, $zs) [MokkiDem]::Level($xs, $zs) }
if ($Osm) {
	[Osm]::Local = $true
	[Osm]::Load($Osm)
	$count = 0
	$features = [Osm]::MokkiFeatures($level, [ref]$count)
	"OSM-kohteita $count"
} else {
	# Nykyiset kohteet: vain vesistöjen pinnat uudelleen (samassa järjestyksessä kuin tiedostossa).
	$txt = [IO.File]::ReadAllText($path)
	$d = $txt | ConvertFrom-Json
	$levels = @()
	foreach ($f in $d.features) {
		if ($f.kind -ne "water") { continue }
		$levels += [math]::Round($level.Invoke([double[]]($f.pts | ForEach-Object { $_[0] }), [double[]]($f.pts | ForEach-Object { $_[1] })), 2)
	}
	$i = 0
	$fi = $txt.IndexOf('"features":')
	$features = [regex]::Replace($txt.Substring($fi + 11, $txt.LastIndexOf('}') - $fi - 11), '"level":\s*-?[0-9.]+',
		{ param($m) $r = '"level":' + $script:levels[$script:i]; $script:i++; $r })
}

# Likasen pinta pihan ruudukon "water"-arvoksi (mökin järvi).
$lik = [regex]::Match($features, '\{"kind":"water","name":"Likanen"[^}]*"level":([0-9.]+)\}')
$water = if ($lik.Success) { $lik.Groups[1].Value } else { "125.34" }
$dem = GridJson -150 2 151 (',"water":' + $water)
$far = GridJson -1000 8 251 ""
$src = "OpenStreetMap (ODbL) ja MML korkeusmalli 2 m (CC BY 4.0, lehti R4333D; ETRS-TM35FIN E 484017.9 N 7153382.0) " +
	"koko alueella (dem 2 m, dem_far 8 m). Kaisuantie 62, Uutelanperä, Vaala: origo osoitepisteessa 64.5054523 N, " +
	"26.6672225 E; x itaan, z etelaan, metreja. Tehty: tools/kartta/mokki.ps1."
$json = '{"source":"' + $src + '","dem":' + $dem + ',"dem_far":' + $far + ',"features":' + $features + '}'
[IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding $false))
$chk = $json | ConvertFrom-Json
"kohteet: " + (($chk.features | Group-Object kind | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ", ")
"pinnat: " + (($chk.features | Where-Object { $_.kind -eq "water" } | ForEach-Object { "$($_.name) $($_.level)" }) -join ", ")
"kirjoitettu $path"
