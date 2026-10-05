import 'package:flutter/material.dart';

import 'du_lieu.dart';
import 'giao_dien.dart';
import 'man_hinh/ban_do.dart';
import 'man_hinh/kham_pha.dart';
import 'man_hinh/trang_chu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KhoDuLieu.chung.tai();
  runApp(const KonTumGo());
}

class KonTumGo extends StatelessWidget {
  const KonTumGo({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kon Tum Go',
        debugShowCheckedModeBanner: false,
        theme: giaoDien(),
        home: const KhungChinh(),
      );
}

class KhungChinh extends StatefulWidget {
  const KhungChinh({super.key});

  @override
  State<KhungChinh> createState() => KhungChinhState();
}

class KhungChinhState extends State<KhungChinh> {
  int _tab = 0;
  final _khamPha = GlobalKey<KhamPhaState>();

  /// Trang chủ gọi để nhảy sang tab Khám phá với bộ lọc sẵn.
  void moKhamPha({String? nhom, String? vung, bool timKiem = false}) {
    setState(() => _tab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _khamPha.currentState?.datLoc(nhom: nhom, vung: vung, timKiem: timKiem));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        TrangChu(khung: this),
        KhamPha(key: _khamPha),
        const BanDo(),
        const KhamPha(chiDaLuu: true),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Khám phá'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Bản đồ'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Đã lưu'),
        ],
      ),
    );
  }
}
