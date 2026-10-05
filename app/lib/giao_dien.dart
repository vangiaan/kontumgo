import 'package:flutter/material.dart';

/// Bảng màu Kon Tum Go: sương sớm, thông Măng Đen, đất đỏ bazan, nắng cao nguyên.
class Mau {
  static const suong = Color(0xFFF4F1EA);
  static const giay = Color(0xFFFFFDF8);
  static const thong = Color(0xFF1F4D3A);
  static const thongNhat = Color(0xFFDFE9E1);
  static const bazan = Color(0xFFB5472A);
  static const nang = Color(0xFFE0A526);
  static const muc = Color(0xFF1C2620);
  static const xam = Color(0xFF66706A);
  static const vien = Color(0xFFE2DDD0);
  static const tren = Color(0xFFF6F2E6); // chữ trên nền thông
}

ThemeData giaoDien() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Mau.thong,
      primary: Mau.thong,
      secondary: Mau.bazan,
      surface: Mau.suong,
    ),
    scaffoldBackgroundColor: Mau.suong,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Mau.muc, displayColor: Mau.muc),
    appBarTheme: const AppBarTheme(
      backgroundColor: Mau.giay,
      foregroundColor: Mau.muc,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(color: Mau.muc, fontSize: 22, fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Mau.giay,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Mau.thongNhat,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? Mau.bazan : Mau.xam,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Mau.bazan : Mau.xam)),
    ),
  );
}

/// Thông tin hiển thị của từng nhóm địa điểm.
class Nhom {
  final String ma, ten;
  final IconData icon;
  final List<Color> mauNen;
  const Nhom(this.ma, this.ten, this.icon, this.mauNen);

  static const tatCa = [
    Nhom('canh-dep', 'Cảnh đẹp', Icons.landscape_outlined, [Color(0xFF6F9C84), Color(0xFF1F4D3A)]),
    Nhom('di-tich', 'Làng & di tích', Icons.account_balance_outlined, [Color(0xFFD9A05B), Color(0xFFB5472A)]),
    Nhom('an-uong', 'Ăn uống', Icons.restaurant_outlined, [Color(0xFFE2B45C), Color(0xFFA9622A)]),
    Nhom('luu-tru', 'Lưu trú', Icons.cottage_outlined, [Color(0xFF9DB7C4), Color(0xFF4B6B7C)]),
    Nhom('tam-linh', 'Tâm linh', Icons.temple_buddhist_outlined, [Color(0xFFC7B98A), Color(0xFF7A6A3A)]),
    Nhom('cho', 'Chợ', Icons.storefront_outlined, [Color(0xFFC9A0A0), Color(0xFF8A4A4A)]),
  ];

  static Nhom cua(String ma) => tatCa.firstWhere((n) => n.ma == ma, orElse: () => tatCa.first);
}

const tenVung = {'kontum': 'Kon Tum', 'mangden': 'Măng Đen', 'khac': 'Vùng khác'};

/// Dải hoa văn thổ cẩm hình thoi: dấu hiệu nhận diện của app.
class ThoCam extends StatelessWidget {
  final double cao;
  const ThoCam({super.key, this.cao = 10});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: cao, width: double.infinity, child: CustomPaint(painter: _ThoCamPainter()));
}

class _ThoCamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Mau.thong);
    final h = size.height, w = h; // mỗi ô thoi rộng bằng chiều cao dải
    final mau = [Paint()..color = Mau.nang, Paint()..color = Mau.bazan];
    var i = 0;
    for (double x = 0; x < size.width + w; x += w, i++) {
      final p = Path()
        ..moveTo(x, h / 2)
        ..lineTo(x + w / 2, 0)
        ..lineTo(x + w, h / 2)
        ..lineTo(x + w / 2, h)
        ..close();
      canvas.drawPath(p, mau[i % 2]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo: mái nhà rông.
class LogoNhaRong extends StatelessWidget {
  final double co;
  const LogoNhaRong({super.key, this.co = 34});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: co, height: co, child: CustomPaint(painter: _NhaRongPainter()));
}

class _NhaRongPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 34;
    final mai = Path()
      ..moveTo(17 * s, 1 * s)
      ..lineTo(6 * s, 25 * s)
      ..lineTo(28 * s, 25 * s)
      ..close();
    canvas.drawPath(mai, Paint()..color = Mau.nang);
    final san = Paint()..color = Mau.tren;
    canvas.drawRect(Rect.fromLTWH(4 * s, 25 * s, 26 * s, 3 * s), san);
    canvas.drawRect(Rect.fromLTWH(8 * s, 28 * s, 3 * s, 5 * s), san);
    canvas.drawRect(Rect.fromLTWH(23 * s, 28 * s, 3 * s, 5 * s), san);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ô thay cho ảnh khi địa điểm chưa có ảnh thật: nền chuyển màu theo nhóm + biểu tượng.
class OAnh extends StatelessWidget {
  final String nhom;
  final double? cao, rong;
  final double bo;
  final Widget? con;
  final String? anh, ghiCong; // ảnh thật (assets) + dòng ghi công; không có / lỗi -> nền màu theo nhóm
  final bool toi; // phủ tối ảnh để chữ trắng trong `con` dễ đọc
  const OAnh(
      {super.key, required this.nhom, this.cao, this.rong, this.bo = 0, this.con, this.anh, this.ghiCong, this.toi = false});

  @override
  Widget build(BuildContext context) {
    final n = Nhom.cua(nhom);
    final bieuTuong = Center(child: Icon(n.icon, color: Colors.white.withValues(alpha: 0.35), size: (cao ?? 76) * 0.42));
    return Container(
      height: cao,
      width: rong,
      clipBehavior: anh == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(bo),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: n.mauNen),
      ),
      child: Stack(children: [
        if (anh == null)
          bieuTuong
        else ...[
          Positioned.fill(
            child: Image.asset(anh!,
                fit: BoxFit.cover,
                cacheWidth: rong != null && rong!.isFinite ? (rong! * 3).round() : null,
                errorBuilder: (_, _, _) => bieuTuong),
          ),
          if (toi) const Positioned.fill(child: ColoredBox(color: Colors.black38)),
          if (ghiCong != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.black45,
                child: Text(ghiCong!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Colors.white)),
              ),
            ),
        ],
        ?con,
      ]),
    );
  }
}
