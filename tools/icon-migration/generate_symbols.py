#!/usr/bin/env python3
"""从 Material Symbols Outlined 生成 HarmonyOS 自定义 Symbol 资源。"""

import json
import os
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
CACHE_DIR = TOOL_DIR / ".cache"
MAPPING_PATH = TOOL_DIR / "mapping.json"
OUTPUT_DIR = ROOT / "products/default/src/main/resources/rawfile/symbol"
STRING_PATH = ROOT / "products/default/src/main/resources/base/element/string_symbols.json"

FONT_URL = (
    "https://raw.githubusercontent.com/google/material-design-icons/master/"
    "variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
)
CODEPOINTS_URL = (
    "https://raw.githubusercontent.com/google/material-design-icons/master/"
    "variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints"
)
FONT_PATH = CACHE_DIR / "MaterialSymbolsOutlined.ttf"
CODEPOINTS_PATH = CACHE_DIR / "MaterialSymbolsOutlined.codepoints"


def download_if_missing(url: str, path: Path) -> None:
    if path.exists():
        return
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "KeePassHomo-icon-migration"})
    with urllib.request.urlopen(request) as response:
        path.write_bytes(response.read())


def load_codepoints() -> dict[str, int]:
    codepoints: dict[str, int] = {}
    for line in CODEPOINTS_PATH.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) == 2:
            codepoints[parts[0]] = int(parts[1], 16)
    return codepoints


def generate_font(icons: list[dict], fill: int, start_codepoint: int) -> dict[str, int]:
    codepoints = load_codepoints()
    missing = [icon["material"] for icon in icons if icon["material"] not in codepoints]
    if missing:
        raise ValueError(f"Material 图标不存在: {missing}")

    font = TTFont(FONT_PATH)
    instantiateVariableFont(font, {"wght": 400, "opsz": 24, "FILL": fill, "GRAD": 0}, inplace=True)

    options = subset.Options()
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables += ["DSIG"]
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=[codepoints[icon["material"]] for icon in icons])
    subsetter.subset(font)

    original_cmap = font.getBestCmap()
    new_cmap: dict[int, str] = {}
    assigned: dict[str, int] = {}
    for index, icon in enumerate(icons):
        codepoint = start_codepoint + index
        assigned[icon["key"]] = codepoint
        new_cmap[codepoint] = original_cmap[codepoints[icon["material"]]]

    cmap = CmapSubtable.getSubtableClass(12)()
    cmap.platformID = 3
    cmap.platEncID = 10
    cmap.language = 0
    cmap.cmap = new_cmap
    font["cmap"].tables = [cmap]

    family = f"KeePassHomoSymbolsFill{fill}"
    for record in font["name"].names:
        if record.nameID in (1, 4, 6, 16):
            record.string = family.encode("utf-16-be")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    font.save(OUTPUT_DIR / f"symbol_fill{fill}.ttf")
    manifest = {
        "version": "1.0.0",
        "axes": [],
        "icons": {icon["key"]: {"unicode": chr(assigned[icon["key"]])} for icon in icons},
    }
    (OUTPUT_DIR / f"symbol_fill{fill}.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return assigned


def write_strings(assigned: dict[str, int]) -> None:
    resources = [
        {"name": key, "value": f"0x{codepoint:X}"}
        for key, codepoint in sorted(assigned.items())
    ]
    STRING_PATH.write_text(
        json.dumps({"string": resources}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    download_if_missing(FONT_URL, FONT_PATH)
    download_if_missing(CODEPOINTS_URL, CODEPOINTS_PATH)

    mapping = json.loads(MAPPING_PATH.read_text(encoding="utf-8"))
    icons = mapping["icons"]
    keys = [icon["key"] for icon in icons]
    if len(keys) != len(set(keys)):
        raise ValueError("mapping.json 存在重复语义键")

    fill0 = [icon for icon in icons if icon["fill"] == 0]
    fill1 = [icon for icon in icons if icon["fill"] == 1]
    assigned = {}
    assigned.update(generate_font(fill0, 0, 0x100000))
    assigned.update(generate_font(fill1, 1, 0x100100))
    write_strings(assigned)

    merged = Merger().merge([
        str(OUTPUT_DIR / "symbol_fill0.ttf"),
        str(OUTPUT_DIR / "symbol_fill1.ttf"),
    ])
    merged.save(OUTPUT_DIR / "symbol_all.ttf")
    manifests = [
        json.loads((OUTPUT_DIR / f"symbol_fill{fill}.json").read_text(encoding="utf-8"))
        for fill in (0, 1)
    ]
    all_manifest = {
        "version": "1.0.0",
        "axes": [],
        "icons": {key: value for manifest in manifests for key, value in manifest["icons"].items()},
    }
    (OUTPUT_DIR / "symbol_all.json").write_text(
        json.dumps(all_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for fill in (0, 1):
        (OUTPUT_DIR / f"symbol_fill{fill}.ttf").unlink()
        (OUTPUT_DIR / f"symbol_fill{fill}.json").unlink()

    print(f"symbol_all.ttf: {((OUTPUT_DIR / 'symbol_all.ttf').stat().st_size)} B")
    print(f"symbol_all.json: {((OUTPUT_DIR / 'symbol_all.json').stat().st_size)} B")
    print(f"icons={len(icons)}, strings={STRING_PATH.stat().st_size} B")


if __name__ == "__main__":
    main()
