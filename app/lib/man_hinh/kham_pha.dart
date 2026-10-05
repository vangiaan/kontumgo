import 'package:flutter/material.dart';

import '../du_lieu.dart';
import '../giao_dien.dart';
import 'chi_tiet.dart';

/// Danh sách địa điểm có tìm kiếm + lọc. `chiDaLuu` = tab "Đã lưu".
class KhamPha extends StatefulWidget {
  final bool chiDaLuu;
  const KhamPha({super.key, this.chiDaLuu = false});

  @override
  State<KhamPha> createState() => KhamPhaState();
}

class KhamPhaState extends State<KhamPha> {
  final _o = TextEditingController();
  final _focus = FocusNode();
  String? _nhom, _vung;

  void datLoc({String? nhom, String? vung, bool timKiem = false}) {
    setState(() {
      _nhom = nhom;
      _vung = vung;
      _o.clear();
    });
    if (timKiem) _focus.requestFocus();
  }

  @override
  void dispose() {
    _o.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kho = KhoDuLieu.chung;
    return ListenableBuilder(
      listenable: kho,
      builder: (context, _) {
        final tu = boDau(_o.text.trim());
        final ds = kho.diaDiem.where((d) {
          if (widget.chiDaLuu && !kho.daLuu.contains(d.id)) return false;
          if (_nhom != null && d.nhom != _nhom) return false;
          if (_vung != null && d.vung != _vung) return false;
          return tu.isEmpty || boDau(d.ten).contains(tu);
        }).toList();

        return SafeArea(
          bottom: false,
          child: Column(children: [
            Container(
              color: Mau.giay,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.chiDaLuu ? 'Đã lưu' : 'Khám phá',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                if (!widget.chiDaLuu) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _o,
                    focusNode: _focus,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _o.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xoá',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setState(_o.clear)),
                      isDense: true,
                      filled: true,
                      fillColor: Mau.suong,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      _nutLoc('Tất cả', _nhom == null && _vung == null, () => setState(() => _nhom = _vung = null)),
                      for (final v in tenVung.entries)
                        _nutLoc(v.value, _vung == v.key, () => setState(() => _vung = _vung == v.key ? null : v.key)),
                      for (final n in Nhom.tatCa)
                        _nutLoc(n.ten, _nhom == n.ma, () => setState(() => _nhom = _nhom == n.ma ? null : n.ma)),
                    ]),
                  ),
                ],
              ]),
            ),
            const Divider(height: 1, color: Mau.vien),
            Expanded(
              child: ds.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          widget.chiDaLuu
                              ? 'Chưa lưu địa điểm nào.\nBấm "Lưu lại" ở trang địa điểm để xem lại ở đây.'
                              : 'Không có địa điểm nào khớp. Thử bỏ bớt bộ lọc.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Mau.xam, height: 1.5),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      itemCount: ds.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => DongDiaDiem(d: ds[i]),
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _nutLoc(String ten, bool chon, VoidCallback khiBam) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: chon ? Mau.thong : Mau.giay,
          shape: StadiumBorder(side: BorderSide(color: chon ? Mau.thong : Mau.vien)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: khiBam,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Text(ten,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: chon ? Mau.tren : Mau.xam)),
              ),
            ),
          ),
        ),
      );
}

class DongDiaDiem extends StatelessWidget {
  final DiaDiem d;
  final int? so; // số thứ tự (dùng trong lịch trình)
  const DongDiaDiem({super.key, required this.d, this.so});

  @override
  Widget build(BuildContext context) => Material(
        color: Mau.giay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Mau.vien)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => moChiTiet(context, d),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              OAnh(
                nhom: d.nhom,
                cao: 76,
                rong: 76,
                bo: 10,
                anh: d.anh,
                toi: so != null,
                con: so == null
                    ? null
                    : Center(
                        child: Text('$so',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.ten, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                  if (d.moTa != null) ...[
                    const SizedBox(height: 3),
                    Text(d.moTa!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Mau.xam, height: 1.45)),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Mau.thongNhat, borderRadius: BorderRadius.circular(6)),
                    child: Text('${Nhom.cua(d.nhom).ten} · ${tenVung[d.vung] ?? ''}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Mau.thong)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}
