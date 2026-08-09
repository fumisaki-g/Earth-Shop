-- ============================================================
--  PC CLINIC — Supabase schema
--  วิธีใช้: เปิด Supabase Dashboard > SQL Editor > วางไฟล์นี้ทั้งหมด > Run
-- ============================================================

-- เปิด extension สำหรับสุ่ม uuid
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------
-- 1) ตารางโปรไฟล์ผู้ใช้ (ผูกกับ auth.users ของ Supabase)
-- ---------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  avatar_url text,
  phone text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: read own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles: update own" on public.profiles
  for update using (auth.uid() = id);

-- trigger: พอมี user สมัคร/ล็อกอินใหม่ผ่าน Google ให้สร้างแถวโปรไฟล์อัตโนมัติ
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.email,
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email,
        avatar_url = excluded.avatar_url;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------
-- 2) ตารางบริการ (หมวดหมู่ที่แสดงบนหน้าเว็บ)
-- ---------------------------------------------------------
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text,
  category text not null,          -- 'consult' | 'clean' | 'checkup'
  duration_days int not null,      -- ใช้คำนวณวันนัดรับล่วงหน้า
  price numeric not null default 0,
  is_free boolean not null default false,
  icon text,                       -- ชื่อไอคอนที่ใช้ในหน้าเว็บ
  sort_order int not null default 0,
  active boolean not null default true
);

alter table public.services enable row level security;
create policy "services: public read" on public.services for select using (true);

-- ข้อมูลตั้งต้น (ปรับแก้ได้ภายหลังใน Table Editor)
insert into public.services (code, name, description, category, duration_days, price, is_free, icon, sort_order) values
('CONSULT-BASIC','ปรึกษาปัญหาคอมพิวเตอร์','พูดคุย วิเคราะห์อาการเครื่อง ให้คำแนะนำเบื้องต้นโดยไม่มีค่าใช้จ่าย','consult',0,0,true,'chat',1),
('CLEAN-EXT','ทำความสะอาดภายนอก','เช็ดทำความสะอาดตัวเครื่อง คีย์บอร์ด หน้าจอ ช่องระบายอากาศ','clean',1,150,false,'spray',2),
('CLEAN-INT','ทำความสะอาดภายใน + เป่าฝุ่น','ถอดฝาเครื่อง เป่าฝุ่นภายใน ทำความสะอาดพัดลมและฮีตซิงก์','clean',2,300,false,'fan',3),
('CLEAN-PASTE','เปลี่ยนซิลิโคน + ทำความสะอาดภายใน','ถอดฝาเครื่อง ทำความสะอาดภายใน เปลี่ยนซิลิโคนระบายความร้อน CPU','clean',3,450,false,'droplet',4),
('CHECKUP-SPEC','ตรวจเช็คสเปค & ประสิทธิภาพ','ตรวจสภาพฮาร์ดแวร์ ทดสอบประสิทธิภาพ แจ้งจุดที่ควรอัปเกรด','checkup',1,0,true,'gauge',5)
on conflict (code) do nothing;

-- ---------------------------------------------------------
-- 3) ตารางคิวงาน / ใบรับซ่อม
-- ---------------------------------------------------------
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  ticket_no text unique not null default ('PC-' || to_char(now(),'YYMMDD') || '-' || lpad(floor(random()*10000)::text,4,'0')),
  user_id uuid not null references public.profiles(id) on delete cascade,
  service_id uuid not null references public.services(id),
  device_type text not null,          -- 'โน้ตบุ๊ก' | 'พีซีตั้งโต๊ะ' | 'อื่นๆ'
  issue_note text,
  dropoff_date date not null,
  estimated_ready_date date not null,
  actual_ready_date date,
  status text not null default 'pending'
    check (status in ('pending','received','in_progress','ready','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.bookings enable row level security;

create policy "bookings: read own" on public.bookings
  for select using (auth.uid() = user_id);

create policy "bookings: insert own" on public.bookings
  for insert with check (auth.uid() = user_id);

create policy "bookings: update own" on public.bookings
  for update using (auth.uid() = user_id);

-- trigger อัปเดต updated_at อัตโนมัติ
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists bookings_set_updated_at on public.bookings;
create trigger bookings_set_updated_at
  before update on public.bookings
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------
-- หมายเหตุสำหรับฝั่งร้าน (แอดมิน)
-- ---------------------------------------------------------
-- ทางร้านอัปเดตสถานะงานได้ตรงๆ ผ่าน Table Editor ในตาราง bookings:
--   'pending'      = ลูกค้าจองคิวไว้ ยังไม่ส่งเครื่อง
--   'received'     = ร้านได้รับเครื่องแล้ว
--   'in_progress'  = กำลังดำเนินการ
--   'ready'        = เสร็จแล้ว พร้อมให้มารับ  (ให้ใส่วันที่ใน actual_ready_date ด้วย)
--   'completed'    = ลูกค้ามารับเครื่องเรียบร้อย
-- เว็บฝั่งลูกค้าจะดึงค่าจากตารางนี้แบบเรียลไทม์ไปแสดงในหน้า dashboard.html โดยอัตโนมัติ
