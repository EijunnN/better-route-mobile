# Release build for the BetterRoute driver app (Windows / PowerShell).
#
# The app fails closed at startup (ApiConfig.assertValid) if the production
# URLs are missing or are not TLS, so a release build MUST inject them. They
# are read from dart_define.json — copy the template and fill in your values:
#
#   Copy-Item dart_define.example.json dart_define.json
#   # then set API_BASE_URL (https://...) and WS_URL (wss://...)
#
# Usage: .\scripts\build-release.ps1 [apk|appbundle|ios]   (default: appbundle)
param([string]$Target = "appbundle")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$config = "dart_define.json"
if (-not (Test-Path $config)) {
  Write-Error "$config not found. Run: Copy-Item dart_define.example.json $config  (then set your https/wss URLs)."
  exit 1
}

Write-Host "> flutter build $Target --release --dart-define-from-file=$config"
flutter build $Target --release --dart-define-from-file=$config
