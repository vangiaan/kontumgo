# Tạo khung dự án Flutter "kontumgo" trên VPS (Flutter chỉ cài ở đó) rồi kéo khung về máy này.
$ErrorActionPreference = 'Stop'
. 'D:\HSOFT_SUDUNG\VGA_Health\scripts\bi_mat.ps1'
$flutter = $BM.vps_build.flutter
$s = Mo-PhienVps
try {
    Invoke-Command -Session $s -ArgumentList $flutter -ScriptBlock {
        param($flutter)
        $goc = 'D:\KonTumGo'
        if (Test-Path "$goc\app\pubspec.yaml") { 'Du an da co san, khong tao lai'; return }
        New-Item -ItemType Directory -Force $goc | Out-Null
        Set-Location $goc
        (& $flutter --version 2>&1 | Select-Object -First 2) -join ' | '
        & $flutter create --org com.namtao --project-name kontumgo --platforms android,ios --description 'Kon Tum Go' app 2>&1 | Select-Object -Last 4
        if (Test-Path "$goc\_khung.zip") { [IO.File]::Delete("$goc\_khung.zip") }
        Compress-Archive -Path "$goc\app\*" -DestinationPath "$goc\_khung.zip"
        'Khung: {0:N0} KB' -f ((Get-Item "$goc\_khung.zip").Length / 1KB)
    }
    $dich = 'D:\NAM\KonTumGo\app'
    if (-not (Test-Path "$dich\pubspec.yaml")) {
        New-Item -ItemType Directory -Force $dich | Out-Null
        $zip = Join-Path $env:TEMP 'kontumgo_khung.zip'
        Copy-Item -FromSession $s -Path 'D:\KonTumGo\_khung.zip' -Destination $zip -Force
        Expand-Archive $zip -DestinationPath $dich -Force
        "Da keo khung ve $dich"
    }
}
finally { Remove-PSSession $s }
