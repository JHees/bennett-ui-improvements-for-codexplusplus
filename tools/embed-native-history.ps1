$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $repoRoot "scripts\bennett-ui-improvements.js"
$loaderPath = Join-Path $repoRoot "features\native-history-loader.js"
$beginMarker = "/* BEGIN BENNETT EMBEDDED NATIVE HISTORY LOADER */"
$endMarker = "/* END BENNETT EMBEDDED NATIVE HISTORY LOADER */"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$runtime = [System.IO.File]::ReadAllText($runtimePath, [System.Text.Encoding]::UTF8)
$loader = [System.IO.File]::ReadAllText($loaderPath, [System.Text.Encoding]::UTF8).Trim()
$markerIndex = $runtime.IndexOf($beginMarker, [System.StringComparison]::Ordinal)
if ($markerIndex -ge 0) {
  $runtime = $runtime.Substring(0, $markerIndex).TrimEnd()
}

$packaged = @(
  $runtime.TrimEnd()
  ""
  $beginMarker
  $loader
  $endMarker
  ""
) -join "`n"

[System.IO.File]::WriteAllText($runtimePath, $packaged, $utf8NoBom)
Write-Output $runtimePath
