/* Service Worker — سهّلي فيزيو (Sahli Physio)
   بيسمح بتثبيت الموقع كتطبيق على الشاشة الرئيسية، وبيخزّن هيكل
   الموقع (الصفحة + الأيقونات + الصور) عشان يفتح بسرعة. بيانات
   Supabase (المحتوى الحي) دايمًا من الشبكة ومش بتتخزن هنا،
   فالمحتوى يفضل محدّث لحظيًا. وكمان بيستقبل إشعارات الدفع
   (Web Push) اللي الأدمن بيبعتها من صفحة الأدمن وبيعرضها على
   الموبايل حتى والموقع مقفل تمامًا. */
const CACHE = "sahli-physio-v3";
const CORE = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./assets/hero.webp",
  "./assets/neuro.webp",
  "./assets/biomechanics.webp",
  "./assets/electro.webp",
  "./assets/physiology.webp",
  "./assets/muscle.webp",
  "./assets/hydro.webp",
  "./assets/biochem.webp",
  "./assets/public-health.webp",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // Supabase وغيره: شبكة مباشرة دايمًا
  if (req.mode === "navigate") {
    // الصفحة: شبكة أولًا (أحدث نسخة)، والكاش بديل لو مفيش نت
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put("./index.html", copy));
          return res;
        })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }
  // الملفات الثابتة: الكاش فورًا للسرعة، وطلب شبكة في الخلفية بيحدّث
  // الكاش (stale-while-revalidate حقيقي) عشان أي ملف اتغيّر على السيرفر
  // يوصل للنسخة المثبّتة عند الفتح اللي بعده من غير ما تستنى تغيير رقم
  // نسخة الكاش — وده جزء من إصلاح «الموقع المثبّت ما بيتحدّثش»
  event.respondWith(
    caches.match(req).then((hit) => {
      const network = fetch(req)
        .then((res) => {
          const copy = res.clone();
          return caches
            .open(CACHE)
            .then((cache) => cache.put(req, copy))
            .then(() => res);
        })
        .catch(() => hit);
      event.waitUntil(network.catch(() => {}));
      return hit || network;
    })
  );
});

/* ---------- إشعارات الدفع (Web Push) ----------
   الإشعار بيتبعت من دالة Supabase ‏(send-push) بمفاتيح VAPID،
   وبيوصل هنا حتى لو الموقع مقفل — العنوان والنص من الأدمن */
self.addEventListener("push", (event) => {
  let data = { title: "سهّلي فيزيو", body: "", url: "./" };
  try {
    if (event.data) data = { ...data, ...event.data.json() };
  } catch (e) {
    if (event.data) data.body = event.data.text();
  }
  event.waitUntil(
    self.registration.showNotification(data.title || "سهّلي فيزيو", {
      body: data.body || "",
      icon: "./icons/icon-192.png",
      badge: "./icons/icon-192.png",
      dir: "rtl",
      lang: "ar",
      data: { url: data.url || "./" },
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || "./";
  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((list) => {
        for (const client of list) {
          if ("focus" in client) return client.focus();
        }
        if (self.clients.openWindow) return self.clients.openWindow(target);
      })
  );
});
