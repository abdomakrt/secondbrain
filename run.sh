#!/usr/bin/env bash
# تشغيل تطبيق «العقل الثاني» على سطح مكتب Linux.
#
#   ./run.sh              → تشغيل النسخة المبنية (بناء تلقائي إن لزم)
#   ./run.sh --debug      → تشغيل نسخة التطوير مع hot reload (flutter run)
#
# ملاحظة: تشغيل نسخة التطوير يتطلّب جلسة X11 حية (DISPLAY=:0).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT/secondbrain"
FLUTTER="${FLUTTER_BIN:-/media/storage/tools/flutter/bin/flutter}"
RELEASE_BIN="$APP_DIR/build/linux/x64/release/bundle/secondbrain"
DEBUG_BIN="$APP_DIR/build/linux/x64/debug/bundle/secondbrain"

if [ "${1:-}" = "--debug" ]; then
  cd "$APP_DIR"
  exec "$FLUTTER" run -d linux
fi

if [ ! -x "$RELEASE_BIN" ]; then
  if [ -x "$DEBUG_BIN" ]; then
    echo "ℹ لم تُبنَ نسخة الإصدار بعد — تشغيل نسخة التطوير."
    cd "$APP_DIR"
    exec "$FLUTTER" run -d linux
  fi
  echo "⟳ أول بناء للنسخة… (قد يستغرق دقائق)"
  (cd "$APP_DIR" && "$FLUTTER" build linux --release)
fi

exec "$RELEASE_BIN" "$@"
