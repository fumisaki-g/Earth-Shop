# PC CLINIC — เว็บไซต์ร้านปรึกษาคอมพิวเตอร์ฟรี & บริการทำความสะอาด

โครงสร้างไฟล์:
```
pc-service-shop/
├─ index.html       หน้าแรก / แสดงหมวดหมู่บริการ
├─ booking.html      หน้าลงคิวงาน + คำนวณวันนัดรับล่วงหน้า
├─ dashboard.html     หน้าติดตามคิวงานของสมาชิก (ต้องล็อกอิน)
├─ css/style.css      ธีม/ดีไซน์ทั้งหมด
├─ js/app.js          ฟังก์ชันร่วม (auth, คำนวณวันทำการ, ตัวติดตามสถานะ)
├─ js/supabase-config.js  จุดใส่ URL / anon key ของ Supabase
└─ schema.sql         สคริปต์สร้างตาราง + RLS สำหรับ Supabase
```

## วิธีต่อกับ Supabase (ทำ 4 ขั้นตอน)

1. **รัน schema.sql**
   ไปที่ Supabase Dashboard → SQL Editor → วางเนื้อหาไฟล์ `schema.sql` ทั้งหมด → Run
   จะได้ตาราง `profiles`, `services` (มีข้อมูลตัวอย่าง 5 บริการใส่ไว้แล้ว), `bookings` พร้อม Row Level Security

2. **ใส่ค่า API keys**
   เปิด `js/supabase-config.js` แล้วแทนที่
   ```js
   const SUPABASE_URL = "YOUR_SUPABASE_PROJECT_URL";
   const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
   ```
   ด้วยค่าจาก Project Settings → API

3. **เปิดใช้ Google Login**
   Supabase Dashboard → Authentication → Providers → Google → เปิดใช้งาน
   ใส่ Client ID / Client Secret จาก Google Cloud Console
   ที่ Google Cloud Console ต้องเพิ่ม Redirect URL เป็น
   `https://<your-project-ref>.supabase.co/auth/v1/callback`
   และเพิ่มโดเมนที่จะโฮสต์เว็บ (เช่น `https://yourdomain.com`) ใน Authorized redirect URIs ด้วย

4. **โฮสต์เว็บ**
   ไฟล์ทั้งหมดเป็น static HTML — วางบน Vercel, Netlify, GitHub Pages หรือโฮสต์ไหนก็ได้
   ตอนทดสอบในเครื่อง แนะนำรันผ่าน local server (เช่น `npx serve .`) แทนการเปิดไฟล์ตรงๆ
   เพราะ Google OAuth ต้องมี URL จริง ไม่ใช่ `file://`

## การอัปเดตสถานะงาน (ฝั่งร้าน)

ร้านอัปเดตสถานะงานได้โดยตรงที่ Supabase → Table Editor → ตาราง `bookings` → แก้ค่าคอลัมน์ `status`:

| status        | ความหมาย                          |
|---------------|-------------------------------------|
| `pending`     | ลูกค้าลงคิวไว้ ยังไม่ส่งเครื่อง      |
| `received`    | ร้านได้รับเครื่องแล้ว                |
| `in_progress` | กำลังดำเนินการ                       |
| `ready`       | เสร็จแล้ว พร้อมให้มารับ (ใส่วันที่ใน `actual_ready_date` ด้วย) |
| `completed`   | ลูกค้ามารับเครื่องเรียบร้อย          |

เว็บฝั่งลูกค้าจะอัปเดตแบบเรียลไทม์ทันทีที่แก้สถานะ (ใช้ Supabase Realtime subscription ที่ต่อไว้ในหน้า dashboard.html) และจะมีแบนเนอร์แจ้งเตือนขึ้นเมื่อลูกค้าเข้าเว็บครั้งถัดไปหากสถานะเปลี่ยนไปจากที่เห็นล่าสุด

## การปรับแต่งบริการ

แก้ไข/เพิ่มบริการได้ที่ตาราง `services` ใน Supabase โดยตรง (ชื่อ, คำอธิบาย, ราคา, จำนวนวันทำการ, ไอคอน)
เว็บจะดึงข้อมูลจากตารางนี้อัตโนมัติ — ถ้ายังไม่เชื่อม Supabase หน้าเว็บจะโชว์ข้อมูลตัวอย่าง (fallback) แทนไปก่อน เพื่อให้ดูดีไซน์ได้ทันที
