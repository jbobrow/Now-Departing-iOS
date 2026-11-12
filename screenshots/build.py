#!/usr/bin/env python3
"""Render the App Store screenshots for Now Departing.

Reads screens.json, drops each capture from captures/ into its frame, and
writes one PNG per screen to out/ at the size named in screens.json.

Needs only Python 3 (standard library) and Google Chrome or Chromium.

    python3 build.py                 # render every screen
    python3 build.py 01-widgets      # render one screen (or several ids)
    CHROME=/path/to/chrome python3 build.py
"""
import html
import json
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CAPTURES = ROOT / "captures"
BUILD = ROOT / "build"
OUT = ROOT / "out"
EXTS = (".png", ".jpg", ".jpeg")

CSS = """
@font-face{font-family:'Bricolage Grotesque';font-weight:600;src:url('../fonts/BricolageGrotesque-600.woff2') format('woff2')}
@font-face{font-family:'Bricolage Grotesque';font-weight:800;src:url('../fonts/BricolageGrotesque-800.woff2') format('woff2')}
html,body{margin:0;background:#000}
.board{width:%(w)dpx;height:%(h)dpx;box-sizing:border-box;padding:130px 96px 0;display:flex;flex-direction:column;gap:56px;overflow:hidden;background:#000;color:#fff;font-family:'Bricolage Grotesque',system-ui,sans-serif}
.copy{height:620px;flex-shrink:0;display:flex;flex-direction:column;gap:30px}
.eyebrow{font-size:44px;line-height:1;font-weight:600;color:%(accent)s}
h1{margin:0;font-size:136px;line-height:.95;font-weight:800;letter-spacing:-4.4px;text-wrap:balance}
.sub{margin:0;font-size:72px;line-height:1;font-weight:600;letter-spacing:-1.6px;color:#A6A6AD}
.phone{flex-shrink:0;align-self:center;width:948px;height:2002px;box-sizing:border-box;padding:24px;background:#1C1C1F;border-radius:150px;box-shadow:0 0 0 3px #3A3A3F}
.phone img,.phone .missing{display:block;width:900px;height:1954px;object-fit:cover;object-position:top;border-radius:126px}
.phone.bleed{align-self:flex-start;margin:110px 0 0 -24px;width:1176px;height:2500px;border-radius:182px}
.phone.bleed img,.phone.bleed .missing{width:1128px;height:auto;min-height:2300px;border-radius:158px}
.watches{flex-shrink:0;align-self:center;display:flex;flex-direction:column;gap:60px}
.watch{width:823px;height:971px;box-sizing:border-box;padding:26px;background:#1C1C1F;border-radius:190px;box-shadow:0 0 0 3px #3A3A3F}
.watch img,.watch .missing{display:block;width:771px;height:919px;object-fit:cover;border-radius:164px}
.missing{box-sizing:border-box;border:5px dashed #6B6B73;display:flex!important;align-items:center;justify-content:center;text-align:center;font-size:44px;font-weight:600;color:#B4B4BB;padding:60px}
"""


def find_capture(stem):
    for ext in EXTS:
        p = CAPTURES / (stem + ext)
        if p.exists():
            return p
    return None


def img(stem, alt):
    p = find_capture(stem)
    if p is None:
        return '<div class="missing">Missing capture<br>captures/%s.png</div>' % html.escape(stem), False
    return '<img src="../captures/%s" alt="%s">' % (p.name, html.escape(alt, quote=True)), True


def page(cfg, s):
    w, h = cfg["size"]
    head = html.escape(s["headline"]).replace("\n", "<br>")
    sub = '<p class="sub">%s</p>' % html.escape(s["sub"]) if s.get("sub") else ""
    alts = s.get("alt", []) + [""] * len(s["captures"])
    tags, ok = [], True
    for stem, alt in zip(s["captures"], alts):
        tag, found = img(stem, alt)
        tags.append(tag)
        ok = ok and found
    layout = s["layout"]
    if layout == "phone":
        device = '<div class="phone">%s</div>' % tags[0]
    elif layout == "phone-bleed":
        device = '<div class="phone bleed">%s</div>' % tags[0]
    elif layout == "watch-pair":
        device = '<div class="watches">%s</div>' % "".join('<div class="watch">%s</div>' % t for t in tags)
    else:
        sys.exit("Unknown layout %r in screen %s" % (layout, s["id"]))
    css = CSS % {"w": w, "h": h, "accent": cfg["accent"]}
    doc = (
        '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>%s</title><style>%s</style></head>'
        '<body><div class="board"><div class="copy"><div class="eyebrow">%s</div><h1>%s</h1>%s</div>%s</div></body></html>'
        % (html.escape(s["id"]), css, html.escape(s["eyebrow"]), head, sub, device)
    )
    return doc, ok


def find_chrome():
    candidates = [
        os.environ.get("CHROME"),
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        shutil.which("google-chrome"),
        shutil.which("chromium"),
        shutil.which("chromium-browser"),
    ]
    for c in candidates:
        if c and Path(c).exists():
            return c
    sys.exit("Could not find Chrome. Set CHROME=/path/to/chrome and run again.")


def png_info(path):
    with open(path, "rb") as f:
        head = f.read(26)
    w, h = struct.unpack(">II", head[16:24])
    return w, h, head[25]  # colour type: 2 = RGB, 6 = RGBA


def drop_alpha(path):
    """App Store Connect rejects images with an alpha channel. Rewrite as plain RGB."""
    try:
        from PIL import Image  # optional
        Image.open(path).convert("RGB").save(path)
        return "RGB (alpha removed with Pillow)"
    except ImportError:
        pass
    if shutil.which("sips"):  # macOS: re-encode as JPEG, which has no alpha
        jpg = path.with_suffix(".jpg")
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "100", str(path), "--out", str(jpg)],
                       check=True, capture_output=True)
        path.unlink()
        return "saved as %s (JPEG, no alpha)" % jpg.name
    return "HAS ALPHA: install Pillow (pip3 install pillow) and run again"


def main():
    cfg = json.loads((ROOT / "screens.json").read_text())
    want = set(sys.argv[1:])
    screens = [s for s in cfg["screens"] if not want or s["id"] in want]
    if want and len(screens) != len(want):
        sys.exit("Unknown screen id. Known ids: " + ", ".join(s["id"] for s in cfg["screens"]))
    chrome = find_chrome()
    BUILD.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    w, h = cfg["size"]
    problems = 0
    for s in screens:
        doc, ok = page(cfg, s)
        src = BUILD / (s["id"] + ".html")
        src.write_text(doc)
        dst = OUT / (s["id"] + ".png")
        for old in (dst, dst.with_suffix(".jpg")):
            if old.exists():
                old.unlink()
        subprocess.run(
            [chrome, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
             "--force-device-scale-factor=1", "--window-size=%d,%d" % (w, h),
             "--virtual-time-budget=3000", "--screenshot=%s" % dst, src.as_uri()],
            check=True, capture_output=True,
        )
        pw, ph, ctype = png_info(dst)
        notes = []
        if (pw, ph) != (w, h):
            notes.append("WRONG SIZE %dx%d" % (pw, ph))
            problems += 1
        if ctype == 6:
            notes.append(drop_alpha(dst))
        if not ok:
            notes.append("MISSING CAPTURE")
            problems += 1
        elif s.get("standin"):
            notes.append("stand-in capture, replace before upload")
        print("%-14s %dx%d  %s" % (s["id"], pw, ph, "; ".join(notes) or "ready"))
    standins = [s["id"] for s in screens if s.get("standin")]
    if standins:
        print("\nNot upload-ready yet. Stand-ins: " + ", ".join(standins))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
