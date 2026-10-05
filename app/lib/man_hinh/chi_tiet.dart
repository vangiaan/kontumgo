import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cong_dong.dart';
import '../du_lieu.dart';
import '../giao_dien.dart';
import 'trang_chu.dart';

void moChiTiet(BuildContext context, DiaDiem d) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChiTiet(d: d)));

Future<void> moLienKet(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máy không mở được liên kết này.')));
  }
}

class ChiTiet extends StatelessWidget {
  final DiaDiem d;
  const ChiTiet({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final kho = KhoDuLieu.chung;
    final gan = kho.ganDay(d);
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        OAnh(
          nhom: d.nhom,
          cao: 230,
          rong: double.infinity,
          anh: d.anh,
          ghiCong: d.anhGhiCong,
          con: Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            child: Material(
              color: Mau.giay.withValues(alpha: 0.94),
              shape: const CircleBorder(),
              child: IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back, color: Mau.muc),
                  onPressed: () => Navigator.pop(context)),
            ),
          ),
        ),
        const ThoCam(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Nhom.cua(d.nhom).ten} · ${tenVung[d.vung] ?? ''}'.toUpperCase(),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: Mau.bazan)),
            const SizedBox(height: 6),
            Text(d.ten, style: const TextStyle(fontSize: 25, height: 1.2, fontWeight: FontWeight.w800)),
            if (d.moTa != null) ...[
              const SizedBox(height: 12),
              Text(d.moTa!, style: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF34403A))),
            ],
            if (d.gio != null || d.dienThoai != null || d.diaChi != null) ...[
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                    color: Mau.giay, borderRadius: BorderRadius.circular(14), border: Border.all(color: Mau.vien)),
                child: Column(children: [
                  if (d.diaChi != null) _dong('Địa chỉ', d.diaChi!, dau: true),
                  if (d.gio != null) _dong('Giờ mở cửa', d.gio!, dau: d.diaChi == null),
                  if (d.dienThoai != null) _dong('Điện thoại', d.dienThoai!, dau: d.diaChi == null && d.gio == null),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Mau.bazan,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => moLienKet(context,
                      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${d.lat},${d.lon}')),
                  icon: const Icon(Icons.directions, size: 20),
                  label: const Text('Chỉ đường', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListenableBuilder(
                  listenable: kho,
                  builder: (_, _) {
                    final luu = kho.daLuu.contains(d.id);
                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Mau.thong,
                          side: const BorderSide(color: Mau.thong, width: 1.5),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => kho.doiLuu(d.id),
                      icon: Icon(luu ? Icons.bookmark : Icons.bookmark_outline, size: 20),
                      label: Text(luu ? 'Đã lưu' : 'Lưu lại', style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ),
            ]),
            // App chưa có ảnh riêng của địa điểm: mở Google Maps để khách xem ảnh và đánh giá ở đó.
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Mau.muc,
                  side: const BorderSide(color: Mau.vien),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => moLienKet(
                  context,
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': '${d.ten}, ${d.vung == 'mangden' ? 'Măng Đen' : 'Kon Tum'}',
                  })),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text('Xem ảnh trên Google Maps'),
            ),
            if (d.dienThoai != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Mau.muc,
                    side: const BorderSide(color: Mau.vien),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => moLienKet(context, Uri(scheme: 'tel', path: d.dienThoai!.replaceAll(' ', ''))),
                icon: const Icon(Icons.call_outlined, size: 20),
                label: Text('Gọi ${d.dienThoai}'),
              ),
            ],
          ]),
        ),
        if (CongDong.batDuoc) MucAnhCongDong(diaDiem: d.id),
        if (gan.isNotEmpty) ...[
          const TieuDeMuc('Gần đây'),
          SizedBox(
            height: 206,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: gan.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => TheLon(d: gan[i]),
            ),
          ),
        ],
        const SizedBox(height: 28),
      ]),
    );
  }

  Widget _dong(String nhan, String giaTri, {bool dau = false}) => Container(
        decoration: BoxDecoration(border: dau ? null : const Border(top: BorderSide(color: Mau.vien))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nhan, style: const TextStyle(fontSize: 14, color: Mau.xam)),
          const SizedBox(width: 16),
          Expanded(
              child: Text(giaTri,
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ]),
      );
}
