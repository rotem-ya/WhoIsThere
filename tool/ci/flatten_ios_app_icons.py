#!/usr/bin/env python3
"""Flatten alpha from iOS app icon PNGs using only the Python standard library.

App Store Connect rejects app icons that contain transparency or an alpha channel.
This script rewrites every PNG in the AppIcon.appiconset as an opaque RGB PNG.
"""

from __future__ import annotations

import argparse
import binascii
import os
import struct
import sys
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
WHITE = (255, 255, 255)


def read_chunks(data: bytes):
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("Not a PNG file")

    offset = len(PNG_SIGNATURE)
    chunks = []
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError("Truncated PNG chunk header")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk_type = data[offset + 4:offset + 8]
        start = offset + 8
        end = start + length
        crc_end = end + 4
        if crc_end > len(data):
            raise ValueError("Truncated PNG chunk data")
        chunks.append((chunk_type, data[start:end]))
        offset = crc_end
        if chunk_type == b"IEND":
            break
    return chunks


def png_chunk(chunk_type: bytes, payload: bytes) -> bytes:
    crc = binascii.crc32(chunk_type)
    crc = binascii.crc32(payload, crc) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + chunk_type + payload + struct.pack(">I", crc)


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def unfilter(raw: bytes, width: int, height: int, bytes_per_pixel: int) -> bytes:
    stride = width * bytes_per_pixel
    result = bytearray(height * stride)
    src_offset = 0

    for row in range(height):
        filter_type = raw[src_offset]
        src_offset += 1
        line = bytearray(raw[src_offset:src_offset + stride])
        src_offset += stride
        prev_offset = (row - 1) * stride
        dst_offset = row * stride

        for i in range(stride):
            left = line[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            up = result[prev_offset + i] if row > 0 else 0
            up_left = result[prev_offset + i - bytes_per_pixel] if row > 0 and i >= bytes_per_pixel else 0

            if filter_type == 0:
                value = line[i]
            elif filter_type == 1:
                value = (line[i] + left) & 0xFF
            elif filter_type == 2:
                value = (line[i] + up) & 0xFF
            elif filter_type == 3:
                value = (line[i] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                value = (line[i] + paeth(left, up, up_left)) & 0xFF
            else:
                raise ValueError(f"Unsupported PNG filter type: {filter_type}")

            line[i] = value
            result[dst_offset + i] = value

    return bytes(result)


def flatten_pixel(channel: int, alpha: int, background: int) -> int:
    return (channel * alpha + background * (255 - alpha) + 127) // 255


def flatten_png(data: bytes, background=WHITE) -> bytes | None:
    chunks = read_chunks(data)
    ihdr = next(payload for chunk_type, payload in chunks if chunk_type == b"IHDR")
    width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", ihdr)

    if bit_depth != 8:
        raise ValueError(f"Unsupported PNG bit depth: {bit_depth}")
    if interlace != 0:
        raise ValueError("Interlaced PNG icons are not supported by this script")

    idat = b"".join(payload for chunk_type, payload in chunks if chunk_type == b"IDAT")
    raw = zlib.decompress(idat)

    palette = None
    transparency = None
    for chunk_type, payload in chunks:
        if chunk_type == b"PLTE":
            palette = [tuple(payload[i:i + 3]) for i in range(0, len(payload), 3)]
        elif chunk_type == b"tRNS":
            transparency = payload

    if color_type == 6:
        source = unfilter(raw, width, height, 4)
        rgb = bytearray(width * height * 3)
        for i in range(width * height):
            r, g, b, a = source[i * 4:i * 4 + 4]
            rgb[i * 3 + 0] = flatten_pixel(r, a, background[0])
            rgb[i * 3 + 1] = flatten_pixel(g, a, background[1])
            rgb[i * 3 + 2] = flatten_pixel(b, a, background[2])
    elif color_type == 4:
        source = unfilter(raw, width, height, 2)
        rgb = bytearray(width * height * 3)
        for i in range(width * height):
            gray, a = source[i * 2:i * 2 + 2]
            value = flatten_pixel(gray, a, background[0])
            rgb[i * 3 + 0] = value
            rgb[i * 3 + 1] = value
            rgb[i * 3 + 2] = value
    elif color_type == 3 and palette is not None and transparency is not None:
        source = unfilter(raw, width, height, 1)
        rgb = bytearray(width * height * 3)
        for i, index in enumerate(source):
            r, g, b = palette[index]
            a = transparency[index] if index < len(transparency) else 255
            rgb[i * 3 + 0] = flatten_pixel(r, a, background[0])
            rgb[i * 3 + 1] = flatten_pixel(g, a, background[1])
            rgb[i * 3 + 2] = flatten_pixel(b, a, background[2])
    elif color_type == 2:
        return None
    else:
        return None

    filtered = bytearray()
    stride = width * 3
    for row in range(height):
        filtered.append(0)
        start = row * stride
        filtered.extend(rgb[start:start + stride])

    new_ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, compression, filter_method, 0)
    return b"".join([
        PNG_SIGNATURE,
        png_chunk(b"IHDR", new_ihdr),
        png_chunk(b"IDAT", zlib.compress(bytes(filtered), 9)),
        png_chunk(b"IEND", b""),
    ])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("iconset", type=Path)
    args = parser.parse_args()

    if not args.iconset.is_dir():
        print(f"Icon set directory not found: {args.iconset}", file=sys.stderr)
        return 1

    changed = 0
    checked = 0
    for path in sorted(args.iconset.glob("*.png")):
        checked += 1
        original = path.read_bytes()
        flattened = flatten_png(original)
        if flattened is not None and flattened != original:
            path.write_bytes(flattened)
            changed += 1
            print(f"Flattened alpha: {path}")
        else:
            print(f"Already opaque: {path}")

    print(f"Checked {checked} icon PNG files; changed {changed}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
