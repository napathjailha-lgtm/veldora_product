$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $root "assets\2d\external"
$zipPath = Join-Path $assetRoot "kenney_roguelike_rpg_pack.zip"
$extractPath = Join-Path $assetRoot "kenney_roguelike_rpg_pack"
New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null
Write-Host "Downloading Kenney Roguelike/RPG Pack (CC0)..." -ForegroundColor Cyan
$uri = "https://kenney.nl/media/pages/assets/roguelike-rpg-pack/12c03cd78b-1677697420/kenney_roguelike-rpg-pack.zip"
Invoke-WebRequest -Uri $uri -OutFile $zipPath
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
Write-Host "Extracted free CC0 tiles to: $extractPath" -ForegroundColor Green
Write-Host "Source/license: https://kenney.nl/assets/roguelike-rpg-pack"
Write-Host "The current demo uses the bundled original SVG placeholders; review the extracted sheet and replace tiles intentionally to keep a consistent art style."
