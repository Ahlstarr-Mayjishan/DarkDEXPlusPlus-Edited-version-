"""
build_lucide_icons.py  (v4 - Chrome headless renderer)
No native C library required.
"""

import base64
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

# ──────────────────────────────────────────────────────────────────────────────
ICON_SIZE    = 64
LUCIDE_BASE  = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/{name}.svg"
ASSET_FOLDER = "DexPlusPlus_Assets"

DOCK_ICONS = [
    # Dock bar items
    ("Home",             "house",                 9),
    # Core
    ("Explorer",         "folder-tree",           0),
    ("Properties",       "sliders-horizontal",    1),
    ("Click part to select", "mouse-pointer-click", 0),
    ("Notepad",          "notebook-pen",           5),
    ("Console",          "terminal",              4),
    ("Save Instance",    "save",                  7),
    ("Settings",         "settings",              8),
    # Spy & Hook
    ("Runtime Monitor",  "monitor",               3),
    ("Remote Usage",     "radio-tower",           3),
    ("Runtime Inspector","scan-eye",              3),
    ("Activity Map",     "map",                   3),
    # Search & Info
    ("Search Center",    "search",                2),
    ("Code Search",      "search-code",           2),
    ("Script Relations", "git-branch",            2),
    ("Object Links",     "link",                  2),
    ("Dependency Graph", "workflow",              2),
    ("Smart Search",     "sparkles",              2),
    ("Snippet Library",  "library",               6),
    ("Client Intelligence", "cpu",               2),
    ("Inspector Hub",    "clipboard-list",        2),
    # Advanced
    ("3D Viewer",        "box",                   8),
    ("Image Viewer",     "image",                 8),
    ("Task Router",      "route",                 8),
    ("Control Center",   "layout-dashboard",      8),
    ("Security Auditor", "shield-check",          8),
    ("Property Tracker", "activity",              3),
    ("Thread Manager",   "layers",                8),
    ("Serialize Inst",   "package",               8),
    ("Memory Forensics", "hard-drive",            8),
    ("Runtime Debugger", "bug",                   8),
    ("IDE Sync",         "git-fork",              8),
]

TOOLS_DIR  = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR  = os.path.join(TOOLS_DIR, "lucide_svg_cache")
SHEET_PNG  = os.path.join(TOOLS_DIR, "lucide_dock_icons.png")
LUAU_OUT   = os.path.join(TOOLS_DIR, "..", "Modules", "Core", "LucideDockIcons.luau")

CHROME_PATHS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

os.makedirs(CACHE_DIR, exist_ok=True)

# ──────────────────────────────────────────────────────────────────────────────
def ensure_pillow():
    try:
        from PIL import Image  # noqa
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "Pillow"])

ensure_pillow()
from PIL import Image  # noqa: E402

# ──────────────────────────────────────────────────────────────────────────────
def find_chrome() -> str:
    for p in CHROME_PATHS:
        if os.path.exists(p):
            return p
    raise RuntimeError("Chrome/Edge not found. Please install Chrome.")


def fetch_svg(slug: str) -> str:
    cache_path = os.path.join(CACHE_DIR, f"{slug}.svg")
    if os.path.exists(cache_path):
        with open(cache_path, "r", encoding="utf-8") as f:
            return f.read()
    url = LUCIDE_BASE.format(name=slug)
    print(f"  Downloading {slug}.svg ...")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        svg = resp.read().decode("utf-8")
    with open(cache_path, "w", encoding="utf-8") as f:
        f.write(svg)
    return svg


def patch_svg_color(svg: str, color: str = "white") -> str:
    svg = svg.replace('stroke="currentColor"', f'stroke="{color}"')
    svg = svg.replace("stroke='currentColor'", f"stroke='{color}'")
    return svg


def svg_to_png_chrome(svg_content: str, size: int, chrome_exe: str) -> bytes:
    """
    Render SVG to PNG via Chrome headless screenshot with transparent background.
    """
    encoded_svg = urllib.request.quote(svg_content)
    html = f"""<!DOCTYPE html>
<html>
<head>
<style>
* {{ margin:0; padding:0; }}
html, body {{ background:transparent !important; width:{size}px; height:{size}px; overflow:hidden; }}
img {{ width:{size}px; height:{size}px; display:block; }}
</style>
</head>
<body>
<img src="data:image/svg+xml;charset=utf-8,{encoded_svg}"/>
</body>
</html>"""

    with tempfile.NamedTemporaryFile(suffix=".html", delete=False, mode="w", encoding="utf-8") as f:
        f.write(html)
        html_path = f.name

    png_path = html_path.replace(".html", ".png")

    try:
        result = subprocess.run([
            chrome_exe,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--hide-scrollbars",
            "--disable-web-security",
            "--default-background-color=00000000",   # transparent
            f"--screenshot={png_path}",
            f"--window-size={size},{size}",
            "--force-device-scale-factor=1",
            f"file:///{html_path.replace(os.sep, '/')}",
        ], capture_output=True, timeout=30)

        if os.path.exists(png_path):
            with open(png_path, "rb") as f:
                return f.read()
        else:
            print(f"    Chrome stderr: {result.stderr.decode('utf-8', errors='replace')[:300]}")
            return b""
    finally:
        for p in [html_path, png_path]:
            if os.path.exists(p):
                try:
                    os.unlink(p)
                except OSError:
                    pass


def make_placeholder(size: int, label: str) -> "Image.Image":
    from PIL import ImageDraw
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    m = 6
    draw.rounded_rectangle([m, m, size-m, size-m], radius=8, outline="white", width=2)
    draw.text((size // 2, size // 2), label[0].upper(), fill="white", anchor="mm")
    return img


def build_spritesheet(chrome_exe: str) -> "Image.Image":
    n = len(DOCK_ICONS)
    sheet = Image.new("RGBA", (ICON_SIZE * n, ICON_SIZE), (0, 0, 0, 0))

    for i, (name, slug, _) in enumerate(DOCK_ICONS):
        print(f"[{i+1}/{n}] {name} ({slug})")
        cache_png = os.path.join(CACHE_DIR, f"{slug}_w{ICON_SIZE}.png")

        if os.path.exists(cache_png):
            icon_img = Image.open(cache_png).convert("RGBA")
        else:
            raw_svg = fetch_svg(slug)
            patched = patch_svg_color(raw_svg, "white")
            png_bytes = svg_to_png_chrome(patched, ICON_SIZE, chrome_exe)

            if png_bytes:
                icon_img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
                if icon_img.size != (ICON_SIZE, ICON_SIZE):
                    icon_img = icon_img.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
                icon_img.save(cache_png)
                print(f"  Rendered OK ({icon_img.size[0]}x{icon_img.size[1]})")
            else:
                print(f"    [!] Chrome render failed, using placeholder")
                icon_img = make_placeholder(ICON_SIZE, name)
                icon_img.save(cache_png)

        sheet.paste(icon_img, (i * ICON_SIZE, 0), icon_img)

    return sheet

# ──────────────────────────────────────────────────────────────────────────────
# Luau module
# ──────────────────────────────────────────────────────────────────────────────

def luau_long_string(value: str) -> str:
    level = 0
    while "]" + "=" * level + "]" in value:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{value}\n]{eq}]"


def chunk_b64(data: bytes, width: int = 76) -> str:
    b64 = base64.b64encode(data).decode("ascii")
    return "\n".join(b64[i:i+width] for i in range(0, len(b64), width))


def build_name_table() -> str:
    return "\n".join(
        f'        ["{name}"] = {{{i}, {fb}}},'
        for i, (name, _, fb) in enumerate(DOCK_ICONS)
    )


LUAU_TEMPLATE = '''\
--!strict
--[[
    LucideDockIcons  -  auto-generated by tools/build_lucide_icons.py
    Spritesheet: {n} Lucide icons, {w}x{h}px, {size}px per slot.
    Source: https://lucide.dev (MIT License)
    
    Runtime behavior:
    - Exploit env: decode base64 -> writefile -> getcustomasset -> use as Image
    - Vanilla env: fallback to DEX++ LargeIcons spritesheet
]]

local Main, Lib, Apps, Settings

local function initDeps(data)
    Main     = data.Main
    Lib      = data.Lib
    Apps     = data.Apps
    Settings = data.Settings
end

local function initAfterMain() end

local function main()
    local ICON_SIZE    = {size}
    local CACHE_FOLDER = "{asset_folder}"
    local CACHE_FILE   = CACHE_FOLDER .. "/lucide_dock.png"

    -- base64-encoded PNG spritesheet ({w}x{h})
    local B64 = {b64_long}

    -- -----------------------------------------------------------------------
    -- Minimal base64 decoder
    -- -----------------------------------------------------------------------
    local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local b64map: {{[string]: number}} = {{}}
    for i = 1, #b64chars do b64map[b64chars:sub(i,i)] = i - 1 end

    local function b64decode(s: string): string
        local out = {{}}
        local buf, bits = 0, 0
        for c in s:gmatch("[%w%+%/]") do
            local v = b64map[c]
            if v then
                buf  = buf * 64 + v
                bits = bits + 6
                if bits >= 8 then
                    bits = bits - 8
                    out[#out+1] = string.char(math.floor(buf / 2^bits) % 256)
                    buf = buf % (2^bits)
                end
            end
        end
        return table.concat(out)
    end

    -- -----------------------------------------------------------------------
    -- Async asset loading
    -- -----------------------------------------------------------------------
    local assetUri: string? = nil
    local callbacks: {{(string?) -> ()}} = {{}}
    local started = false

    local function tryGetUri(): string?
        local e         = rawget(_G, "env") or {{}}
        local writefile = e.writefile    or rawget(_G, "writefile")
        local isfile    = e.isfile       or rawget(_G, "isfile")
        local isfolder  = e.isfolder     or rawget(_G, "isfolder")
        local mkfolder  = e.makefolder   or rawget(_G, "makefolder")
        local getca     = e.getcustomasset or rawget(_G, "getcustomasset")
        if not (writefile and isfile and isfolder and mkfolder and getca) then return nil end

        if not isfolder(CACHE_FOLDER) then
            if not pcall(mkfolder, CACHE_FOLDER) then return nil end
        end
        if not isfile(CACHE_FILE) then
            local ok, data = pcall(b64decode, B64)
            if not ok then return nil end
            if not pcall(writefile, CACHE_FILE, data) then return nil end
        end
        local ok, uri = pcall(getca, CACHE_FILE)
        return (ok and uri) or nil
    end

    local function ensureLoaded(cb: (string?) -> ())
        if assetUri ~= nil then
            cb(if assetUri == "" then nil else assetUri)
            return
        end
        table.insert(callbacks, cb)
        if started then return end
        started = true
        task.spawn(function()
            local uri = tryGetUri()
            assetUri = uri or ""
            local q = callbacks; callbacks = {{}}
            for _, fn in ipairs(q) do fn(uri) end
        end)
    end

    -- -----------------------------------------------------------------------
    -- Public API
    -- -----------------------------------------------------------------------
    local function Apply(label: ImageLabel, index: number, fallbackIdx: number?)
        ensureLoaded(function(uri: string?)
            if uri then
                label.Image           = uri
                label.ImageRectOffset = Vector2.new(index * ICON_SIZE, 0)
                label.ImageRectSize   = Vector2.new(ICON_SIZE, ICON_SIZE)
                label.ScaleType       = Enum.ScaleType.Crop
                label.Size            = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
            elseif Main.LargeIcons and fallbackIdx ~= nil then
                Main.LargeIcons:Display(label, fallbackIdx)
            end
        end)
    end

    local NAME_MAP: {{[string]: {{number}}}} = {{
{name_table}
    }}

    local function ApplyByName(label: ImageLabel, name: string)
        local e = NAME_MAP[name]
        if e then Apply(label, e[1], e[2]) end
    end

    Main.LucideIcons = {{
        Apply       = Apply,
        ApplyByName = ApplyByName,
        IconSize    = ICON_SIZE,
    }}
end

return {{InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}}
'''


def generate_luau(sheet: "Image.Image") -> str:
    buf = io.BytesIO()
    sheet.save(buf, format="PNG", optimize=True)
    png_bytes = buf.getvalue()
    w, h = sheet.size
    b64_long = luau_long_string(chunk_b64(png_bytes))
    return LUAU_TEMPLATE.format(
        n=len(DOCK_ICONS), w=w, h=h, size=ICON_SIZE,
        asset_folder=ASSET_FOLDER,
        b64_long=b64_long,
        name_table=build_name_table(),
    )

# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=== Lucide dock-icon builder ===\n")

    chrome = find_chrome()
    print(f"Using browser: {chrome}\n")

    print("[1/3] Building spritesheet ...")
    sheet = build_spritesheet(chrome)
    sheet.save(SHEET_PNG)
    w, h = sheet.size
    print(f"      Saved -> {SHEET_PNG}  ({w}x{h})")

    print("\n[2/3] Generating Luau module ...")
    luau_code = generate_luau(sheet)
    os.makedirs(os.path.dirname(os.path.abspath(LUAU_OUT)), exist_ok=True)
    with open(LUAU_OUT, "w", encoding="utf-8") as f:
        f.write(luau_code)
    print(f"      Saved -> {os.path.abspath(LUAU_OUT)}")

    print("\n[3/3] Done!")
    print("\nNext steps:")
    print("  1. Run: python build.py")
    print("  2. In MainMenu.luau dock loop, use:")
    print("     Main.LucideIcons.ApplyByName(icon, item.Name)")
