"""Resize the official Sabt marks into platform launcher icons.

Sources live in assets/brand:
- sabt_icon.png — black mark for iOS, web, Windows
- sabt_icon_android.png — purple mark for the Android launcher
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "brand"


def save_png(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, "PNG", optimize=True)


def main() -> None:
    black = Image.open(BRAND / "sabt_icon.png").convert("RGB")
    android = Image.open(BRAND / "sabt_icon_android.png").convert("RGB")

    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, size in ios_sizes.items():
        save_png(black, ios / name, size)

    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        save_png(android, res / folder / "ic_launcher.png", size)

    web = ROOT / "web"
    save_png(black, web / "favicon.png", 32)
    save_png(black, web / "icons" / "Icon-192.png", 192)
    save_png(black, web / "icons" / "Icon-512.png", 512)
    save_png(black, web / "icons" / "Icon-maskable-192.png", 192)
    save_png(black, web / "icons" / "Icon-maskable-512.png", 512)

    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    black.save(
        ico,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()
