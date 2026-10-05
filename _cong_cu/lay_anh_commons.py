# Lấy ảnh cho các địa điểm từ Wikimedia Commons (chỉ ảnh có giấy phép tự do) -> app/assets/anh/<id>.jpg
# kèm thông tin ghi công -> du_lieu/anh_commons.json. Chạy SAU tao_du_lieu_app.py, rồi chạy lại tao_du_lieu_app.py
# để gắn ảnh vào dia_diem.json.
#
# Nguồn ảnh, theo thứ tự ưu tiên:
#   1. Ảnh đại diện của bài Wikipedia cùng tên / cách < 300 m (du_lieu/wikipedia_tho.json, cột "anh").
#   2. Ảnh trên Commons chụp ngay tại toạ độ địa điểm (< 150 m) - CHỈ với cảnh đẹp, di tích, tâm linh, chợ.
#      Không dò ảnh theo toạ độ cho quán ăn / chỗ ở: ảnh gần đó gần như chắc chắn là chỗ khác.
# Chỉ nhận CC0, public domain, CC BY, CC BY-SA. Bỏ ảnh NC (phi thương mại), ND, ảnh "fair use".
#
# Chạy: python lay_anh_commons.py [--lam-lai] [--toi-da N]
#   --lam-lai : tải lại cả những điểm đã có ảnh
#   --toi-da N: chỉ xử lý N điểm (để thử)
import io
import json
import math
import pathlib
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GOC = pathlib.Path(__file__).resolve().parent.parent
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "KonTumGo/0.1 (ung dung du lich ca nhan; lien he app@vangiaan.vn)"}
RONG = 800                      # chiều rộng ảnh tải về (px) - đủ nét trên điện thoại, mỗi ảnh ~60-120 KB
NHOM_DO_THEO_TOA_DO = {"canh-dep", "di-tich", "tam-linh", "cho"}
THU_MUC_ANH = GOC / "app" / "assets" / "anh"
FILE_GHI_CONG = GOC / "du_lieu" / "anh_commons.json"


def goi(**kw):
    kw.update(format="json", formatversion="2")
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(kw), headers=UA)
    for lan in range(5):
        try:
            time.sleep(1.0)     # Commons giới hạn tốc độ: đi chậm
            return json.loads(urllib.request.urlopen(req, timeout=40).read())
        except Exception as e:
            if lan == 4:
                raise
            time.sleep(25 if "429" in str(e) else 3)


def tai(url, dich):
    req = urllib.request.Request(url, headers=UA)
    for lan in range(4):
        try:
            time.sleep(1.0)
            dich.write_bytes(urllib.request.urlopen(req, timeout=60).read())
            return
        except Exception as e:
            if lan == 3:
                raise
            time.sleep(25 if "429" in str(e) else 3)


def khoa(s):
    s = unicodedata.normalize("NFD", (s or "").lower().replace("đ", "d"))
    return re.sub(r"[^a-z0-9]+", " ", "".join(c for c in s if unicodedata.category(c) != "Mn")).strip()


def km(a_lat, a_lon, b_lat, b_lon):
    dx = (a_lon - b_lon) * 111.3 * math.cos(math.radians(a_lat))
    return math.hypot(dx, (a_lat - b_lat) * 111.3)


def bo_the(html):
    """Bỏ thẻ HTML trong tên tác giả của Commons (thường là link tới trang người dùng)."""
    return " ".join(re.sub(r"<[^>]+>", " ", html or "").split())


def giay_phep_tu_do(ma):
    """Mã giấy phép (LicenseShortName của Commons) có cho phép dùng trong app không."""
    m = (ma or "").lower()
    if any(x in m for x in ("nc", "nd", "fair use", "non-free", "copyrighted")):
        return False
    return m.startswith(("cc0", "cc by", "cc-by", "public domain", "pd")) or m in ("pd", "cc0")


# Ảnh minh hoạ chung của bài Wikipedia (bản đồ, logo, cờ...) - không phải ảnh địa điểm.
TU_BO = ("map", "location", "logo", "flag", "coat_of_arms", "huy_hieu", "icon", "seal", "symbol", "locator")


def thong_tin_anh(ten_tep):
    """-> dict (url_thu_nho, tac_gia, giay_phep, trang) hoặc None nếu không dùng được."""
    if any(t in ten_tep.lower().replace(" ", "_") for t in TU_BO):
        return None
    kq = goi(action="query", titles="File:" + ten_tep, prop="imageinfo",
             iiprop="url|extmetadata|mime", iiurlwidth=str(RONG))
    trang = (kq.get("query", {}).get("pages") or [{}])[0]
    ii = (trang.get("imageinfo") or [None])[0]
    if not ii or ii.get("mime") not in ("image/jpeg", "image/png", "image/webp"):
        return None
    md = ii.get("extmetadata") or {}
    gp = (md.get("LicenseShortName") or {}).get("value", "")
    if not giay_phep_tu_do(gp):
        return None
    return {
        "url": ii.get("thumburl") or ii.get("url"),
        "tac_gia": bo_the((md.get("Artist") or {}).get("value", "")) or "Không rõ tác giả",
        "giay_phep": gp,
        "trang": ii.get("descriptionurl"),
        "tep_goc": ten_tep,
    }


def anh_theo_toa_do(lat, lon):
    """Tên tệp ảnh trên Commons chụp trong bán kính 150 m (gần nhất trước)."""
    kq = goi(action="query", list="geosearch", gscoord=f"{lat}|{lon}", gsradius="150",
             gsnamespace="6", gslimit="10")
    return [x["title"].split(":", 1)[1] for x in kq.get("query", {}).get("geosearch", [])]


def main():
    lam_lai = "--lam-lai" in sys.argv
    toi_da = int(sys.argv[sys.argv.index("--toi-da") + 1]) if "--toi-da" in sys.argv else None
    dia_diem = json.loads((GOC / "app" / "assets" / "du_lieu" / "dia_diem.json").read_text(encoding="utf-8"))["dia_diem"]
    wiki = json.loads((GOC / "du_lieu" / "wikipedia_tho.json").read_text(encoding="utf-8"))
    ghi_cong = json.loads(FILE_GHI_CONG.read_text(encoding="utf-8")) if FILE_GHI_CONG.exists() else {}
    THU_MUC_ANH.mkdir(parents=True, exist_ok=True)

    # Ưu tiên điểm nổi bật, rồi các nhóm tham quan, cuối cùng là quán ăn / chỗ ở.
    thu_tu = sorted(dia_diem, key=lambda d: (d.get("noi_bat") is None, d.get("noi_bat") or 0,
                                             d["nhom"] not in NHOM_DO_THEO_TOA_DO))
    if toi_da:
        thu_tu = thu_tu[:toi_da]
    co_moi = 0
    for d in thu_tu:
        if d["id"] in ghi_cong and not lam_lai and (THU_MUC_ANH / f"{d['id']}.jpg").exists():
            continue
        ung_vien = []
        k = khoa(d["ten"])
        for w in wiki:
            if not w.get("anh"):
                continue
            cung_ten = khoa(w["ten"]) == k
            gan = w.get("lat") and km(d["lat"], d["lon"], w["lat"], w["lon"]) < 0.3
            if cung_ten or gan:
                ung_vien.append(w["anh"])
        if d["nhom"] in NHOM_DO_THEO_TOA_DO:
            try:
                ung_vien += anh_theo_toa_do(d["lat"], d["lon"])
            except Exception as e:
                print(f"  ! {d['ten']}: lỗi tìm ảnh theo toạ độ: {e}")
        da_xet = set()
        for tep in ung_vien:
            if tep in da_xet:
                continue
            da_xet.add(tep)
            try:
                tt = thong_tin_anh(tep)
                if not tt:
                    continue
                tai(tt["url"], THU_MUC_ANH / f"{d['id']}.jpg")
            except Exception as e:
                print(f"  ! {d['ten']}: lỗi tải {tep}: {e}")
                continue
            ghi_cong[d["id"]] = {k2: v for k2, v in tt.items() if k2 != "url"}
            co_moi += 1
            print(f"+ {d['ten']}: {tep} ({tt['giay_phep']}, {tt['tac_gia'][:40]})")
            break
        FILE_GHI_CONG.write_text(json.dumps(ghi_cong, ensure_ascii=False, indent=1), encoding="utf-8")

    tong = sum(f.stat().st_size for f in THU_MUC_ANH.glob("*.jpg"))
    print(f"\nanh moi: {co_moi} | tong co anh: {len(ghi_cong)}/{len(dia_diem)} dia diem | "
          f"dung luong anh: {tong / 1024 / 1024:.1f} MB")
    print("Tiep theo: python tao_du_lieu_app.py  (gan anh vao dia_diem.json)")


if __name__ == "__main__":
    main()
