-- =====================================================================
-- سهلي فزيو — Sahli Physio · إعداد Supabase (قاعدة بيانات حية + Realtime)
-- نفّذ الملف ده مرة واحدة فقط:
-- Supabase Dashboard → SQL Editor → New query → الصق الكل → Run
-- =====================================================================

-- ---------- 1) الجداول ----------
-- ملحوظة: دي نفس أعمدة المشروع الحي الحالي بالظبط — المواد ليها معرّف
-- uuid (id) واسم (slug)، والمحتوى بيتربط بالمادة بـ subject_id،
-- وجدول الأسئلة أعمدته question / answer. النسخة الستاتيك بتقرأ
-- وتكتب بنفس الأعمدة دي.
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_en text not null,
  name_ar text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.videos (
  id bigint generated always as identity primary key,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  url text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.files (
  id bigint generated always as identity primary key,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  url text,
  file_type text,
  file_category text not null default 'lecture' check (file_category in ('lecture','section')),
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.questions (
  id bigint generated always as identity primary key,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  question text not null,
  answer text not null,
  topic text,
  image_url text,
  description text,
  created_at timestamptz not null default now()
);

-- المواد الثمانية — سنة تانية علاج طبيعي، الترم الأول (PT13)
insert into public.subjects (slug, name_en, name_ar) values
  ('neuro-anatomy','Neuro-anatomy','تشريح الجهاز العصبي'),
  ('biomechanics','Biomechanics','الميكانيكا الحيوية'),
  ('electro-therapy','Electro-therapy','العلاج بالكهرباء'),
  ('physiology-3','Physiology 3','فسيولوجيا ٣'),
  ('muscle-test','Muscle Test','اختبار العضلات'),
  ('hydro-therapy','Hydro-therapy','العلاج المائي'),
  ('biochemistry-2','Biochemistry 2','الكيمياء الحيوية ٢'),
  ('public-health','Public Health','الصحة العامة')
on conflict (slug) do nothing;

-- ---------- 2) تفعيل Realtime ----------
-- replica identity full عشان أحداث التعديل والحذف توصل بكامل البيانات
alter table public.subjects replica identity full;
alter table public.videos replica identity full;
alter table public.files replica identity full;
alter table public.questions replica identity full;

-- إضافة الجداول لمنشور Realtime (لو الجدول مضاف قبل كده هيظهر تنبيه وتكمل عادي)
alter publication supabase_realtime add table public.subjects;
alter publication supabase_realtime add table public.videos;
alter publication supabase_realtime add table public.files;
alter publication supabase_realtime add table public.questions;

-- ---------- 3) سياسات الأمان (RLS) ----------
-- القراءة: عامة للطلبة (anon + authenticated)
-- الكتابة: من صفحة الأدمن فقط — أي مستخدم مسجّل دخول بـ Supabase Auth
--          (اعمل حساب الأدمن من: Supabase → Authentication → Users → Add user)

alter table public.subjects enable row level security;
alter table public.videos enable row level security;
alter table public.files enable row level security;
alter table public.questions enable row level security;

drop policy if exists "public read" on public.subjects;
create policy "public read" on public.subjects for select using (true);
drop policy if exists "public read" on public.videos;
create policy "public read" on public.videos for select using (true);
drop policy if exists "public read" on public.files;
create policy "public read" on public.files for select using (true);
drop policy if exists "public read" on public.questions;
create policy "public read" on public.questions for select using (true);

drop policy if exists "admin write" on public.videos;
create policy "admin write" on public.videos
  for all to authenticated using (true) with check (true);
drop policy if exists "admin write" on public.files;
create policy "admin write" on public.files
  for all to authenticated using (true) with check (true);
drop policy if exists "admin write" on public.questions;
create policy "admin write" on public.questions
  for all to authenticated using (true) with check (true);
-- المواد ثابتة (الـ 8 مواد) — لا كتابة عليها من الواجهة.

-- ---------- 4) صلاحيات الجداول (GRANTS) ----------
-- من غير الـ grants دي مفتاح الـ publishable/anon بيرجع
-- "permission denied for table" حتى لو سياسات RLS موجودة.
grant select on public.subjects, public.videos, public.files, public.questions to anon, authenticated;
grant insert, update, delete on public.videos, public.files, public.questions to authenticated;

-- ---------- 5) السيمسترات + سجل الزيارات ونشاط الأدمن (لصفحة الإدارة المخفية) ----------
create table if not exists public.semesters (
  slug text primary key,
  name_ar text not null,
  name_en text not null default '',
  term_label text not null default '',
  sort_order int not null default 0
);
insert into public.semesters (slug, name_ar, name_en, term_label, sort_order) values
  ('semester-1','سيمستر 1','Semester 1','الترم الأول',1)
on conflict (slug) do nothing;

-- السيمسترات كمان على Realtime عشان أي سيمستر جديد يوصل للطلبة لحظيًا
alter table public.semesters replica identity full;
alter publication supabase_realtime add table public.semesters;

create table if not exists public.visits (
  id bigint generated always as identity primary key,
  page text not null,
  ip text,
  city text,
  country text,
  created_at timestamptz not null default now()
);

create table if not exists public.activity_log (
  id bigint generated always as identity primary key,
  admin_name text not null default '',
  action text not null,
  kind text not null default '',
  subject_slug text not null default '',
  item_title text not null default '',
  created_at timestamptz not null default now()
);

alter table public.semesters enable row level security;
alter table public.visits enable row level security;
alter table public.activity_log enable row level security;

drop policy if exists "public read" on public.semesters;
create policy "public read" on public.semesters for select using (true);
drop policy if exists "visits insert" on public.visits;
create policy "visits insert" on public.visits for insert with check (true);
drop policy if exists "owner read visits" on public.visits;
create policy "owner read visits" on public.visits for select using (true);
drop policy if exists "activity insert" on public.activity_log;
create policy "activity insert" on public.activity_log for insert to authenticated with check (true);
drop policy if exists "owner read activity" on public.activity_log;
create policy "owner read activity" on public.activity_log for select using (true);

grant select on public.semesters, public.visits, public.activity_log to anon, authenticated;
grant insert on public.visits to anon, authenticated;
grant insert on public.activity_log to authenticated;

-- ---------- 6) التحقق من الأكواد على السيرفر (RPC) ----------
-- مهم: قبل ما تشغّل القسم ده، بدّل النصين اللي بين القوسين تحت
-- (<ADMIN_CODE> و <OWNER_CODE>) بالأكواد الحقيقية بنفسك هنا في
-- SQL Editor — الأكواد لا تُكتب في أي ملف موقع ولا في الريبو.
-- الدوال دي هي اللي النسخة الستاتيك بتناديها للتحقق من كود الأدمن
-- وباسورد صفحة الإدارة، فالأكواد نفسها عمرها ما توصل للمتصفح.
create or replace function public.check_admin_code(candidate text)
returns boolean language sql security definer set search_path = public
as $$ select candidate = '<ADMIN_CODE>' $$;

create or replace function public.check_owner_code(candidate text)
returns boolean language sql security definer set search_path = public
as $$ select candidate = '<OWNER_CODE>' $$;

grant execute on function public.check_admin_code(text) to anon, authenticated;
grant execute on function public.check_owner_code(text) to anon, authenticated;

-- ---------- 7) اقتراحات الزوار (شارك وساعد) ----------
-- الزوار يقدروا يبعتوا اقتراح بس (insert وحالته pending)،
-- والأدمن (authenticated) بس هو اللي يقرأ الاقتراحات ويعدّل حالتها.
create table if not exists public.suggestions (
  id bigint generated always as identity primary key,
  subject_id uuid references public.subjects(id) on delete set null,
  subject_slug text not null default '',
  kind text not null check (kind in ('video','file','question')),
  title text not null default '',
  url text,
  file_category text not null default 'lecture' check (file_category in ('lecture','section')),
  question text,
  answer text,
  topic text,
  image_url text,
  suggester_name text not null default '',
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now()
);

alter table public.suggestions enable row level security;

drop policy if exists "visitors insert suggestions" on public.suggestions;
create policy "visitors insert suggestions" on public.suggestions
  for insert to anon, authenticated with check (status = 'pending');
drop policy if exists "admin read suggestions" on public.suggestions;
create policy "admin read suggestions" on public.suggestions
  for select to authenticated using (true);
drop policy if exists "admin update suggestions" on public.suggestions;
create policy "admin update suggestions" on public.suggestions
  for update to authenticated using (true) with check (true);

grant insert on public.suggestions to anon, authenticated;
grant select, update on public.suggestions to authenticated;

alter table public.suggestions replica identity full;
alter publication supabase_realtime add table public.suggestions;

-- ---------- 8) أعمدة إضافية (للقواعد الموجودة أصلًا) ----------
-- شغّل القسم ده مرة واحدة على المشروع الحي الحالي عشان يضيف الأعمدة
-- الجديدة للجداول الموجودة: قسم الملف (محاضرة/سكشن)، وموضوع السؤال
-- وصورته وشرحه، وموضوع وصورة اقتراحات الأسئلة.
alter table public.files add column if not exists file_category text not null default 'lecture';
alter table public.suggestions add column if not exists file_category text not null default 'lecture';
alter table public.questions add column if not exists topic text;
alter table public.questions add column if not exists image_url text;
alter table public.questions add column if not exists description text;
alter table public.suggestions add column if not exists topic text;
alter table public.suggestions add column if not exists image_url text;

-- ---------- 9) إعدادات الموقع: إعلام الزوار (إعلان/تنبيه عام) ----------
-- جدول إعدادات بسيط (key/value). صف announcement بيحمل نص الإعلام
-- اللي الأدمن بينشره من زرار «إعلام» في صفحة الأدمن، وبيظهر كشريط
-- بارز أعلى الموقع العام لكل الزوار. القراءة عامة، والكتابة للأدمن
-- المسجّل (authenticated) بس. نص فاضي = مفيش إعلام منشور.
create table if not exists public.site_settings (
  key text primary key,
  value text not null default ''
);

alter table public.site_settings enable row level security;

drop policy if exists "public read site settings" on public.site_settings;
create policy "public read site settings" on public.site_settings
  for select to anon, authenticated using (true);
drop policy if exists "admin write site settings" on public.site_settings;
create policy "admin write site settings" on public.site_settings
  for insert to authenticated with check (true);
drop policy if exists "admin update site settings" on public.site_settings;
create policy "admin update site settings" on public.site_settings
  for update to authenticated using (true) with check (true);
drop policy if exists "admin delete site settings" on public.site_settings;
create policy "admin delete site settings" on public.site_settings
  for delete to authenticated using (true);

grant select on public.site_settings to anon, authenticated;
grant insert, update, delete on public.site_settings to authenticated;

alter table public.site_settings replica identity full;
alter publication supabase_realtime add table public.site_settings;

-- ---------- 10) الامتحانات + الأسئلة المجهولة ----------
-- أ) جدول الامتحانات: مواعيد الميدتيرم/العملي/الفاينال اللي بتظهر في
--    قسم «الامتحانات الجاية» في الرئيسية مع عدّاد تنازلي وجدول كامل.
--    القراءة عامة لكل الزوار، والكتابة والحذف للأدمن المسجّل بس.
--    subject_slug نص اختياري بيربط الامتحان بمادة (نفس slug المادة).
create table if not exists public.exams (
  id bigint generated always as identity primary key,
  title text not null,
  exam_type text not null default 'other' check (exam_type in ('midterm','practical','final','other')),
  subject_slug text,
  exam_date timestamptz not null,
  note text,
  created_at timestamptz not null default now()
);

alter table public.exams enable row level security;

drop policy if exists "public read exams" on public.exams;
create policy "public read exams" on public.exams
  for select to anon, authenticated using (true);
drop policy if exists "admin insert exams" on public.exams;
create policy "admin insert exams" on public.exams
  for insert to authenticated with check (true);
drop policy if exists "admin update exams" on public.exams;
create policy "admin update exams" on public.exams
  for update to authenticated using (true) with check (true);
drop policy if exists "admin delete exams" on public.exams;
create policy "admin delete exams" on public.exams
  for delete to authenticated using (true);

grant select on public.exams to anon, authenticated;
grant insert, update, delete on public.exams to authenticated;

alter table public.exams replica identity full;
alter publication supabase_realtime add table public.exams;

-- ب) الأسئلة المجهولة: الطالب يسأل من غير اسم ومن غير تسجيل دخول —
--    مفيش أي عمود للاسم أصلًا. السؤال بيتدخل بحالة pending (مراجعة
--    الأدمن)، والأدمن يجاوب وينشره (status = 'published') فيظهر في
--    «الأسئلة المتكررة» لكل الزوار، أو يحذفه. القراءة العامة للمنشور
--    بس؛ قراءة الكل والتعديل والحذف للأدمن المسجّل بس.
create table if not exists public.anon_questions (
  id bigint generated always as identity primary key,
  question_text text not null,
  answer_text text,
  status text not null default 'pending' check (status in ('pending','published')),
  created_at timestamptz not null default now()
);

alter table public.anon_questions enable row level security;

drop policy if exists "visitors ask anonymous" on public.anon_questions;
create policy "visitors ask anonymous" on public.anon_questions
  for insert to anon, authenticated with check (status = 'pending');
drop policy if exists "public read published anon questions" on public.anon_questions;
create policy "public read published anon questions" on public.anon_questions
  for select to anon using (status = 'published');
drop policy if exists "admin read anon questions" on public.anon_questions;
create policy "admin read anon questions" on public.anon_questions
  for select to authenticated using (true);
drop policy if exists "admin update anon questions" on public.anon_questions;
create policy "admin update anon questions" on public.anon_questions
  for update to authenticated using (true) with check (true);
drop policy if exists "admin delete anon questions" on public.anon_questions;
create policy "admin delete anon questions" on public.anon_questions
  for delete to authenticated using (true);

grant insert on public.anon_questions to anon, authenticated;
grant select on public.anon_questions to anon, authenticated;
grant update, delete on public.anon_questions to authenticated;

alter table public.anon_questions replica identity full;
alter publication supabase_realtime add table public.anon_questions;

-- ج) ردود الزوار المجهولة على الأسئلة المنشورة: أي حد يرد من غير اسم
--    (مفيش عمود اسم بردو). الإدراج مسموح للزوار بشرط السؤال يكون
--    منشور — الشرط بيتنفذ بسياسة insert بمراجعة جدول الأسئلة،
--    والقراءة عامة، والحذف للأدمن المسجّل بس.
create table if not exists public.anon_replies (
  id bigint generated always as identity primary key,
  question_id bigint not null references public.anon_questions(id) on delete cascade,
  reply_text text not null,
  created_at timestamptz not null default now()
);

alter table public.anon_replies enable row level security;

drop policy if exists "visitors reply anonymous" on public.anon_replies;
create policy "visitors reply anonymous" on public.anon_replies
  for insert to anon, authenticated with check (
    exists (select 1 from public.anon_questions q where q.id = question_id and q.status = 'published')
  );
drop policy if exists "public read anon replies" on public.anon_replies;
create policy "public read anon replies" on public.anon_replies
  for select to anon, authenticated using (true);
drop policy if exists "admin delete anon replies" on public.anon_replies;
create policy "admin delete anon replies" on public.anon_replies
  for delete to authenticated using (true);

grant insert, select on public.anon_replies to anon, authenticated;
grant delete on public.anon_replies to authenticated;

alter table public.anon_replies replica identity full;
alter publication supabase_realtime add table public.anon_replies;

-- ---------- 11) تغيير باسورد صفحة الإدارة من جوه الصفحة نفسها ----------
-- الباسورد الحالي معرّف كنص جوه دالة check_owner_code في قسم 6.
-- الدالة دي بتتحقق من الباسورد الحالي الأول، وبعدين بتعيد تعريف
-- check_owner_code بالباسورد الجديد — فالتغيير بيتم على السيرفر،
-- والباسورد الجديد مش بيتحفظ في أي ملف موقع ولا في الريبو.
-- ملحوظات مهمة:
--  * شغّل القسم ده بعد ما تظبط قسم 6 (النص اللي مكان <OWNER_CODE>
--    تحت لازم يبقى الباسورد الحالي وقت التشغيل).
--  * لو غيّرت الباسورد من الصفحة نفسها بعد كده، حدّث النص اللي مكان
--    <OWNER_CODE> هنا قبل أي تشغيل تاني للقسم ده — إعادة التشغيل
--    بترجّع المقارنة للباسورد المكتوب هنا.
--  * الباسورد لو اتنسى خالص لا يمكن استرجاعه (مفيش نسخة نصية منه
--    بره الدالة) — الحل الوحيد وقتها تعديل قسم 6 يدويًا من هنا.
create or replace function public.change_owner_code(current_code text, new_code text)
returns boolean language plpgsql security definer set search_path = public
as $$
begin
  if new_code is null or length(new_code) < 4 or length(new_code) > 64 then
    return false;
  end if;
  if current_code is distinct from '<OWNER_CODE>' then
    return false;
  end if;
  execute format(
    'create or replace function public.check_owner_code(candidate text) returns boolean language sql security definer set search_path = public as $fn$ select candidate = %L $fn$',
    new_code
  );
  return true;
end $$;

grant execute on function public.change_owner_code(text, text) to anon, authenticated;

-- ---------- 12) تسجيل دخول الأدمن التلقائي في النسخة الستاتيك ----------
-- المشكلة اللي بيحلها القسم ده: صفحة الأدمن في النسخة الستاتيك كانت
-- بتتحقق من الكود عبر check_admin_code (قسم 6) وبتفتح للعرض بس، لكن
-- الكتابة في الجداول مقفولة بسياسات RLS على دور authenticated،
-- والصفحة مكانتش بتعمل أي جلسة Supabase Auth — فأي إضافة/حذف كان
-- بيفشل («سجّل دخول الأدمن الأول»).
-- الحل: باسورد حساب الأدمن المشترك في Supabase Auth بتتظبط على نفس
-- قيمة كود الأدمن، وبعد ما الصفحة تتحقق من الكود بترجع إيميل الحساب
-- من الدالة اللي تحت (بترجّعه بس لو الكود المبعوت صح) وبتعمل
-- signInWithPassword بالإيميل + الكود اللي الأدمن كتبه — فالدخول
-- والكتابة بيشتغلوا بالكود بس، من غير إيميل أو باسورد في أي ملف.
-- قبل التشغيل: بدّل <ADMIN_CODE> بنفس كود الأدمن اللي حطيته في
-- قسم 6، و<ADMIN_EMAIL> بإيميل حساب الأدمن المشترك في Supabase Auth.
create or replace function public.admin_signin_email(candidate text)
returns text language sql security definer set search_path = public
as $$ select case when candidate = '<ADMIN_CODE>' then '<ADMIN_EMAIL>' else null end $$;

grant execute on function public.admin_signin_email(text) to anon, authenticated;

-- مزامنة باسورد حساب الأدمن المشترك مع كود الأدمن (بتتشغّل مرة
-- واحدة، وتتعاد لو كود الأدمن اتغيّر — مع تحديث قسم 6 والدالة
-- اللي فوق بنفس القيمة الجديدة).
update auth.users
set encrypted_password = extensions.crypt('<ADMIN_CODE>', extensions.gen_salt('bf')),
    updated_at = now()
where email = '<ADMIN_EMAIL>';

-- ---------- 13) تخزين الملفات المرفوعة من صفحة الأدمن (Storage) ----------
-- باكت عام للقراءة: الأدمن يرفع ملف من جهازه من صفحة الأدمن (PDF أو
-- Word أو PowerPoint أو صور أو أي ملف، وصور الأسئلة كمان) فيترفع هنا،
-- واللينك العام اللي بيرجع بيتسجل كلينك المحتوى — الطلبة بيفتحوا
-- الملفات باللينك العام من غير أي دخول. الرفع والتعديل والحذف
-- للأدمن المسجّل بس (نفس جلسة Supabase Auth اللي بتتعمل تلقائيًا
-- بعد إدخال الكود — قسم 12)، فالرفع بيشتغل بالكود بس.
insert into storage.buckets (id, name, public)
values ('sahli-files', 'sahli-files', true)
on conflict (id) do nothing;

drop policy if exists "public read uploads" on storage.objects;
create policy "public read uploads" on storage.objects
  for select to anon, authenticated using (bucket_id = 'sahli-files');

drop policy if exists "admin insert uploads" on storage.objects;
create policy "admin insert uploads" on storage.objects
  for insert to authenticated with check (bucket_id = 'sahli-files');

drop policy if exists "admin update uploads" on storage.objects;
create policy "admin update uploads" on storage.objects
  for update to authenticated using (bucket_id = 'sahli-files') with check (bucket_id = 'sahli-files');

drop policy if exists "admin delete uploads" on storage.objects;
create policy "admin delete uploads" on storage.objects
  for delete to authenticated using (bucket_id = 'sahli-files');

-- ---------- 14) جداول الريكوردات والملخصات ----------
-- قسمان جديدان في كل مادة: «ريكوردات» (تسجيلات صوتية) و«ملخصات»،
-- وكل واحد فيهم متقسم زي الملفات بالظبط: محاضرات (نظري) وسكاشن
-- (عملي) عبر file_category — فالعملي ليه نفس الأقسام اللي للنظري
-- في كل مادة. النسخة الستاتيك بتقرأ الجدولين دول وبتكتب فيهم من
-- صفحة الأدمن بنفس جلسة الأدمن التلقائية (قسم 12)، والمنصة
-- الرئيسية بتخزن نفس الأنواع في جدول المحتوى الموحّد عندها.
-- نفّذ القسم ده مرة واحدة في SQL Editor على المشروع الحي.
create table if not exists public.recordings (
  id bigint generated always as identity primary key,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  url text,
  file_category text not null default 'lecture' check (file_category in ('lecture','section')),
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.summaries (
  id bigint generated always as identity primary key,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  title text not null,
  url text,
  file_type text,
  file_category text not null default 'lecture' check (file_category in ('lecture','section')),
  description text,
  created_at timestamptz not null default now()
);

alter table public.recordings replica identity full;
alter table public.summaries replica identity full;

alter publication supabase_realtime add table public.recordings;
alter publication supabase_realtime add table public.summaries;

alter table public.recordings enable row level security;
alter table public.summaries enable row level security;

drop policy if exists "public read" on public.recordings;
create policy "public read" on public.recordings for select using (true);
drop policy if exists "public read" on public.summaries;
create policy "public read" on public.summaries for select using (true);

drop policy if exists "admin write" on public.recordings;
create policy "admin write" on public.recordings
  for all to authenticated using (true) with check (true);
drop policy if exists "admin write" on public.summaries;
create policy "admin write" on public.summaries
  for all to authenticated using (true) with check (true);

grant select on public.recordings, public.summaries to anon, authenticated;
grant insert, update, delete on public.recordings, public.summaries to authenticated;
