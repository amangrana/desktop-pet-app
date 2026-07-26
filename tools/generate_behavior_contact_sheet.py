#!/usr/bin/env python3
"""Generate a deterministic light/dark behavior contact sheet for a pet."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


CORE_BEHAVIORS = (
    "idle_blink",
    "click_happy",
    "keyboard",
    "mouse",
    "focus_calm",
    "reminder_attention",
)
CANVAS_WIDTH = 1800
HEADER_HEIGHT = 150
ROW_HEIGHT = 225
FOOTER_HEIGHT = 48
LABEL_WIDTH = 260
OUTER_GAP = 20
PANEL_WIDTH = 740
LIGHT_BACKGROUND = "#F3F0EA"
DARK_BACKGROUND = "#25212D"
SHEET_BACKGROUND = "#17141D"
TEXT_PRIMARY = "#F7F2FA"
TEXT_SECONDARY = "#BEB4C8"
ACCENT = "#D9A7C5"
MISSING = "#FF7B88"


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = (
        "C:/Windows/Fonts/seguisb.ttf" if bold
        else "C:/Windows/Fonts/segoeui.ttf",
        "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf",
    )
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _master_path(pet_dir: Path) -> Path:
    pet_id = pet_dir.name
    candidates = (
        pet_dir / f"{pet_id}-master.png",
        pet_dir / "runtime" / "idle.png",
        pet_dir / "idle.png",
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(
        f"No idle master found under {pet_dir}. "
        f"Expected {pet_id}-master.png or runtime/idle.png."
    )


def _behavior_frames(pet_dir: Path, behavior_id: str) -> list[Path]:
    directory = pet_dir / "runtime" / "behaviors" / behavior_id
    if not directory.is_dir():
        return []
    return sorted(
        path for path in directory.iterdir()
        if path.is_file() and path.suffix.lower() == ".png"
    )


def _fit_frame(path: Path, maximum_size: int) -> Image.Image:
    frame = Image.open(path).convert("RGBA")
    frame.thumbnail(
        (maximum_size, maximum_size),
        Image.Resampling.LANCZOS,
    )
    return frame


def _draw_panel(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    panel_box: tuple[int, int, int, int],
    background: str,
    frames: list[Path],
) -> None:
    draw.rounded_rectangle(
        panel_box,
        radius=14,
        fill=background,
        outline="#675D70",
        width=2,
    )
    left, top, right, bottom = panel_box
    if not frames:
        message = "MISSING"
        bounds = draw.textbbox((0, 0), message, font=_font(22, True))
        draw.text(
            (
                (left + right - (bounds[2] - bounds[0])) // 2,
                (top + bottom - (bounds[3] - bounds[1])) // 2,
            ),
            message,
            font=_font(22, True),
            fill=MISSING,
        )
        return

    gap = 18
    available_width = right - left - gap * (len(frames) + 1)
    cell_width = max(72, available_width // len(frames))
    maximum_size = min(172, cell_width, bottom - top - 42)
    total_width = cell_width * len(frames) + gap * (len(frames) - 1)
    cursor_x = left + (right - left - total_width) // 2
    caption_font = _font(14)
    for path in frames:
        frame = _fit_frame(path, maximum_size)
        frame_x = cursor_x + (cell_width - frame.width) // 2
        frame_y = top + 10 + (maximum_size - frame.height) // 2
        sheet.alpha_composite(frame, (frame_x, frame_y))
        caption = path.stem.removeprefix("frame_").replace("_", " ")
        bounds = draw.textbbox((0, 0), caption, font=caption_font)
        caption_x = cursor_x + (
            cell_width - (bounds[2] - bounds[0])
        ) // 2
        draw.text(
            (caption_x, bottom - 27),
            caption,
            font=caption_font,
            fill="#514A57" if background == LIGHT_BACKGROUND
            else "#E7DFEB",
        )
        cursor_x += cell_width + gap


def generate_contact_sheet(pet_dir: Path, output: Path) -> Path:
    pet_dir = pet_dir.resolve()
    master = _master_path(pet_dir)
    rows: list[tuple[str, list[Path]]] = [("idle", [master])]
    missing: list[str] = []
    for behavior_id in CORE_BEHAVIORS:
        frames = _behavior_frames(pet_dir, behavior_id)
        if not frames:
            missing.append(behavior_id)
        rows.append((behavior_id, frames))
    if missing:
        raise FileNotFoundError(
            "Missing runtime behavior directories or PNG frames: "
            + ", ".join(missing)
        )

    height = HEADER_HEIGHT + ROW_HEIGHT * len(rows) + FOOTER_HEIGHT
    sheet = Image.new("RGBA", (CANVAS_WIDTH, height), SHEET_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = _font(34, True)
    subtitle_font = _font(18)
    row_font = _font(22, True)
    detail_font = _font(15)
    pet_name = pet_dir.name.capitalize()

    draw.text(
        (OUTER_GAP, 24),
        f"{pet_name} | desktop_pet_behavior_v1",
        font=title_font,
        fill=TEXT_PRIMARY,
    )
    draw.text(
        (OUTER_GAP, 72),
        "Runtime keyframes shown on light and dark backgrounds",
        font=subtitle_font,
        fill=TEXT_SECONDARY,
    )
    light_x = LABEL_WIDTH + OUTER_GAP * 2
    dark_x = light_x + PANEL_WIDTH + OUTER_GAP
    draw.text(
        (light_x, 112),
        "LIGHT BACKGROUND",
        font=detail_font,
        fill=ACCENT,
    )
    draw.text(
        (dark_x, 112),
        "DARK BACKGROUND",
        font=detail_font,
        fill=ACCENT,
    )

    for index, (behavior_id, frames) in enumerate(rows):
        row_top = HEADER_HEIGHT + index * ROW_HEIGHT
        draw.line(
            (OUTER_GAP, row_top, CANVAS_WIDTH - OUTER_GAP, row_top),
            fill="#403847",
            width=1,
        )
        draw.text(
            (OUTER_GAP, row_top + 62),
            behavior_id,
            font=row_font,
            fill=TEXT_PRIMARY,
        )
        count_text = (
            "base idle frame"
            if behavior_id == "idle"
            else f"{len(frames)} independent runtime frame"
            + ("" if len(frames) == 1 else "s")
        )
        draw.text(
            (OUTER_GAP, row_top + 98),
            count_text,
            font=detail_font,
            fill=TEXT_SECONDARY,
        )
        light_box = (
            light_x,
            row_top + 14,
            light_x + PANEL_WIDTH,
            row_top + ROW_HEIGHT - 14,
        )
        dark_box = (
            dark_x,
            row_top + 14,
            dark_x + PANEL_WIDTH,
            row_top + ROW_HEIGHT - 14,
        )
        _draw_panel(sheet, draw, light_box, LIGHT_BACKGROUND, frames)
        _draw_panel(sheet, draw, dark_box, DARK_BACKGROUND, frames)

    footer_y = HEADER_HEIGHT + ROW_HEIGHT * len(rows)
    draw.text(
        (OUTER_GAP, footer_y + 15),
        "Generated from project runtime assets; authoring sources are excluded.",
        font=detail_font,
        fill=TEXT_SECONDARY,
    )
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output, quality=95)
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--pet-dir",
        required=True,
        type=Path,
        help="Pet package directory, for example assets/pets/leo",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output PNG; defaults to authoring/behavior-contact-sheet.png",
    )
    args = parser.parse_args()
    output = args.output or (
        args.pet_dir / "authoring" / "behavior-contact-sheet.png"
    )
    saved = generate_contact_sheet(args.pet_dir, output)
    print(f"Behavior contact sheet: {saved}")


if __name__ == "__main__":
    main()
