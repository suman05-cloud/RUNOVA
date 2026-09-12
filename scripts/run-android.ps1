param(
    [string]$DeviceId,
    [string]$AndroidSdkPath = $env:ANDROID_HOME
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = Join-Path $projectRoot '.tooling\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter was not found at $flutter. Install the workspace SDK first."
}

if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
if (-not $AndroidSdkPath) {
    $properties = Join-Path $projectRoot 'mobile\android\local.properties'
    if (Test-Path -LiteralPath $properties) {
        $sdkLine = Get-Content -LiteralPath $properties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($sdkLine) {
            $AndroidSdkPath = $sdkLine.Substring(8).Replace('\:', ':').Replace('\\', '\')
        }
    }
}
if (-not $AndroidSdkPath) { throw 'Specify -AndroidSdkPath with your Android SDK folder.' }
$adb = Join-Path $AndroidSdkPath 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "ADB was not found at $adb." }

$devices = @(& $adb devices | ForEach-Object {
    if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
})
if ($LASTEXITCODE -ne 0) { throw 'Unable to list Android devices.' }
if (-not $DeviceId) {
    if ($devices.Count -ne 1) { throw 'Connect and authorize one phone, or specify -DeviceId.' }
    $DeviceId = $devices[0]
}
if ($DeviceId -notin $devices) { throw "Device $DeviceId is not connected and authorized for USB debugging." }

try {
    $health = Invoke-RestMethod 'http://127.0.0.1:8000/health/ready' -TimeoutSec 5
    if ($health.status -ne 'ok') { throw 'Unexpected health response.' }
} catch {
    throw 'Start the Runova backend on port 8000 and keep Docker running, then retry.'
}

$previousPubCache = $env:PUB_CACHE
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
try {
    # Avoid encoded cross-drive package paths and Windows short-name socket paths.
    $env:PUB_CACHE = Join-Path $projectRoot '.tooling\pub-cache'
    $javaTmp = Join-Path $projectRoot '.tooling\java-tmp'
    New-Item -ItemType Directory -Force -Path $javaTmp | Out-Null
    $env:JAVA_TOOL_OPTIONS = ($previousJavaOptions + ' "-Djdk.net.unixdomain.tmpdir=' + $javaTmp + '"').Trim()

    & $adb -s $DeviceId reverse tcp:8000 tcp:8000
    if ($LASTEXITCODE -ne 0) { throw 'Could not forward the backend port over USB.' }
    Push-Location (Join-Path $projectRoot 'mobile')
    try {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
        & $flutter run -d $DeviceId '--dart-define=RUNOVA_API_BASE_URL=http://127.0.0.1:8000'
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build or launch failed; see the output above.' }
    } finally {
        Pop-Location
    }
} finally {
    $env:PUB_CACHE = $previousPubCache
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
}
