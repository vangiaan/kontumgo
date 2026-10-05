import 'package:flutter/material.dart';

import '../du_lieu.dart';
import '../giao_dien.dart';
import 'kham_pha.dart';

class ManLichTrinh extends StatelessWidget {
  final LichTrinh lt;
  const ManLichTrinh({super.key, required this.lt});

  @override
  Widget build(BuildContext context) {
    final diem = [
      for (final id in lt.diem)
        if (KhoDuLieu.chung.theoId(id) != null) KhoDuLieu.chung.theoId(id)!
    ];
    return Scaffold(
      appBar: AppBar(title: Text('${lt.soNgay} ngày', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        Text(lt.ten, style: const TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Thứ tự gợi ý để đi cho thuận đường. Bấm vào từng điểm để xem chi tiết và chỉ đường.',
            style: TextStyle(fontSize: 14, height: 1.55, color: Mau.xam)),
        const SizedBox(height: 16),
        for (var i = 0; i < diem.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DongDiaDiem(d: diem[i], so: i + 1)),
      ]),
    );
  }
}
