# Kiểm tra máy chủ ảnh (không cần mạng, Google được giả lập). Chạy: python -m pytest -q test_app.py
import base64
import io
import json
import os
import tempfile

import pytest
from PIL import Image

_tam = tempfile.mkdtemp()
_ch = os.path.join(_tam, "cau_hinh.json")
with open(_ch, "w", encoding="utf-8") as f:
    json.dump({"thu_muc_du_lieu": os.path.join(_tam, "du_lieu"), "mat_khau_quan_tri": "mk-thu",
               "google_client_ids": ["web-id"]}, f)
os.environ["KTG_CAU_HINH"] = _ch

import app as may_chu  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

may_chu.kiem_google = lambda t: {"sub": t, "email": f"{t}@vd.com", "name": f"Người {t}", "aud": "web-id"}
kh = TestClient(may_chu.app)
QT = {"Authorization": "Basic " + base64.b64encode(b"x:mk-thu").decode()}


def dang_nhap(sub, dong_y=True):
    tok = kh.post("/api/dang-nhap/google", json={"id_token": sub}).json()["token"]
    h = {"Authorization": f"Bearer {tok}"}
    if dong_y:
        assert kh.post("/api/dong-y", json={"phien_ban": may_chu.PHIEN_BAN_DIEU_KHOAN}, headers=h).status_code == 200
    return h


def anh_jpeg(rong=2000, cao=1500, exif=True):
    b = io.BytesIO()
    im = Image.new("RGB", (rong, cao), (30, 80, 60))
    kw = {}
    if exif:
        e = Image.Exif()
        e[0x010F] = "MayChupThu"  # Make
        kw["exif"] = e
    im.save(b, "JPEG", **kw)
    return b.getvalue()


def gui(h, dia_diem="nha-tho-go-kon-tum", du_lieu=None):
    return kh.post("/api/anh", data={"dia_diem": dia_diem},
                   files={"tep": ("a.jpg", du_lieu or anh_jpeg(), "image/jpeg")}, headers=h)


def duyet(anh_id):
    trang = kh.get("/quan-tri", headers=QT).text
    assert anh_id in trang
    r = kh.post("/quan-tri/duyet", data={"anh_id": anh_id, "ma": may_chu.MA_CHONG_GIA_MAO}, headers=QT,
                follow_redirects=False)
    assert r.status_code == 303


def test_luong_day_du():
    a = dang_nhap("a")
    r = gui(a)
    assert r.status_code == 200, r.text
    anh = r.json()
    assert anh["cho_duyet"] and anh["cua_toi"] and anh["rong"] == 1600
    # Ảnh lưu lại không còn EXIF.
    luu = Image.open(io.BytesIO(kh.get(anh["url"]).content))
    assert not luu.getexif()
    # Người khác chưa thấy ảnh chờ duyệt; chính mình thấy.
    b = dang_nhap("b")
    assert kh.get("/api/anh?dia_diem=nha-tho-go-kon-tum", headers=b).json() == []
    assert kh.get("/api/anh?dia_diem=nha-tho-go-kon-tum").json() == []
    assert len(kh.get("/api/anh?dia_diem=nha-tho-go-kon-tum", headers=a).json()) == 1
    duyet(anh["id"])
    ds = kh.get("/api/anh?dia_diem=nha-tho-go-kon-tum").json()
    assert len(ds) == 1 and ds[0]["nguoi_dang"] == "Người a" and not ds[0]["cho_duyet"]
    # Chặn: b không còn thấy ảnh của a.
    assert kh.post(f"/api/chan/{anh['nguoi_dang_id']}", headers=b).status_code == 200
    assert kh.get("/api/anh?dia_diem=nha-tho-go-kon-tum", headers=b).json() == []
    # Xoá tài khoản a -> ảnh + tệp biến mất.
    assert kh.delete("/api/tai-khoan", headers=a).json()["so_anh_da_xoa"] == 1
    assert kh.get(anh["url"]).status_code == 404
    assert kh.get("/api/toi", headers=a).status_code == 401


def test_bat_buoc_dong_y_va_kiem_tep():
    c = dang_nhap("c", dong_y=False)
    assert gui(c).status_code == 403
    c = dang_nhap("c")
    assert gui(c, du_lieu=b"khong phai anh").status_code == 400
    assert gui(c, du_lieu=anh_jpeg(200, 200)).status_code == 400
    assert gui(c, dia_diem="../../etc").status_code == 400
    assert kh.post("/api/anh", data={"dia_diem": "x"}, files={"tep": ("a.jpg", anh_jpeg(), "image/jpeg")}
                   ).status_code == 401


def test_bao_cao_du_so_thi_tu_an():
    d = dang_nhap("d")
    anh = gui(d, "thac-pa-sy").json()
    duyet(anh["id"])
    for s in ("e", "f", "g"):
        assert kh.post(f"/api/anh/{anh['id']}/bao-cao", json={"ly_do": "spam"}, headers=dang_nhap(s)).status_code == 200
    assert kh.get("/api/anh?dia_diem=thac-pa-sy").json() == []
    assert anh["id"] in kh.get("/quan-tri?xem=bao_cao", headers=QT).text


def test_khoa_nguoi_dung():
    h = dang_nhap("xau")
    anh = gui(h, "ho-dak-ke").json()
    kh.post("/quan-tri/khoa", data={"anh_id": anh["id"], "ma": may_chu.MA_CHONG_GIA_MAO}, headers=QT)
    assert kh.get("/api/toi", headers=h).status_code == 401
    assert kh.post("/api/dang-nhap/google", json={"id_token": "xau"}).status_code == 403


def test_quan_tri_can_mat_khau_va_ma():
    assert kh.get("/quan-tri").status_code == 401
    sai = {"Authorization": "Basic " + base64.b64encode(b"x:sai").decode()}
    assert kh.get("/quan-tri", headers=sai).status_code == 401
    r = kh.post("/quan-tri/xoa", data={"anh_id": "0" * 32, "ma": "sai"}, headers=QT)
    assert r.status_code == 400


@pytest.mark.parametrize("duong_dan", ["/tep/lon/..%2Fanh_cong_dong.db", "/tep/abc/x.jpg", "/tep/nho/zz.jpg"])
def test_tep_khong_cho_di_ra_ngoai(duong_dan):
    assert kh.get(duong_dan).status_code == 404
