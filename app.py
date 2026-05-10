from flask import Flask, render_template, request, redirect, url_for, flash
import pyodbc

app = Flask(__name__)
app.secret_key = "super_gizli_anahtar"  # Uyarı mesajları verebilmek için gerekli


# --- VERİTABANI BAĞLANTISI ---
def baglanti_kur():
    # DİKKAT: Buradaki YOUR_SERVER_NAME kısmına SSMS'teki kendi sunucu adını yaz!
    server = r'HackerReis'
    database = 'KafeDB'
    conn_str = f'DRIVER={{SQL Server}};SERVER={server};DATABASE={database};Trusted_Connection=yes;'
    return pyodbc.connect(conn_str)


# --- ANA SAYFA (ÜRÜNLERİ LİSTELE) ---
@app.route('/')
def index():
    conn = baglanti_kur()
    cursor = conn.cursor()
    cursor.execute("SELECT isim, fiyat, stok_miktari FROM Urunler")
    urunler = cursor.fetchall()
    conn.close()
    return render_template('index.html', urunler=urunler)


# --- KATEGORİ EKLE (STORED PROCEDURE ÇAĞIRMA) ---
@app.route('/kategori_ekle', methods=['POST'])
def kategori_ekle():
    ad = request.form['kat_ad']
    aciklama = request.form['kat_desc']

    conn = baglanti_kur()
    try:
        cursor = conn.cursor()
        # Yazdığın Stored Procedure'ü çalıştırıyoruz
        cursor.execute("{CALL sp_KategoriEkle (?, ?)}", (ad, aciklama))
        conn.commit()
        flash(f"'{ad}' kategorisi başarıyla eklendi!", "success")
    except Exception as e:
        flash(f"Hata oluştu: {str(e)}", "danger")
    finally:
        conn.close()

    return redirect(url_for('index'))


if __name__ == '__main__':
    app.run(debug=True)