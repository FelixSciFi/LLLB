#!/usr/bin/env python3
"""Split a 2×2 sprite sheet into four PNGs: Resources/ + Asset Catalog imagesets."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as e:
    raise SystemExit("Install Pillow: pip3 install Pillow") from e

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "LearnLanguageLikeABaby" / "Resources"
ASSETS = ROOT / "LearnLanguageLikeABaby" / "Assets.xcassets"

NAMES = [
    ("shopkeeper_idle", "shopkeeper_idle.png"),
    ("shopkeeper_talking", "shopkeeper_talking.png"),
    ("shopkeeper_happy", "shopkeeper_happy.png"),
    ("shopkeeper_thinking", "shopkeeper_thinking.png"),
]


def contents_json(filename: str) -> dict:
    return {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }


def main() -> None:
    default_src = ROOT / "4F2D0146-CBC7-4586-9F3B-CA99D50B1791.png"
    alt_src = Path("/mnt/user-data/uploads/4F2D0146-CBC7-4586-9F3B-CA99D50B1791.png")
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else default_src
    if not src.is_file():
        if alt_src.is_file():
            src = alt_src
        else:
            raise SystemExit(f"Source PNG not found: {src}")

    im = Image.open(src).convert("RGBA")
    w, h = im.size
    w2, h2 = w // 2, h // 2
    cells = [
        im.crop((0, 0, w2, h2)),
        im.crop((w2, 0, w, h2)),
        im.crop((0, h2, w2, h)),
        im.crop((w2, h2, w, h)),
    ]

    RESOURCES.mkdir(parents=True, exist_ok=True)

    for cell, (base, filename) in zip(cells, NAMES):
        out_res = RESOURCES / filename
        cell.save(out_res, "PNG")
        print(f"wrote {out_res.relative_to(ROOT)}")

        imageset = ASSETS / f"{base}.imageset"
        imageset.mkdir(parents=True, exist_ok=True)
        dest = imageset / filename
        shutil.copy2(out_res, dest)
        meta = imageset / "Contents.json"
        meta.write_text(json.dumps(contents_json(filename), indent=2) + "\n", encoding="utf-8")
        print(f"  -> Assets: {imageset.relative_to(ROOT)}/")

    print("done.")


if __name__ == "__main__":
    main()
