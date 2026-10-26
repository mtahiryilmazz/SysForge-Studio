import os
import time
import datetime
import core.startup_check
from core.logger import get_logger

logger = get_logger("web_server")
from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from database.connection import DatabaseConnection
from database.logger import write_log
from modules.dashboard import DashboardModule
from modules.tickets import TicketsModule
from modules.inventory import InventoryModule

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY') or os.urandom(24)

def get_db():
    db = DatabaseConnection()
    db.connect()
    return db

@app.before_request
def update_last_active():
    if 'user_id' in session and request.endpoint and request.endpoint != 'static':
        db = get_db()
        db.execute_query("UPDATE users SET last_active=? WHERE id=?",
                         (str(int(time.time())) + "|web", session['user_id']))
        db.close()

# ── Auth ──────────────────────────────────────────────────────────────────────
@app.route('/')
def root():
    return redirect(url_for('login') if 'user_id' not in session else url_for('dashboard'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        u = request.form.get('username')
        p = request.form.get('password')
        db = get_db()
        user = db.fetch_data("SELECT * FROM users WHERE username=? COLLATE NOCASE AND password=?", (u, p))
        
        if user:
            ud = dict(user[0])
            session.update({
                'user_id': ud['id'], 'username': ud['username'],
                'role': ud['role'], 'permissions': ud.get('permissions', '*')
            })
            try:
                write_log(db, u, "GİRİŞ", f"Web portal girişi başarılı: {u}")
            except: pass
            
            # ── ACİL DURUM KURTARMA HESABI ALGILANDI ──────────────────────────
            if ud['username'] == 'Recovery':
                session['recovery_mode'] = True
                try:
                    write_log(db, u, "KRİTİK_UYARI",
                        "⚠️ ACİL DURUM KURTARMA HESABI (Recovery) sisteme giriş yaptı! "
                        "Yetkisiz erişim şüphesi varsa hesabı derhal kilitleyin.")
                except: pass
            else:
                session.pop('recovery_mode', None)
            # ───────────────────────────────────────────────────────────────────
            
            db.close()
            return redirect(url_for('dashboard'))
            
        try:
            write_log(db, u, "GİRİŞ_HATA", f"Web portal hatalı giriş: {u}")
        except: pass
        db.close()
        
        flash("Geçersiz kullanıcı adı veya şifre", "danger")
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/auto_login')
def auto_login():
    import time
    import hashlib
    u = request.args.get('u')
    t = request.args.get('t')
    token = request.args.get('token')
    
    if not u or not t or not token:
        return redirect(url_for('login'))
        
    try:
        # Token 30 saniye geçerli olsun
        if int(time.time()) - int(t) > 30:
            return redirect(url_for('login'))
    except:
        return redirect(url_for('login'))
        
    db = get_db()
    user = db.fetch_data("SELECT * FROM users WHERE username = ?", (u,))
    db.close()
    
    if user:
        ud = dict(user[0])
        p = ud['password']
        expected = hashlib.sha256(f"{u}:{p}:{t}:IT_TECH_SECRET".encode()).hexdigest()
        if expected == token:
            session.update({
                'user_id': ud['id'], 'username': ud['username'],
                'role': ud['role'], 'permissions': ud.get('permissions', '*')
            })
            return redirect(url_for('dashboard'))
            
    return redirect(url_for('login'))

# ── Dashboard ─────────────────────────────────────────────────────────────────
@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session: return redirect(url_for('login'))
    perms = session.get('permissions', '')
    if '*' not in perms and 'dashboard' not in perms:
        flash("Dashboard modülüne erişim yetkiniz yok.", "danger")
        return redirect(url_for('profile'))
    db = get_db()
    stats = DashboardModule(db).get_statistics()
    db.close()
    return render_template('index.html', stats=stats)

# ── Müdürlük / Birim ──────────────────────────────────────────────────────────
@app.route('/departments', methods=['GET', 'POST'])
def departments():
    if 'user_id' not in session: return redirect(url_for('login'))
    # Sadece Admin
    if session.get('role') != 'Admin':
        flash("Müdürlük/Birim yönetimi yalnızca Admin'e açıktır.", "danger")
        return redirect(url_for('dashboard'))
    db = get_db()

    if request.method == 'POST':
        action = request.form.get('action')

        if action == 'add_dept':
            name = request.form.get('dept_name', '').strip()
            if name:
                db.execute_query("INSERT OR IGNORE INTO departments (name) VALUES (?)", (name,))
                flash(f"'{name}' müdürlüğü eklendi.", "success")

        elif action == 'del_dept':
            did = request.form.get('dept_id')
            if did:
                db.execute_query("DELETE FROM units WHERE department_id=?", (did,))
                db.execute_query("DELETE FROM departments WHERE id=?", (did,))
                flash("Müdürlük ve bağlı birimler silindi.", "success")
                write_log(db, session.get('username','?'), "SİL", f"Müdürlük silindi (ID:{did})")

        elif action == 'add_unit':
            dept_id = request.form.get('dept_id')
            name    = request.form.get('unit_name', '').strip()
            if dept_id and name:
                db.execute_query("INSERT INTO units (department_id, name) VALUES (?,?)", (dept_id, name))
                flash(f"'{name}' birimi eklendi.", "success")

        elif action == 'del_unit':
            uid = request.form.get('unit_id')
            if uid:
                db.execute_query("DELETE FROM units WHERE id=?", (uid,))
                flash("Birim silindi.", "success")

        db.close()
        return redirect(url_for('departments'))

    depts = [dict(r) for r in db.fetch_data("SELECT * FROM departments ORDER BY name")]
    units = [dict(r) for r in db.fetch_data(
        "SELECT u.*, d.name as dept_name FROM units u "
        "JOIN departments d ON d.id=u.department_id ORDER BY d.name, u.name"
    )]
    db.close()
    return render_template('departments.html', depts=depts, units=units)

# API: Birim listesi (müdürlüğe göre) — JSON
@app.route('/api/units/<int:dept_id>')
def api_units(dept_id):
    if 'user_id' not in session: return jsonify([])
    db = get_db()
    units = [dict(r) for r in db.fetch_data(
        "SELECT id, name FROM units WHERE department_id=? ORDER BY name", (dept_id,)
    )]
    db.close()
    return jsonify(units)

# ── Lisanslama API ────────────────────────────────────────────────────────────
@app.route('/api/license/activate', methods=['POST'])
def api_license_activate():
    data = request.json
    key = data.get('key')
    hwid = data.get('hwid')
    
    if not key or not hwid:
        return jsonify({"error": "Eksik bilgi"}), 400
        
    db = get_db()
    # Lisans anahtarını bul
    lic = db.fetch_data("SELECT * FROM licenses WHERE license_key=?", (key,))
    if not lic:
        db.close()
        return jsonify({"error": "Geçersiz lisans anahtarı"}), 404
        
    lic = dict(lic[0])
    
    # İptal edilmiş bir lisans mı?
    if lic['status'] == 'REVOKED':
        db.close()
        return jsonify({"error": "Bu lisans anahtarı iptal edilmiştir!"}), 403
        
    # Eğer başka bir HWID'ye bağlıysa
    if lic['hwid'] and lic['hwid'] != hwid:
        db.close()
        return jsonify({"error": "Bu lisans başka bir bilgisayara (HWID: " + lic['hwid'][:8] + "...) kayıtlı!"}), 403
        
    # Etkinleştir
    db.execute_query("UPDATE licenses SET hwid=?, status='ACTIVE' WHERE license_key=?", (hwid, key))
    db.close()
    return jsonify({"message": "Lisans başarıyla etkinleştirildi!"})

@app.route('/api/license/check', methods=['GET'])
@app.route('/api/license/check/', methods=['GET']) # Trailing slash desteği
def api_license_check():
    key = request.args.get('key')
    hwid = request.args.get('hwid')
    
    if not key or not hwid:
        return jsonify({"status": "ERROR", "message": "Eksik bilgi"}), 400
        
    db = get_db()
    lic = db.fetch_data("SELECT status, hwid FROM licenses WHERE license_key=?", (key,))
    db.close()
    
    if not lic:
        return jsonify({"status": "INVALID", "message": "Lisans bulunamadı"}), 404
        
    lic = dict(lic[0])
    if lic['hwid'] and lic['hwid'] != hwid:
        return jsonify({"status": "MISMATCH", "message": "Cihaz eşleşmiyor"}), 403
        
    return jsonify({"status": lic['status']})

# ── Arıza Kayıtları ───────────────────────────────────────────────────────────
@app.route('/tickets', methods=['GET', 'POST'])
def tickets():
    if 'user_id' not in session: return redirect(url_for('login'))
    perms = session.get('permissions', '')
    if '*' not in perms and 'tickets' not in perms:
        flash("Arızalar modülüne erişim yetkiniz yok.", "danger")
        return redirect(url_for('dashboard'))

    db = get_db()

    if request.method == 'POST':
        dept_id  = request.form.get('department_id') or None
        unit_id  = request.form.get('unit_id') or None
        dept_txt = request.form.get('department_text', '')
        person   = request.form.get('personnel_name', '').strip()
        desc     = request.form.get('description', '').strip()
        itype    = request.form.get('issue_type', 'Diğer')
        prio     = request.form.get('priority', 'Normal')

        if person:
            import datetime
            now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            db.execute_query(
                """INSERT INTO tickets
                   (department, department_id, unit_id, personnel_name,
                    issue_type, priority, description, date, status)
                   VALUES (?,?,?,?,?,?,?,?,'Açık')""",
                (dept_txt, dept_id, unit_id, person, itype, prio, desc, now)
            )
            flash("Arıza kaydı oluşturuldu.", "success")
        db.close()
        return redirect(url_for('tickets'))

    depts = [dict(r) for r in db.fetch_data("SELECT id, name FROM departments ORDER BY name")]
    all_tickets = [dict(r) for r in db.fetch_data(
        """SELECT t.*, COALESCE(d.name, t.department, '—') AS dept_name,
                  COALESCE(u.name, '—') AS unit_name
           FROM tickets t
           LEFT JOIN departments d ON d.id=t.department_id
           LEFT JOIN units u ON u.id=t.unit_id
           ORDER BY t.id DESC"""
    )]
    db.close()
    return render_template('tickets.html', tickets=all_tickets, depts=depts)

@app.route('/close_ticket', methods=['POST'])
def close_ticket():
    if 'user_id' not in session: return redirect(url_for('login'))
    db = get_db()
    t_id   = request.form.get('ticket_id')
    reply  = request.form.get('resolution', '')
    if t_id and reply:
        import datetime
        date_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        old = db.fetch_data("SELECT description FROM tickets WHERE id=?", (t_id,))
        old_desc = dict(old[0])['description'] if old else ''
        new_desc = f"{old_desc}\n\n[Çözüm - {date_str}]: {reply}"
        db.execute_query(
            "UPDATE tickets SET description=?, status='Kapalı' WHERE id=?",
            (new_desc, t_id)
        )
        flash(f"#{t_id} numaralı kayıt kapatıldı.", "success")
    db.close()
    return redirect(url_for('tickets'))

# ── Envanter ─────────────────────────────────────────────────────────────────
@app.route('/inventory', methods=['GET', 'POST'])
def inventory():
    if 'user_id' not in session: return redirect(url_for('login'))
    perms = session.get('permissions', '')
    if '*' not in perms and 'inventory' not in perms:
        flash("Envanter modülüne erişim yetkiniz yok.", "danger")
        return redirect(url_for('dashboard'))

    db = get_db()
    inv_mod = InventoryModule(db)

    if request.method == 'POST':
        user    = request.form.get('user', '').strip()
        dept_id = request.form.get('department_id') or None
        unit_id = request.form.get('unit_id') or None
        brands  = request.form.getlist('brand[]')
        models  = request.form.getlist('model[]')
        ips     = request.form.getlist('ip[]')

        if user and brands:
            today = datetime.date.today().isoformat()
            added = 0
            for i, b in enumerate(brands):
                b = b.strip(); m = (models[i] if i < len(models) else '').strip()
                ip = (ips[i] if i < len(ips) else '').strip()
                if b:
                    import uuid
                    sn = f"TEMP-{uuid.uuid4().hex[:8]}"
                    ok = db.execute_query(
                        """INSERT INTO inventory
                           (brand, model, serial_no, ip_address, location,
                            user_name, department_id, unit_id, date)
                           VALUES (?,?,?,?,?,?,?,?,?)""",
                        (b, m, sn, ip, '', user, dept_id, unit_id, today)
                    )
                    if ok:
                        added += 1
                        write_log(db, session.get('username','?'), "EKLE",
                                  f"Envanter (web): {b} {m} — Personel: {user}")
            flash(f"{added} cihaz envantere eklendi.", "success")
        else:
            flash("Personel adı ve en az bir cihaz bilgisi zorunludur.", "danger")

        db.close()
        return redirect(url_for('inventory'))

    depts = [dict(r) for r in db.fetch_data("SELECT id, name FROM departments ORDER BY name")]
    all_devices = [dict(r) for r in db.fetch_data(
        """SELECT i.*, COALESCE(d.name,'—') AS dept_name, COALESCE(u.name,'—') AS unit_name
           FROM inventory i
           LEFT JOIN departments d ON d.id=i.department_id
           LEFT JOIN units u ON u.id=i.unit_id
           ORDER BY i.id DESC"""
    )]
    db.close()
    return render_template('inventory.html', inventory=all_devices, depts=depts)

@app.route('/inventory/delete/<int:device_id>', methods=['POST'])
def delete_device(device_id):
    if 'user_id' not in session: return redirect(url_for('login'))
    db = get_db()
    rec = db.fetch_data("SELECT brand, model, user_name FROM inventory WHERE id=?", (device_id,))
    if rec:
        r = dict(rec[0])
        write_log(db, session.get('username','?'), "SİL",
                  f"Envanter (web) silindi: {r['brand']} {r['model']} — {r['user_name']} (ID:{device_id})")
    db.execute_query("DELETE FROM inventory WHERE id=?", (device_id,))
    db.close()
    flash("Cihaz envanterden silindi.", "success")
    return redirect(url_for('inventory'))

# ── Sistem Logları (Sadece Admin) ─────────────────────────────────────────────
@app.route('/logs')
def logs():
    if 'user_id' not in session: return redirect(url_for('login'))
    if session.get('role') != 'Admin':
        flash("Sistem loglarına yalnızca Admin erişebilir.", "danger")
        return redirect(url_for('dashboard'))
    db = get_db()
    action_filter = request.args.get('action', '')
    all_logs = [dict(r) for r in db.fetch_data("SELECT * FROM logs ORDER BY id DESC LIMIT 500")]
    if action_filter:
        all_logs = [l for l in all_logs if l.get('action_type') == action_filter]
    db.close()
    return render_template('logs.html', logs=all_logs, action_filter=action_filter)

@app.route('/logs/clear', methods=['POST'])
def clear_logs():
    if 'user_id' not in session or session.get('role') != 'Admin':
        return redirect(url_for('login'))
    db = get_db()
    try:
        if db.execute_query("DELETE FROM logs"):
            write_log(db, session.get('username','Admin'), "SİL", "Tüm sistem logları temizlendi.")
            flash("Tüm loglar temizlendi.", "success")
        else:
            flash("Loglar temizlenirken veritabanı hatası oluştu.", "danger")
    except Exception as e:
        flash(f"Hata: {str(e)}", "danger")
    finally:
        db.close()
    return redirect(url_for('logs'))

# ── Profil & Admin ────────────────────────────────────────────────────────────
@app.route('/profile', methods=['GET', 'POST'])
def profile():
    if 'user_id' not in session: return redirect(url_for('login'))
    db = get_db()
    if request.method == 'POST':
        nu = request.form.get('username', '').strip()
        np = request.form.get('password', '').strip()
        if nu and np:
            try:
                db.execute_query("UPDATE users SET username=?, password=? WHERE id=?",
                                 (nu, np, session['user_id']))
                session['username'] = nu
                flash("Profil güncellendi.", "success")
            except Exception:
                flash("Bu kullanıcı adı zaten kullanımda.", "danger")
        db.close()
        return redirect(url_for('profile'))
    user = db.fetch_data("SELECT * FROM users WHERE id=?", (session['user_id'],))
    db.close()
    return render_template('profile.html', user=user[0] if user else {})

@app.route('/admin/users')
def admin_users():
    if 'user_id' not in session or session.get('role') != 'Admin':
        flash("Bu sayfayı görüntüleme yetkiniz yok.", "danger")
        return redirect(url_for('dashboard'))
    db = get_db()
    cur = int(time.time())
    all_u = db.fetch_data("SELECT * FROM users")
    registered = [dict(u) for u in all_u]
    active = []
    
    for dict_u in all_u:
        u = dict(dict_u)
        la = str(u.get('last_active') or '')
        if la:
            if "|" in la:
                ts, plat = la.split("|", 1)
            else:
                ts, plat = la, "unknown"
            
            if ts.isdigit():
                diff = cur - int(ts)
                if diff <= 300:
                    u['platform'] = plat
                    u['diff_str'] = "Şu an Aktif" if diff < 60 else f"{diff // 60} dk önce"
                    active.append(u)

    db.close()
    return render_template('admin_users.html', users=registered, active_users=active)

if __name__ == '__main__':
    try:
        logger.info("Web Portalı başlatılıyor... (Host: 0.0.0.0, Port: 5000)")
        # Başlangıcı DB'ye kaydetmeyi dene
        try:
            db = get_db()
            write_log(db, "SİSTEM", "WEB_START", "Web portal sunucusu başlatıldı.")
            db.close()
        except: pass
        
        app.run(host='0.0.0.0', port=5000, debug=False)
    except Exception as e:
        logger.critical(f"Web sunucusu başlatılırken kritik hata: {e}")
        import traceback
        logger.critical(traceback.format_exc())
