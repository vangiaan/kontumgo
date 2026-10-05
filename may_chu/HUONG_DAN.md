# Ảnh cộng đồng – hướng dẫn cài đặt

Du khách đăng nhập Google → đồng ý điều khoản → gửi ảnh địa điểm → **bạn duyệt** trên trang `/quan-tri` → ảnh hiện
trong app (mục "Ảnh từ du khách" ở trang chi tiết). App vẫn chạy offline bình thường; khi chưa cấu hình máy chủ thì
mục này tự ẩn.

```
Điện thoại ──HTTPS──> Caddy (VPS, cổng 443) ──> app.py (127.0.0.1:8100, tài khoản Windows 'ktg_anh')
                                                   └─ D:\KonTumGo_Anh\  (ảnh lon\, nho\, anh_cong_dong.db)
```

## 1. Tên miền
Tạo bản ghi **A**: `anh.<ten-mien-cua-ban>` → IP VPS. (Có Cloudflare thì bật đám mây cam sau khi Caddy đã lấy được
chứng chỉ, chế độ SSL "Full (strict)".)

## 2. Google Cloud (đăng nhập Google) – làm 1 lần
https://console.cloud.google.com → tạo project **KonTumGo**.
1. **APIs & Services → OAuth consent screen**: External, tên app "Kon Tum Go", email hỗ trợ, link chính sách
   = `https://anh.<ten-mien>/dieu-khoan`. Scope chỉ cần mặc định (email, profile). Bấm **Publish app**.
2. **Credentials → Create credentials → OAuth client ID**, tạo 3 cái:
   - **Web application** (tên "May chu") → chép **Client ID** – đây là `googleServerClientId` và `-GoogleClientId`.
   - **Android**: package `com.namtao.kontumgo`, SHA-1 của **khoá ký upload** (`keytool -list -v -keystore <file.jks>`).
     Khi đã lên Google Play: tạo thêm 1 Android client nữa với SHA-1 ở Play Console → *Test and release → App
     integrity → App signing key certificate* (bản tải từ Play được Google ký lại bằng khoá đó).
   - **iOS** (khi làm bản iPhone): bundle ID của app → chép **iOS client ID**.

## 3. Cài máy chủ lên VPS (từ máy bạn, như build APK)
```powershell
cd D:\NAM\KonTumGo
git pull
.\_cong_cu\trien_khai_may_chu.ps1 -TenMien anh.<ten-mien> -GoogleClientId <WEB_CLIENT_ID>
```
Script tự: cài Python 3.12, tạo tài khoản quyền thấp `ktg_anh` (bị cấm đọc `D:\KonTumGo`, `D:\HSOFT_SUDUNG`…), chạy
máy chủ bằng Task Scheduler (tự bật lại khi lỗi / khởi động lại VPS), cài Caddy lấy HTTPS, mở tường lửa 80/443.
**Cuối cùng nó in MẬT KHẨU TRANG DUYỆT ẢNH** – lưu lại (xem lại trong `C:\KonTumGo_MayChu\cau_hinh.json` trên VPS).

Kiểm tra: mở `https://anh.<ten-mien>/dieu-khoan` (thấy điều khoản) và `https://anh.<ten-mien>/quan-tri` (hỏi mật khẩu).

Cập nhật mã máy chủ sau này: `.\_cong_cu\trien_khai_may_chu.ps1` (không cần tham số).

**Đã có IIS chiếm cổng 443?** Script sẽ cảnh báo và bỏ qua Caddy. Khi đó trong IIS: cài *URL Rewrite* + *ARR*, tạo
site `anh.<ten-mien>` (binding https + chứng chỉ, ví dụ dùng win-acme), quy tắc Reverse Proxy tới `127.0.0.1:8100`,
và tăng *maxAllowedContentLength* lên 16 MB.

## 4. Bật trong app
Sửa `app/lib/cau_hinh.dart`:
```dart
const diaChiMayChuAnh = 'https://anh.<ten-mien>';
const googleServerClientId = '<WEB_CLIENT_ID>';
const googleIosClientId = '';   // điền khi làm bản iOS
```
Tăng `version` trong `pubspec.yaml` → build như thường.

**Bản iOS** cần thêm vào `ios/Runner/Info.plist`: `GIDClientID` = iOS client ID và `CFBundleURLTypes` với scheme =
*iOS URL scheme* (dạng `com.googleusercontent.apps.xxxx`) – xem README của `google_sign_in_ios`.

## 5. Hằng ngày: duyệt ảnh
`https://anh.<ten-mien>/quan-tri` → tab **Chờ duyệt** (Duyệt / Xoá ảnh / Khoá người gửi), tab **Bị báo cáo**.
Ảnh bị 3 người báo cáo tự ẩn chờ bạn xem lại. Apple / Google yêu cầu xử lý báo cáo **trong 24 giờ**.

## 6. Khai báo khi nộp lên cửa hàng
- **Google Play → App content**: *User-generated content* = có; *Data safety*: thu thập **Ảnh** và **Email/Tên**
  (để hiển thị người đăng, không bán, không quảng cáo; người dùng xoá được – nút "Xoá tài khoản và toàn bộ ảnh").
  Link xoá tài khoản / chính sách: `https://anh.<ten-mien>/dieu-khoan`.
- **App Store**: guideline 1.2 (UGC) đã có đủ: điều khoản, lọc (duyệt trước), báo cáo, chặn, liên hệ.

## 7. Sao lưu
Toàn bộ dữ liệu nằm trong `D:\KonTumGo_Anh`. Nên chép định kỳ ra nơi khác (ổ khác / NAS / cloud), ví dụ tác vụ hằng
đêm: `robocopy D:\KonTumGo_Anh E:\SaoLuu\KonTumGo_Anh /MIR /R:1 /W:1`.

## Thử trên máy (không cần Google)
```
cd may_chu
python -m venv .venv && .venv\Scripts\pip install -r requirements.txt pytest httpx
.venv\Scripts\python -m pytest -q test_app.py
```
