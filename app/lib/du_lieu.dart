import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaDiem {
  final String id, ten, nhom, vung;
  final double lat, lon;
  final String? moTa, dienThoai, gio, diaChi;
  final int? noiBat;

  const DiaDiem({
    required this.id,
    required this.ten,
    required this.nhom,
    required this.vung,
    required this.lat,
    required this.lon,
    this.moTa,
    this.dienThoai,
    this.gio,
    this.diaChi,
    this.noiBat,
  });

  factory DiaDiem.tuJson(Map<String, dynamic> j) => DiaDiem(
        id: j['id'] as String,
        ten: j['ten'] as String,
        nhom: j['nhom'] as String,
        vung: j['vung'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        moTa: j['mo_ta'] as String?,
        dienThoai: j['dien_thoai'] as String?,
        gio: j['gio'] as String?,
        diaChi: j['dia_chi'] as String?,
        noiBat: j['noi_bat'] as int?,
      );
}

class LichTrinh {
  final int soNgay;
  final String ten, tomTat;
  final List<String> diem; // id địa điểm, theo thứ tự đi
  const LichTrinh(this.soNgay, this.ten, this.tomTat, this.diem);
}

const lichTrinhGoiY = [
  LichTrinh(1, 'Một ngày ở trung tâm Kon Tum', 'Nhà thờ Gỗ, Toà Giám mục, nhà rông Kon Klor, Ngục Kon Tum',
      ['nha-tho-go-kon-tum', 'toa-giam-muc-kon-tum', 'nha-rong-kon-klor', 'nguc-kon-tum', 'bao-tang-kon-tum']),
  LichTrinh(2, 'Cuối tuần ở Măng Đen', 'Thác Pa Sỹ, hồ Đăk Ke, làng Kon Pring, chùa Khánh Lâm',
      ['thac-pa-sy', 'ho-dak-ke', 'tuong-duc-me-mang-den', 'lang-kon-pring', 'chua-khanh-lam', 'con-duong-thong-cong', 'cho-kon-plong']),
];

/// Dữ liệu địa điểm đóng kèm trong app (xem được khi mất sóng) + danh sách đã lưu trên máy.
class KhoDuLieu extends ChangeNotifier {
  static final KhoDuLieu chung = KhoDuLieu._();
  KhoDuLieu._();

  List<DiaDiem> diaDiem = const [];
  String ghiNguon = '';
  final Set<String> daLuu = {};

  Future<void> tai() async {
    final j = jsonDecode(await rootBundle.loadString('assets/du_lieu/dia_diem.json')) as Map<String, dynamic>;
    diaDiem = (j['dia_diem'] as List).map((e) => DiaDiem.tuJson(e as Map<String, dynamic>)).toList();
    ghiNguon = j['ghi_nguon'] as String? ?? '';
    final p = await SharedPreferences.getInstance();
    daLuu.addAll(p.getStringList('da_luu') ?? const []);
    notifyListeners();
  }

  List<DiaDiem> get noiBat =>
      diaDiem.where((d) => d.noiBat != null).toList()..sort((a, b) => a.noiBat!.compareTo(b.noiBat!));

  DiaDiem? theoId(String id) {
    for (final d in diaDiem) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> doiLuu(String id) async {
    if (!daLuu.remove(id)) daLuu.add(id);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('da_luu', daLuu.toList());
  }

  /// Các điểm gần nhất (theo đường chim bay), bỏ chính nó.
  List<DiaDiem> ganDay(DiaDiem d, {int soLuong = 6}) {
    final ds = diaDiem.where((x) => x.id != d.id && x.vung == d.vung).toList()
      ..sort((a, b) => _kc2(d, a).compareTo(_kc2(d, b)));
    return ds.take(soLuong).toList();
  }

  static double _kc2(DiaDiem a, DiaDiem b) {
    final dx = a.lon - b.lon, dy = a.lat - b.lat;
    return dx * dx + dy * dy;
  }
}

/// Bỏ dấu tiếng Việt để tìm kiếm không phân biệt dấu.
String boDau(String s) {
  const co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = co.indexOf(c);
    b.write(i >= 0 ? khong[i] : c);
  }
  return b.toString();
}
