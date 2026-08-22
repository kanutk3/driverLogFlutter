# 🚗 driverLog

ระบบบันทึกและจัดการการเดินรถอัจฉริยะสำหรับคนขับมืออาชีพ

## 📱 ฟีเจอร์หลัก

- **🔐 ล็อกอิน** — Google Login + Fingerprint (ลายนิ้วมือ)
- **📝 บันทึกการเดินทาง** — กรอกข้อมูลเที่ยวรถ (ทะเบียน, เลขไมล์, ตั๋ว, ค่าทางด่วน)
- **📋 ประวัติการเดินทาง** — ดูรายการที่บันทึกไว้ พร้อมค้นหาและกรอง
- **📤 Export** — สร้างรายงาน PDF/JPG เพื่อแชร์ต่อ
- **⚙️ ตั้งค่า** — จัดการบัญชีผู้ใช้ เปิด/ปิดล็อกอินด้วยลายนิ้วมือ

## 🏗️ สถาปัตยกรรม

```
lib/
├── main.dart                    # Entry point + Auth gate
├── screens/
│   ├── home_screen.dart         # Landing page (ไม่ได้ล็อกอิน)
│   ├── driver_home_screen.dart  # หน้าหลัก + BottomNav
│   ├── login_dialog.dart        # กล่องล็อกอิน
│   ├── trip_form_screen.dart    # ฟอร์มบันทึกเที่ยวรถ
│   ├── trip_history_screen.dart # ประวัติการเดินทาง
│   ├── trip_report_screen.dart  # Export PDF/JPG
│   └── settings_screen.dart     # ตั้งค่า + Fingerprint
└── services/
    ├── auth_service.dart        # Google Login + Device Login
    ├── biometric_service.dart   # Fingerprint / Biometric auth
    └── device_service.dart      # ข้อมูลอุปกรณ์
```

## 🛠️ เทคโนโลยี

| ส่วน | เทคโนโลยี |
|---|---|
| Framework | Flutter (Web + Mobile) |
| Backend | Supabase (PostgreSQL, Auth, Realtime) |
| Authentication | Google OAuth + Fingerprint (local_auth) |
| Hosting | Cloudflare Workers |

## 📖 คู่มือใช้งาน (User Guide)

### 1. ล็อกอิน

1. กดปุ่ม **"เข้าสู่ระบบ"** มุมบนขวา
2. เลือก **"เข้าสู่ระบบด้วย Google"** → เลือกบัญชี Google
3. หรือเลือก **"ลงทะเบียนเครื่องใหม่ด้วย Device ID"** สำหรับอุปกรณ์ที่ไม่มี Google

### 2. บันทึกการเดินทาง

1. กดปุ่ม **"เริ่มบันทึกการเดินทาง"** บนหน้าหลัก
2. กรอกข้อมูล:
   - เลือก/เพิ่มรถยนต์ (ทะเบียน + จังหวัด)
   - กรอกเลขที่ตั๋ว + ราคาตั๋ว
   - กรอกจุดหมายปลายทาง
   - กรอกเลขไมล์ต้นทาง
   - กด **"บันทึกร่าง"** ระหว่างเดินทาง
3. เมื่อถึงจุดหมาย:
   - กรอกเลขไมล์ปลายทาง
   - กรอกเวลาจบการเดินทาง
   - กรอกค่าทางด่วน (ถ้ามี)
   - กด **"จบการเดินทาง"**

### 3. ดูและแก้ไขประวัติการเดินทาง

- กดแท็บ **"ล่าสุด"** เพื่อดูรายการล่าสุด 5 เที่ยว
- **แก้ไขเที่ยว:** กดที่รายการ trip → เลือก **"แก้ไข"** → เปลี่ยนแปลงข้อมูล → กด **"บันทึก"**
- **ลบเที่ยว:** กดที่รายการ trip → เลือก **"ลบ"** → ยืนยัน
- กดแท็บ **"Export"** เพื่อสร้างรายงาน PDF/JPG

### 4. Fingerprint Login (ล็อกอินด้วยลายนิ้วมือ)

1. ล็อกอินด้วย Google ให้สำเร็จก่อน
2. ไปแท็บ **"ตั้งค่า"** → เปิด **"ล็อกอินด้วยลายนิ้วมือ"**
3. ยืนยันด้วยลายนิ้วมือ
4. ครั้งถัดไปล็อกอินด้วยลายนิ้วมือได้เลย!

---

## 🚀 เริ่มต้นใช้งาน (สำหรับนักพัฒนา)

### ติดตั้ง Flutter

```bash
# ตรวจสอบ version
flutter --version

# รันบน Web
flutter run -d chrome --web-port=8080

# Build สำหรับ Production
flutter build web --release
```

### ตั้งค่า Supabase

1. สร้าง Project บน [Supabase](https://supabase.com)
2. รัน SQL ใน `docs-private/sql/user_credentials.sql` เพื่อสร้างตาราง
3. ตั้งค่า Google OAuth ใน Supabase Dashboard → Authentication → Providers

### Deploy บน Cloudflare

```bash
flutter build web --release
# อัปโหลดไฟล์ใน build/web/ ไปที่ Cloudflare Pages
```

## 📊 Database Schema

### Tables

| Table | คำอธิบาย |
|---|---|
| `profiles` | ข้อมูลผู้ใช้ (ชื่อ, email, role) |
| `trip_logs` | บันทึกการเดินทาง |
| `vehicles` | ข้อมูลรถยนต์ |
| `user_credentials` | ข้อมูลลายนิ้วมือสำหรับ Fingerprint Login |
| `user_devices` | ข้อมูลอุปกรณ์ที่ลงทะเบียน |
| `pairing_sessions` | คู่อุปกรณ์สำหรับ Device Login |

### Key Columns

| Table | Columns |
|---|---|
| `profiles` | id (UUID PK), display_name, google_name, email, role, default_vehicle_id |
| `trip_logs` | id (UUID PK), user_id (FK), vehicle_id (FK), ticket_number, destination, start_odometer, end_odometer, distance, start_time, end_time, toll_fee, ticket_price |
| `vehicles` | id (UUID PK), vehicle_plate, province, brand, model |
| `user_credentials` | id (UUID PK), user_id (FK), credential_id, credential_type |
| `user_devices` | id (UUID PK), user_id (FK), device_id, device_name, is_primary |
| `pairing_sessions` | id (UUID PK), pairing_token, new_device_id, approved_by_user_id, status, expires_at |

### Relationships

```
profiles (1) ──────< (N) trip_logs
     │                      │
     │ (default_vehicle_id) │ (vehicle_id)
     │                      │
     └──────> vehicles <────┘

profiles (1) ──────< (N) user_credentials
profiles (1) ──────< (N) user_devices
profiles (1) ──────< (N) pairing_sessions
```

## 🔒 Security

- **Data Isolation** — คนขับ A ไม่เห็นข้อมูลของคนขับ B (RLS Policies)
- **Fingerprint Login** — ล็อกอินด้วยลายนิ้วมือผ่าน Supabase `user_credentials`
- **Device Binding** — ผูกอุปกรณ์กับบัญชีผู้ใช้

## 📄 License

MIT License © 2025
