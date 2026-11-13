#!/usr/bin/env python3
"""يولّد أيقونة التطبيق لكل المنصات (PNG واحدة + مولّد C لسطح المكتب).

الرمز: شبكة معرفة — مركز متصل بثلاث عقد («العقل الثاني»).
يُشغَّل من جذر حزمة التطبيق:

    python3 tool/make_icon.py

يُنتج:
  - android/app/src/main/res/mipmap-*/ic_launcher.png
  - android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml + adaptive
  - linux/runner/resources/app_icon.png + app_icon.c (مضمّنة في.Binary)
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling for smooth edges
SIZE = 1024

# الألوان
BG_TOP = (79, 70, 229)      # indigo-600
BG_BOTTOM = (124, 58, 237)  # violet-600
SYMBOL = (255, 255, 255)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


def gradient(size, top, bottom):
    """تدرّج قطري ناعم."""
    grad = Image.new("RGBA", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(0, size, 8):
            t = (x + y) / (2 * (size - 1))
            c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            for dx in range(8):
                if x + dx < size:
                    px[x + dx, y] = c + (255,)
    return grad


def draw_symbol(img, cx, cy, scale):
    """مركز + ثلاث عقد متصلة."""
    d = ImageDraw.Draw(img)
    hub_r = 0.115 * scale
    node_r = 0.082 * scale
    arm = 0.265 * scale
    line_w = max(2, int(0.046 * scale))

    nodes = []
    for angle in (-90, 30, 150):
        import math

        rad = math.radians(angle)
        nodes.append(
            (cx + arm * math.cos(rad), cy + arm * math.sin(rad))
        )

    # الخطوط (بشفافية أقل قليلًا لتبقى العقد بارزة)
    for nx, ny in nodes:
        d.line([(cx, cy), (nx, ny)], fill=SYMBOL + (215,), width=line_w)
        d.ellipse(
            [nx - line_w / 2, ny - line_w / 2, nx + line_w / 2, ny + line_w / 2],
            fill=SYMBOL + (215,),
        )

    # العقد
    for nx, ny in nodes:
        d.ellipse(
            [nx - node_r, ny - node_r, nx + node_r, ny + node_r], fill=SYMBOL
        )

    # المركز
    d.ellipse([cx - hub_r, cy - hub_r, cx + hub_r, cy + hub_r], fill=SYMBOL)
    # شق صغير في المركز يوحي «العقل الثاني» (عقلان)
    inner = hub_r * 0.42
    d.ellipse(
        [cx - inner, cy - inner, cx + inner, cy + inner],
        fill=BG_TOP + (255,),
    )


def make_icon(size=1024, symbol_scale=0.62, with_background=True):
    """أيقونة مربّعة بحواف دائرية (للأيقونات القديمة) أو شفافة (للأمام)."""
    s = size * SS
    if with_background:
        img = gradient(s, BG_TOP, BG_BOTTOM)
        img.putalpha(rounded_mask(s, int(s * 0.225)))
    else:
        img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_symbol(img, s / 2, s / 2, s * symbol_scale)
    return img.resize((size, size), Image.LANCZOS)


def make_adaptive_foreground(size=432):
    """طبقة الأمام للأيقونة التكيّفية: الرمز داخل المنطقة الآمنة."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_symbol(img, s / 2, s / 2, s * 0.52)
    return img.resize((size, size), Image.LANCZOS)


def save_png(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("→", os.path.relpath(path, ROOT))


def main():
    master = make_icon(1024)

    # ---- Android: أيقونات قديمة ----
    res = os.path.join(ROOT, "android/app/src/main/res")
    for folder, px in [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]:
        save_png(make_icon(px), os.path.join(res, folder, "ic_launcher.png"))

    # ---- Android: أيقونة تكيّفية (Android 8+) ----
    for folder, px in [
        ("mipmap-mdpi", 108),
        ("mipmap-hdpi", 162),
        ("mipmap-xhdpi", 216),
        ("mipmap-xxhdpi", 324),
        ("mipmap-xxxhdpi", 432),
    ]:
        save_png(
            make_adaptive_foreground(px),
            os.path.join(res, folder, "ic_launcher_foreground.png"),
        )
    save_png(master, os.path.join(res, "drawable", "ic_launcher_background.png"))

    anydpi = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            "</adaptive-icon>\n"
        )
    with open(os.path.join(res, "values", "colors.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#4F46E5</color>\n'
            "</resources>\n"
        )
    print("→ android adaptive icon")

    # ---- سطح المكتب: PNG + ملف C مضمّن ----
    linux_res = os.path.join(ROOT, "linux/runner/resources")
    os.makedirs(linux_res, exist_ok=True)
    icon_png = os.path.join(linux_res, "app_icon.png")
    master.save(icon_png, "PNG")
    print("→", os.path.relpath(icon_png, ROOT))

    # حجم 128 بكسل داخل الملف التنفيذي (الأكبر يجعل الملف ضخمًا جدًا)
    embedded = make_icon(128)
    data = embedded.convert("RGBA").tobytes()
    with open(os.path.join(linux_res, "app_icon.c"), "w", encoding="utf-8") as f:
        f.write("// Generated by tool/make_icon.py — do not edit by hand.\n")
        f.write("#include <gtk/gtk.h>\n\n")
        f.write("#define ICON_SIZE 128\n\n")
        f.write("static const guint8 app_icon_data[] = {\n")
        for i in range(0, len(data), 16):
            chunk = ",".join(str(b) for b in data[i : i + 16])
            f.write(f"  {chunk},\n")
        f.write("};\n\n")
        f.write(
            "// The application icon, embedded so it works from anywhere.\n"
            "GdkPixbuf* app_icon_pixbuf() {\n"
            "  return gdk_pixbuf_new_from_data(\n"
            "      app_icon_data, GDK_COLORSPACE_RGB, TRUE, 8, ICON_SIZE,\n"
            "      ICON_SIZE, ICON_SIZE * 4, NULL, NULL);\n"
            "}\n"
        )
    print("→", os.path.relpath(os.path.join(linux_res, "app_icon.c"), ROOT))

    with open(os.path.join(linux_res, "app_icon.h"), "w", encoding="utf-8") as f:
        f.write(
            "// Generated by tool/make_icon.py — do not edit by hand.\n"
            "#pragma once\n"
            "#include <gtk/gtk.h>\n\n"
            "#ifdef __cplusplus\n"
            'extern "C" {\n'
            "#endif\n\n"
            "// The application icon, embedded so it works from anywhere.\n"
            "GdkPixbuf* app_icon_pixbuf();\n\n"
            "#ifdef __cplusplus\n"
            "}\n"
            "#endif\n"
        )
    print("→", os.path.relpath(os.path.join(linux_res, "app_icon.h"), ROOT))

    # ---- نسخة للاختصار على سطح المكتب ----
    desktop_icon = os.path.expanduser(
        "~/.local/share/icons/hicolor/256x256/apps/secondbrain.png"
    )
    save_png(make_icon(256), desktop_icon)


if __name__ == "__main__":
    main()
