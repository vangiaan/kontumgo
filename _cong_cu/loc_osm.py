# Lọc dữ liệu OpenStreetMap đã tải (osm_kontum.json) theo 2 vùng: TP. Kon Tum và Măng Đen.
# Chạy: python loc_osm.py <đường dẫn osm_kontum.json> [--ghi]
import io
import json
import pathlib
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
VUNG = {
    "kontum": (14.28, 14.42, 107.93, 108.08),   # TP. Kon Tum
    "mangden": (14.52, 14.72, 108.20, 108.40),  # Măng Đen (Kon Plông)
}
NHOM = {
    "attraction": "canh-dep", "viewpoint": "canh-dep", "museum": "di-tich", "artwork": "di-tich",
    "hotel": "luu-tru", "guest_house": "luu-tru", "motel": "luu-tru", "hostel": "luu-tru", "chalet": "luu-tru",
    "camp_site": "luu-tru", "apartment": "luu-tru", "alpine_hut": "luu-tru",
    "restaurant": "an-uong", "cafe": "an-uong", "fast_food": "an-uong",
    "place_of_worship": "tam-linh", "marketplace": "cho",
}


def phan_loai(t):
    for k in ("tourism", "amenity"):
        if t.get(k) in NHOM:
            return NHOM[t[k]]
    if t.get("historic"):
        return "di-tich"
    if t.get("natural") in ("waterfall", "peak") or t.get("waterway") == "waterfall":
        return "canh-dep"
    return None


def main():
    d = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))["elements"]
    ra = []
    for e in d:
        t = e.get("tags", {})
        ten = t.get("name:vi") or t.get("name")
        lat = e.get("lat") or e.get("center", {}).get("lat")
        lon = e.get("lon") or e.get("center", {}).get("lon")
        nhom = phan_loai(t)
        if not (ten and lat and lon and nhom):
            continue
        vung = next((v for v, (a, b, c, d2) in VUNG.items() if a <= lat <= b and c <= lon <= d2), None)
        if not vung:
            continue
        ra.append({
            "osm": f"{e['type']}/{e['id']}", "ten": ten.strip(), "nhom": nhom, "vung": vung,
            "lat": round(lat, 6), "lon": round(lon, 6),
            "dien_thoai": t.get("phone") or t.get("contact:phone"), "gio": t.get("opening_hours"),
            "dia_chi": " ".join(x for x in (t.get("addr:housenumber"), t.get("addr:street")) if x) or None,
            "loai_osm": t.get("tourism") or t.get("amenity") or t.get("historic") or t.get("natural") or "waterfall",
        })
    ra.sort(key=lambda x: (x["vung"], x["nhom"], x["ten"]))
    for v in VUNG:
        print(f"== {v}: {sum(1 for x in ra if x['vung'] == v)}")
        for n in sorted({x["nhom"] for x in ra if x["vung"] == v}):
            ds = [x["ten"] for x in ra if x["vung"] == v and x["nhom"] == n]
            print(f"  {n} ({len(ds)}): " + "; ".join(ds))
    if "--ghi" in sys.argv:
        p = pathlib.Path(__file__).resolve().parent.parent / "du_lieu" / "osm_loc.json"
        p.parent.mkdir(exist_ok=True)
        p.write_text(json.dumps(ra, ensure_ascii=False, indent=1), encoding="utf-8")
        print("da ghi", p, len(ra))


if __name__ == "__main__":
    main()
