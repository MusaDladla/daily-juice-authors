<#
Publishes a new Android version: builds the APK with the release key and
puts it on GitHub as a release. Authors' apps then show
"New version available" and download it from there.

Before running:
  1. Raise the version in pubspec.yaml (e.g. 1.0.2+3 -> 1.0.3+4).
  2. Commit and push your changes to GitHub.

Run from the project folder:
  powershell -ExecutionPolicy Bypass -File tool\release_android.ps1 -Notes "What changed, in one or two sentences."
#>
param(
    [Parameter(Mandatory = $true)][string]$Notes
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)

if (-not (Test-Path 'android\key.properties')) {
    throw 'android\key.properties is missing. Copy it from your signing backup (see README, "Signing key").'
}

$match = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*([0-9.]+)\+'
if (-not $match) { throw 'Could not read the version from pubspec.yaml.' }
$version = $match.Matches[0].Groups[1].Value
$tag = "v$version"

$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = "$env:LOCALAPPDATA\gh-cli\bin\gh.exe" }

# The release must match what is on GitHub.
if (git status --porcelain --untracked-files=no) { throw 'You have uncommitted changes. Commit and push them first.' }
git fetch origin main --quiet
if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) { throw 'Your commits are not on GitHub yet. Push them first (git push).' }

$existing = & $gh release list --limit 100 | Select-String -SimpleMatch "`t$tag`t"
if ($existing) { throw "Version $version is already released. Raise the version in pubspec.yaml first." }

flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'The build failed.' }

$apk = "build\daily-juice-authors-$version.apk"
Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' $apk -Force

& $gh release create $tag $apk --target main --title "Daily Juice Authors $version" --notes $Notes
if ($LASTEXITCODE -ne 0) { throw 'Publishing on GitHub failed.' }
Write-Host ""
Write-Host "Released $version. Authors' apps will offer it the next time they open."
