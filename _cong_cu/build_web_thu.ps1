# Build bản web của app (chỉ để XEM THỬ giao diện trên trình duyệt ở máy này) rồi kéo về ban_build\web.
# Chạy sau build_apk.ps1 (mã nguồn trên VPS đã là bản mới).
$ErrorActionPreference = 'Stop'
. 'D:\HSOFT_SUDUNG\VGA_Health\scripts\bi_mat.ps1'
$goc = 'D:\NAM\KonTumGo'
$s = Mo-PhienVps
try {
    Invoke-Command -Session $s -ArgumentList $BM.vps_build.flutter -ScriptBlock {
        param($flutter)
        $proj = 'D:\KonTumGo\app'
        Set-Location $proj
        $ErrorActionPreference = 'Continue'
        if (-not (Test-Path "$proj\web")) { & $flutter create --platforms web . 2>&1 | Select-Object -Last 2 }
        & $flutter build web --release 2>&1 | ForEach-Object { "$_" } | Select-String 'Built|Error|error|Failed' | Select-Object -First 8 | Out-String -Width 250
        if (Test-Path 'D:\KonTumGo\_web.zip') { [IO.File]::Delete('D:\KonTumGo\_web.zip') }
        Compress-Archive -Path "$proj\build\web\*" -DestinationPath 'D:\KonTumGo\_web.zip'
        'web.zip: {0:N1} MB' -f ((Get-Item 'D:\KonTumGo\_web.zip').Length / 1MB)
    }
    $zip = Join-Path $env:TEMP 'kontumgo_web.zip'
    Copy-Item -FromSession $s -Path 'D:\KonTumGo\_web.zip' -Destination $zip -Force
    $dich = "$goc\ban_build\web"
    if (Test-Path $dich) { [IO.Directory]::Delete($dich, $true) }
    Expand-Archive $zip -DestinationPath $dich -Force
    "Da keo ve $dich"
}
finally { Remove-PSSession $s }
