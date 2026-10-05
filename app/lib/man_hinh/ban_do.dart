import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../du_lieu.dart';
import '../giao_dien.dart';
import 'chi_tiet.dart';

class BanDo extends StatefulWidget {
  const BanDo({super.key});

  @override
  State<BanDo> createState() => _BanDoState();
}

class _BanDoState extends State<BanDo> {
  // tâm và mức phóng của từng khu vực; 'khac' = nhìn toàn vùng
  static const _tam = {'kontum': LatLng(14.352, 108.005), 'mangden': LatLng(14.603, 108.290), 'khac': LatLng(14.70, 107.95)};
  static const _phong = {'kontum': 13.5, 'mangden': 13.5, 'khac': 9.3};
  final _dk = MapController();
  String _vung = 'kontum';
  DiaDiem? _chon;
  double _zoom = 13.5;

  /// Gom các điểm nằm sát nhau thành cụm theo ô lưới ~64 px ở mức phóng hiện tại, để ghim không đè lên nhau.
  List<List<DiaDiem>> _gomCum(List<DiaDiem> ds) {
    if (_zoom >= 16.5) return [for (final d in ds) [d]];
    final doMoiPx = 360 / (256 * math.pow(2, _zoom)); // số độ kinh tuyến ứng với 1 px
    final o = doMoiPx * 64;
    final cum = <String, List<DiaDiem>>{};
    for (final d in ds) {
      (cum['${(d.lon / o).floor()}_${(d.lat / o).floor()}'] ??= []).add(d);
    }
    return cum.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final ds = KhoDuLieu.chung.diaDiem;
    return Stack(children: [
      FlutterMap(
        mapController: _dk,
        options: MapOptions(
          initialCenter: _tam[_vung]!,
          initialZoom: 13.5,
          minZoom: 8,
          maxZoom: 18,
          onTap: (_, _) => setState(() => _chon = null),
          onPositionChanged: (cam, _) {
            if ((cam.zoom - _zoom).abs() >= 0.2) setState(() => _zoom = cam.zoom);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.namtao.kontumgo',
          ),
          MarkerLayer(markers: [
            for (final c in _gomCum(ds))
              if (c.length == 1)
                Marker(
                  point: LatLng(c.first.lat, c.first.lon),
                  width: 36,
                  height: 36,
                  child: GestureDetector(
                    onTap: () => setState(() => _chon = c.first),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _chon?.id == c.first.id ? Mau.bazan : Mau.thong,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(Nhom.cua(c.first.nhom).icon, size: 18, color: Colors.white),
                    ),
                  ),
                )
              else
                // Cụm nhiều điểm: hiện số lượng, bấm để phóng to vào giữa cụm
                Marker(
                  point: LatLng(
                    c.map((d) => d.lat).reduce((a, b) => a + b) / c.length,
                    c.map((d) => d.lon).reduce((a, b) => a + b) / c.length,
                  ),
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _chon = null);
                      _dk.move(
                        LatLng(
                          c.map((d) => d.lat).reduce((a, b) => a + b) / c.length,
                          c.map((d) => d.lon).reduce((a, b) => a + b) / c.length,
                        ),
                        math.min(_zoom + 1.6, 18),
                      );
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Mau.bazan,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: Text('${c.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
          ]),
          const SimpleAttributionWidget(source: Text('OpenStreetMap')),
        ],
      ),
      // Chuyển nhanh giữa hai khu vực
      Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final v in tenVung.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                elevation: 2,
                color: _vung == v.key ? Mau.thong : Mau.giay,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    setState(() {
                      _vung = v.key;
                      _chon = null;
                    });
                    _dk.move(_tam[v.key]!, _phong[v.key]!);
                    setState(() => _zoom = _phong[v.key]!);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(v.key == 'khac' ? 'Toàn vùng' : v.value,
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: _vung == v.key ? Mau.tren : Mau.muc)),
                  ),
                ),
              ),
            ),
        ]),
      ),
      if (_chon != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: 28,
          child: Material(
            elevation: 4,
            color: Mau.giay,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => moChiTiet(context, _chon!),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  OAnh(nhom: _chon!.nhom, cao: 52, rong: 52, bo: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_chon!.ten,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(Nhom.cua(_chon!.nhom).ten, style: const TextStyle(fontSize: 12.5, color: Mau.xam)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Mau.xam),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}
