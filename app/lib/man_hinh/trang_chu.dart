import 'package:flutter/material.dart';

import '../du_lieu.dart';
import '../giao_dien.dart';
import '../main.dart';
import 'chi_tiet.dart';
import 'lich_trinh.dart';

class TrangChu extends StatelessWidget {
  final KhungChinhState khung;
  const TrangChu({super.key, required this.khung});

  @override
  Widget build(BuildContext context) {
    final kho = KhoDuLieu.chung;
    final nhom4 = Nhom.tatCa.take(4).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── MỞ ĐẦU ──
        Container(
          color: Mau.thong,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const LogoNhaRong(),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Mau.tren),
                  children: [TextSpan(text: 'Kon Tum '), TextSpan(text: 'Go', style: TextStyle(color: Mau.nang))],
                ),
              ),
            ]),
            const SizedBox(height: 22),
            const Text('Hôm nay mình đi đâu ở Kon Tum?',
                style: TextStyle(fontSize: 27, height: 1.2, fontWeight: FontWeight.w800, color: Mau.tren)),
            const SizedBox(height: 8),
            const Text('Nhà rông, thác rừng, đồi thông Măng Đen — có đường đi và chỗ ăn nghỉ gần đó.',
                style: TextStyle(fontSize: 14, height: 1.55, color: Color(0xFFCFDCD2))),
            const SizedBox(height: 18),
            Material(
              color: Mau.giay,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => khung.moKhamPha(timKiem: true),
                child: const SizedBox(
                  height: 48,
                  child: Row(children: [
                    SizedBox(width: 14),
                    Icon(Icons.search, size: 20, color: Mau.xam),
                    SizedBox(width: 10),
                    Text('Tìm địa điểm, quán ăn, homestay', style: TextStyle(fontSize: 14.5, color: Mau.xam)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        const ThoCam(),

        // ── NHÓM ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
          child: Row(children: [
            for (final n in nhom4)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => khung.moKhamPha(nhom: n.ma),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: Mau.thongNhat, borderRadius: BorderRadius.circular(16)),
                        child: Icon(n.icon, color: Mau.thong, size: 26),
                      ),
                      const SizedBox(height: 7),
                      Text(n.ten,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.25)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),

        // ── NÊN GHÉ ──
        TieuDeMuc('Nên ghé đầu tiên', nut: 'Xem tất cả', khiBam: () => khung.moKhamPha()),
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: kho.noiBat.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => TheLon(d: kho.noiBat[i]),
          ),
        ),

        // ── KHU VỰC ──
        const TieuDeMuc('Chọn theo khu vực'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            for (final v in tenVung.entries) ...[
              Expanded(
                child: _OVung(
                  ten: v.value,
                  soDiem: kho.diaDiem.where((d) => d.vung == v.key).length,
                  mau: v.key == 'mangden' ? Mau.thong : v.key == 'kontum' ? Mau.bazan : const Color(0xFF4B6B7C),
                  khiBam: () => khung.moKhamPha(vung: v.key),
                ),
              ),
              if (v.key != tenVung.keys.last) const SizedBox(width: 12),
            ],
          ]),
        ),

        // ── LỊCH TRÌNH ──
        const TieuDeMuc('Lịch trình gợi ý'),
        for (final lt in lichTrinhGoiY)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Material(
              color: Mau.giay,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Mau.vien)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManLichTrinh(lt: lt))),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Mau.bazan, borderRadius: BorderRadius.circular(12)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${lt.soNgay}',
                            style: const TextStyle(color: Colors.white, fontSize: 19, height: 1, fontWeight: FontWeight.w800)),
                        const Text('ngày', style: TextStyle(color: Colors.white, fontSize: 11, height: 1.2, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lt.ten, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(lt.tomTat, style: const TextStyle(fontSize: 12.5, color: Mau.xam)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: Mau.xam),
                  ]),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Text('Dữ liệu bản đồ: ${kho.ghiNguon}', style: const TextStyle(fontSize: 11.5, color: Mau.xam)),
        ),
      ],
    );
  }
}

class TieuDeMuc extends StatelessWidget {
  final String ten;
  final String? nut;
  final VoidCallback? khiBam;
  const TieuDeMuc(this.ten, {super.key, this.nut, this.khiBam});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
        child: Row(children: [
          Expanded(child: Text(ten, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (nut != null)
            TextButton(
              onPressed: khiBam,
              style: TextButton.styleFrom(foregroundColor: Mau.bazan, visualDensity: VisualDensity.compact),
              child: Text(nut!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )
          else
            const SizedBox(height: 40),
        ]),
      );
}

class TheLon extends StatelessWidget {
  final DiaDiem d;
  const TheLon({super.key, required this.d});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 216,
        child: Material(
          color: Mau.giay,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Mau.vien)),
          child: InkWell(
            onTap: () => moChiTiet(context, d),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              OAnh(
                nhom: d.nhom,
                cao: 124,
                rong: double.infinity,
                con: Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Mau.giay.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(6)),
                    child: Text((tenVung[d.vung] ?? '').toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.ten,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 3),
                  Text(Nhom.cua(d.nhom).ten, style: const TextStyle(fontSize: 12.5, color: Mau.xam)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _OVung extends StatelessWidget {
  final String ten;
  final int soDiem;
  final Color mau;
  final VoidCallback khiBam;
  const _OVung({required this.ten, required this.soDiem, required this.mau, required this.khiBam});

  @override
  Widget build(BuildContext context) => Material(
        color: mau,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: khiBam,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ten, style: const TextStyle(color: Mau.tren, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$soDiem địa điểm', style: TextStyle(color: Mau.tren.withValues(alpha: 0.8), fontSize: 12.5)),
            ]),
          ),
        ),
      );
}
