# AGENTS.md — Second Brain (العقل الثاني)

## Project
Personal productivity/knowledge app: Flutter + Dart, single codebase, Android + Linux desktop (Windows later). Arabic RTL primary. Local-first: each device holds a full SQLite DB; optional Wi-Fi sync between devices. No central server, no Node.js, no Postgres — `PRD_v0.2.md` §9 ("computer as Node server, single DB") is outdated and superseded by `TECHNICAL_SPEC.md`.

## Source of truth
- `TECHNICAL_SPEC.md` — authoritative engineering spec.
- `PRD_v0.2.md` — product requirements.
- `TECH_STACK_RECOMMENDED.md` — package recommendations (verify via spikes; not final).
- When PRD and spec conflict, trust the spec.

## Stack (planned; unverified until M0 spikes)
- Flutter 3.47.x / Dart 3.13+ minimum (`hotkey_manager` 0.3.0 requirement).
- DB: drift 2.35+ over sqlite3, FTS5; `NativeDatabase.createInBackground`.
- State: Riverpod 3; nav: go_router; sync server: shelf + shelf_router inside the app.
- Desktop plugins: leanflutter `nativeapi` (window_manager, tray_manager, hotkey_manager, screen_retriever) — hotkeys are **X11 only** (XWayland on Wayland).
- Linux system deps: `clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev xclip xdotool`.

## X11 capture (Linux desktop) — settled facts
- الجلسة على جهاز المستخدم: **X11 + Cinnamon + Mesa (AMD Vega 8)**، والمحرك يعمل بـ Impeller/OpenGLES (لا Vulkan). `FLUTTER_LINUX_RENDERER=software` **غير صالح** (Impeller لا يرسم على Skia) → لا تستخدمه كحل.
- الاختصار العام: `hotkey_manager`/`XGrabKey` **لا يسلّم الأحداث** على هذا النظام → الحل المعتمد `xinput test-xi2 --root` (يقرأ أحداث XI2 الخام). صيغة XI2 تعطي `detail: <keycode>` بلا `state` ⇒ تُبنى حالة الـModifiers من ضغط/رفع مفاتيح المودِفايزر نفسها.
- نفس الضغط يُبلَّغ مرتين (النواة + الجهاز) ⇒ تصفية التكرار زمنيًا (400ms).
- `xinput` واحد فقط يمكنه grabs الـXInput ⇒ قبل البدء تُقتل المستمعات اليتما (`pkill -f 'xinput test-xi2 --root'`) وإلا فشل بـ `BadAccess`.
- قراءة التحديد/الحافظة عبر `xclip -o -selection primary|clipboard` (قراءة فقط)؛ العنوان عبر `xdotool` والتطبيق عبر `xprop WM_CLASS`.
- عند تشغيل `xclip` لاختبار يدوي: المالك يبقي التحديد حيًّا ما دام alive؛Applications أخرى قد تسرق التحديد عند استلام المفتاح — الاختبار الحقيقي يتم من تطبيق يملك التحديد فعليًا.

## Architecture invariants (do not violate)
- All DB writes go through `WriteGate` inside a transaction: sets `updated_at`/`hlc`, writes `oplog`, updates FTS. No direct table writes anywhere.
- Synced tables have **no strict FKs**; store IDs and treat orphans as "unclassified" (records arrive out of order during sync).
- Soft delete only (`deleted_at` tombstones, retained ≥180 days); hard delete never. Deleting a project/course detaches children, never cascades.
- IDs are UUIDv7; time is HLC string `{13ms}-{4hex}-{device_id}`; all timestamps UTC ms.
- Every synced table has: `id, user_id (default 'local'), created_at, updated_at, hlc, deleted_at`.
- Local-only tables: `oplog, sync_state, devices, item_versions, local_paths, import_map, import_batches, capture_drafts, items_fts`.
- Platform-specific code lives behind interfaces in `lib/platform/` (`desktop/`, `android/`); no OS leaks into other layers.
- Pure logic (Arabic normalization, sync merge, import, backup) must be testable without UI.

## Planned layout
`lib/{core,data,domain,sync,importers,backup,platform/{desktop,android},features/*,l10n/app_ar.arb}`, plus `test/`, `integration_test/`, `docs/`.

## Commands
Flutter 3.47.9 + Dart 3.13.7 installed at `/media/storage/tools/flutter/bin` (already in `~/.bashrc`). App code lives in `secondbrain/`; docs stay at the repo root.
- System build deps for Linux desktop (clang/cmake/ninja/libgtk-3-dev/…) are NOT installed yet — needs sudo; only blocks `flutter run` on desktop, not `flutter test`/codegen.
- `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev xclip xdotool`
- `flutter create secondbrain` (Android + Linux), then `flutter doctor`.
- `flutter test` / `flutter analyze` once the project exists.
- Do not pin package versions in `pubspec.yaml` until spikes S1–S6 pass.

## Conventions
- Arabic only; all UI strings in `app_ar.arb` from day one; `Directionality` RTL app-wide; code blocks always LTR.
- Markdown notes: single newline renders as line break (for imported Keep notes).
- Never mutate an import source; always take a safety backup before restore; no silent data loss.
- Milestone order is fixed: M0 spikes → M1 knowledge/search → M2 Keep import → M3 backup/restore → M4 projects/tasks/plan → M5 courses → M6 sync/pairing → M7 quick capture → M8 packaging. M3 deliberately precedes M4/M5.
- Out of v1: background Android sync (WorkManager), HTML→Markdown, recurring tasks, cloud sync, password vault, multi-user.

## Unverified (⚠️) — do not assume
- FTS5 availability and <200ms p95 on 20k Arabic items (S4).
- Global hotkey + tray + PRIMARY selection on Mint/X11 (S1).
- mDNS on home router (S3); fallbacks: last-known IP + manual entry.
- Cert generation via `basic_utils`; fallback `pointycastle` (S2).
- `flutter_secure_storage` Linux backend (beta); fallback encrypted file.
- `markdown_widget` RTL behavior (S6); default to `flutter_markdown`.
- Keep checklist schema unknown (A2); `createdTimestampUsec` uniqueness unverified (S5).
- Week starts Saturday and Western digits by default (A3, configurable).

## Testing
- Unit: Arabic normalization cases, HLC merge/win rule, progress calc, Keep parsing, dedup.
- Sync: two in-memory DBs, concurrent edits, delete-vs-edit, random arrival order, mid-sync disconnect, duplicate replay.
- Backup: dump → wipe → restore → full compare.
- Golden RTL screenshots; on-device testing each milestone; perf on 20k items.