/* ============================================================
   ตั้งค่า Supabase ของร้านตรงนี้
   หาได้จาก Supabase Dashboard > Project Settings > API
   ============================================================ */
const SUPABASE_URL = "https://ggqbwxmjzglkrisiavjl.supabase.co";      // เช่น https://xxxxx.supabase.co
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdncWJ3eG1qemdsa3Jpc2lhdmpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNDA4OTgsImV4cCI6MjEwMTgxNjg5OH0.67CpiSz24Da0AY5Z_-TOrvTcMYFtxc_dbrVHw5PRrGg";     // anon public key

// สร้าง client เดียวใช้ร่วมกันทั้งเว็บ (ต้องโหลด supabase-js ผ่าน <script> ก่อนไฟล์นี้)
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
