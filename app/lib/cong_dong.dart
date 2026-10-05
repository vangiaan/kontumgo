import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cau_hinh.dart';
import 'giao_dien.dart';

/// Phải trùng PHIEN_BAN_DIEU_KHOAN trong may_chu/app.py.
const phienBanDieuKhoan = '2026-10';
const dieuKhoan = [
  'Bạn chỉ gửi ảnh do chính mình chụp, hoặc đã được người chụp cho phép.',
  'Không gửi ảnh khoả thân, bạo lực, thù ghét, quảng cáo, ảnh chụp màn hình, hay ảnh lộ rõ mặt / thông tin cá nhân '
      'của người khác khi chưa được đồng ý.',
  'Ảnh được kiểm duyệt trước khi hiện. Ảnh vi phạm bị xoá; tài khoản vi phạm nhiều lần bị khoá.',
  'Bạn đồng ý cho Kon Tum Go hiển thị ảnh trong ứng dụng, kèm tên hiển thị tài khoản Google của bạn.',
  'Ứng dụng tự xoá thông tin vị trí GPS và thông tin máy chụp trong ảnh trước khi lưu.',
  'Bạn có thể xoá từng ảnh hoặc xoá hẳn tài khoản (kèm toàn bộ ảnh) ngay trong ứng dụng.',
  'Thấy ảnh không phù hợp: bấm vào ảnh rồi chọn Báo cáo, hoặc Chặn người đăng.',
];

class LoiCongDong implements Exception {
  final String thongBao;
  final bool hetPhien;
  LoiCongDong(this.thongBao, {this.hetPhien = false});
  @override
  String toString() => thongBao;
}

class AnhCongDong {
  final String id, nguoiDang, url, urlNho;
  final int nguoiDangId;
  final bool choDuyet, cuaToi;
  AnhCongDong.tuJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        nguoiDang = j['nguoi_dang'] as String,
        nguoiDangId = j['nguoi_dang_id'] as int,
        url = '$diaChiMayChuAnh${j['url']}',
        urlNho = '$diaChiMayChuAnh${j['url_nho']}',
        choDuyet = j['cho_duyet'] as bool,
        cuaToi = j['cua_toi'] as bool;
}

/// Tài khoản + gọi máy chủ ảnh cộng đồng (may_chu/app.py).
class CongDong extends ChangeNotifier {
  static final CongDong chung = CongDong._();
  CongDong._();

  static bool get batDuoc => diaChiMayChuAnh.isNotEmpty;

  String? _token;
  String? ten;
  bool daDongY = false;
  bool _daTaiPhien = false, _daKhoiTaoGoogle = false;

  bool get daDangNhap => _token != null;

  Future<void> _taiPhien() async {
    if (_daTaiPhien) return;
    _daTaiPhien = true;
    final p = await SharedPreferences.getInstance();
    _token = p.getString('cd_token');
    ten = p.getString('cd_ten');
    daDongY = p.getString('cd_dong_y') == phienBanDieuKhoan;
  }

  Future<void> _luuPhien() async {
    final p = await SharedPreferences.getInstance();
    if (_token == null) {
      for (final k in ['cd_token', 'cd_ten', 'cd_dong_y']) {
        await p.remove(k);
      }
    } else {
      await p.setString('cd_token', _token!);
      await p.setString('cd_ten', ten ?? '');
      await p.setString('cd_dong_y', daDongY ? phienBanDieuKhoan : '');
    }
    notifyListeners();
  }

  Map<String, String> get _dauTrang => {if (_token != null) 'Authorization': 'Bearer $_token'};

  Future<dynamic> _goi(Future<http.Response> Function() f) async {
    final http.Response r;
    try {
      r = await f().timeout(const Duration(seconds: 60));
    } catch (_) {
      throw LoiCongDong('Không kết nối được máy chủ ảnh. Kiểm tra mạng rồi thử lại.');
    }
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return j;
    final tb = (j is Map ? j['detail']?.toString() : null) ?? 'Có lỗi xảy ra (mã ${r.statusCode}).';
    if (r.statusCode == 401 && _token != null) {
      _token = null;
      await _luuPhien();
      throw LoiCongDong(tb, hetPhien: true);
    }
    throw LoiCongDong(tb);
  }

  Uri _u(String duong, [Map<String, String>? q]) => Uri.parse('$diaChiMayChuAnh$duong').replace(queryParameters: q);

  Future<void> dangNhapGoogle() async {
    final gs = GoogleSignIn.instance;
    if (!_daKhoiTaoGoogle) {
      await gs.initialize(
          clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
          serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId);
      _daKhoiTaoGoogle = true;
    }
    final GoogleSignInAccount tk;
    try {
      tk = await gs.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw LoiCongDong('Bạn đã huỷ đăng nhập.');
      throw LoiCongDong('Đăng nhập Google không thành công (${e.code.name}).');
    }
    final idToken = tk.authentication.idToken;
    if (idToken == null) throw LoiCongDong('Google không trả về mã xác thực. Kiểm tra cấu hình client ID.');
    final j = await _goi(() => http.post(_u('/api/dang-nhap/google'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id_token': idToken})));
    _token = j['token'] as String;
    ten = j['nguoi_dung']['ten'] as String;
    daDongY = j['nguoi_dung']['da_dong_y'] as bool;
    await _luuPhien();
  }

  Future<void> dongY() async {
    await _goi(() => http.post(_u('/api/dong-y'),
        headers: {..._dauTrang, 'Content-Type': 'application/json'}, body: jsonEncode({'phien_ban': phienBanDieuKhoan})));
    daDongY = true;
    await _luuPhien();
  }

  Future<void> dangXuat() async {
    try {
      await http.post(_u('/api/dang-xuat'), headers: _dauTrang).timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _token = null;
    await _luuPhien();
  }

  /// Xoá hẳn tài khoản + toàn bộ ảnh đã gửi trên máy chủ.
  Future<void> xoaTaiKhoan() async {
    await _goi(() => http.delete(_u('/api/tai-khoan'), headers: _dauTrang));
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
    _token = null;
    await _luuPhien();
  }

  Future<List<AnhCongDong>> danhSach(String diaDiem) async {
    await _taiPhien();
    final j = await _goi(() => http.get(_u('/api/anh', {'dia_diem': diaDiem}), headers: _dauTrang));
    return (j as List).map((e) => AnhCongDong.tuJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> guiAnh(String diaDiem, XFile tep) async {
    final rq = http.MultipartRequest('POST', _u('/api/anh'))
      ..headers.addAll(_dauTrang)
      ..fields['dia_diem'] = diaDiem
      ..files.add(http.MultipartFile.fromBytes('tep', await tep.readAsBytes(), filename: 'anh.jpg'));
    await _goi(() async => http.Response.fromStream(await rq.send()));
  }

  Future<void> xoaAnh(String id) => _goi(() => http.delete(_u('/api/anh/$id'), headers: _dauTrang));

  Future<void> baoCao(String id, String lyDo) => _goi(() => http.post(_u('/api/anh/$id/bao-cao'),
      headers: {..._dauTrang, 'Content-Type': 'application/json'}, body: jsonEncode({'ly_do': lyDo})));

  Future<void> chan(int nguoiDungId) => _goi(() => http.post(_u('/api/chan/$nguoiDungId'), headers: _dauTrang));

  /// Đảm bảo đã đăng nhập + đồng ý điều khoản (hiện màn hình nếu chưa). true = sẵn sàng gửi / báo cáo.
  Future<bool> sanSang(BuildContext context) async {
    await _taiPhien();
    if (daDangNhap && daDongY) return true;
    if (!context.mounted) return false;
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Mau.giay,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => const _ManDangNhap(),
        ) ??
        false;
  }
}

void _bao(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is LoiCongDong ? e.thongBao : '$e')));
}

class _ManDangNhap extends StatefulWidget {
  const _ManDangNhap();
  @override
  State<_ManDangNhap> createState() => _ManDangNhapState();
}

class _ManDangNhapState extends State<_ManDangNhap> {
  bool _dongY = false, _dangChay = false;

  Future<void> _tiep() async {
    final cd = CongDong.chung;
    setState(() => _dangChay = true);
    try {
      if (!cd.daDangNhap) await cd.dangNhapGoogle();
      if (!cd.daDongY) await cd.dongY();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _bao(context, e);
      setState(() => _dangChay = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 40, height: 4, decoration: BoxDecoration(color: Mau.vien, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            const Text('Chia sẻ ảnh với du khách', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Đọc và đồng ý điều khoản trước khi gửi ảnh:', style: TextStyle(color: Mau.xam)),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(children: [
                  for (var i = 0; i < dieuKhoan.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w700, color: Mau.thong)),
                        Expanded(child: Text(dieuKhoan[i], style: const TextStyle(height: 1.45))),
                      ]),
                    ),
                ]),
              ),
            ),
            CheckboxListTile(
              value: _dongY,
              onChanged: _dangChay ? null : (v) => setState(() => _dongY = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Tôi đồng ý với các điều khoản trên', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Mau.thong,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: !_dongY || _dangChay ? null : _tiep,
              icon: _dangChay
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login),
              label: Text(CongDong.chung.daDangNhap ? 'Đồng ý và tiếp tục' : 'Đăng nhập bằng Google'),
            ),
          ]),
        ),
      );
}

/// Mục "Ảnh từ du khách" trong trang chi tiết địa điểm.
class MucAnhCongDong extends StatefulWidget {
  final String diaDiem;
  const MucAnhCongDong({super.key, required this.diaDiem});
  @override
  State<MucAnhCongDong> createState() => _MucAnhCongDongState();
}

class _MucAnhCongDongState extends State<MucAnhCongDong> {
  final _cd = CongDong.chung;
  List<AnhCongDong>? _ds;
  String? _loi;
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final ds = await _cd.danhSach(widget.diaDiem);
      if (mounted) {
        setState(() {
          _ds = ds;
          _loi = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loi = '$e');
    }
  }

  Future<void> _gui() async {
    if (!await _cd.sanSang(context) || !mounted) return;
    final nguon = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Mau.giay,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (nguon == null) return;
    final XFile? tep;
    try {
      tep = await ImagePicker().pickImage(source: nguon, maxWidth: 2400, maxHeight: 2400, imageQuality: 88);
    } catch (e) {
      if (mounted) _bao(context, 'Không mở được máy ảnh / thư viện ảnh.');
      return;
    }
    if (tep == null || !mounted) return;
    setState(() => _dangGui = true);
    try {
      await _cd.guiAnh(widget.diaDiem, tep);
      if (mounted) _bao(context, 'Đã gửi! Ảnh sẽ hiện cho mọi người sau khi được duyệt.');
      await _tai();
    } catch (e) {
      if (mounted) _bao(context, e);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _moAnh(int i) async {
    final doi = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => XemAnhCongDong(ds: _ds!, batDau: i)));
    if (doi == true) _tai();
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
        child: Row(children: [
          const Expanded(child: Text('Ảnh từ du khách', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ListenableBuilder(
            listenable: _cd,
            builder: (_, _) => _cd.daDangNhap
                ? IconButton(
                    tooltip: 'Tài khoản',
                    icon: const Icon(Icons.account_circle_outlined, color: Mau.xam),
                    onPressed: () => _taiKhoan(context))
                : const SizedBox.shrink(),
          ),
          TextButton.icon(
            onPressed: _dangGui ? null : _gui,
            style: TextButton.styleFrom(foregroundColor: Mau.bazan),
            icon: _dangGui
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined, size: 19),
            label: Text(_dangGui ? 'Đang gửi…' : 'Gửi ảnh', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      if (ds == null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(_loi ?? 'Đang tải ảnh…', style: const TextStyle(fontSize: 13, color: Mau.xam)),
        )
      else if (ds.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Chưa có ảnh nào. Bạn đã đến đây? Hãy là người đầu tiên chia sẻ!',
              style: TextStyle(fontSize: 13.5, color: Mau.xam)),
        )
      else
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: ds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _moAnh(i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  Image.network(ds[i].urlNho,
                      width: 118,
                      height: 118,
                      fit: BoxFit.cover,
                      cacheWidth: 354,
                      errorBuilder: (_, _, _) => Container(width: 118, height: 118, color: Mau.vien)),
                  if (ds[i].choDuyet)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: const Text('Chờ duyệt',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  Future<void> _taiKhoan(BuildContext context) async {
    final hanhDong = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Mau.giay,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(_cd.ten ?? ''),
              subtitle: const Text('Tài khoản gửi ảnh')),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Đăng xuất'), onTap: () => Navigator.pop(c, 'ra')),
          ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Mau.bazan),
              title: const Text('Xoá tài khoản và toàn bộ ảnh', style: TextStyle(color: Mau.bazan)),
              onTap: () => Navigator.pop(c, 'xoa')),
        ]),
      ),
    );
    if (!context.mounted) return;
    try {
      if (hanhDong == 'ra') {
        await _cd.dangXuat();
      } else if (hanhDong == 'xoa') {
        final chac = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Xoá tài khoản?'),
            content: const Text('Toàn bộ ảnh bạn đã gửi sẽ bị xoá vĩnh viễn khỏi máy chủ. Không khôi phục được.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Mau.bazan),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Xoá vĩnh viễn')),
            ],
          ),
        );
        if (chac != true) return;
        await _cd.xoaTaiKhoan();
        if (context.mounted) _bao(context, 'Đã xoá tài khoản và toàn bộ ảnh.');
      } else {
        return;
      }
      await _tai();
    } catch (e) {
      if (context.mounted) _bao(context, e);
    }
  }
}

/// Xem ảnh toàn màn hình; menu: xoá (ảnh của mình) / báo cáo / chặn người đăng. Trả true nếu danh sách cần tải lại.
class XemAnhCongDong extends StatefulWidget {
  final List<AnhCongDong> ds;
  final int batDau;
  const XemAnhCongDong({super.key, required this.ds, required this.batDau});
  @override
  State<XemAnhCongDong> createState() => _XemAnhCongDongState();
}

class _XemAnhCongDongState extends State<XemAnhCongDong> {
  late int _i = widget.batDau;
  final _cd = CongDong.chung;

  Future<void> _menu(String chon) async {
    final a = widget.ds[_i];
    try {
      if (chon == 'xoa') {
        await _cd.xoaAnh(a.id);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (!await _cd.sanSang(context) || !mounted) return;
      if (chon == 'bao_cao') {
        final lyDo = await showDialog<String>(
          context: context,
          builder: (c) => SimpleDialog(title: const Text('Báo cáo ảnh vì…'), children: [
            for (final l in ['Nội dung không phù hợp', 'Không phải ảnh địa điểm này', 'Quảng cáo / spam', 'Vi phạm bản quyền', 'Lộ thông tin cá nhân'])
              SimpleDialogOption(onPressed: () => Navigator.pop(c, l), child: Text(l)),
          ]),
        );
        if (lyDo == null) return;
        await _cd.baoCao(a.id, lyDo);
        if (mounted) _bao(context, 'Cảm ơn bạn. Chúng tôi sẽ xem xét ảnh này trong 24 giờ.');
      } else if (chon == 'chan') {
        await _cd.chan(a.nguoiDangId);
        if (mounted) {
          _bao(context, 'Đã chặn. Bạn sẽ không thấy ảnh của ${a.nguoiDang} nữa.');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) _bao(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ds[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        title: Text(a.choDuyet ? '${a.nguoiDang} · chờ duyệt' : a.nguoiDang),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => a.cuaToi
                ? const [PopupMenuItem(value: 'xoa', child: Text('Xoá ảnh của tôi'))]
                : const [
                    PopupMenuItem(value: 'bao_cao', child: Text('Báo cáo ảnh')),
                    PopupMenuItem(value: 'chan', child: Text('Chặn người đăng')),
                  ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.batDau),
        itemCount: widget.ds.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(widget.ds[i].url,
                fit: BoxFit.contain,
                loadingBuilder: (_, w, p) => p == null ? w : const CircularProgressIndicator(color: Colors.white),
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
          ),
        ),
      ),
    );
  }
}
