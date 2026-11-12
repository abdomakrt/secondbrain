#!/usr/bin/env bash
# لقطة شاشة للشاشة كاملة (أو لنافذة واحدة).
#
# ترتيب الأدوات:
#   1. gnome-screenshot — يعمل دائمًا على Cinnamon.
#   2. xwd + tool/xwd2png.py — بديل إذا تعذّر الأول (وهو ما فشل مؤخرًا
#      بخطأ X_QueryColors/BadColor داخل خادم X).
#
# الاستخدام:
#   tool/shot.sh                 → لقطة الشاشة كاملة
#   tool/shot.sh --window <id>   → لقطة نافذة محددة
set -uo pipefail

OUT="${1:-/tmp/secondbrain-shot.png}"
WINDOW_ID=""

if [ "${1:-}" = "--window" ]; then
  WINDOW_ID="${2:-}"
  OUT="${3:-/tmp/secondbrain-shot.png}"
fi

cd "$(dirname "$0")/.."

if [ -n "$WINDOW_ID" ] && command -v xwd >/dev/null; then
  DUMP="$(mktemp /tmp/xwd-XXXXXX.xwd)"
  if xwd -id "$WINDOW_ID" -out "$DUMP" 2>/dev/null && [ -s "$DUMP" ]; then
    python3 tool/xwd2png.py "$DUMP" "$OUT"
    rm -f "$DUMP"
    exit 0
  fi
  rm -f "$DUMP"
fi

if command -v gnome-screenshot >/dev/null; then
  if [ -n "$WINDOW_ID" ]; then
    gnome-screenshot -w -f "$OUT" && echo "$OUT" && exit 0
  else
    gnome-screenshot -f "$OUT" && echo "$OUT" && exit 0
  fi
fi

echo "تعذّر التقاط الشاشة: لا gnome-screenshot ولا xwd يعملان." >&2
exit 1
