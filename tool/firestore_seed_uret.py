"""Ders 18 — Firestore örnek verisini üretir: assets/data/firestore_seed.json

Sabit tohumla (random.seed) çalışır; her çalıştırmada aynı veri çıkar.
Çalıştırma:  python3 tool/firestore_seed_uret.py
"""
import json
import random
from datetime import datetime, timedelta, timezone

random.seed(18)
TR = timezone(timedelta(hours=3))
START = datetime(2026, 6, 1, tzinfo=TR)
END = datetime(2026, 11, 5, 23, 0, tzinfo=TR)
EXPENSE_COUNT = 520

categories = [
    {"id": "food", "ad": "Yemek", "ikon": "restaurant", "renk": "#F97316", "sira": 1},
    {"id": "transport", "ad": "Ulaşım", "ikon": "directions_bus", "renk": "#2563EB", "sira": 2},
    {"id": "bills", "ad": "Fatura", "ikon": "receipt_long", "renk": "#DC2626", "sira": 3},
    {"id": "fun", "ad": "Eğlence", "ikon": "celebration", "renk": "#9333EA", "sira": 4},
    {"id": "other", "ad": "Diğer", "ikon": "more_horiz", "renk": "#64748B", "sira": 5},
]
payment_methods = [
    {"id": "nakit", "ad": "Nakit", "tur": "nakit"},
    {"id": "kredi_karti", "ad": "Kredi kartı", "tur": "kart"},
    {"id": "banka_karti", "ad": "Banka kartı", "tur": "kart"},
    {"id": "yemek_karti", "ad": "Yemek kartı", "tur": "kart"},
    {"id": "havale", "ad": "Havale / EFT", "tur": "havale"},
]
tags = [
    {"id": "is", "ad": "İş"}, {"id": "aile", "ad": "Aile"},
    {"id": "aylik", "ad": "Aylık"}, {"id": "indirim", "ad": "İndirimli"},
    {"id": "hafta_sonu", "ad": "Hafta sonu"}, {"id": "acil", "ad": "Acil"},
    {"id": "hediye", "ad": "Hediye"}, {"id": "saglik", "ad": "Sağlık"},
]
# mağaza: (id, ad, kategori, tutar aralığı, notlar, ödeme yöntemleri)
stores = [
    ("mahalle_market", "Mahalle Market", "food", (60, 900), ["Haftalık market alışverişi", "Ekmek, süt, yumurta", "Meyve sebze", "Akşam yemeği için alışveriş"], ["banka_karti", "nakit", "kredi_karti"]),
    ("zincir_market", "Zincir Market", "food", (150, 1800), ["Aylık büyük alışveriş", "Temizlik ve gıda", "Kampanyalı ürünler"], ["kredi_karti", "banka_karti"]),
    ("kose_kafe", "Köşe Kafe", "food", (45, 220), ["Kahve ve tatlı", "Sabah kahvesi", "Toplantı kahvesi"], ["nakit", "banka_karti", "yemek_karti"]),
    ("esnaf_lokanta", "Esnaf Lokantası", "food", (110, 380), ["Öğle yemeği", "Ev yemeği"], ["yemek_karti", "banka_karti"]),
    ("firin", "Fırın", "food", (15, 120), ["Simit ve poğaça", "Ekmek"], ["nakit"]),
    ("paket_servis", "Paket Servis", "food", (180, 650), ["Akşam siparişi", "Pizza siparişi", "Döner siparişi"], ["kredi_karti", "yemek_karti"]),
    ("toplu_tasima", "Toplu Taşıma Kart Dolum", "transport", (100, 600), ["Ulaşım kartı dolumu"], ["kredi_karti", "banka_karti", "nakit"]),
    ("taksi", "Taksi", "transport", (90, 450), ["Gece dönüşü taksi", "Havalimanı yolu", "Yağmurlu gün taksisi"], ["nakit", "kredi_karti"]),
    ("akaryakit", "Akaryakıt İstasyonu", "transport", (600, 2400), ["Depo dolumu", "Yakıt"], ["kredi_karti"]),
    ("otopark", "Otopark", "transport", (40, 180), ["Otopark ücreti"], ["nakit", "banka_karti"]),
    ("elektrik", "Elektrik Dağıtım", "bills", (600, 1500), ["Elektrik faturası"], ["havale", "kredi_karti"]),
    ("dogalgaz", "Doğal Gaz", "bills", (250, 2200), ["Doğal gaz faturası"], ["havale", "kredi_karti"]),
    ("su", "Su İdaresi", "bills", (150, 420), ["Su faturası"], ["havale"]),
    ("internet", "Ev İnterneti", "bills", (449.90, 449.90), ["Ev interneti"], ["kredi_karti"]),
    ("mobil_hat", "Mobil Hat", "bills", (299, 299), ["Telefon faturası"], ["kredi_karti"]),
    ("sinema", "Sinema Salonu", "fun", (150, 420), ["Sinema bileti", "İki kişilik sinema"], ["kredi_karti", "banka_karti"]),
    ("konser", "Konser Salonu", "fun", (400, 1600), ["Konser bileti"], ["kredi_karti"]),
    ("dijital_abonelik", "Dijital Abonelik", "fun", (99, 259), ["Müzik aboneliği", "Dizi aboneliği"], ["kredi_karti"]),
    ("kitapci", "Kitapçı", "fun", (90, 480), ["Kitap", "Dergi ve kitap"], ["banka_karti", "kredi_karti"]),
    ("spor_salonu", "Spor Salonu", "fun", (750, 750), ["Spor salonu üyeliği"], ["kredi_karti"]),
    ("kirtasiye", "Kırtasiye", "other", (30, 260), ["Defter ve kalem", "Çıktı ve fotokopi"], ["nakit", "banka_karti"]),
    ("eczane", "Eczane", "other", (60, 650), ["İlaç", "Vitamin"], ["banka_karti", "nakit"]),
    ("kuafor", "Kuaför", "other", (200, 700), ["Saç kesimi"], ["nakit", "kredi_karti"]),
    ("hediyelik", "Hediyelik Eşya", "other", (150, 1200), ["Doğum günü hediyesi", "Hediye"], ["kredi_karti"]),
]
monthly = {"elektrik": 3, "dogalgaz": 5, "su": 8, "internet": 2, "mobil_hat": 12, "dijital_abonelik": 15, "spor_salonu": 1}
budget_limits = {"food": 9000, "transport": 3500, "bills": 4500, "fun": 3000, "other": 1500}

def rand_time(day):
    return day.replace(hour=random.randint(7, 22), minute=random.choice(range(0, 60, 5)))

def pick_tags(store_id, cat, when):
    t = set()
    if store_id in monthly: t.add("aylik")
    if when.weekday() >= 5 and random.random() < 0.6: t.add("hafta_sonu")
    if cat == "food" and random.random() < 0.25: t.add("aile")
    if store_id in ("esnaf_lokanta", "kose_kafe", "taksi") and when.weekday() < 5 and random.random() < 0.4: t.add("is")
    if random.random() < 0.12: t.add("indirim")
    if store_id == "eczane": t.add("saglik")
    if store_id == "hediyelik": t.add("hediye")
    if store_id == "taksi" and random.random() < 0.2: t.add("acil")
    return sorted(t)[:5]

expenses = []
def add(store, when):
    sid, _, cat, (lo, hi), notes, pms = store
    amount = round(lo if lo == hi else random.uniform(lo, hi), 2)
    e = {"tutar": amount, "tarih": when.isoformat(timespec="minutes"),
         "not": random.choice(notes), "kategoriId": cat,
         "odemeYontemiId": random.choice(pms), "magazaId": sid,
         "etiketIdleri": pick_tags(sid, cat, when)}
    if random.random() < 0.04:  # birkaç harcamanın mağazası yok
        del e["magazaId"]
    expenses.append(e)

by_id = {s[0]: s for s in stores}
# Düzenli (aylık) ödemeler
month = START
while month <= END:
    for sid, day in monthly.items():
        d = month.replace(day=day)
        if d <= END: add(by_id[sid], rand_time(d))
    month = (month.replace(day=1) + timedelta(days=32)).replace(day=1)
# Günlük harcamalar
weights = {"food": 6, "transport": 3, "fun": 1.2, "other": 1}
daily = [s for s in stores if s[0] not in monthly]
w = [weights[s[2]] for s in daily]
days = (END - START).days + 1
while len(expenses) < EXPENSE_COUNT:
    d = START + timedelta(days=random.randrange(days))
    add(random.choices(daily, weights=w)[0], rand_time(d))

expenses.sort(key=lambda e: e["tarih"])
for i, e in enumerate(expenses, 1):
    e["id"] = f"h{i:03d}"
    expenses[i - 1] = {"id": e.pop("id"), **e}

budgets = []
month = START
while month <= END:
    ay = month.strftime("%Y-%m")
    for c, limit in budget_limits.items():
        budgets.append({"id": f"{ay}_{c}", "kategoriId": c, "ay": ay, "limit": limit})
    month = (month.replace(day=1) + timedelta(days=32)).replace(day=1)

seed = {
    "surum": 2,
    "kategoriler": categories,
    "odeme_yontemleri": payment_methods,
    "etiketler": tags,
    "magazalar": [{"id": s[0], "ad": s[1], "kategoriId": s[2]} for s in stores],
    "butceler": budgets,
    "harcamalar": expenses,
}
with open("assets/data/firestore_seed.json", "w") as f:
    json.dump(seed, f, ensure_ascii=False, indent=1)
    f.write("\n")
print({k: len(v) for k, v in seed.items() if isinstance(v, list)})
