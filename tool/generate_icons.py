"""Resize the official WeBrand mark into every platform launcher icon and brand asset.

Platform targets:
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset` and `LaunchImage.imageset`
- Android: `android/app/src/main/res/mipmap-*` (legacy full icons)
           `android/app/src/main/res/drawable-*` (adaptive icon foreground)
           `android/app/src/main/res/values/colors.xml` (adaptive background)
- Web: `web/favicon.png` and `web/icons/`
- Windows: `windows/runner/resources/app_icon.ico`
- Brand: `assets/brand/` (webrand_icon, webrand_mark, webrand_logo, etc.)
"""

from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "assets" / "images"
BRAND = ROOT / "assets" / "brand"
WHITE = (255, 255, 255)


def save_png(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, "PNG", optimize=True)


def save_adaptive_foreground(mark_image: Image.Image, path: Path, size: int) -> None:
    """Place the mark inside the adaptive-icon safe zone (66dp keyline inside 108dp canvas).

    Foreground uses transparent background so Android's adaptive icon engine
    layers it cleanly over @color/ic_launcher_background with parallax.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 0))

    # Safe zone keyline width: 56dp out of 108dp canvas keeps all corners inside 66dp diameter circle.
    bbox = mark_image.getbbox()
    if bbox:
        cropped = mark_image.crop(bbox)
    else:
        cropped = mark_image

    target_w = round(size * 56 / 108)
    target_h = round(target_w * cropped.height / cropped.width)

    mark_resized = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    offset_x = (size - target_w) // 2
    offset_y = (size - target_h) // 2

    canvas.paste(mark_resized, (offset_x, offset_y), mark_resized)
    canvas.save(path, "PNG", optimize=True)


def main() -> None:
    # 1. Load source images
    webrand_3_path = IMAGES / "webrand_3.png"
    webrand_4_path = IMAGES / "webrand_4.png"
    webrand_1_path = IMAGES / "webrand_1.png"
    webrand_2_path = IMAGES / "webrand_2.png"

    icon_white = Image.open(webrand_3_path).convert("RGB")
    mark_transparent = Image.open(webrand_4_path).convert("RGBA")

    # 2. iOS AppIcon.appiconset
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
        save_png(icon_white, ios / name, size)

    # 3. Android launcher icons
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    # Legacy mipmap icons (solid white background)
    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        save_png(icon_white, res / folder / "ic_launcher.png", size)

    # Adaptive icon foregrounds (transparent keyline)
    for folder, size in {
        "drawable-mdpi": 108,
        "drawable-hdpi": 162,
        "drawable-xhdpi": 216,
        "drawable-xxhdpi": 324,
        "drawable-xxxhdpi": 432,
    }.items():
        save_adaptive_foreground(mark_transparent, res / folder / "ic_launcher_foreground.png", size)

    # Update Android ic_launcher_background color to white
    colors_xml = res / "values" / "colors.xml"
    if colors_xml.exists():
        content = colors_xml.read_text(encoding="utf-8")
        if "#FF000000" in content:
            content = content.replace("#FF000000", "#FFFFFFFF")
            colors_xml.write_text(content, encoding="utf-8")

    # 4. Web icons
    web = ROOT / "web"
    save_png(icon_white, web / "favicon.png", 32)
    save_png(icon_white, web / "icons" / "Icon-192.png", 192)
    save_png(icon_white, web / "icons" / "Icon-512.png", 512)
    save_png(icon_white, web / "icons" / "Icon-maskable-192.png", 192)
    save_png(icon_white, web / "icons" / "Icon-maskable-512.png", 512)

    # 5. Windows ICO
    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico.parent.mkdir(parents=True, exist_ok=True)
    icon_white.save(
        ico,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    # 6. Prepare brand assets in assets/brand/
    BRAND.mkdir(parents=True, exist_ok=True)
    icon_white.save(BRAND / "webrand_icon.png", "PNG", optimize=True)
    mark_transparent.save(BRAND / "webrand_mark.png", "PNG", optimize=True)
    if webrand_1_path.exists():
        shutil.copy2(webrand_1_path, BRAND / "webrand_logo.png")
    if webrand_2_path.exists():
        shutil.copy2(webrand_2_path, BRAND / "webrand_logo_dark.png")

    # Backward compatibility aliases for existing code before refactoring completes
    icon_white.save(BRAND / "sabt_icon.png", "PNG", optimize=True)
    mark_transparent.save(BRAND / "sabt_mark.png", "PNG", optimize=True)

    # 7. iOS LaunchImage.imageset
    launch_image_set = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    launch_image_set.mkdir(parents=True, exist_ok=True)
    save_png(icon_white, launch_image_set / "LaunchImage.png", 128)
    save_png(icon_white, launch_image_set / "LaunchImage@2x.png", 256)
    save_png(icon_white, launch_image_set / "LaunchImage@3x.png", 384)

    print("All icons and brand assets generated successfully.")


if __name__ == "__main__":
    main()
