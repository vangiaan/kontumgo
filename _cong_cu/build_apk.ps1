# Build APK Kon Tum Go trên VPS (D:\KonTumGo\app) từ mã nguồn ở máy này (bản gốc: D:\Nam\KonTumGo\app).
# Chép lib, assets, test, pubspec.yaml, AndroidManifest -> pub get/add -> analyze -> test -> build -> kéo APK về ban_build\.
param([switch]$ChiKiemTra)   # chỉ analyze + test, không build
$ErrorActionPreference = 'Stop'
. 'D:\HSOFT_SUDUNG\VGA_Health\scripts\bi_mat.ps1'
$goc = 'D:\NAM\KonTumGo'
$zip = Join-Path $env:TEMP 'kontumgo_nguon.zip'
if (Test-Path $zip) { [IO.File]::Delete($zip) }
Compress-Archive -Path "$goc\app\lib", "$goc\app\assets", "$goc\app\test", "$goc\app\pubspec.yaml" -DestinationPath $zip
$ver = (Select-String -Path "$goc\app\pubspec.yaml" -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -replace '\+', '_'

$s = Mo-PhienVps
try {
    Copy-Item -ToSession $s -Path $zip -Destination 'D:\KonTumGo\_nguon.zip' -Force
    Copy-Item -ToSession $s -Path "$goc\app\android\gradle.properties" -Destination 'D:\KonTumGo\app\android\gradle.properties' -Force
    Copy-Item -ToSession $s -Path "$goc\app\android\app\src\main\AndroidManifest.xml" -Destination 'D:\KonTumGo\app\android\app\src\main\AndroidManifest.xml' -Force
    Invoke-Command -Session $s -ArgumentList $BM.vps_build.flutter, $ChiKiemTra.IsPresent -ScriptBlock {
        param($flutter, $chiKiemTra)
        $proj = 'D:\KonTumGo\app'
        foreach ($d in 'lib', 'assets', 'test') { if (Test-Path "$proj\$d") { [IO.Directory]::Delete("$proj\$d", $true) } }
        Expand-Archive 'D:\KonTumGo\_nguon.zip' -DestinationPath $proj -Force
        [IO.File]::Delete('D:\KonTumGo\_nguon.zip')
        Set-Location $proj
        $ErrorActionPreference = 'Continue'
        $env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot'
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
        # Thêm thư viện nếu pubspec chưa có (flutter tự chọn phiên bản hợp với SDK trên VPS)
        $pub = Get-Content pubspec.yaml -Raw
        $thieu = 'url_launcher', 'shared_preferences', 'flutter_map', 'latlong2' | Where-Object { $pub -notmatch "(?m)^\s+$_\s*:" }
        if ($thieu) { & $flutter pub add @thieu 2>&1 | Select-Object -Last 3 } else { & $flutter pub get 2>&1 | Select-Object -Last 1 }
        '--- phien ban thu vien'
        Select-String -Path pubspec.yaml -Pattern '^\s+(url_launcher|shared_preferences|flutter_map|latlong2):' | ForEach-Object { $_.Line.Trim() }
        '--- analyze'
        & $flutter analyze 2>&1 | Select-String 'error|warning|info •|issues found|No issues' | Select-Object -First 40 | Out-String -Width 250
        '--- test'
        & $flutter test 2>&1 | Select-Object -Last 3 | Out-String -Width 250
        if ($chiKiemTra) { return }
        $apk = "$proj\build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apk) { [IO.File]::Delete($apk) }
        $kq = & $flutter build apk --release --target-platform android-arm64 2>&1 | ForEach-Object { "$_" }
        $kq | Select-String 'Built|FAILURE|^e: |Error|error:' | Select-Object -First 10 | Out-String -Width 250
        $i = [Array]::FindIndex([string[]]$kq, [Predicate[string]] { param($d) $d -match 'What went wrong' })
        if ($i -ge 0) { ($kq[$i..([Math]::Min($i + 30, $kq.Count - 1))]) -join "`n" }
    }
    # pubspec trên VPS có thêm dòng thư viện -> kéo về để bản gốc ở máy này khớp
    Copy-Item -FromSession $s -Path 'D:\KonTumGo\app\pubspec.yaml' -Destination "$goc\app\pubspec.yaml" -Force
    Copy-Item -FromSession $s -Path 'D:\KonTumGo\app\pubspec.lock' -Destination "$goc\app\pubspec.lock" -Force
    if (-not $ChiKiemTra) {
        New-Item -ItemType Directory -Force "$goc\ban_build" | Out-Null
        $dich = "$goc\ban_build\kontumgo_$ver.apk"
        Copy-Item -FromSession $s -Path 'D:\KonTumGo\app\build\app\outputs\flutter-apk\app-release.apk' -Destination $dich -Force
        'Da chep ve: {0} ({1:N1} MB)' -f $dich, ((Get-Item $dich).Length / 1MB)
    }
}
finally { Remove-PSSession $s }
