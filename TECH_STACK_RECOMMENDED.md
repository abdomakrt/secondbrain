# TECH_STACK_RECOMMENDED.md — العقل الثاني (Second Brain)

**مبنية على:** `PRD_v0.2.md` + `TECHNICAL_SPEC.md` v0.1 + فحص صيانة الحزم (Nov 2026)  
**الحالة:** توصية (ليست قرارًا نهائيًا حتى تُنفَّذ الـ Spikes)

---

## 0. خلاصة (TL;DR)

- **أبقِ Flutter + Dart** (الأفضل لهذا المشروع: Android + Linux + Windows لاحقًا، كود واحد).
- **أبقِ drift + Riverpod + go_router + shelf** (جميعها نشطة وموثوقة в 2026).
- **أبقِ HotKey/Window/Tray من leanflutter** ( migrated to nativeapi، متوافق مع Flutter 3.47+).
- **بدّل/تحقق من 4 حزم** before committing: `markdown_widget`, `qr_flutter`, `basic_utils`, `nsd` (انظر §7).
- **أضِف** `connectivity_plus` + `internet_connection_checker_plus`, `flutter_local_notifications`, `receive_sharing_intent`, `single_instance`, `path_provider`.
- **الهدف:** Flutter **3.47.x** (Dart 3.13) كحد أدنى — لأن `hotkey_manager 0.3.0` يتطلب Dart 3.13+/Flutter 3.47+.

---

## 1. الإطار واللغة

| الغرض | التوصية | ملاحظة |
|-------|---------|--------|
| الإطار | Flutter 3.47.x (stable) | 3.50 (Nov 2026) اختياري بعد الاستقرار |
| اللغة | Dart 3.13+ | records/patterns/sealed classes مفيدة للـ Sync |
| البناء | Linux: clang, cmake, ninja, pkg-config, libgtk-3-dev, libx11-dev, libxi-dev | required by nativeapi (window/hotkey/tray) |
| التعبئة | Linux: `.deb` + AppImage؛ Android: AAB | |

> **ملاحظة بيئة:** لا يوجد Flutter/Dart مثبت حاليًا على جهازك. أول خطوة (M0) = تثبيت SDK + تشغيل `flutter doctor`.

---

## 2. قاعدة البيانات والبحث

| الغرض | التوصية | ملاحظة |
|-------|---------|--------|
| ORM/DB | **drift 2.35+** | FTS5 support added in 2.35.0; Flutter Favorite; all 6 platforms |
| محرك SQLite | sqlite3 (via drift) + `NativeDatabase.createInBackground` | لا تحجب UI thread |
| البحث | FTS5 (`unicode61`) + تطبيع في Dart (§6.2 من TECHNICAL_SPEC) | Spike S4: p95 < 200ms على 20k عناصر |
| التشفير | `sqlite3_multiple_ciphers` (درفت يوصي به) | اختياري (النسخة 1 بدون تشفير) |

**تأكيد:** drift هو "أقوى قصة صيانة" (2.35.1, 30 Sep 2026). لا تستخدم `sqflite` (أبطأ، لا streaming) ولا Isar/Realm (Realm deprecated).

---

## 3. إدارة الحالة والتنقل

| الغرض | التوصية | ملاحظة |
|-------|---------|--------|
| State | **Riverpod 3.x** (`flutter_riverpod` + `riverpod_generator`) | AsyncValue, autoDispose, codegen; experimental persistence — لا تستخدمها (استخدم SQLite) |
| التنقل | **go_router** | declarative, deep links |

> **بديل:** Bloc 9 (Cubit) إذا توسّع الفريق > 4 مطورين أو أردت audit logging. للمطور المنفرد + offline-first، Riverpod أفضل.

---

## 4. الخادم والمزامنة (Local-first)

| الغرض | التوصية | ملاحظة |
|-------|---------|--------|
| HTTP server | **shelf + shelf_router** + `dart:io HttpServer.bindSecure` | داخل التطبيق |
| التوجيه | `shelf_router` | |
| التحقق من الشهادة | بصمة SHA-256 (لا سلسلة النظام) | phone compares fingerprint from QR |
| توليد الشهادة | **basic_utils** (`X509Utils.generateSelfSignedCertificate`, ECDSA P-256) | ⚠️ آخر إصدار 5.7.0 (Oct 2022) — verify; fallback: pointycastle asn1 (pure Dart) |
| mDNS | **nsd** (الخيار (practically) الوحيد لـ Linux desktop) | ⚠️ صيانة slowing (28 weeks quiet). احتفظ بـ fallbacks (last IP + manual) كما في §7.9 |
| اكتشاف الأجهزة | nsd + last-known IP + manual entry | |
| التخزين الآمن (token) | **flutter_secure_storage 11.x** | ⚠️ Linux backend = beta (v4.0.0-beta.1). اختبر؛ fallback: encrypted file in app data dir |
| JSON/gzip | `dart:convert` + `gzip` | مدمج |
| UUID | **uuid 4.x (v7)** | time-ordered |
| التجزئة | **crypto (SHA-256)** | |

**بديل mDNS:** `bonsoir` (صيانة Good) لكن دعم Linux desktop غير مؤكد — استخدم nsd (يدعم Windows/Linux registration).

---

## 5. سطح المكتب (Linux Mint → Windows)

| الغرض | التوصية | ملاحظة |
|-------|---------|--------|
| النافذة | **window_manager 0.6.x** (nativeapi) | active (leanflutter) |
| شريط النظام | **tray_manager 0.8.x** (nativeapi) | StatusNotifierItem على Linux (بدون ayatana-appindicator) |
| الاختصار العام | **hotkey_manager 0.3.0** (nativeapi) | requires Flutter 3.47+/Dart 3.13+. **Linux: X11 only** (XWayland). Wayland portal supported in 0.3 |
| شاشة | **screen_retriever** | leanflutter |
| اختيار الملفات | **file_picker 13.x** (federated, very active) | |
| فتح مجلد | `url_launcher` (`file://`) + fallback `xdg-open` | |
| نسخة واحدة | **single_instance** (أو lock-file/socket) | required for `secondbrain --capture` IPC |
| إشعارات (desktop) | `flutter_local_notifications` | |
| قراءة النص المحدد (X11) | `xclip` (system dep) — PRIMARY selection | |
| عنوان النافذة النشطة | `xdotool` + `xprop` (system deps) | |

**ملاحظة:** leanflutter plugins (window/tray/hotkey/screen) كلها migrated to `nativeapi` C++ core — single dependency, active (last releases days ago). جيدة.

---

## 6. Android

| الغرض | التوصية | ملاحظة |
|-------|---------|--------|
| مسح QR | **mobile_scanner 7.5.x** | active, verified publisher (steenbakker.dev) |
| توليد QR | **qr_flutter** (⚠️ صيانة Poor، آخر 2023) **أو** `pretty_qr_code` / `qr` package | qr_flutter لا يزال يعمل على كل المنصات؛ Spike: verify. بديل: `pretty_qr_code` (active) |
| استقبال "مشاركة" | `receive_sharing_intent` أو Platform Channel | |
| إشعارات محلية | `flutter_local_notifications` | |
| التخزين الآمن | flutter_secure_storage | |
| WorkManager (v2) | `workmanager` | خارج v1 (حسب TECHNICAL_SPEC) |

---

## 7. الحزم التي تحتاج تحقق/استبدال (⚠️)

| الحزمة | الحالة | التوصية |
|--------|--------|---------|
| `markdown_widget` | صيانة Average، آخر إصدار 18 شهرًا | **Spike S6**: اختبر RTL العربي + كتل الأكواد. بديل: `flutter_markdown` (official، أكثر صيانة، ميزات أقل). ابدأ بـ flutter_markdown، انتقل لـ markdown_widget إن احتجت TOC/نسخ كود |
| `qr_flutter` | صيانة Poor، آخر 2023 | يعمل (1.1M downloads/30d). بديل: `pretty_qr_code` (active) أو `qr` (pure Dart). Spike: verify rendering |
| `basic_utils` | آخر إصدار 5.7.0 (Oct 2022) | X509Utils يدعم ECDSA self-signed. **Verify**؛ fallback: توليد X.509 بـ pointycastle asn1 (pure Dart) |
| `nsd` | صيانة slowing (28 weeks quiet) | **الخيار (practically) الوحيد** لـ Linux desktop registration. احتفظ بـ fallbacks (last IP + manual) — كما في §7.9 |
| `flutter_secure_storage` (Linux) | backend beta | اختبر على Mint؛ fallback: encrypted file |

---

## 8. Markdown/النص/الترجمة

| الغرض | التوصية |
|-------|---------|
| Markdown | `flutter_markdown` (primary) / `markdown_widget` (if needed) |
| الترجمة | `flutter_localizations` + `intl` + ARB (`app_ar.arb`) |
| الخطوط | bundle: Noto Sans Arabic (أو IBM Plex Arabic) + emoji font |
| RTL | `Directionality` = RTL للتطبيق كله؛ كتل الأكواد LTR (Spike S6) |
| الأرقام | غربية (0-9) افتراضيًا + إعداد للأرقام العربية-الهندية |

---

## 9. الملفات/ZIP/النسخ الاحتياطي/الاستيراد

| الغرض | التوصية |
|-------|---------|
| ZIP (قراءة/كتابة) | **archive** (streaming) |
| اختيار الملفات/المجلدات | **file_picker 13.x** |
| Hash | **crypto (SHA-256)** |
| Paths | **path_provider** + `path` |
| YAML Front Matter (export) | `yaml` package أو يدوي |

---

## 10. الاتصال/الشبكة (UI)

| الغرض | التوصية |
|-------|---------|
| نوع الاتصال | **connectivity_plus** |
| reachability حقيقي | **internet_connection_checker_plus** (HEAD request قبل sync) |
| HTTP client | `dart:io HttpClient` مع certificate pinning (fingerprint) |

---

## 11. الاختبار/CI

| الغرض | التوصية |
|-------|---------|
| Unit/Widget | `flutter_test` + `mocktail` |
| Integration | `integration_test` |
| Golden (RTL) | `flutter_test` golden files |
| CI | GitHub Actions: Linux + Android builds + tests |

---

## 12. هيكل المشروع (من TECHNICAL_SPEC §17)

```
secondbrain/
├─ lib/
│  ├─ core/            ← HLC, UUID, تطبيع النص, أدوات التاريخ, الأخطاء
│  ├─ data/            ← drift: الجداول, الهجرات, WriteGate, المستودعات, FTS
│  ├─ domain/          ← حساب التقدم, قواعد المهام, تصنيف المعرفة
│  ├─ sync/            ← الخادم, العميل, HLC merge, blobs, الاقتران
│  ├─ importers/       ← keep_importer (محلل, معاينة, تقرير)
│  ├─ backup/          ← إنشاء, استعادة, تحقق, تصدير Markdown
│  ├─ platform/
│  │   ├─ desktop/     ← hotkey, tray, selection_reader (X11/Windows), ipc, autostart
│  │   └─ android/     ← share intent, إشعارات محلية
│  ├─ features/        ← dashboard, knowledge, search, projects, tasks, plan, courses, capture, settings, sync_ui
│  └─ l10n/            ← app_ar.arb
├─ test/
├─ integration_test/
└─ docs/
```

---

## 13. الترتيب (Milestones) — تأكيد

M0 (Spikes) → M1 (Knowledge/Search) → M2 (Keep import) → M3 (Backup/Restore) → M4 (Projects/Tasks/Plan) → M5 (Courses) → M6 (Sync/Pairing) → M7 (Quick Capture) → M8 (Packaging).

**M3 (Backup) قبل M4/M5** عمدًا: بعد استيراد Keep تصبح لديك بيانات تستحق الحماية.

---

## 14. بديل "لا تستخدم" (Anti-recommendations)

| لا تستخدم | السبب |
|-----------|-------|
| Node.js server منفصل | PRD قديم؛ TECHNICAL_SPEC اعتمد local-first (تطبيق واحد) |
| PostgreSQL | SQLite local per device |
| `sqflite` | drift أفضل (type-safe, migrations, FTS5, isolate) |
| Isar / Realm | Realm deprecated; Isar community bug-fix only |
| `qr_code_scanner` | maintenance mode |
| `provider` (state) | Riverpod 3 أفضل لـ async/offline |
| HTML→Markdown في v1 | خارج النطاق (PRD) |
| مزامنة خلفية Android (WorkManager) | خارج v1 |

---

## 15. الخطوات التالية (M0)

1. تثبيت Flutter 3.47 + Dart 3.13 (Linux).
2. `flutter create secondbrain` (Android + Linux).
3. تثبيت system deps: `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev xclip xdotool`.
4. Spikes: S1 (hotkey+tray+window+PRIMARY), S2 (cert+pairing), S3 (mDNS), S4 (FTS5 Arabic 20k), S5 (Keep dry run), S6 (Markdown RTL).
5. إعداد CI (GitHub Actions) لـ Linux+Android.

---

**ملاحظة أخيرة:** الإجابات (Spikes) هي التي تُثبت أو تُبدّل كل "⚠️" أعلاه. لا تُثبِّت إصدارات حزم في `pubspec.yaml` قبل إكمال M0.
