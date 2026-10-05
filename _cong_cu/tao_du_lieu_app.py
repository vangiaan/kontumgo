# Tạo app/assets/du_lieu/dia_diem.json từ du_lieu/osm_loc.json + phần biên tập tay (BIEN_TAP).
# Mô tả trong BIEN_TAP là bản nháp viết từ hiểu biết chung, da_kiem=False cho tới khi người địa phương xác nhận.
import io
import json
import math
import pathlib
import re
import sys
import unicodedata

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GOC = pathlib.Path(__file__).resolve().parent.parent

BO = {"đường nhỏ khó đi", "Military Bulldozer", "Highland Eco Tours", "Jollibee", "Banh", "Vong", "Lynn",
      "Nhà Hàng Tiệc Cưới Thiên Hương", "Thien Huong Wedding Restaurant", "Đài liệt sĩ", "Kon Tum Martyrs Cemetery"}
DOI_TEN = {
    "Nhà thờ chính tòa Kon Tum": "Nhà thờ Gỗ Kon Tum",
    "Tòa giám mục Kon Tum - Chủng viện thừa sai": "Toà Giám mục Kon Tum",
    "Kon Tum Museum": "Bảo tàng Kon Tum",
    "Đức mẹ Măng Đen": "Tượng Đức Mẹ Măng Đen",
    "Hồ Đắk Ke": "Hồ Đăk Ke",
    "Nhà Rông Kon Pring": "Làng Kon Pring",
}
# tên (sau khi đổi) -> (nhóm ghi đè, thứ tự nổi bật, mô tả nháp)
BIEN_TAP = {
    "Nhà thờ Gỗ Kon Tum": ("di-tich", 1, "Nhà thờ chính toà làm gần như hoàn toàn bằng gỗ, kết hợp kiểu Roman với dáng nhà sàn của người Ba Na. Nằm ngay trung tâm Kon Tum, đi bộ thăm được."),
    "Thác Pa Sỹ": ("canh-dep", 2, "Thác nằm giữa rừng nguyên sinh, đi bộ một đoạn dưới tán cây là tới chân thác. Trong khu có vườn tượng gỗ và nhà rông."),
    "Nhà rông Kon Klor": ("di-tich", 3, "Nhà rông của làng Ba Na Kon Klor, mái cao vút, nằm cạnh cầu treo Kon Klor bắc qua sông Đăk Bla."),
    "Hồ Đăk Ke": ("canh-dep", 4, "Hồ nước nằm giữa rừng thông, có lối đi bộ quanh hồ. Sáng sớm thường có sương."),
    "Toà Giám mục Kon Tum": ("di-tich", 5, "Chủng viện thừa sai xây từ đầu thế kỷ 20, pha trộn kiến trúc phương Tây với nhà sàn bản địa. Bên trong có phòng truyền thống trưng bày hiện vật các dân tộc Tây Nguyên."),
    "Tượng Đức Mẹ Măng Đen": ("tam-linh", 6, "Tượng Đức Mẹ đặt giữa rừng, là điểm hành hương của giáo dân và điểm dừng chân quen thuộc của khách tới Măng Đen."),
    "Chùa Khánh Lâm": ("tam-linh", 7, "Ngôi chùa trên đồi giữa rừng Măng Đen, lối lên là những bậc thang dưới tán cây."),
    "Làng Kon Pring": ("di-tich", 8, "Làng du lịch cộng đồng của người Xơ Đăng ở Măng Đen, có nhà rông và các hoạt động văn hoá của làng."),
    "Ngục Kon Tum": ("di-tich", 9, "Di tích nhà ngục thời Pháp thuộc bên bờ sông Đăk Bla, nay là khu tưởng niệm và trưng bày."),
    "Bảo tàng Kon Tum": ("di-tich", 10, "Bảo tàng tỉnh, trưng bày hiện vật về lịch sử và văn hoá các dân tộc ở Kon Tum."),
    "Con đường thông cong": ("canh-dep", 11, "Đoạn đường uốn cong giữa hai hàng thông, điểm chụp ảnh quen thuộc ở Măng Đen."),
    "Cầu dây võng Kon Pring": ("canh-dep", 12, "Cầu treo ở làng Kon Pring."),
    "Tượng đài Chiến thắng Măng Đen": ("di-tich", 13, "Tượng đài ghi dấu chiến thắng Măng Đen, nằm ở khu trung tâm."),
    "Chợ Kon Plông": ("cho", 14, "Chợ trung tâm Măng Đen, nơi mua nông sản và đặc sản địa phương."),
}


# Điểm bổ sung ngoài OpenStreetMap: toạ độ và dữ kiện lấy từ bài Wikipedia tiếng Việt, mô tả viết lại.
# (tên, nhóm, vùng, lat, lon, mô tả, tên bài nguồn)
BO_SUNG = [
    ("Cầu treo Kon Klor", "canh-dep", "kontum", 14.347252, 108.035391,
     "Cầu treo dài gần 300 m bắc qua sông Đăk Bla, sơn màu vàng cam, nằm ngay cạnh nhà rông Kon Klor.", "Cầu treo Kon Klor"),
    ("Đèo Măng Đen", "canh-dep", "mangden", 14.564534, 108.274014,
     "Đoạn đèo trên quốc lộ 24, cửa ngõ lên Măng Đen từ phía Kon Tum.", "Đèo Măng Đen"),
    ("Cửa khẩu quốc tế Bờ Y", "canh-dep", "khac", 14.70532, 107.562192,
     "Cửa khẩu quốc tế sang Lào, điểm cuối quốc lộ 40. Khu vực Bờ Y là nơi có cột mốc ngã ba Đông Dương, giáp ranh Việt Nam – Lào – Campuchia.", "Cửa khẩu Bờ Y"),
    ("Thác Đắk Lung", "canh-dep", "khac", 14.695511, 107.865164,
     "Thác trên suối Đăk Lung ở vùng Đăk Tô, cùng khu vực với suối nước nóng Đăk Tô và các di tích Đăk Tô – Tân Cảnh.", "Thác Đắk Lung"),
    ("Thác Đắk Chè", "canh-dep", "khac", 15.223605, 107.728867,
     "Thác trên suối Đăk Chè, nằm sát đường Hồ Chí Minh; đứng trên cầu Đăk Chè là ngắm được thác. Cách trung tâm Đăk Glei hơn 20 km về phía bắc.", "Thác Đắk Chè"),
    ("Vùng núi Ngọc Linh", "canh-dep", "khac", 15.08754, 107.926369,
     "Vùng núi thuộc khối Ngọc Linh, khối núi cao nhất miền Trung, nơi sinh trưởng của sâm Ngọc Linh.", "Ngọc Linh; Khối núi Ngọc Linh"),
]


def khoa(s):
    s = unicodedata.normalize("NFD", s.lower().replace("đ", "d"))
    return re.sub(r"[^a-z0-9]+", "-", "".join(c for c in s if unicodedata.category(c) != "Mn")).strip("-")


def km(a, b):
    dx = (a["lon"] - b["lon"]) * 111.3 * math.cos(math.radians(a["lat"]))
    return math.hypot(dx, (a["lat"] - b["lat"]) * 111.3)


def main():
    tho = json.loads((GOC / "du_lieu" / "osm_loc.json").read_text(encoding="utf-8"))
    ra, da_co = [], {}
    for x in tho:
        goc_ten = unicodedata.normalize("NFC", " ".join(x["ten"].replace("​", "").split()))
        ten = DOI_TEN.get(goc_ten, goc_ten)
        if goc_ten in BO or ten in BO or len(ten) > 60:
            continue
        k = khoa(ten)
        cu = da_co.get(k)
        if cu and km(cu, x) < 0.5:   # cùng tên, cách nhau < 500 m: trùng
            for f in ("dien_thoai", "gio", "dia_chi"):
                cu[f] = cu.get(f) or x.get(f)
            continue
        bt = BIEN_TAP.get(ten)
        d = {
            "id": k if not cu else f"{k}-{x['osm'].split('/')[1]}",
            "ten": ten, "nhom": bt[0] if bt else x["nhom"], "vung": x["vung"],
            "lat": x["lat"], "lon": x["lon"],
            "mo_ta": bt[2] if bt else None, "noi_bat": bt[1] if bt else None,
            "dien_thoai": x.get("dien_thoai"), "gio": x.get("gio"), "dia_chi": x.get("dia_chi"),
            "nguon": "OpenStreetMap " + x["osm"], "da_kiem": False,
        }
        da_co.setdefault(k, d)
        ra.append(d)
    for ten, nhom, vung, lat, lon, mo_ta, bai in BO_SUNG:
        if any(d["ten"] == ten for d in ra):
            continue
        ra.append({"id": khoa(ten), "ten": ten, "nhom": nhom, "vung": vung, "lat": lat, "lon": lon, "mo_ta": mo_ta,
                   "noi_bat": None, "dien_thoai": None, "gio": None, "dia_chi": None,
                   "nguon": "Wikipedia tiếng Việt: " + bai, "da_kiem": False})
    thieu = [t for t in BIEN_TAP if not any(d["ten"] == t for d in ra)]
    ra.sort(key=lambda d: (d["noi_bat"] is None, d["noi_bat"] or 0, d["ten"]))
    dich = GOC / "app" / "assets" / "du_lieu" / "dia_diem.json"
    dich.parent.mkdir(parents=True, exist_ok=True)
    dich.write_text(json.dumps({"phien_ban": 1, "ghi_nguon": "© Những người đóng góp OpenStreetMap; Wikipedia tiếng Việt (CC BY-SA)", "dia_diem": ra}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("tong", len(ra), "| noi bat", sum(1 for d in ra if d["noi_bat"]), "| thieu bien tap:", thieu)
    for v in ("kontum", "mangden", "khac"):
        print(v, {n: sum(1 for d in ra if d["vung"] == v and d["nhom"] == n) for n in sorted({d["nhom"] for d in ra})})


if __name__ == "__main__":
    main()
