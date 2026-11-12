#!/usr/bin/env python3
"""Convert an XWD dump to PNG.

The XWD header is written in **network byte order** (big endian) — every
32-bit field, including `header_size`. Mixing `=I` (native/little endian)
for `header_size` with `>25I` for the rest yields a huge offset
(0x70000000 instead of 112) and a broken image.

Usage: xwd2png.py <dump.xwd> <out.png>
"""
import struct
import sys

from PIL import Image


def load(path: str) -> Image.Image:
    with open(path, "rb") as handle:
        data = handle.read()

    if len(data) < 100:
        raise SystemExit(
            f"{path}: الملف فارغ أو ناقص ({len(data)} بايت) — فشل xwd نفسه "
            "(خطأ X في الخادم) وليس مشكلة تحليل."
        )

    header = struct.unpack(">25I", data[:100])
    (
        header_size,
        _version,
        _format,
        _depth,
        width,
        height,
        _xoffset,
        _byte_order,
        _bitmap_unit,
        _bitmap_bit_order,
        _bitmap_pad,
        bits_per_pixel,
        bytes_per_line,
        _visual_class,
        _red_mask,
        _green_mask,
        _blue_mask,
        _bits_per_rgb,
        _colormap_entries,
        ncolors,
        *_rest,
    ) = header

    offset = header_size + ncolors * 12
    pixels = data[offset : offset + bytes_per_line * height]
    mode = {32: "BGRX", 24: "BGR", 16: "BGR;16"}.get(bits_per_pixel)
    if mode is None:
        raise SystemExit(f"عمق غير مدعوم: {bits_per_pixel} بت/بكسل")

    image = Image.frombytes(
        "RGB", (width, height), pixels, "raw", mode, bytes_per_line, 1
    )
    # XWD يخزّن الصفوف من الأسفل إلى الأعلى.
    return image.transpose(Image.FLIP_TOP_BOTTOM)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("الاستخدام: xwd2png.py <dump.xwd> <out.png>")
    image = load(sys.argv[1])
    image.save(sys.argv[2])
    print(f"{sys.argv[2]} ← {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
