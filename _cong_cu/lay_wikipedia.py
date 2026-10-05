# Lấy các bài Wikipedia tiếng Việt về địa danh/di tích/thắng cảnh ở Kon Tum (API công khai, nội dung CC BY-SA).
# Chỉ dùng để lấy DỮ KIỆN (tên, toạ độ, tóm tắt để viết lại) + tên ảnh trên Commons để xét giấy phép sau.
# Chạy: python lay_wikipedia.py  -> du_lieu/wikipedia_tho.json
import io
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
API = "https://vi.wikipedia.org/w/api.php"
UA = {"User-Agent": "KonTumGo-research/0.1 (du an ca nhan; lien he qua truyentamlinh.vn)"}
GOC = pathlib.Path(__file__).resolve().parent.parent

THE_LOAI = [
    "Du lịch Kon Tum", "Di tích tại Kon Tum", "Địa lý Kon Tum", "Kon Tum", "Văn hóa Kon Tum",
    "Núi tại Kon Tum", "Sông tại Kon Tum", "Thác tại Kon Tum", "Vườn quốc gia Việt Nam", "Nhà thờ tại Kon Tum",
    "Giáo phận Kon Tum", "Di tích quốc gia đặc biệt (Việt Nam)", "Khu bảo tồn thiên nhiên Việt Nam", "Hồ tại Kon Tum",
]
# Tâm tìm quanh (bán kính 10 km): thành phố, Măng Đen, Ngọc Hồi, Đăk Tô, Sa Thầy, Đăk Glei, Tu Mơ Rông, Đăk Hà, Kon Rẫy
TAM = [(14.352, 108.005), (14.603, 108.290), (14.700, 107.690), (14.660, 107.840), (14.410, 107.790),
       (15.080, 107.740), (14.900, 107.950), (14.520, 107.920), (14.500, 108.150), (14.720, 107.560), (15.070, 107.970)]


def goi(**kw):
    kw.update(format="json", formatversion="2")
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(kw), headers=UA)
    for lan in range(5):
        try:
            time.sleep(1.2)   # Wikipedia gioi han toc do: di cham
            return json.loads(urllib.request.urlopen(req, timeout=40).read())
        except Exception as e:  # 429 hoac mang chap chon: cho roi thu lai
            if lan == 4:
                raise
            time.sleep(25 if "429" in str(e) else 3)


def main():
    ten = {}
    for tl in THE_LOAI:
        kq = goi(action="query", list="categorymembers", cmtitle="Thể loại:" + tl, cmlimit="200", cmtype="page")
        ds = [x["title"] for x in kq.get("query", {}).get("categorymembers", [])]
        print(f"the loai {tl}: {len(ds)}")
        for t in ds:
            ten.setdefault(t, set()).add("tl:" + tl)
    for lat, lon in TAM:
        kq = goi(action="query", list="geosearch", gscoord=f"{lat}|{lon}", gsradius="10000", gslimit="100")
        ds = [x["title"] for x in kq.get("query", {}).get("geosearch", [])]
        print(f"quanh {lat},{lon}: {len(ds)}")
        for t in ds:
            ten.setdefault(t, set()).add("gan")

    ra, ds = [], sorted(ten)
    for i in range(0, len(ds), 20):
        kq = goi(action="query", titles="|".join(ds[i:i + 20]), prop="coordinates|pageimages|extracts|info",
                 exintro="1", explaintext="1", exlimit="20", piprop="name|original", pilimit="20", inprop="url", colimit="20")
        for p in kq.get("query", {}).get("pages", []):
            c = (p.get("coordinates") or [{}])[0]
            ra.append({
                "ten": p["title"], "url": p.get("fullurl"), "lat": c.get("lat"), "lon": c.get("lon"),
                "tom_tat": (p.get("extract") or "").strip(), "anh": p.get("pageimage"),
                "anh_url": (p.get("original") or {}).get("source"), "tu": sorted(ten[p["title"]]),
            })
        time.sleep(0.3)
    dich = GOC / "du_lieu" / "wikipedia_tho.json"
    dich.write_text(json.dumps(ra, ensure_ascii=False, indent=1), encoding="utf-8")
    co_td = [x for x in ra if x["lat"]]
    print(f"\ntong bai: {len(ra)} | co toa do: {len(co_td)} | co anh: {sum(1 for x in ra if x['anh'])} | co tom tat: {sum(1 for x in ra if x['tom_tat'])}")
    kt = [x for x in co_td if 13.9 <= x["lat"] <= 15.45 and 107.3 <= x["lon"] <= 108.55]
    print(f"trong khung Kon Tum: {len(kt)}")
    for x in sorted(kt, key=lambda x: x["ten"]):
        print(f"  {x['ten']} ({x['lat']:.3f},{x['lon']:.3f}){' [anh]' if x['anh'] else ''}")
    print("khong toa do nhung thuoc the loai:", "; ".join(sorted(x["ten"] for x in ra if not x["lat"] and any(t.startswith('tl:') and 'Kon Tum' in t for t in x["tu"]))))


if __name__ == "__main__":
    main()
