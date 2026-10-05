# Máy chủ ảnh cộng đồng Kon Tum Go: du khách gửi ảnh địa điểm, quản trị viên duyệt rồi mới hiện trong app.
# Chạy: uvicorn app:app --host 127.0.0.1 --port 8100   (Caddy đứng trước lo HTTPS - xem HUONG_DAN.md)
#
# Theo chính sách nội dung người dùng (UGC) của Google Play / App Store:
#   - đăng nhập Google + đồng ý điều khoản trước khi gửi ảnh
#   - ảnh mới ở trạng thái chờ duyệt; bị >= SO_BAO_CAO_TU_AN người báo cáo -> tự ẩn chờ xem lại
#   - người dùng chặn được người khác, xoá được ảnh của mình và xoá cả tài khoản
import base64
import hashlib
import hmac
import html
import io
import json
import urllib.parse
import os
import pathlib
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from PIL import Image, ImageOps

GOC = pathlib.Path(__file__).resolve().parent
CAU_HINH = json.loads(pathlib.Path(os.environ.get("KTG_CAU_HINH", GOC / "cau_hinh.json")).read_text(encoding="utf-8"))
THU_MUC = pathlib.Path(CAU_HINH["thu_muc_du_lieu"])
CSDL = THU_MUC / "anh_cong_dong.db"
GOOGLE_CLIENT_IDS = CAU_HINH.get("google_client_ids", [])
MAT_KHAU_QT = CAU_HINH["mat_khau_quan_tri"]
PHIEN_BAN_DIEU_KHOAN = "2026-10"
TOI_DA_BYTE = 15 * 1024 * 1024        # tệp gửi lên tối đa 15 MB
TOI_DA_MOI_NGAY = 30                  # mỗi người tối đa 30 ảnh / 24 giờ
SO_BAO_CAO_TU_AN = 3
CO_LON, CO_NHO = 1600, 480            # cạnh dài ảnh lớn / ảnh thu nhỏ (px)
MA_DIA_DIEM = re.compile(r"^[a-z0-9-]{1,80}$")
MA_ANH = re.compile(r"^[a-f0-9]{32}$")
Image.MAX_IMAGE_PIXELS = 60_000_000   # chặn "bom ảnh" (ảnh khai kích thước khổng lồ)

for con in ("lon", "nho"):
    (THU_MUC / con).mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Kon Tum Go - ảnh cộng đồng", docs_url=None, redoc_url=None, openapi_url=None)


@contextmanager
def csdl():
    c = sqlite3.connect(CSDL, timeout=20)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA foreign_keys = ON")
    try:
        yield c
        c.commit()
    finally:
        c.close()


with csdl() as c:
    c.executescript("""
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS nguoi_dung (
        id INTEGER PRIMARY KEY, google_sub TEXT UNIQUE NOT NULL, email TEXT, ten TEXT NOT NULL,
        dong_y TEXT, bi_khoa INTEGER NOT NULL DEFAULT 0, ngay_tao INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS phien (
        ma_bam TEXT PRIMARY KEY, nguoi_dung_id INTEGER NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,
        ngay_tao INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS anh (
        id TEXT PRIMARY KEY, dia_diem TEXT NOT NULL,
        nguoi_dung_id INTEGER NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,
        trang_thai TEXT NOT NULL DEFAULT 'cho', rong INTEGER, cao INTEGER, ngay_tao INTEGER NOT NULL, ngay_duyet INTEGER);
    CREATE INDEX IF NOT EXISTS anh_dia_diem ON anh(dia_diem, trang_thai);
    CREATE TABLE IF NOT EXISTS bao_cao (
        anh_id TEXT NOT NULL REFERENCES anh(id) ON DELETE CASCADE,
        nguoi_dung_id INTEGER NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,
        ly_do TEXT, ngay INTEGER NOT NULL, da_xu_ly INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (anh_id, nguoi_dung_id));
    CREATE TABLE IF NOT EXISTS chan (
        nguoi_dung_id INTEGER NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,
        bi_chan_id INTEGER NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,
        PRIMARY KEY (nguoi_dung_id, bi_chan_id));
    """)


def bam(token):
    return hashlib.sha256(token.encode()).hexdigest()


def xoa_tep_anh(anh_id):
    for con in ("lon", "nho"):
        (THU_MUC / con / f"{anh_id}.jpg").unlink(missing_ok=True)


# ---------------------------------------------------------------- xác thực

def kiem_google(id_token):
    """Kiểm chữ ký ID token của Google -> dict thông tin người dùng. Tách hàm để test thay thế được."""
    from google.auth.transport import requests as g_requests
    from google.oauth2 import id_token as g_id_token
    tt = g_id_token.verify_oauth2_token(id_token, g_requests.Request())
    if tt.get("aud") not in GOOGLE_CLIENT_IDS:
        raise ValueError("sai client id")
    return tt


def nguoi_dung_tuy_chon(authorization: str | None = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        return None
    with csdl() as c:
        nd = c.execute("SELECT n.* FROM phien p JOIN nguoi_dung n ON n.id = p.nguoi_dung_id WHERE p.ma_bam = ?",
                       (bam(authorization[7:]),)).fetchone()
    return dict(nd) if nd else None


def nguoi_dung_bat_buoc(nd=Depends(nguoi_dung_tuy_chon)):
    if not nd:
        raise HTTPException(401, "Phiên đăng nhập đã hết, vui lòng đăng nhập lại.")
    if nd["bi_khoa"]:
        raise HTTPException(403, "Tài khoản đã bị khoá do vi phạm điều khoản.")
    return nd


def thong_tin(nd):
    return {"id": nd["id"], "ten": nd["ten"], "da_dong_y": nd["dong_y"] == PHIEN_BAN_DIEU_KHOAN}


@app.post("/api/dang-nhap/google")
def dang_nhap_google(body: dict):
    try:
        tt = kiem_google(str(body.get("id_token", "")))
    except Exception:
        raise HTTPException(401, "Không xác thực được tài khoản Google.")
    ten = (tt.get("name") or tt.get("email", "").split("@")[0] or "Du khách")[:60]
    with csdl() as c:
        c.execute("INSERT INTO nguoi_dung (google_sub, email, ten, ngay_tao) VALUES (?, ?, ?, ?) "
                  "ON CONFLICT(google_sub) DO UPDATE SET email = excluded.email",
                  (tt["sub"], tt.get("email"), ten, int(time.time())))
        nd = dict(c.execute("SELECT * FROM nguoi_dung WHERE google_sub = ?", (tt["sub"],)).fetchone())
        if nd["bi_khoa"]:
            raise HTTPException(403, "Tài khoản đã bị khoá do vi phạm điều khoản.")
        token = secrets.token_urlsafe(32)
        c.execute("INSERT INTO phien VALUES (?, ?, ?)", (bam(token), nd["id"], int(time.time())))
    return {"token": token, "nguoi_dung": thong_tin(nd)}


@app.post("/api/dang-xuat")
def dang_xuat(authorization: str | None = Header(None)):
    if authorization and authorization.startswith("Bearer "):
        with csdl() as c:
            c.execute("DELETE FROM phien WHERE ma_bam = ?", (bam(authorization[7:]),))
    return {"ok": True}


@app.get("/api/toi")
def toi(nd=Depends(nguoi_dung_bat_buoc)):
    return thong_tin(nd)


@app.post("/api/dong-y")
def dong_y(body: dict, nd=Depends(nguoi_dung_bat_buoc)):
    if body.get("phien_ban") != PHIEN_BAN_DIEU_KHOAN:
        raise HTTPException(400, "Điều khoản đã thay đổi, vui lòng cập nhật app.")
    with csdl() as c:
        c.execute("UPDATE nguoi_dung SET dong_y = ? WHERE id = ?", (PHIEN_BAN_DIEU_KHOAN, nd["id"]))
    return {"ok": True}


@app.delete("/api/tai-khoan")
def xoa_tai_khoan(nd=Depends(nguoi_dung_tuy_chon)):
    """Xoá hẳn tài khoản + toàn bộ ảnh đã gửi (yêu cầu bắt buộc của Google Play / App Store)."""
    if not nd:
        raise HTTPException(401, "Phiên đăng nhập đã hết, vui lòng đăng nhập lại.")
    with csdl() as c:
        ds = [r["id"] for r in c.execute("SELECT id FROM anh WHERE nguoi_dung_id = ?", (nd["id"],))]
        c.execute("DELETE FROM nguoi_dung WHERE id = ?", (nd["id"],))
    for a in ds:
        xoa_tep_anh(a)
    return {"ok": True, "so_anh_da_xoa": len(ds)}


# ---------------------------------------------------------------- ảnh

def dong_anh(r, nd):
    return {"id": r["id"], "dia_diem": r["dia_diem"], "nguoi_dang": r["ten"], "nguoi_dang_id": r["nguoi_dung_id"],
            "rong": r["rong"], "cao": r["cao"], "ngay": r["ngay_tao"],
            "cho_duyet": r["trang_thai"] != "duyet", "cua_toi": bool(nd) and r["nguoi_dung_id"] == nd["id"],
            "url": f"/tep/lon/{r['id']}.jpg", "url_nho": f"/tep/nho/{r['id']}.jpg"}


@app.get("/api/anh")
def danh_sach_anh(dia_diem: str, nd=Depends(nguoi_dung_tuy_chon)):
    """Ảnh đã duyệt của 1 địa điểm (bỏ ảnh của người mình đã chặn) + ảnh đang chờ duyệt của chính mình."""
    if not MA_DIA_DIEM.match(dia_diem):
        raise HTTPException(400, "Mã địa điểm không hợp lệ.")
    toi_id = nd["id"] if nd else -1
    with csdl() as c:
        ds = c.execute("""
            SELECT a.*, n.ten FROM anh a JOIN nguoi_dung n ON n.id = a.nguoi_dung_id
            WHERE a.dia_diem = ? AND n.bi_khoa = 0
              AND (a.trang_thai = 'duyet' OR (a.trang_thai = 'cho' AND a.nguoi_dung_id = ?))
              AND a.nguoi_dung_id NOT IN (SELECT bi_chan_id FROM chan WHERE nguoi_dung_id = ?)
            ORDER BY a.ngay_tao DESC LIMIT 200""", (dia_diem, toi_id, toi_id)).fetchall()
    return [dong_anh(r, nd) for r in ds]


@app.post("/api/anh")
async def gui_anh(dia_diem: str = Form(...), tep: UploadFile = File(...), nd=Depends(nguoi_dung_bat_buoc)):
    if nd["dong_y"] != PHIEN_BAN_DIEU_KHOAN:
        raise HTTPException(403, "Bạn cần đồng ý điều khoản trước khi gửi ảnh.")
    if not MA_DIA_DIEM.match(dia_diem):
        raise HTTPException(400, "Mã địa điểm không hợp lệ.")
    with csdl() as c:
        so = c.execute("SELECT COUNT(*) FROM anh WHERE nguoi_dung_id = ? AND ngay_tao > ?",
                       (nd["id"], int(time.time()) - 86400)).fetchone()[0]
    if so >= TOI_DA_MOI_NGAY:
        raise HTTPException(429, f"Mỗi ngày chỉ gửi được tối đa {TOI_DA_MOI_NGAY} ảnh.")
    du_lieu = await tep.read(TOI_DA_BYTE + 1)
    if len(du_lieu) > TOI_DA_BYTE:
        raise HTTPException(413, "Ảnh quá lớn (tối đa 15 MB).")
    # Mở lại ảnh bằng Pillow và LƯU MỚI: chỉ nhận đúng ảnh JPEG/PNG/WEBP, đồng thời bỏ hết EXIF (toạ độ GPS, máy chụp...).
    try:
        anh = Image.open(io.BytesIO(du_lieu))
        if anh.format not in ("JPEG", "PNG", "WEBP"):
            raise ValueError(anh.format)
        anh = ImageOps.exif_transpose(anh).convert("RGB")
    except Exception:
        raise HTTPException(400, "Tệp gửi lên không phải ảnh JPEG, PNG hoặc WEBP.")
    if min(anh.size) < 300:
        raise HTTPException(400, "Ảnh quá nhỏ (cạnh ngắn cần từ 300 px).")
    anh_id = secrets.token_hex(16)
    lon = anh.copy()
    lon.thumbnail((CO_LON, CO_LON), Image.LANCZOS)
    lon.save(THU_MUC / "lon" / f"{anh_id}.jpg", "JPEG", quality=84, optimize=True, progressive=True)
    nho = anh.copy()
    nho.thumbnail((CO_NHO, CO_NHO), Image.LANCZOS)
    nho.save(THU_MUC / "nho" / f"{anh_id}.jpg", "JPEG", quality=80, optimize=True)
    with csdl() as c:
        c.execute("INSERT INTO anh (id, dia_diem, nguoi_dung_id, rong, cao, ngay_tao) VALUES (?, ?, ?, ?, ?, ?)",
                  (anh_id, dia_diem, nd["id"], lon.width, lon.height, int(time.time())))
        r = c.execute("SELECT a.*, n.ten FROM anh a JOIN nguoi_dung n ON n.id = a.nguoi_dung_id WHERE a.id = ?",
                      (anh_id,)).fetchone()
    return dong_anh(r, nd)


@app.delete("/api/anh/{anh_id}")
def xoa_anh(anh_id: str, nd=Depends(nguoi_dung_tuy_chon)):
    if not nd:
        raise HTTPException(401, "Phiên đăng nhập đã hết, vui lòng đăng nhập lại.")
    with csdl() as c:
        n = c.execute("DELETE FROM anh WHERE id = ? AND nguoi_dung_id = ?", (anh_id, nd["id"])).rowcount
    if not n:
        raise HTTPException(404, "Không tìm thấy ảnh.")
    xoa_tep_anh(anh_id)
    return {"ok": True}


@app.post("/api/anh/{anh_id}/bao-cao")
def bao_cao(anh_id: str, body: dict, nd=Depends(nguoi_dung_bat_buoc)):
    ly_do = str(body.get("ly_do", ""))[:300]
    with csdl() as c:
        if not c.execute("SELECT 1 FROM anh WHERE id = ?", (anh_id,)).fetchone():
            raise HTTPException(404, "Không tìm thấy ảnh.")
        c.execute("INSERT OR REPLACE INTO bao_cao (anh_id, nguoi_dung_id, ly_do, ngay) VALUES (?, ?, ?, ?)",
                  (anh_id, nd["id"], ly_do, int(time.time())))
        so = c.execute("SELECT COUNT(*) FROM bao_cao WHERE anh_id = ? AND da_xu_ly = 0", (anh_id,)).fetchone()[0]
        if so >= SO_BAO_CAO_TU_AN:
            c.execute("UPDATE anh SET trang_thai = 'cho' WHERE id = ?", (anh_id,))
    return {"ok": True}


@app.post("/api/chan/{nguoi_dung_id}")
def chan_nguoi_dung(nguoi_dung_id: int, nd=Depends(nguoi_dung_bat_buoc)):
    if nguoi_dung_id == nd["id"]:
        raise HTTPException(400, "Không thể tự chặn mình.")
    with csdl() as c:
        if not c.execute("SELECT 1 FROM nguoi_dung WHERE id = ?", (nguoi_dung_id,)).fetchone():
            raise HTTPException(404, "Không tìm thấy người dùng.")
        c.execute("INSERT OR IGNORE INTO chan VALUES (?, ?)", (nd["id"], nguoi_dung_id))
    return {"ok": True}


@app.get("/tep/{co}/{ten}")
def tep_anh(co: str, ten: str):
    # Tên ảnh là 32 ký tự ngẫu nhiên (không đoán được) nên ảnh chờ duyệt vẫn mở được cho chính người gửi xem.
    if co not in ("lon", "nho") or not ten.endswith(".jpg") or not MA_ANH.match(ten[:-4]):
        raise HTTPException(404)
    p = THU_MUC / co / ten
    if not p.exists():
        raise HTTPException(404)
    return FileResponse(p, media_type="image/jpeg", headers={"Cache-Control": "public, max-age=86400"})


@app.get("/api/suc-khoe")
def suc_khoe():
    return {"ok": True}


# ---------------------------------------------------------------- trang quản trị (duyệt ảnh, xử lý báo cáo)

def quan_tri(authorization: str | None = Header(None)):
    """HTTP Basic: tên gì cũng được, mật khẩu = mat_khau_quan_tri trong cau_hinh.json."""
    try:
        mk = base64.b64decode((authorization or "")[6:]).decode().split(":", 1)[1]
    except Exception:
        mk = ""
    if not (authorization or "").startswith("Basic ") or not hmac.compare_digest(mk, MAT_KHAU_QT):
        time.sleep(1)  # làm chậm dò mật khẩu
        raise HTTPException(401, "Cần đăng nhập", headers={"WWW-Authenticate": 'Basic realm="KonTumGo"'})
    return True


MA_CHONG_GIA_MAO = hmac.new(MAT_KHAU_QT.encode(), b"csrf-ktg", hashlib.sha256).hexdigest()[:32]

TRANG = """<!doctype html><html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Duyệt ảnh · Kon Tum Go</title>
<style>
:root{--nen:#f4f1ea;--the:#fffdf8;--chu:#1c2620;--phu:#66706a;--vien:#e2ddd0;--thong:#1f4d3a;--bazan:#b5472a}
body{margin:0;background:var(--nen);color:var(--chu);font:15px/1.45 system-ui,sans-serif;padding:16px}
h1{font-size:20px;margin:0 0 4px}nav{display:flex;gap:8px;margin:12px 0 18px;flex-wrap:wrap}
nav a{padding:7px 12px;border-radius:999px;border:1px solid var(--vien);background:var(--the);color:var(--chu);text-decoration:none}
nav a.chon{background:var(--thong);color:#fff;border-color:var(--thong)}
.luoi{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
.the{background:var(--the);border:1px solid var(--vien);border-radius:14px;overflow:hidden}
.the img{width:100%;aspect-ratio:4/3;object-fit:cover;display:block;background:#ddd}
.the .tt{padding:10px 12px;font-size:13px;color:var(--phu)}.the b{color:var(--chu)}
.nut{display:flex;gap:6px;padding:0 12px 12px;flex-wrap:wrap}
button{font:inherit;padding:7px 12px;border-radius:9px;border:1px solid var(--vien);background:var(--the);cursor:pointer}
button.ok{background:var(--thong);color:#fff;border-color:var(--thong)}button.xoa{color:var(--bazan);border-color:var(--bazan)}
.rong{color:var(--phu);padding:30px 0}
</style></head><body><h1>Ảnh cộng đồng Kon Tum Go</h1><nav>{nav}</nav>{noi_dung}</body></html>"""


def _nut(hanh_dong, anh_id, nhan, lop=""):
    return (f'<form method="post" action="/quan-tri/{hanh_dong}" style="display:inline">'
            f'<input type="hidden" name="anh_id" value="{anh_id}"><input type="hidden" name="ma" value="{MA_CHONG_GIA_MAO}">'
            f'<button class="{lop}">{nhan}</button></form>')


@app.get("/quan-tri", response_class=HTMLResponse)
def trang_quan_tri(xem: str = "cho", _=Depends(quan_tri)):
    with csdl() as c:
        dem = {k: c.execute(q).fetchone()[0] for k, q in {
            "cho": "SELECT COUNT(*) FROM anh WHERE trang_thai = 'cho'",
            "bao_cao": "SELECT COUNT(DISTINCT anh_id) FROM bao_cao WHERE da_xu_ly = 0",
            "duyet": "SELECT COUNT(*) FROM anh WHERE trang_thai = 'duyet'"}.items()}
        if xem == "bao_cao":
            ds = c.execute("""SELECT a.*, n.ten, n.email, COUNT(b.anh_id) so_bc, GROUP_CONCAT(b.ly_do, ' | ') ly_do
                FROM bao_cao b JOIN anh a ON a.id = b.anh_id JOIN nguoi_dung n ON n.id = a.nguoi_dung_id
                WHERE b.da_xu_ly = 0 GROUP BY a.id ORDER BY so_bc DESC LIMIT 100""").fetchall()
        else:
            tt = "duyet" if xem == "duyet" else "cho"
            ds = c.execute("""SELECT a.*, n.ten, n.email, 0 so_bc, '' ly_do FROM anh a
                JOIN nguoi_dung n ON n.id = a.nguoi_dung_id WHERE a.trang_thai = ? AND n.bi_khoa = 0
                ORDER BY a.ngay_tao DESC LIMIT 100""", (tt,)).fetchall()
    nav = "".join(f'<a href="/quan-tri?xem={k}" class="{"chon" if k == xem else ""}">{t} ({dem[k]})</a>'
                  for k, t in (("cho", "Chờ duyệt"), ("bao_cao", "Bị báo cáo"), ("duyet", "Đã duyệt")))
    the = []
    for r in ds:
        nut = []
        if r["trang_thai"] != "duyet":
            nut.append(_nut("duyet", r["id"], "Duyệt", "ok"))
        if xem == "bao_cao":
            nut.append(_nut("bo-qua-bao-cao", r["id"], "Ảnh không sao"))
        nut += [_nut("xoa", r["id"], "Xoá ảnh", "xoa"), _nut("khoa", r["id"], "Khoá người gửi", "xoa")]
        bc = f'<br>⚠ {r["so_bc"]} báo cáo: {html.escape(r["ly_do"] or "")}' if r["so_bc"] else ""
        the.append(f'<div class="the"><a href="/tep/lon/{r["id"]}.jpg" target="_blank"><img loading="lazy" '
                   f'src="/tep/nho/{r["id"]}.jpg" alt=""></a><div class="tt"><b>{html.escape(r["dia_diem"])}</b><br>'
                   f'{html.escape(r["ten"])} · {html.escape(r["email"] or "")}<br>'
                   f'{time.strftime("%d/%m/%Y %H:%M", time.localtime(r["ngay_tao"]))}{bc}</div>'
                   f'<div class="nut">{"".join(nut)}</div></div>')
    noi_dung = f'<div class="luoi">{"".join(the)}</div>' if the else '<p class="rong">Không có ảnh nào.</p>'
    return TRANG.replace("{nav}", nav).replace("{noi_dung}", noi_dung)


@app.post("/quan-tri/{hanh_dong}")
def xu_ly_quan_tri(hanh_dong: str, request: Request, anh_id: str = Form(...), ma: str = Form(...),
                   _=Depends(quan_tri)):
    if not hmac.compare_digest(ma, MA_CHONG_GIA_MAO) or not MA_ANH.match(anh_id):
        raise HTTPException(400)
    with csdl() as c:
        if hanh_dong == "duyet":
            c.execute("UPDATE anh SET trang_thai = 'duyet', ngay_duyet = ? WHERE id = ?", (int(time.time()), anh_id))
            c.execute("UPDATE bao_cao SET da_xu_ly = 1 WHERE anh_id = ?", (anh_id,))
        elif hanh_dong == "bo-qua-bao-cao":
            c.execute("UPDATE bao_cao SET da_xu_ly = 1 WHERE anh_id = ?", (anh_id,))
        elif hanh_dong == "xoa":
            c.execute("DELETE FROM anh WHERE id = ?", (anh_id,))
            xoa_tep_anh(anh_id)
        elif hanh_dong == "khoa":
            r = c.execute("SELECT nguoi_dung_id FROM anh WHERE id = ?", (anh_id,)).fetchone()
            if r:
                ds = [x["id"] for x in c.execute("SELECT id FROM anh WHERE nguoi_dung_id = ?", (r[0],))]
                c.execute("UPDATE nguoi_dung SET bi_khoa = 1 WHERE id = ?", (r[0],))
                c.execute("DELETE FROM phien WHERE nguoi_dung_id = ?", (r[0],))
                c.execute("DELETE FROM anh WHERE nguoi_dung_id = ?", (r[0],))
                for a in ds:
                    xoa_tep_anh(a)
        else:
            raise HTTPException(404)
    # Quay lại đúng tab đang xem (chỉ lấy đường dẫn trong trang, không theo liên kết ngoài).
    u = urllib.parse.urlsplit(request.headers.get("referer", ""))
    return RedirectResponse(u.path + ("?" + u.query if u.query else "") if u.path == "/quan-tri" else "/quan-tri",
                            status_code=303)


DIEU_KHOAN = [
    "Bạn chỉ gửi ảnh do chính mình chụp, hoặc đã được người chụp cho phép.",
    "Không gửi ảnh khoả thân, bạo lực, thù ghét, quảng cáo, ảnh chụp màn hình, hay ảnh lộ rõ mặt / thông tin cá nhân "
    "của người khác khi chưa được đồng ý.",
    "Ảnh được kiểm duyệt trước khi hiện. Ảnh vi phạm bị xoá; tài khoản vi phạm nhiều lần bị khoá.",
    "Bạn đồng ý cho Kon Tum Go hiển thị ảnh trong ứng dụng, kèm tên hiển thị tài khoản Google của bạn.",
    "Ứng dụng tự xoá thông tin vị trí GPS và thông tin máy chụp trong ảnh trước khi lưu.",
    "Bạn có thể xoá từng ảnh hoặc xoá hẳn tài khoản (kèm toàn bộ ảnh) ngay trong ứng dụng.",
    "Thấy ảnh không phù hợp: bấm vào ảnh rồi chọn Báo cáo, hoặc Chặn người đăng.",
]


@app.get("/dieu-khoan", response_class=HTMLResponse)
def trang_dieu_khoan():
    """Trang công khai (đưa link này vào mục chính sách của Google Play / App Store)."""
    ds = "".join(f"<li>{html.escape(x)}</li>" for x in DIEU_KHOAN)
    return TRANG.replace("<title>Duyệt ảnh", "<title>Điều khoản ảnh").replace("<h1>Ảnh cộng đồng Kon Tum Go</h1>", (
        f"<h1>Điều khoản gửi ảnh – Kon Tum Go</h1><p>Phiên bản {PHIEN_BAN_DIEU_KHOAN}</p>")).replace(
        "<nav>{nav}</nav>", "").replace("{noi_dung}", f'<ol style="max-width:65ch">{ds}</ol>')


@app.get("/api/dieu-khoan")
def api_dieu_khoan():
    return {"phien_ban": PHIEN_BAN_DIEU_KHOAN, "noi_dung": DIEU_KHOAN}


@app.get("/", response_class=HTMLResponse)
def trang_dau():
    return '<p>Kon Tum Go - máy chủ ảnh cộng đồng. <a href="/dieu-khoan">Điều khoản gửi ảnh</a></p>'
