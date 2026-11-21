/* Service Worker — سهلي فزيو (Sahli Physio)
   بيسمح بتثبيت الموقع كتطبيق على الشاشة الرئيسية، وبيخزّن هيكل
   الموقع (الصفحة + الأيقونات + الصور) عشان يفتح بسرعة. بيانات
   Supabase (المحتوى الحي) دايمًا من الشبكة ومش بتتخزن هنا،
   فالمحتوى يفضل محدّث لحظيًا. */
const CACHE = "sahli-physio-v1";
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
  // الملفات الثابتة: كاش أولًا، وتتحدث في الخلفية
  event.respondWith(
    caches.match(req).then(
      (hit) =>
        hit ||
        fetch(req).then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy));
          return res;
        })
    )
  );
});
