# Triển khai máy chủ ảnh cộng đồng (thư mục may_chu\) lên VPS - chạy trên máy này, giống build_apk.ps1.
# Lần đầu:  .\trien_khai_may_chu.ps1 -TenMien anh.ten-mien.vn -GoogleClientId xxxx.apps.googleusercontent.com
# Cập nhật: .\trien_khai_may_chu.ps1
param([string]$TenMien, [string]$GoogleClientId)
$ErrorActionPreference = 'Stop'
. 'D:\HSOFT_SUDUNG\VGA_Health\scripts\bi_mat.ps1'
$goc = 'D:\NAM\KonTumGo'
$zip = Join-Path $env:TEMP 'kontumgo_may_chu.zip'
if (Test-Path $zip) { [IO.File]::Delete($zip) }
Compress-Archive -Path "$goc\may_chu\app.py", "$goc\may_chu\requirements.txt", "$goc\may_chu\cai_dat.ps1", "$goc\may_chu\Caddyfile.mau" -DestinationPath $zip

$s = Mo-PhienVps
try {
    Invoke-Command -Session $s { New-Item -ItemType Directory -Force 'C:\KonTumGo_CaiDat' | Out-Null }
    Copy-Item -ToSession $s -Path $zip -Destination 'C:\KonTumGo_CaiDat\may_chu.zip' -Force
    Invoke-Command -Session $s -ArgumentList $TenMien, $GoogleClientId -ScriptBlock {
        param($tenMien, $clientId)
        Expand-Archive 'C:\KonTumGo_CaiDat\may_chu.zip' -DestinationPath 'C:\KonTumGo_CaiDat' -Force
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $ts = @{}
        if ($tenMien) { $ts.TenMien = $tenMien }
        if ($clientId) { $ts.GoogleClientId = $clientId }
        & 'C:\KonTumGo_CaiDat\cai_dat.ps1' @ts
    }
}
finally { Remove-PSSession $s }
