#!/usr/bin/env python3
"""从 Material Symbols 生成 HarmonyOS 自定义 Symbol 资源。"""

import json
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

FONT_BASE_URL = "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/"

# 每个来源独立分配码位段，保证已有图标的码位不随来源增加而漂移。
SOURCES = {
    "outlined": {"family": "MaterialSymbolsOutlined", "starts": {0: 0x100000, 1: 0x100100}},
    "sharp": {"family": "MaterialSymbolsSharp", "starts": {0: 0x100200, 1: 0x100300}},
}

_CODEPOINTS: dict[str, dict[str, int]] = {}


def source_font_path(source: str) -> Path:
    return CACHE_DIR / f"{SOURCES[source]['family']}.ttf"


def source_codepoints_path(source: str) -> Path:
    return CACHE_DIR / f"{SOURCES[source]['family']}.codepoints"


def download_if_missing(url: str, path: Path) -> None:
    if path.exists():
        return
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "KeePassHomo-icon-migration"})
    with urllib.request.urlopen(request) as response:
        path.write_bytes(response.read())


def download_source(source: str) -> None:
    family = SOURCES[source]["family"]
    base = FONT_BASE_URL + family + "%5BFILL%2CGRAD%2Copsz%2Cwght%5D"
    download_if_missing(base + ".ttf", source_font_path(source))
    download_if_missing(base + ".codepoints", source_codepoints_path(source))


def load_codepoints(source: str) -> dict[str, int]:
    if source not in _CODEPOINTS:
        codepoints: dict[str, int] = {}
        for line in source_codepoints_path(source).read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) == 2:
                codepoints[parts[0]] = int(parts[1], 16)
        _CODEPOINTS[source] = codepoints
    return _CODEPOINTS[source]


def generate_font(icons: list[dict], fill: int, start_codepoint: int, source: str) -> dict[str, int]:
    codepoints = load_codepoints(source)
    missing = [icon["material"] for icon in icons if icon["material"] not in codepoints]
    if missing:
        raise ValueError(f"Material 图标不存在: {missing}")

    font = TTFont(source_font_path(source))
    instantiateVariableFont(font, {"wght": 400, "opsz": 24, "FILL": fill, "GRAD": 0}, inplace=True)

    options = subset.Options()
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    # symbolRegister 限制 TTF 体积，去掉 hinting 与无用表以留出新增图标的余量。
    options.hinting = False
    options.drop_tables += ["DSIG", "GSUB", "gasp", "prep"]
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
    font.save(OUTPUT_DIR / f"symbol_{source}_fill{fill}.ttf")
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
    icons = json.loads(MAPPING_PATH.read_text(encoding="utf-8"))["icons"]
    keys = [icon["key"] for icon in icons]
    if len(keys) != len(set(keys)):
        raise ValueError("mapping.json 存在重复语义键")

    used_sources = {icon.get("source", "outlined") for icon in icons}
    unknown = used_sources - set(SOURCES)
    if unknown:
        raise ValueError(f"mapping.json 存在未登记的图标来源: {sorted(unknown)}")
    for source in used_sources:
        download_source(source)

    assigned: dict[str, int] = {}
    font_paths: list[str] = []
    manifests: list[dict] = []
    for source, config in SOURCES.items():
        if source not in used_sources:
            continue
        for fill in (0, 1):
            group = [icon for icon in icons
                     if icon.get("source", "outlined") == source and icon["fill"] == fill]
            if not group:
                continue
            assigned.update(generate_font(group, fill, config["starts"][fill], source))
            font_paths.append(str(OUTPUT_DIR / f"symbol_{source}_fill{fill}.ttf"))
            manifests.append({
                "version": "1.0.0",
                "axes": [],
                "icons": {icon["key"]: {"unicode": chr(assigned[icon["key"]])} for icon in group},
            })
    write_strings(assigned)

    merged = Merger().merge(font_paths)
    merged.save(OUTPUT_DIR / "symbol_all.ttf")
    all_manifest = {
        "version": "1.0.0",
        "axes": [],
        "icons": {key: value for manifest in manifests for key, value in manifest["icons"].items()},
    }
    (OUTPUT_DIR / "symbol_all.json").write_text(
        json.dumps(all_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for path in font_paths:
        Path(path).unlink()

    print(f"symbol_all.ttf: {((OUTPUT_DIR / 'symbol_all.ttf').stat().st_size)} B")
    print(f"symbol_all.json: {((OUTPUT_DIR / 'symbol_all.json').stat().st_size)} B")
    print(f"icons={len(icons)}, strings={STRING_PATH.stat().st_size} B")


if __name__ == "__main__":
    main()
