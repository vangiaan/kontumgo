# Cài / cập nhật máy chủ ảnh cộng đồng Kon Tum Go trên VPS Windows Server. Chạy bằng quyền Administrator.
# Thường không chạy tay: _cong_cu\trien_khai_may_chu.ps1 (trên máy bạn) chép thư mục này lên VPS rồi gọi file này.
#
#   .\cai_dat.ps1 -TenMien anh.ten-mien.vn -GoogleClientId xxx.apps.googleusercontent.com   (lần đầu)
#   .\cai_dat.ps1                                                                         (cập nhật mã)
#
# Làm gì:
#   1. Cài Python 3.12 (nếu chưa có), tạo venv + thư viện trong $ThuMucCaiDat
#   2. Tạo tài khoản Windows riêng 'ktg_anh' (quyền thấp): CHỈ ghi được thư mục ảnh, bị CẤM đọc $ThuMucCam
#   3. Chạy máy chủ (uvicorn, 127.0.0.1:8100) bằng Task Scheduler dưới tài khoản đó, tự chạy lại khi lỗi / khởi động máy
#   4. Cài Caddy làm dịch vụ Windows: nhận HTTPS cổng 443 (tự xin chứng chỉ Let's Encrypt) -> chuyển vào 8100
param(
    [string]$TenMien,
    [string]$GoogleClientId,
    [string]$ThuMucCaiDat = 'C:\KonTumGo_MayChu',
    [string]$ThuMucDuLieu = 'D:\KonTumGo_Anh',
    # Thư mục tài khoản ktg_anh tuyệt đối không được đọc (mã nguồn, khoá ký, dữ liệu khác trên VPS). Thêm nếu cần.
    [string[]]$ThuMucCam = @('D:\KonTumGo', 'D:\HSOFT_SUDUNG', 'D:\VGA_Health', 'C:\Users\Administrator')
)
$ErrorActionPreference = 'Stop'
$nguon = $PSScriptRoot
$TAI_KHOAN = 'ktg_anh'
$TEN_TAC_VU = 'KonTumGo_MayChuAnh'
$CONG = 8100
function Buoc($s) { Write-Host "`n== $s" -ForegroundColor Cyan }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Cần chạy bằng quyền Administrator.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------------------------------------------------------------- 1. Python + mã nguồn
Buoc 'Python'
$py = 'C:\Program Files\Python312\python.exe'
if (-not (Test-Path $py)) {
    $cai = Join-Path $env:TEMP 'python-3.12.10-amd64.exe'
    Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe' -OutFile $cai -UseBasicParsing
    Start-Process $cai -ArgumentList '/quiet', 'InstallAllUsers=1', 'PrependPath=0', 'Include_test=0', 'Include_launcher=0' -Wait
    if (-not (Test-Path $py)) { throw 'Cài Python không thành công.' }
}
& $py --version

Buoc "Chép mã nguồn -> $ThuMucCaiDat"
New-Item -ItemType Directory -Force $ThuMucCaiDat, $ThuMucDuLieu | Out-Null
foreach ($f in 'app.py', 'requirements.txt') { Copy-Item (Join-Path $nguon $f) $ThuMucCaiDat -Force }
$venvPy = Join-Path $ThuMucCaiDat 'venv\Scripts\python.exe'
if (-not (Test-Path $venvPy)) { & $py -m venv (Join-Path $ThuMucCaiDat 'venv') }
& $venvPy -m pip install --disable-pip-version-check -q -r (Join-Path $ThuMucCaiDat 'requirements.txt')
if ($LASTEXITCODE) { throw 'pip install lỗi.' }

# ---------------------------------------------------------------- 2. Cấu hình
$fCauHinh = Join-Path $ThuMucCaiDat 'cau_hinh.json'
if (-not (Test-Path $fCauHinh)) {
    if (-not $GoogleClientId) { throw 'Lần cài đầu cần -GoogleClientId (Web client ID trong Google Cloud Console).' }
    $mkQt = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
    [IO.File]::WriteAllText($fCauHinh, (@{
                thu_muc_du_lieu   = $ThuMucDuLieu
                mat_khau_quan_tri = $mkQt
                google_client_ids = @($GoogleClientId)
            } | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
    Write-Host "MAT KHAU TRANG DUYET ANH: $mkQt   (luu lai; xem lai trong $fCauHinh)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 3. Tài khoản chạy dịch vụ + phân quyền
Buoc "Tài khoản Windows '$TAI_KHOAN' (quyền thấp)"
$mkTk = -join ((33..126) | Get-Random -Count 32 | ForEach-Object { [char]$_ })   # không ai cần nhớ: đổi mỗi lần cài
$ss = ConvertTo-SecureString $mkTk -AsPlainText -Force
if (Get-LocalUser $TAI_KHOAN -ErrorAction SilentlyContinue) { Set-LocalUser $TAI_KHOAN -Password $ss }
else { New-LocalUser $TAI_KHOAN -Password $ss -PasswordNeverExpires -UserMayNotChangePassword -Description 'Kon Tum Go - may chu anh' | Out-Null }
# Nhóm Users: đủ quyền chạy Python trong C:\Program Files, không phải quản trị.
Add-LocalGroupMember -Group 'Users' -Member $TAI_KHOAN -ErrorAction SilentlyContinue

# Mã nguồn: chỉ đọc + chạy. Thư mục ảnh: đọc + ghi. cau_hinh.json: chỉ đọc (chứa mật khẩu trang quản trị).
icacls $ThuMucCaiDat /inheritance:r /grant:r 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' "${TAI_KHOAN}:(OI)(CI)RX" | Out-Null
icacls $ThuMucDuLieu /inheritance:r /grant:r 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' "${TAI_KHOAN}:(OI)(CI)M" | Out-Null
foreach ($d in $ThuMucCam) {
    if (Test-Path $d) { icacls $d /deny "${TAI_KHOAN}:(OI)(CI)(RX)" /T /C /Q | Out-Null; Write-Host "  cam doc: $d" }
}

# ---------------------------------------------------------------- 4. Chạy máy chủ (Task Scheduler)
Buoc 'Tác vụ chạy máy chủ'
$hd = New-ScheduledTaskAction -Execute $venvPy -WorkingDirectory $ThuMucCaiDat `
    -Argument "-m uvicorn app:app --host 127.0.0.1 --port $CONG --workers 2 --proxy-headers"
$kh = New-ScheduledTaskTrigger -AtStartup
$cd = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -AllowStartIfOnBatteries
Stop-ScheduledTask $TEN_TAC_VU -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Where-Object { $_.CommandLine -like "*uvicorn app:app*--port $CONG*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Register-ScheduledTask $TEN_TAC_VU -Action $hd -Trigger $kh -Settings $cd -User "$env:COMPUTERNAME\$TAI_KHOAN" `
    -Password $mkTk -RunLevel Limited -Force | Out-Null
Start-ScheduledTask $TEN_TAC_VU
$ok = $false
for ($i = 0; $i -lt 20 -and -not $ok; $i++) {
    Start-Sleep 2
    try { $ok = (Invoke-RestMethod "http://127.0.0.1:$CONG/api/suc-khoe" -TimeoutSec 3).ok } catch {}
}
if (-not $ok) { throw "Máy chủ không lên ở cổng $CONG. Thử chạy tay: cd $ThuMucCaiDat; venv\Scripts\python -m uvicorn app:app --port $CONG" }
Write-Host "  may chu chay OK: http://127.0.0.1:$CONG" -ForegroundColor Green

# ---------------------------------------------------------------- 5. Caddy (HTTPS)
$caddyDir = 'C:\Caddy'
$caddy = Join-Path $caddyDir 'caddy.exe'
if ($TenMien) {
    Buoc "Caddy HTTPS cho $TenMien"
    $chiem = Get-NetTCPConnection -LocalPort 443 -State Listen -ErrorAction SilentlyContinue |
        Where-Object { (Get-Process -Id $_.OwningProcess).Name -ne 'caddy' }
    if ($chiem) {
        $ten = ($chiem | ForEach-Object { (Get-Process -Id $_.OwningProcess).Name }) -join ', '
        Write-Warning "Cổng 443 đang do '$ten' dùng (IIS?). Bỏ qua Caddy - xem HUONG_DAN.md mục 'Đã có IIS'."
    }
    else {
        New-Item -ItemType Directory -Force $caddyDir | Out-Null
        if (-not (Test-Path $caddy)) {
            Invoke-WebRequest 'https://caddyserver.com/api/download?os=windows&arch=amd64' -OutFile $caddy -UseBasicParsing
        }
        $cf = (Get-Content (Join-Path $nguon 'Caddyfile.mau') -Raw -Encoding UTF8) -replace 'anh\.ten-mien-cua-ban\.vn', $TenMien
        [IO.File]::WriteAllText((Join-Path $caddyDir 'Caddyfile'), $cf, (New-Object Text.UTF8Encoding $false))
        & $caddy validate --config (Join-Path $caddyDir 'Caddyfile') 2>&1 | Select-Object -Last 1
        if (-not (Get-Service caddy -ErrorAction SilentlyContinue)) {
            sc.exe create caddy start= auto binPath= "`"$caddy`" run --config `"$caddyDir\Caddyfile`"" | Out-Null
            sc.exe failure caddy reset= 86400 actions= restart/5000/restart/5000/restart/60000 | Out-Null
        }
        Restart-Service caddy -ErrorAction SilentlyContinue; Start-Service caddy
        foreach ($c in 80, 443) {
            if (-not (Get-NetFirewallRule -DisplayName "KonTumGo HTTPS $c" -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName "KonTumGo HTTPS $c" -Direction Inbound -Protocol TCP -LocalPort $c -Action Allow | Out-Null
            }
        }
        Write-Host "  Caddy chay. Mo thu: https://$TenMien/dieu-khoan   |   trang duyet anh: https://$TenMien/quan-tri" -ForegroundColor Green
    }
}
elseif (Get-Service caddy -ErrorAction SilentlyContinue) { Restart-Service caddy }

Buoc 'Xong'
