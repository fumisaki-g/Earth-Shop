/* ============================================================
   PC CLINIC — shared logic ใช้ร่วมกันทุกหน้า
   ============================================================ */

const STATUS_LABEL = {
  pending:     "รอส่งมอบเครื่อง",
  received:    "ร้านรับเครื่องแล้ว",
  in_progress: "กำลังดำเนินการ",
  ready:       "พร้อมรับเครื่องแล้ว",
  completed:   "รับเครื่องเรียบร้อย",
  cancelled:   "ยกเลิกคิว",
};

const STATUS_ORDER = ["pending", "received", "in_progress", "ready"];

const DEVICE_TYPES = ["โน้ตบุ๊ก", "พีซีตั้งโต๊ะ (คอมประกอบ)", "All-in-One", "อื่นๆ"];

/* ---------- date helpers ---------- */
// นับ "วันทำการ" ข้ามวันอาทิตย์ (ร้านหยุดอาทิตย์) เพื่อประเมินวันรับเครื่องล่วงหน้า
function addWorkingDays(startDateStr, days) {
  const d = new Date(startDateStr + "T00:00:00");
  let added = 0;
  // วันที่รับเครื่องเริ่มนับจากวันถัดไปเสมอ (ต้องมีเวลาให้ช่างตรวจเครื่องก่อน)
  while (added < Math.max(days, 1)) {
    d.setDate(d.getDate() + 1);
    if (d.getDay() !== 0) added++; // ข้ามวันอาทิตย์ (0)
  }
  return d.toISOString().slice(0, 10);
}

function formatThaiDate(dateStr) {
  if (!dateStr) return "-";
  const d = new Date(dateStr + "T00:00:00");
  return d.toLocaleDateString("th-TH", { year: "numeric", month: "long", day: "numeric" });
}

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

/* ---------- status track markup ---------- */
function buildTrackHTML(status) {
  const steps = [
    { key: "pending", label: "ลงคิว" },
    { key: "received", label: "รับเครื่อง" },
    { key: "in_progress", label: "ดำเนินการ" },
    { key: "ready", label: "พร้อมรับ" },
  ];
  if (status === "cancelled") {
    return `<div class="alert alert-red" style="margin-top:10px">ใบงานนี้ถูกยกเลิกแล้ว</div>`;
  }
  const currentIdx = status === "completed" ? steps.length : STATUS_ORDER.indexOf(status);
  return `<div class="ticket-track">${steps
    .map((s, i) => {
      let cls = "";
      if (i < currentIdx) cls = "done";
      else if (i === currentIdx) cls = "current";
      return `<div class="track-step ${cls}"><span class="line"></span><span class="node"></span><small>${s.label}</small></div>`;
    })
    .join("")}</div>`;
}

/* ---------- auth ---------- */
async function getCurrentUser() {
  const { data } = await supabaseClient.auth.getUser();
  return data?.user || null;
}

async function signInWithGoogle(redirectPath = "dashboard.html") {
  await supabaseClient.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: window.location.origin + window.location.pathname.replace(/[^/]+$/, "") + redirectPath },
  });
}

async function signOut() {
  await supabaseClient.auth.signOut();
  window.location.href = "index.html";
}

// วาด avatar / ปุ่มเข้าสู่ระบบบน nav ให้ทุกหน้าโดยอัตโนมัติ
async function mountNavAuth(elId = "navAuthSlot") {
  const slot = document.getElementById(elId);
  if (!slot) return;
  const user = await getCurrentUser();
  if (user) {
    const name = user.user_metadata?.full_name || user.email;
    const avatar = user.user_metadata?.avatar_url;
    slot.innerHTML = `
      <a href="dashboard.html" class="btn btn-ghost btn-sm" style="gap:8px">
        ${avatar ? `<img src="${avatar}" class="avatar" style="width:22px;height:22px">` : ""}
        <span>${name}</span>
      </a>
      <button class="btn btn-ghost btn-sm" id="btnSignOut">ออกจากระบบ</button>
    `;
    document.getElementById("btnSignOut")?.addEventListener("click", signOut);
  } else {
    slot.innerHTML = `<button class="btn btn-primary btn-sm" id="btnSignIn">เข้าสู่ระบบด้วย Google</button>`;
    document.getElementById("btnSignIn")?.addEventListener("click", () => signInWithGoogle());
  }
}

/* ---------- notify on status change since last visit ---------- */
// เก็บสถานะล่าสุดที่เคยเห็นของแต่ละคิวไว้ใน localStorage ของเบราว์เซอร์ผู้ใช้
// พอเข้ามาอีกครั้งแล้วสถานะเปลี่ยน จะเด้งแจ้งเตือนให้ทันที
function checkStatusChanges(bookings) {
  const seenKey = "pcclinic_seen_status";
  const seen = JSON.parse(localStorage.getItem(seenKey) || "{}");
  const changed = [];
  bookings.forEach((b) => {
    if (seen[b.id] && seen[b.id] !== b.status) {
      changed.push(b);
    }
    seen[b.id] = b.status;
  });
  localStorage.setItem(seenKey, JSON.stringify(seen));
  return changed;
}
