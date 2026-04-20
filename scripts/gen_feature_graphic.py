#!/usr/bin/env python3
"""Generate a 1024x500 Play Store feature graphic for ESP Frame.

Usage:
    python3 scripts/gen_feature_graphic.py [--screenshots <dir>] [--output <path>]

Screenshots default to the img/ directory in the project root.
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH, HEIGHT = 1024, 500
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
ICON_PATH = os.path.join(PROJECT_DIR, "assets", "icon.png")
DEFAULT_OUTPUT = os.path.join(PROJECT_DIR, "docs", "feature_graphic.png")
DEFAULT_SCREENSHOTS_DIR = os.path.join(PROJECT_DIR, "img")

# Best screenshots: Image Processing (colorful), AI Generation, Settings
DEFAULT_SCREENSHOTS = [
    "image_processing.png",
    "ai_generation.png",
    "settings.png",
]


def create_rounded_mask(size, radius):
    """Create a rounded rectangle mask."""
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def add_phone_frame(screenshot, target_height):
    """Resize screenshot and add rounded corners with subtle border."""
    aspect = screenshot.width / screenshot.height
    target_width = int(target_height * aspect)
    screenshot = screenshot.resize((target_width, target_height), Image.LANCZOS)

    radius = 14
    mask = create_rounded_mask((target_width, target_height), radius)

    border = 2
    frame_w = target_width + border * 2
    frame_h = target_height + border * 2
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))

    # Subtle white border
    border_mask = create_rounded_mask((frame_w, frame_h), radius + border)
    border_layer = Image.new("RGBA", (frame_w, frame_h), (255, 255, 255, 60))
    frame.paste(border_layer, mask=border_mask)

    # Paste screenshot with rounded corners
    screenshot_rgba = screenshot.convert("RGBA")
    rounded = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    rounded.paste(screenshot_rgba, mask=mask)
    frame.paste(rounded, (border, border), rounded)

    return frame


def main():
    parser = argparse.ArgumentParser(description="Generate Play Store feature graphic")
    parser.add_argument(
        "--screenshots", default=DEFAULT_SCREENSHOTS_DIR,
        help="Directory containing app screenshots (default: img/)",
    )
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="Output PNG path")
    parser.add_argument(
        "--files",
        nargs="*",
        default=DEFAULT_SCREENSHOTS,
        help="Screenshot filenames to use (default: built-in list)",
    )
    args = parser.parse_args()

    # Solid brown background matching app theme
    bg = Image.new("RGBA", (WIDTH, HEIGHT), (75, 48, 26, 255))

    # Subtle gradient overlay - slightly lighter at top
    gradient = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    for y in range(HEIGHT):
        t = y / HEIGHT
        alpha = int(30 * (1 - t))
        for x in range(WIDTH):
            tx = x / WIDTH
            a = int(alpha * (1 - tx * 0.5))
            gradient.putpixel((x, y), (255, 230, 200, a))
    bg = Image.alpha_composite(bg, gradient)

    # Load and place app icon
    icon = Image.open(ICON_PATH).convert("RGBA")
    icon_size = 88
    icon = icon.resize((icon_size, icon_size), Image.LANCZOS)
    icon_x = 70
    icon_y = HEIGHT // 2 - 80
    bg.paste(icon, (icon_x, icon_y), icon)

    # Add text
    draw = ImageDraw.Draw(bg)

    font_paths = [
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]

    title_font = subtitle_font = None
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                title_font = ImageFont.truetype(fp, 46)
                subtitle_font = ImageFont.truetype(fp, 16)
                break
            except Exception:
                continue

    if title_font is None:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()

    # App title
    title_y = icon_y + icon_size + 18
    draw.text(
        (icon_x, title_y), "ESP Frame", fill=(255, 255, 255, 255), font=title_font
    )

    # Subtitle
    sub_y = title_y + 55
    draw.text(
        (icon_x, sub_y),
        "Companion app for the",
        fill=(220, 200, 175, 220),
        font=subtitle_font,
    )
    draw.text(
        (icon_x, sub_y + 22),
        "esp32-photoframe project",
        fill=(220, 200, 175, 220),
        font=subtitle_font,
    )

    # Load screenshots
    screenshot_height = 400
    screenshots = []
    for fname in args.files:
        path = os.path.join(args.screenshots, fname)
        if not os.path.exists(path):
            print(f"Warning: screenshot not found: {path}")
            continue
        img = Image.open(path).convert("RGBA")
        framed = add_phone_frame(img, screenshot_height)
        screenshots.append(framed)

    if not screenshots:
        print("Error: no screenshots found")
        return 1

    # Position screenshots - spread across right side with slight stagger
    gap = 12
    total_w = sum(s.width for s in screenshots) + gap * (len(screenshots) - 1)
    start_x = WIDTH - total_w - 40

    # Stagger heights slightly for visual interest
    y_offsets = [25, -15, 20]

    x = start_x
    for i, sc in enumerate(screenshots):
        py = (HEIGHT - sc.height) // 2 + y_offsets[i % len(y_offsets)]

        # Drop shadow
        shadow = Image.new("RGBA", (sc.width + 24, sc.height + 24), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rounded_rectangle(
            [6, 8, sc.width + 16, sc.height + 18], radius=16, fill=(0, 0, 0, 50)
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(10))
        bg.paste(shadow, (x - 8, py - 4), shadow)

        bg.paste(sc, (x, py), sc)
        x += sc.width + gap

    # Save
    final = bg.convert("RGB")
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    final.save(args.output, "PNG", quality=95)
    print(f"Feature graphic saved to {args.output}")
    print(f"Size: {final.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
