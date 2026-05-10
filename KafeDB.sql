CREATE DATABASE KafeDB;
USE KafeDB;
GO


-- TABLOLAR 

CREATE TABLE Roller (
    id INT PRIMARY KEY IDENTITY(1,1),
    rol_adi VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Kullanicilar (
    id INT PRIMARY KEY IDENTITY(1,1),
    kullanici_adi VARCHAR(50) NOT NULL UNIQUE,
    sifre_hash VARCHAR(255) NOT NULL,
    rol_id INT NOT NULL,
    email VARCHAR(100),
    eklenme_tarihi DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (rol_id) REFERENCES Roller(id)
);

CREATE TABLE Kategoriler (
    id INT PRIMARY KEY IDENTITY(1,1),
    ad VARCHAR(50) NOT NULL,
    aciklama VARCHAR(MAX)
);

CREATE TABLE Urunler (
    id INT PRIMARY KEY IDENTITY(1,1),
    isim VARCHAR(100) NOT NULL,
    kategori_id INT NOT NULL,
    fiyat DECIMAL(6,2) NOT NULL CHECK (fiyat >= 0),
    stok_miktari INT NOT NULL CHECK (stok_miktari >= 0),
    eklenme_tarihi DATE NOT NULL,
    FOREIGN KEY (kategori_id) REFERENCES Kategoriler(id)
);

CREATE TABLE Calisanlar (
    id INT PRIMARY KEY IDENTITY(1,1),
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    pozisyon VARCHAR(50) NOT NULL,
    vardiya_saati VARCHAR(20) NOT NULL,
    ise_giris_tarihi DATE NOT NULL
);

CREATE TABLE Siparisler (
    id INT PRIMARY KEY IDENTITY(1,1),
    siparis_tarihi DATETIME NOT NULL,
    calisan_id INT NOT NULL,
    toplam_tutar DECIMAL(8,2) NOT NULL CHECK (toplam_tutar >= 0),
    FOREIGN KEY (calisan_id) REFERENCES Calisanlar(id)
);

CREATE TABLE SiparisDetay (
    id INT PRIMARY KEY IDENTITY(1,1),
    siparis_id INT NOT NULL,
    urun_id INT NOT NULL,
    adet INT NOT NULL CHECK (adet > 0),
    ara_toplam DECIMAL(8,2) NOT NULL CHECK (ara_toplam >= 0),
    FOREIGN KEY (siparis_id) REFERENCES Siparisler(id),
    FOREIGN KEY (urun_id) REFERENCES Urunler(id)
);
GO

-- ALTER TABLE 
ALTER TABLE Kullanicilar ADD email_onaylandi BIT DEFAULT 0;
GO

-- DROP TABLE 

CREATE TABLE GeciciRapor (id INT, rapor_adi VARCHAR(50));
GO
DROP TABLE GeciciRapor;
GO


--  TRIGGER 

CREATE TRIGGER trg_StokDusur
ON SiparisDetay
AFTER INSERT
AS
BEGIN
    
    UPDATE Urunler
    SET stok_miktari = stok_miktari - i.adet
    FROM Urunler U
    INNER JOIN inserted i ON U.id = i.urun_id;
END;
GO



-- STORED PROCEDURES (Saklý Yordamlar)

-- Kategori ekleme
CREATE PROCEDURE sp_KategoriEkle
    @p_Ad VARCHAR(50),
    @p_Aciklama VARCHAR(MAX)
AS
BEGIN
    INSERT INTO Kategoriler (ad, aciklama)
    VALUES (@p_Ad, @p_Aciklama);
END;
GO

--  Kimlik doðrulama - Giriþ Yap
CREATE PROCEDURE sp_GirisYap
    @KullaniciAdi VARCHAR(50),
    @SifreHash VARCHAR(255)
AS
BEGIN
    SELECT K.id, K.kullanici_adi, R.rol_adi, K.email
    FROM Kullanicilar K
    JOIN Roller R ON K.rol_id = R.id
    WHERE K.kullanici_adi = @KullaniciAdi
      AND K.sifre_hash = @SifreHash;
END;
GO

-- Kimlik doðrulama - Üye Ol
CREATE PROCEDURE sp_UyeOl
    @KullaniciAdi VARCHAR(50),
    @SifreHash VARCHAR(255),
    @Email VARCHAR(100)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Kullanicilar WHERE kullanici_adi = @KullaniciAdi)
    BEGIN
        RAISERROR('Bu kullanýcý adý zaten alýnmýþ.', 16, 1);
        RETURN;
    END;
    INSERT INTO Kullanicilar (kullanici_adi, sifre_hash, rol_id, email)
    VALUES (@KullaniciAdi, @SifreHash, 3, @Email);
END;
GO

-- Admin ürün silme 
CREATE PROCEDURE sp_UrunSil
    @UrunId INT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Urunler WHERE id = @UrunId)
    BEGIN
        RAISERROR('Ürün bulunamadý.', 16, 1);
        RETURN;
    END;
    DELETE FROM Urunler WHERE id = @UrunId;
END;
GO


--  FONKSÝYONLAR

CREATE FUNCTION fn_CalisanToplamSatis (@p_CalisanId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @ToplamSatis DECIMAL(10,2);
    SELECT @ToplamSatis = SUM(toplam_tutar)
    FROM Siparisler
    WHERE calisan_id = @p_CalisanId;
    RETURN ISNULL(@ToplamSatis, 0);
END;
GO


--KULLANICI ROLLERÝ VE YETKÝLENDÝRME

-- Admin login ve kullanýcýsý
CREATE LOGIN admin_login WITH PASSWORD = 'Admin@KafeDB2024!';
CREATE USER admin_user FOR LOGIN admin_login;

-- Admin: tüm tablolara tam yetki
GRANT SELECT, INSERT, UPDATE, DELETE ON Urunler       TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON Kullanicilar  TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON Siparisler    TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON SiparisDetay  TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON Calisanlar    TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON Kategoriler   TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON Roller        TO admin_user;
GRANT EXECUTE ON sp_KategoriEkle TO admin_user;
GRANT EXECUTE ON sp_GirisYap     TO admin_user;
GRANT EXECUTE ON sp_UyeOl        TO admin_user;
GRANT EXECUTE ON sp_UrunSil      TO admin_user;

-- Calisan login ve kullanýcýsý
CREATE LOGIN calisan_login WITH PASSWORD = 'Calisan@KafeDB2024!';
CREATE USER calisan_user FOR LOGIN calisan_login;

-- Calisan: siparis ekleyebilir, ürün/kategori okuyabilir, kullanýcý/çalýþan silemez
GRANT SELECT ON Urunler    TO calisan_user;
GRANT SELECT ON Kategoriler TO calisan_user;
GRANT SELECT, INSERT ON Siparisler   TO calisan_user;
GRANT SELECT, INSERT ON SiparisDetay TO calisan_user;
DENY  DELETE ON Kullanicilar TO calisan_user;
DENY  DELETE ON Urunler      TO calisan_user;
DENY  DELETE ON Calisanlar   TO calisan_user;
DENY  INSERT ON Calisanlar   TO calisan_user;
GRANT EXECUTE ON sp_GirisYap TO calisan_user;

-- Musteri login ve kullanýcýsý
CREATE LOGIN musteri_login WITH PASSWORD = 'Musteri@KafeDB2024!';
CREATE USER musteri_user FOR LOGIN musteri_login;

-- Musteri: sadece ürün/kategori okuyabilir
GRANT SELECT ON Urunler     TO musteri_user;
GRANT SELECT ON Kategoriler TO musteri_user;
DENY  DELETE ON Siparisler  TO musteri_user;
DENY  INSERT ON Calisanlar  TO musteri_user;
DENY  INSERT ON Urunler     TO musteri_user;
GRANT EXECUTE ON sp_GirisYap TO musteri_user;
GRANT EXECUTE ON sp_UyeOl    TO musteri_user;
GO


--  VERÝ EKLEME

INSERT INTO Roller (rol_adi) VALUES ('Admin'), ('Calisan'), ('Musteri');
select * from Roller

INSERT INTO Kullanicilar (kullanici_adi, sifre_hash, rol_id, email)
VALUES
    ('admin_kullanici', 'hashed_sifre_123', 1, 'admin@kafedb.com'),
    ('barista_emre',    'hashed_sifre_456', 2, 'emre@kafedb.com'),
    ('musteri_ali',     'hashed_sifre_789', 3, 'ali@gmail.com');
select * from Kullanicilar

INSERT INTO Kategoriler (ad, aciklama) VALUES
('Sýcak Ýçecekler',  'Kahve, çay ve diðer sýcak içecekler'),
('Soðuk Ýçecekler',  'Soðuk kahve, meþrubat ve içecekler'),
('Tatlýlar',         'Pastalar, kekler ve tatlý atýþtýrmalýklar'),
('Sandviçler',       'Soðuk ve sýcak sandviçler'),
('Atýþtýrmalýklar',  'Kuruyemiþ, kraker, cips'),
('Kahvaltýlýklar',   'Tost, omlet, menemen vb.'),
('Smoothie & Shake', 'Meyve bazlý içecekler'),
('Salatalar',        'Taze hazýrlanmýþ salatalar'),
('Yemekler',         'Günün yemeði ve ev yemekleri'),
('Çorbalar',         'Günün çorbasý ve klasik çorbalar');
select * from Kategoriler


INSERT INTO Urunler (isim, kategori_id, fiyat, stok_miktari, eklenme_tarihi) VALUES
('Espresso',            1, 30.00, 100, '2025-05-01'),   
('Latte',               1, 38.00,  80, '2025-05-01'),   
('Cappuccino',          1, 36.00,  70, '2025-05-01'),  
('Siyah Çay',           1, 20.00, 120, '2025-05-01'),   
('Buzlu Americano',     2, 34.00,  60, '2025-05-01'),   
('Limonata',            2, 25.00,  90, '2025-05-01'),   
('Soðuk Çay',           2, 24.00,  85, '2025-05-01'),   
('Tiramisu',            3, 42.00,  30, '2025-05-01'),   
('Brownie',             3, 35.00,  40, '2025-05-01'),   
('Cheesecake',          3, 45.00,  35, '2025-05-01'),   
('Tost',                6, 30.00,  50, '2025-05-01'),   
('Omlet',               6, 32.00,  40, '2025-05-01'),   
('Ton Balýklý Sandviç', 4, 40.00,  20, '2025-05-01'),   
('Tavuklu Sandviç',     4, 38.00,  25, '2025-05-01'),   
('Çikolatalý Milkshake',7, 28.00,  30, '2025-05-01'),   
('Muzlu Smoothie',      7, 30.00,  28, '2025-05-01'),   
('Cips',                5, 12.00,  50, '2025-05-01'),   
('Kraker',              5, 10.00,  60, '2025-05-01'),   
('Çoban Salata',        8, 22.00,  25, '2025-05-01'),   
('Akdeniz Salata',      8, 28.00,  20, '2025-05-01'),   
('Mercimek Çorbasý',   10, 18.00,  30, '2025-05-01'),   
('Tarhana Çorbasý',    10, 20.00,  25, '2025-05-01'),   
('Ev Köftesi',          9, 48.00,  18, '2025-05-01'),   
('Günün Yemeði',        9, 50.00,  15, '2025-05-01'),   
('Menemen',             6, 26.00,  35, '2025-05-01'),   
('Ekstra Latte',        1, 45.00, 100, '2025-05-01');   
select * from Urunler

INSERT INTO Calisanlar (ad, soyad, pozisyon, vardiya_saati, ise_giris_tarihi) VALUES
('Zeynep',  'Kaya',      'Barista',             '08:00-16:00', '2023-06-15'),  
('Ahmet',   'Yýlmaz',    'Garson',              '12:00-20:00', '2026-01-10'),  
('Elif',    'Demir',     'Barista',             '10:00-18:00', '2022-11-20'),  
('Mert',    'Þahin',     'Kasiyer',             '14:00-22:00', '2023-09-05'),  
('Cansu',   'Aydýn',     'Garson',              '08:00-16:00', '2023-04-10'),  
('Berk',    'Çelik',     'Hademe',              '07:00-15:00', '2022-10-01'),  
('Yasemin', 'Koç',       'Kasiyer',             '16:00-00:00', '2024-03-05'),  
('Mehmet',  'Eren',      'Barista',             '09:00-17:00', '2026-02-17'),  
('Nazan',   'Öz',        'Garson',              '13:00-21:00', '2024-01-28'),  
('Fatih',   'Kurt',      'Þef',                 '10:00-18:00', '2022-06-10'),  
('Arda',    'Güneþ',     'Garson',              '14:00-22:00', '2023-11-20'),  
('Pelin',   'Þimþek',    'Hademe',              '06:00-14:00', '2023-07-01'),  
('Emre',    'Özdemir',   'Barista',             '08:00-16:00', '2022-09-01'), 
('Ece',     'Uçar',      'Garson',              '12:00-20:00', '2024-01-10'),  
('Ali',     'Kara',      'Kasiyer',             '16:00-00:00', '2023-03-03'),  
('Selin',   'Durmaz',    'Þef Yardýmcýsý',      '11:00-19:00', '2023-08-12'),  
('Hakan',   'Bozkurt',   'Barista',             '07:00-15:00', '2025-12-05'),  
('Ýrem',    'Sarýkaya',  'Garson',              '13:00-21:00', '2024-01-20'),  
('Sena',    'Arslan',    'Temizlik Görevlisi',  '05:00-13:00', '2022-04-18'),  
('Ozan',    'Kaplan',    'Kasiyer',             '15:00-23:00', '2023-10-09'),  
('Ayþe',    'Kara',      'Barista',             '08:00-16:00', '2025-04-10');  
select* from Calisanlar

INSERT INTO Siparisler (siparis_tarihi, calisan_id, toplam_tutar) VALUES
('2026-05-06 16:31:00', 12,  94.00),  
('2026-05-03 16:23:00', 17,  10.00),  
('2026-05-15 08:03:00',  3, 106.00),  
('2026-05-02 11:42:00', 20,  92.00),  
('2026-05-08 10:08:00', 15,  98.00),   
('2026-05-10 14:36:00',  9, 190.00), 
('2026-05-04 09:18:00',  4,  60.00),  
('2026-05-11 16:02:00',  6,  98.00),   
('2026-05-05 12:22:00',  7,  45.00),  
('2026-05-13 13:47:00', 10, 108.00),   
('2026-05-14 15:10:00',  2,  81.00),   
('2026-05-09 17:55:00',  1, 112.00),   
('2026-05-07 10:44:00',  5,  35.00), 
('2026-05-01 08:57:00', 13,  58.00),  
('2026-05-12 18:13:00', 18,  94.00),  
('2026-05-06 11:22:00', 16,  85.00),   
('2026-05-08 09:38:00', 11,  98.00),   
('2026-05-03 16:12:00',  8,  80.00),   
('2026-05-15 14:27:00', 14,  60.00),   
('2026-05-10 14:42:00',  9,  98.00),  
('2026-05-10 14:30:00',  1,  60.00);  
select * from Siparisler

INSERT INTO SiparisDetay (siparis_id, urun_id, adet, ara_toplam) VALUES
(1,  19, 3,  66.00), (1,  20, 1,  28.00),           
(2,  18, 1,  10.00),                                
(3,  18, 1,  10.00), (3,  12, 3,  96.00),            
(4,   7, 3,  72.00), (4,   4, 1,  20.00),            
(5,  11, 2,  60.00), (5,   2, 1,  38.00),            
(6,  14, 2,  76.00), (6,   1, 1,  30.00), (6, 8, 2, 84.00), 
(7,  17, 2,  24.00), (7,   3, 1,  36.00),            
(8,   5, 2,  68.00), (8,  16, 1,  30.00),           
(9,  10, 1,  45.00),                                 
(10, 20, 1,  28.00), (10, 13, 2,  80.00),            
(11, 15, 2,  56.00), (11,  6, 1,  25.00),           
(12,  4, 2,  40.00), (12,  8, 1,  42.00), (12, 11, 1, 30.00),
(13,  9, 1,  35.00),                                
(14,  7, 2,  48.00), (14, 18, 1,  10.00),            
(15,  3, 2,  72.00), (15, 19, 1,  22.00),            
(16,  6, 1,  25.00), (16,  1, 2,  60.00),            
(17,  5, 1,  34.00), (17, 12, 2,  64.00),            
(18, 15, 2,  56.00), (18,  7, 1,  24.00),            
(19,  4, 1,  20.00), (19, 13, 1,  40.00),            
(20, 11, 2,  60.00), (20,  2, 1,  38.00),            
(21,  1, 2,  60.00);                                 
GO
select * from SiparisDetay

--  VERÝ GÜNCELLEME (UPDATE)

UPDATE Urunler 
SET fiyat = 48.00 
WHERE isim = 'Latte';

UPDATE Calisanlar SET vardiya_saati = '12:00-20:00'
WHERE ad = 'Ayþe' AND soyad = 'Kara';


--  VERÝ SÝLME (DELETE)
-- calisan_id=1 (Zeynep) sipariþlerini sil
DELETE FROM SiparisDetay
WHERE siparis_id IN (SELECT id FROM Siparisler WHERE calisan_id = 1);

DELETE FROM Siparisler WHERE calisan_id = 1;

-- Stoðu biten ürünleri sil
DELETE FROM Urunler WHERE stok_miktari = 0;
GO

-- Tüm ürünler
SELECT * FROM Urunler;

-- 30 TL üzeri ürünler
SELECT isim, fiyat FROM Urunler WHERE fiyat > 30;

-- Düþük stoklu ürünler (20'nin altý)
SELECT isim, stok_miktari FROM Urunler WHERE stok_miktari < 20;

-- Son 7 günün sipariþleri
SELECT * FROM Siparisler
WHERE siparis_tarihi >= DATEADD(DAY, -7, GETDATE());

-- Düþük stok VE yüksek fiyat filtresi
SELECT * FROM Urunler WHERE stok_miktari < 50 AND fiyat > 40;

-- Öðleden sonra sipariþler (12-18 arasý)
SELECT * FROM Siparisler
WHERE DATEPART(HOUR, siparis_tarihi) BETWEEN 12 AND 18;

-- En pahalý ürün
SELECT TOP 1 * FROM Urunler ORDER BY fiyat DESC;

-- Kategorilere göre ürün sayýsý
SELECT K.ad AS Kategori, COUNT(U.id) AS UrunSayisi
FROM Kategoriler K
JOIN Urunler U ON K.id = U.kategori_id
GROUP BY K.ad;

-- Günlük ciro
SELECT CAST(siparis_tarihi AS DATE) AS Tarih,
       SUM(toplam_tutar) AS GunlukCiro
FROM Siparisler
GROUP BY CAST(siparis_tarihi AS DATE)
ORDER BY Tarih;

-- Çalýþana göre sipariþ sayýsý
SELECT C.ad, C.soyad, COUNT(S.id) AS SiparisSayisi
FROM Calisanlar C
JOIN Siparisler S ON C.id = S.calisan_id
GROUP BY C.ad, C.soyad;

-- En çok sipariþ alan çalýþan
SELECT TOP 1 C.ad, C.soyad, COUNT(S.id) AS SiparisSayisi
FROM Calisanlar C
JOIN Siparisler S ON C.id = S.calisan_id
GROUP BY C.ad, C.soyad
ORDER BY SiparisSayisi DESC;

-- Sipariþ detaylarý (sipariþ + ürün adý)
SELECT S.id AS SiparisID, U.isim AS Urun, SD.adet, SD.ara_toplam
FROM Siparisler S
JOIN SiparisDetay SD ON S.id = SD.siparis_id
JOIN Urunler U       ON U.id  = SD.urun_id;

-- En çok sipariþ edilen ürünler
SELECT U.isim, SUM(SD.adet) AS ToplamAdet
FROM SiparisDetay SD
JOIN Urunler U ON U.id = SD.urun_id
GROUP BY U.isim
ORDER BY ToplamAdet DESC;

-- Kategorilere göre ortalama fiyat
SELECT K.ad AS Kategori, AVG(U.fiyat) AS OrtalamaFiyat
FROM Urunler U
JOIN Kategoriler K ON U.kategori_id = K.id
GROUP BY K.ad;

-- Ürünlerin kaç farklý sipariþte yer aldýðý
SELECT U.isim, COUNT(DISTINCT SD.siparis_id) AS SiparisSayisi
FROM SiparisDetay SD
JOIN Urunler U ON U.id = SD.urun_id
GROUP BY U.isim;

-- Çalýþan toplam satýþ tutarlarý
SELECT C.ad, C.soyad, SUM(S.toplam_tutar) AS ToplamTutar
FROM Calisanlar C
JOIN Siparisler S ON C.id = S.calisan_id
GROUP BY C.ad, C.soyad;


--Ortalama sipariþ tutarý
SELECT AVG(toplam_tutar) AS OrtalamaSiparisTutari FROM Siparisler;

SELECT AVG(adet)         AS OrtalamaUrunAdedi     FROM SiparisDetay;

SELECT SUM(toplam_tutar) AS MayisToplam
FROM Siparisler
WHERE MONTH(siparis_tarihi) = 5 AND YEAR(siparis_tarihi) = 2026;

-- Pozisyonlardaki kiþi sayýsýna göre büyükten küçüðe sýralama
SELECT pozisyon, COUNT(*) AS KisiSayisi
FROM Calisanlar
GROUP BY pozisyon
ORDER BY KisiSayisi DESC;


-- 150 TL üzeri ciro yapan çalýþanlar
SELECT C.ad, C.soyad, SUM(S.toplam_tutar) AS ToplamCiro
FROM Calisanlar C
JOIN Siparisler S ON C.id = S.calisan_id
GROUP BY C.ad, C.soyad
HAVING SUM(S.toplam_tutar) > 150;


-- Toplam cirolarý büyükten küçükðe sýralama 
SELECT ad, soyad, dbo.fn_CalisanToplamSatis(id) AS ToplamCiro
FROM Calisanlar
ORDER BY ToplamCiro DESC;
GO