/// Cấu hình ảnh cộng đồng - điền sau khi cài máy chủ (may_chu/HUONG_DAN.md).
/// Để trống [diaChiMayChuAnh]: app ẩn hẳn phần "Ảnh từ du khách" (chạy offline như cũ).
library;

/// VD 'https://anh.ten-mien.vn' (không có dấu / ở cuối).
const diaChiMayChuAnh = '';

/// "Web client ID" trong Google Cloud Console (APIs & Services > Credentials). Máy chủ kiểm token theo ID này.
const googleServerClientId = '';

/// "iOS client ID" (chỉ cần khi build iOS). Android không cần: Google nhận app qua tên gói + SHA-1 khoá ký.
const googleIosClientId = '';
