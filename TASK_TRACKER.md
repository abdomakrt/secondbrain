# TASK_TRACKER.md — العقل الثاني (Second Brain)

> مرجع دائم: [ ] غير منجز، [x] منجز. تُنفَّذ المراحل بالترتيب (M0→M8). لا تُضاف مكتبات/ميزات خارج المرحلة الحالية.

## Phase 0 — Spikes & Scaffold (M0) — الحالة النهائية (2026-11-11)
- [x] تثبيت Flutter 3.47 + Dart 3.13 على Linux (Flutter 3.47.9 / Dart 3.13.7 في `/media/storage/tools/flutter`).
- [x] تثبيت system deps: `clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev xclip xdotool` (sudo). `flutter doctor`: **Linux toolchain ✓** — `flutter build linux` ناجح والتطبيق يعمل ويبقى حيًا على سطح المكتب. (Android SDK + Chrome ما زالا ناقصين — تثبيت Android SDK مؤجَّل بنود مستقلة ~2GB.)
- [x] `flutter create secondbrain` (Android + Linux).
- [~] S1 (نتيجة جزئية مهمة): tray ✓ (`tray_manager` على Cinnamon/X11 — يتطلب ملف PNG حقيقي، أسماء أيقونات النظام لا تعمل)، قراءة PRIMARY ✓ (`xclip`)، عنوان النافذة النشطة ✓ (`xdotool getactivewindow getwindowname`)، تسجيل الاختصار ✓ (`hotkey_manager` — Ctrl+Alt+Space فشل تسجيله (محجوز) وCtrl+Alt+J نجح). **لكن توصيل الأحداث ✗**: لا `hotkey_manager` ولا استيلاء XGrabKey خام (python-Xlib) يستقبل ضغطات حقيقية (مؤكَّد من المستخدم بالضغط اليدوي والتحقق من xmodmap: Alt_L/Alt_R كلاهما Mod1). في المقابل **xinput test-xi2 --root يستقبل الضغطات** — مسار بديل واعد للمسكة (XI2 listener بلا استيلاء، أو تسجيل الاختصار عبر Cinnamon نفسها gsettings/csd-media-keys). **تم حسم الأمر في Phase 8**: الاختصار العام عبر `xinput test-xi2 --root` مع تتبّع حالة الـModifiers من الأحداث الخام (صيغة XI2 لا تعطي `state`)، وهو يعمل فعليًا — انظر Phase 8. spike محفوظ في `spikes/s1_hotkey/`. قياس <500ms ×20 معلّق على اختيار الآلية.
- [ ] S2: شهادة ذاتية التوقيع + تحقق بالبصمة + اقتران QR — يحتاج جهاز Android حاضرًا (لا يمكن محاكاته).
- [ ] S3: اكتشاف mDNS — يحتاج جهازًا ثانيًا/شبكة فعلية.
- [x] S4: FTS5 + **20k** عناصر عربية/إنجليزية — **p95 = 47–92ms** (الحد §6.5: <200ms) ✓ على desktop؛ البذر (20k في معاملة واحدة) يستغرق ~180s (ملحوظة للأداء المستقبلي للاستيراد). الاختبار: `test/spikes/s4_fts_20k_test.dart`. إعادة القياس على هاتف Android عند توفر الأداة.
- [ ] S5: Dry run على Takeout — **مؤجَّل مع Phase 3 (Keep import) إلى v2** بقرار المستخدم.
- [x] S6: Markdown RTL — سلوك flutter_markdown موثّق ومُثبَّت: الفقرة العربية ترث RTL من البيئة ✓، السطر المفرد يُعرض كسطر جديد (`softLineBreak: true`) ✓، وكتل الكود **لا تُجبر LTR في المكتبة** (ترث الاتجاه المحيط) — أُنشئ `ArabicMarkdownBody` (بتاص `lib/features/knowledge/widgets/arabic_markdown.dart`) يجبر كتل الكود على LTR ويُستخدم في الشاشتين. الاختبارات: `test/spikes/s6_markdown_rtl_test.dart`.
- [x] تهيئة l10n: `app_ar.arb` (~95 مفتاحًا) + `Directionality` RTL للتطبيق كله + **خط عربي مضمّن** (Noto Sans Arabic Regular+Bold من notofonts v2.013 في `assets/fonts/` مضبوط كـ fontFamily افتراضي).
- [x] إعداد CI (`.github/workflows/ci.yml`: analyze + tests كاملة + بناء Linux debug). **ملاحظة**: مجلد العمل أصبح مستودع git (تهيئة 2026-11-12، فرع `main`) — CI سيعمل فور الرفع إلى GitHub.
- [x] Gate: الحزم بقيد caret (^) وليس pinned (قرار موثق في Phase 1)؛ S1/S6 أثبتا صلاحية الاختيارات، S2/S3 تتحقق عند توفر الأجهزة.

## Phase 1 — Infrastructure & Database Setup (الحالية)
> الحالة: **مكتملة** — `flutter test` 33/33 ناجحة، `flutter analyze` نظيف. أُضيفت `unorm_dart` (NFKC للخطوة 1 من §6.2) و`sqlite3_flutter_libs` (تضمين sqlite3 على Android) — كلاهما مطلوب لصحة القاعدة. الحزم بقيد caret (^) وليس pinned.
- [x] إضافة الحد الأدنى من التبعيات: `drift`, `sqlite3`, `uuid`, `build_runner`/`drift_dev` (dev).
- [x] إنشاء `lib/core/`: UUIDv7 (`ids.dart` — يشمل UUIDv5 للجداول الزوجية)، HLC (`hlc.dart` — format/parse/recv بعرض ثابت)، الوقت عبر HLC (UTC ms).
- [x] إنشاء `lib/data/`: `AppDatabase` (drift) — `inMemory()` للاختبارات و`atFile()` عبر `NativeDatabase.createInBackground`.
- [x] تعريف الجداول المتزامنة + الأعمدة القياسية (`lib/data/tables.dart`).
- [x] تعريف الجداول المحلية (oplog, sync_state, devices, item_versions, local_paths, import_map, import_batches, capture_drafts) + `items_fts` عبر customStatement.
- [x] `PRAGMA journal_mode=WAL` في `beforeOpen` + `schemaVersion=1` (drift يضبط user_version).
- [x] ترحيلات (Migrations) منظمة + اختبار إعادة فتح/ترقية + ثبات `device_id` (يُنشأ مرة في settings).
- [x] تنفيذ `WriteGate` (`lib/data/write_gate.dart`): transaction واحد، stamp `updated_at`/`hlc`، إدخال `oplog`، تحديث FTS.
- [x] فهرس FTS5 (`items_fts`) + تطبيع عربي §6.2 كاملًا (`lib/core/text_normalizer.dart`) + stems §6.3 + بناء تعبير MATCH.
- [x] زرع الأنواع المدمجة الـ12 في `item_types` عند أول إقلاع (لا تكرار عند إعادة الفتح).
- [x] لا FKs صارمة على الجداول المتزامنة؛ فهارس فريدة لـ item_tags/links + فهارس جزئية `WHERE deleted_at IS NULL` + `idx_oplog_record`.
- [x] اختبارات: مخطط/فهارس/WAL/user_version، WriteGate (stamp/oplog/ترتيب HLC)، FTS بحث عربي (تشكيل/«ال»/وسوم)، HLC (format/parse/monotonic/overflow/recv)، التطبيع (جدول حالات §6.2)، بذر الأنواع.

## Phase 2 — Knowledge & Search (M1)
> الحالة: **مكتملة (المنطق + الواجهة)** — `flutter analyze` نظيف، `flutter test` 56/56 (33 بنية تحتية + 13 مستودعات/بحث + 5 واجهة + 4 golden + 1 أداء).
> ملاحظة على المنصتين: المنطق والاختبارات كلها تعمل على Linux desktop، و**سطح المكتب أصبح يعمل** بعد تثبيت system deps في Phase 0 (بناء debug + تشغيل ناجح)؛ الاختبار الفعلي على جهاز Android يتأجل لتثبيت Android SDK — لا حجب منطقي متوقع.
> ملاحظة معمارية: بدون Riverpod/go_router عمدًا (Navigator + `AppScope` InheritedWidget) — تبسيط مقصود للموجة الأولى.
- [x] كيانات المعرفة: إنشاء/تعديل/عرض Markdown، الأنواع، الوسوم، العلاقات، المرفقات، Inbox (تعمل على desktop؛ تحقق Android لاحقًا مع system deps).
- [x] سلة محذوفات (استرجاع فقط؛ الاحتفاظ/المسح النهائي في مرحلة Backup وفق المبدأ) + آخر نسختين (`item_versions` بقاعدة 30 دقيقة §7.5).
- [x] مصغّرات الصور في القوائم (عرض بمستوى `Image.file(cacheWidth:)`) + حد أقصى 50 MB للمرفق في `AttachmentsRepository`.
- [x] بحث موحد + تصفية (Type/Tag/Date/Archived/Inbox؛ Project/Course محجوزة بالواجهة، الخدمة تدعمها) + snippets على النص الأصلي + bm25 أوزان 10/1/2/5/1 + دفعة المثبّت + زر "العناصر المرتبطة".
- [x] Golden tests (RTL) للشاشات الأساسية: home/edit/search/detail (بساعة ثابتة `HlcClock(nowMs:)` لثبات الطوابع؛ خط Ahem يعرض العربية مربعات — اختبار تخطيط سليم).
- [x] أداء: 1000 عنصر في معاملة واحدة + 33 استعلامًا عربيًا بالمتغيرات الإملائية — **p95 = 4ms** (الحد §6.5: <200ms؛ هدف 20k على هاتف يبقى لـ S4).
> فجوة معروفة موثقة في المواصفة نفسها («يُوسّع لاحقًا» §6.3): الأصلان (stems) يشملان الرموز الأطول من 4 حرفًا فقط بعد حذف «ال»، فالاستعلام بجذر قصير (مثل «شبكه») لا يطابق عنوانًا بـ«الشبكة» حتى الآن — يُعالج عند S4 بعد اختبار استعلامات حقيقية.
> درس تقني: drift + widget tests — أي قراءة DB بعد تفاعل الواجهة يجب أن تكون داخل `tester.runAsync` (وإلا تعلق في fake-async)؛ أي `FutureBuilder` يبني future في كل build يعلّق `pumpAndSettle` — استُبدل بويدجتات stateful تحمّل مرة واحدة (`didChangeDependencies`).

## Phase 3 — Google Keep Import (M2) — **مؤجَّلة إلى الإصدار الثاني** (قرار 2026-11-11)
> لا اعتماد من Phase 4 على هذه المرحلة؛ حقول المصدر جاهزة في المخطط (`source_kind/source_url/source_app`, `attachments.originalRef`) فلا ترحيل مطلوب عند العودة.
- [ ] محلل ZIP/مجلد Takeout (قراءة تدفقية).
- [ ] Dry run + معاينة + اختيار (تصنيف/أرشيف/محذوف).
- [ ] تنفيذ (دفعات 100) + تقرير.
- [ ] منع التكرار (`source='google_keep'`, `source_key=createdTimestampUsec`, `content_hash`).
- [ ] Fixtures من 4 عينات Keep + اختبارات (غياب labels/attachments، عنوان فارغ، مرفق مفقود، إعادة استيراد، تعديل بعد الاستيراد).

## Phase 4 — Backup / Restore (M3) — مكتمل (2026-11-11)
- [x] صيغة `.sbbackup` (ZIP): manifest.json + db/secondbrain.sqlite + blobs/<2hex>/<sha256> (`lib/backup/backup_service.dart`).
- [x] لقطة متسقة عبر `VACUUM INTO` (نتظر `await` للعبارة، والملف الهدف يجب ألا يكون موجودًا).
- [x] استعادة: تحقق manifest + SHA-256 + فحص سلامة عبر sqlite3 خام (فتح drift يلوث WAL)، نسخة أمان تلقائية في `<support>/safety/` (آخر 3)، حذف `-wal/-shm/-journal` الجانبية قبل النسخ، تبديل ذري، `db_epoch` جديد (settings + sync_state)، إعادة بناء FTS، إعادة فتح الحزمة عبر `AppDeps` وتبديلها في الواجهة (`appDepsSwapRequest`).
- [x] زر «التحقق من النسخة» في شاشة النسخ (استعادة في مجلد مؤقت + تقرير عدّادات/مرفقات ناقصة أو تالفة) + اختبار آلي dump → wipe → restore → مقارنة كاملة (`test/backup/backup_test.dart`، 8 اختبارات).
- [x] نسخ تلقائي يومي عند الإقلاع (مفتاح `auto_backup_daily`، الاحتفاظ بآخر 7). **عند الخروج مؤجَّل** — يتطلب `AppLifecycleState.detached` hook وتجربته فعليًا؛ يُنفَّذ لاحقًا أو في v2. **التحقق على المنصتين معلّق** على نظام deps السطحي (sudo) — منطق الخدمة مُختبَر آليًا على Linux.
- [x] تصدير Markdown (YAML Front Matter + مجلد attachments + `export.json`) في `lib/backup/export_service.dart` + شاشة `lib/features/backup/backup_screen.dart` بأزرار: إنشاء نسخة/تحقق/استعادة (بتأكيد)/تصدير/مفتاح النسخ اليومي، مع اختبار واجهة للتحويل.

## Phase UI — واجهة المستخدم (UI_SPEC.md)
> الحالة: **مكتملة للمرحلة الأولى + الثانية (بدون محرّك المزامنة/الاستيراد)** — `flutter analyze` نظيف، `flutter test` 101/101 ناجحة، وبناء Linux debug ناجح.
- [x] **الهيكل (AppShell)**: شريط تنقل سفلي على Android (الرئيسية/المهام/المشاريع/المعرفة/المزيد)، شريط جانبي ثابت + شريط علوي (بحث/إضافة سريع/حالة اتصال) على الكمبيوتر، ولوحة تفاصيل جانبية عند عرض النافذة (≥1100px) وإلا مسار منسدل. `lib/features/shell/`.
- [x] **الشاشات**: UI-01 الإعداد، UI-02 لوحة التحكم، UI-03/04 المهام، UI-05/06 المشاريع، UI-07/08 المعرفة، UI-09 البحث الموحّد (معرفة + مشاريع + مهام + كورسات)، UI-10 الوارد، UI-11/12 الكورسات والدروس، UI-13 نافذة الالتقاط، UI-14 استيراد Keep (الواجهة فقط)، UI-15 الإعدادات.
- [x] **المكوّنات المشتركة** (§7): `AppShell, Sidebar, BottomNavigation, GlobalSearch, QuickAddMenu, ProjectCard, TaskItem, ProgressBar, KnowledgeCard, TagChip, PriorityIndicator, ConnectionStatus, EmptyState, ConfirmDialog, CaptureWindow` في `lib/features/common/` و`lib/features/shell/`.
- [x] **RTL وإمكانية الوصول**: `Directionality` RTL للتطبيق كله، روابط/مصادر/عناوين بلغة LTR، حالة الأولوية/الاتصال/التقدم بنص + أيقونة (لا لون وحده)، أهداف لمس مناسبة، لكل شاشة حالات تحميل/فراغ/خطأ/انقطاع، وتأكيد قبل الحذف/الاستيراد/الاستعادة.
- [x] **الترجمة**: `app_ar.arb` (~260 مفتاحًا) لكل النصوص — لا نصوص UI مكتوبة داخل الكود.
- [x] **الاختبارات**: 30 اختبار واجهة (shell/لوحة/مشاريع/مهام/معرفة/كورسات/التقاط/إعداد) + 2 اختبار وحدة للتقدم وقواعد المهام + 3 goldens RTL (قائمة المعرفة، نتائج البحث، تفاصيل العنصر).
- [ ] نقل الاستيراد الفعلي (Google Keep) — مؤجَّل إلى v2 بقرار المالك.
- [x] الالتقاط التلقائي على الكمبيوتر عبر X11 (hotkey + selection/clipboard + عنوان النافذة) — يعمل ومُتحقَّق منه يدويًا.
- [ ] أيقونة في شريط النظام (tray) + تشغيل تلقائي — تبقى لـ M8.

## Phase 5 — Projects / Tasks / Plan (M4)
> الحالة: **الواجهة مكتملة على المنصتين** — طبقة البيانات (مستودعات المشاريع/المهام + حساب التقدم) والواجهة (لوحة التحكم، المشاريع، المهام، الجدول اليومي) منفّذة ومُختبَرة. المتبقّي: ربط المجلدات، التذكيرات المحلية (plugin)، وشاشة «العودة للمشروع» كاختصار مستقل.
- [x] طبقة البيانات: `ProjectsRepository` (المشاريع + المراحل + نقطة التوقف/الخطوة التالية + `active_capture_project_id`)، `TasksRepository` (المهام/الفرعيات/التأجيل/الترتيب/الاستحقاق/التاريخ المخطط)، `SettingsRepository` (إعدادات محلية: المظهر، اللغة، مشروع الالتقاط النشط، الاختصار، أقسام لوحة التحكم).
- [x] حساب التقدم (auto/manual + المراحل) في `lib/domain/progress.dart`، وقواعد المهام في `lib/domain/task_rules.dart` (مصفوفة أيزنهاور، المتأخر، الفرز) — مع اختبارات وحدة.
- [x] **لوحة التحكم (UI-02)**: التاريخ والتحية، ملخص اليوم (إجمالي/مكتمل/متبقي/متأخر)، أهم مهام اليوم، الجدول اليومي الزمني، المشاريع النشطة (تقدم + آخر نشاط + الخطوة التالية)، الكورس الحالي والدرس التالي، آخر المعرفة المحفوظة، عناصر الوارد، تنبيهات المتأخر — كل قسم محدود مع «عرض الكل» (لا ازدحام).
- [x] **شاشة المهام (UI-03)**: اليوم/القادمة/المتأخرة/الكل، تصفية بالمشروع/الحالة/الأهمية، إكمال من القائمة، تأجيل إلى الغد.
- [x] **تفاصيل المهمة (UI-04)**: العنوان، الوصف، المشروع، الأهمية والاستعجال (مصفوفة أيزنهاور كنص لا لون فقط)، تاريخ ووقت الاستحقاق، المدة التقديرية، الحالة، خطوات فرعية، إجراءات (حفظ/إكمال/تأجيل/فتح المشروع/نقل للسلة).
- [x] **شاشة المشاريع (UI-05)** و**تفاصيل المشروع (UI-06)**: تبويبات (نظرة عامة/المهام/المعرفة/القرارات/المرفقات)، شريط تقدم + «لا مهام» بدل 0% مصطنع، إضافة مهمة/معرفة مرتبطة، تعيين مشروع الالتقاط النشط، تحديث نقطة التوقف والخطوة التالية.
- [x] الجدول اليومي المرن: `planned_date` + `planned_start_min` + خط زمني، و«غير مجدولة» ضمن «القادمة».
- [ ] ربط مجلدات (local_paths) على desktop فقط (فتح/نسخ/تحقق عند الفتح).
- [ ] تذكيرات محلية.
- [ ] شاشة «العودة للمشروع» (الهدف، آخر نشاط، الخطوة التالية، آخر 5 عناصر معرفة).

## Phase 6 — Courses (M5)
> الحالة: **الواجهة مكتملة** — `CoursesRepository` + شاشات الكورسات والدروس.
- [x] Course → Units → Lessons؛ الدرس الحالي ونقطة التوقف (`CoursesRepository`).
- [x] تقدم الكورس + «المتبقي» + آخر درس والدرس التالي في بطاقة الكورس.
- [x] عناصر معرفة مربوطة بـ lesson/course؛ نوع «سؤال» (`answer_md` + `reviewed_at` + «بانتظار المراجعة»).
- [x] **شاشة الدرس (UI-12)**: «احفظ ملاحظة من هذا الدرس» من داخل الشاشة (شرط أساسي في UI_SPEC)، «أنشئ مهمة من هذا الدرس»، ملخص ما تعلمته، ملاحظات ومعلومات مهمة، أسئلة ونقاط للمراجعة.

## Phase 7 — Sync & Pairing (M6)
> الحالة: **الواجهة فقط** — `lib/sync/connection.dart` (غير مقترن/جارٍ الاتصال/متصل/فشل/الخادم غير متاح) + واجهة `ConnectionService` + شاشة الإعداد (UI-01) + قسم الاتصال في الإعدادات. المحرك الحقيقي (خادم HTTPS، اقتران QR، شهادات) لم يُنفَّذ → الواجهة تصرّح بأن الخادم غير متاح بدل ادعاء الاتصال.
- [ ] HLC merge + قاعدة الفوز على مستوى السجل.
- [ ] خادم HTTPS (`shelf`) داخل التطبيق + `HttpServer.bindSecure`; توليد شهادة ECDSA P-256 + بصمة.
- [ ] اقتران QR (سر 32 bytes، 2 min، مرة واحدة) + token 256-bit (hash only) + Android Keystore.
- [ ] endpoints: hello/pair/push/pull/blobs/session; حد 500; protocol_version.
- [ ] أمان: قبول عناوين الشبكات الخاصة فقط، 5 محاولات اقتران فاشلة ← إيقاف مؤقت، إلغاء الاقتران يبطل token فورًا، سجل أخطاء دون محتوى المستخدم، لا فتح منافذ في الراوتر.
- [ ] mDNS + last IP + manual; فحص clock skew (warn >2min, reject >24h).
- [ ] مرافق Blobs (sha256 path، idempotent) + sync_state + db_epoch.
- [ ] اختبارات: تعديل متزامن، حذف vs تعديل، ترتيب وصول، انقطاع، replay.

## Phase 8 — Quick Capture (M7)
> الحالة: **الالتقاط الفعلي يعمل على X11** (مُتحقَّق منه يدويًا على جهاز المستخدم: X11/Cinnamon + Mesa) — الاختصار العام مسجَّل عبر `xinput test-xi2 --root` (لأن `XGrabKey` لا يسلّم الأحداث على هذا النظام حسب S1)، وقراءة التحديد/الحافظة عبر `xclip`، وعنوان النافذة والتطبيق عبر `xdotool`/`xprop`.
- [x] نافذة الالتقاط بالحقول + مراجعة قبل الحفظ + إرسال إلى Inbox عند غياب المشروع النشط.
- [x] واجهة `DesktopCapturePlatform` + تنفيذ X11 كامل (`lib/platform/desktop/x11_capture.dart`).
- [x] **الاختصار العام**: `X11HotkeyListener` يتابع أحداث XI2 يبني حالة الـModifiers بنفسه (صيغة `xinput test-xi2` لا تعطي `state`) + حل تعارضات التكرار (نفس الضغط يُبلَّغ مرتين) + قتل المستمعين اليتما عند الإقلاع (تفادي `BadAccess`).
- [x] **قراءة المحتوى**: التحديد المحدد (PRIMARY) ثم الحافظة (قراءة فقط — لا تعديل للحافظة) + عنوان النافذة + اسم التطبيق (WM_CLASS).
- [x] **التحقق من تسجيل الاختصار في الإعدادات**: زر يغيّر الاختصار ويعيد تسجيله فعليًا ويعرض النتيجة (نجاح/فشل) + صف «بيئة سطح المكتب» (الجلسة، العرض، توفر xclip/xinput).
- [x] **معالج أخطاء عام** (`lib/core/app_logger.dart`): كل خطأ غير ملتقَط يُسجَّل في `errors.log` ويُعرض كحوار «حدث خطأ» بدل شاشة مكسورة، + تنظيف مستمعي xinput عند الخروج.
- [ ] نافذة مستقلة فوق النوافذ (Flutter Linux embedding) — حاليًا تظهر داخل النافذة الرئيسية (تُرفع إلى الأمام عبر `xdotool`).
- [ ] بديل `secondbrain --capture` (IPC socket) + single instance + autostart.
- [ ] Android: share intent → شاشة capture (واجهة `ShareIntentSource` جاهزة).
- [ ] F11/F12 ومفاتيح وظيفية: مدعوم في التحليل (`HotkeySpec.parse`) لكن لم يُختبر على جهاز حقيقي.

## Phase 9 — Packaging & Hardening (M8)
- [ ] حزمة .deb/AppImage + APK/AAB.
- [ ] autostart + إعدادات النظام.
- [x] شاشة الإعدادات (UI-15): اللغة والمظهر، تخصيص لوحة التحكم، الوسوم وأنواع المحتوى، إعدادات المهام والتنبيهات، اختصار الالتقاط، الأجهزة المقترنة، عنوان الخادم وحالة الاتصال، النسخ الاحتياطي والاستعادة، تصدير البيانات، معلومات التطبيق.
- [ ] اختبار تحمل (20k عنصر، 5k مرفق) + p95 بحث <200ms.
- [ ] دليل تثبيت.

## Phase 10 — Clean Code & Repo Hygiene (2026-11-12)
> الحالة: **مكتملة** — `flutter analyze` نظيف، `flutter test` 126/126 ناجحة، بناء Linux debug ناجح، والمجلد مستودع git (فرع `main`).
- [x] حذف مخلفات البناء (`build/`, `.dart_tool/`, `.idea/`, `linux/flutter/ephemeral/`) من `secondbrain/` و`spikes/s1_hotkey/` — من 767 MB إلى 2.9 MB.
- [x] حذف نسخة احتياطية متسربة (`secondbrain-*.sbbackup`) من جذر الحزمة + استبعاد `*.sbbackup` و`*.sqlite` وصور فشل الـ goldens من git.
- [x] `.gitignore` جذري (Flutter/Dart + IDE + مخرجات التطبيق) وتهيئة مستودع git + أول commit.
- [x] `ItemTypesRepository` بدل 10 استعلامات أنواع مكرّرة (مقروءة عبر `scope.itemTypes`).
- [x] مكوّنات مشتركة بدل نسخ/لصق: `FilterChipMenu`, `KnowledgeFilterBar` (شاشتا المعرفة والبحث), `MetaLabel`, `LoadingView`, `EmptyState` موحّد.
- [x] مساعدات مشتركة: `showOptionSheet`, `askForTags`, `splitTagNames`, `itemDisplayTitle`.
- [x] نقل كشف نوع الملف (`mimeFromName`) من الواجهة إلى `AttachmentsRepository` (قرار طبقة البيانات).
- [x] **إصلاح سلوكي**: عنصر «الكل» في قوائم التصفية كان لا يمسح الفلتر (`PopupMenuButton` يُهمل القيمة `null`) — صار له قيمة مُميّزة.
- [x] 10 اختبارات جديدة: `test/data/item_types_repository_test.dart`, `test/features/dialogs_test.dart`, `test/features/filter_chip_menu_test.dart`.

## خارج v1 (لا تُنفَّذ الآن)
- **استيراد Google Keep (Phase 3 كاملة — مؤجَّلة إلى v2 بقرار المستخدم).**
- WorkManager background sync, HTML→Markdown, recurring tasks, cloud sync, password vault, multi-user, browser extension, تحويل وسم إلى مشروع/كورس، تحويل أسطر إلى مهام، Google Calendar، تشفير النسخ الاحتياطي، مزامنة عبر الإنترنت، تصدير من الهاتف، مراقبة تلقائية للنشاط، شاشة/ضغطات المفاتيح.