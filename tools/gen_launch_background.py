"""按设计稿合成启动页整屏图：1170×2532（390×844vp @3x），明/暗两套，系统启动页与应用首帧共用。"""

import argparse
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "products" / "default" / "src" / "main" / "resources"

DESIGN_WIDTH_VP = 390
DESIGN_HEIGHT_VP = 844
SCALE = 3
LOGO_SIZE_VP = 86
LOGO_TOP_VP = 270
NAME_TOP_VP = 382
NAME_SIZE_VP = 22
APP_NAME = "KeePassHomo"

THEMES = (
    {
        "background": "#FFFFFF",
        "text": "#191C1D",
        "icon": MEDIA / "base" / "media" / "launch_icon.png",
        "output": MEDIA / "base" / "media" / "launch_background.png",
    },
    {
        "background": "#0A0C0D",
        "text": "#EDEFF0",
        "icon": MEDIA / "dark" / "media" / "launch_icon.png",
        "output": MEDIA / "dark" / "media" / "launch_background.png",
    },
)

FONT_RELATIVE_PATH = Path("sdk/default/hms/previewer/resources/fonts/HarmonyOS_Sans_SC.ttf")
FONT_ROOTS = (
    Path("C:/Program Files/Huawei/DevEco Studio"),
    Path("D:/Program Files/Huawei/DevEco Studio"),
)


def resolve_font(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    env_font = os.environ.get("HARMONYOS_SANS_FONT")
    if env_font:
        return Path(env_font)
    for root in FONT_ROOTS:
        candidate = root / FONT_RELATIVE_PATH
        if candidate.exists():
            return candidate
    raise FileNotFoundError("未找到 HarmonyOS_Sans_SC.ttf，请通过 --font 或 HARMONYOS_SANS_FONT 指定")


def vp(value: float) -> int:
    return round(value * SCALE)


def compose(theme: dict, font_path: Path) -> None:
    width = vp(DESIGN_WIDTH_VP)
    height = vp(DESIGN_HEIGHT_VP)
    image = Image.new("RGB", (width, height), theme["background"])
    logo_size = vp(LOGO_SIZE_VP)
    logo = Image.open(theme["icon"]).convert("RGBA").resize((logo_size, logo_size), Image.LANCZOS)
    image.paste(logo, ((width - logo_size) // 2, vp(LOGO_TOP_VP)), logo)
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(font_path), vp(NAME_SIZE_VP))
    draw.text((width // 2, vp(NAME_TOP_VP)), APP_NAME, font=font, fill=theme["text"],
              anchor="ma", stroke_width=1, stroke_fill=theme["text"])
    image.save(theme["output"])
    print(f"{theme['output'].relative_to(ROOT)} {width}x{height}")


def main() -> None:
    parser = argparse.ArgumentParser(description="生成启动页整屏图")
    parser.add_argument("--font", help="HarmonyOS Sans SC 字体路径")
    args = parser.parse_args()
    font_path = resolve_font(args.font)
    for theme in THEMES:
        compose(theme, font_path)


if __name__ == "__main__":
    main()
