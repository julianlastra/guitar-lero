# Asset Guide

This folder is organized so external art generation can target fixed file names.

## Folder Layout

- `res/backgrounds/gameplay/`
- `res/sprites/notes/`
- `res/sprites/fx/`
- `res/ui/hit_zone/`

## Required Files

### Gameplay Background

- `res/backgrounds/gameplay/lane_bg.png`
  - Background for the gameplay screen
  - No HUD text
  - 3 lanes
  - Dark rock/arcade style

### Note Sprites

- `res/sprites/notes/note_red.png`
- `res/sprites/notes/note_yellow.png`
- `res/sprites/notes/note_green.png`
  - Recommended size: `16x16`
  - Transparent background
  - Pixel art, Genesis-friendly

Optional sheet version:

- `res/sprites/notes/notes_sheet.png`

### Hit Zone

- `res/ui/hit_zone/hit_zone_red.png`
- `res/ui/hit_zone/hit_zone_yellow.png`
- `res/ui/hit_zone/hit_zone_green.png`
  - Recommended size: `24x8` or `32x8`
  - Transparent background

Optional bright variants:

- `res/ui/hit_zone/hit_zone_red_hit.png`
- `res/ui/hit_zone/hit_zone_yellow_hit.png`
- `res/ui/hit_zone/hit_zone_green_hit.png`

### Feedback FX

- `res/sprites/fx/fx_hit.png`
- `res/sprites/fx/fx_miss.png`
- `res/sprites/fx/fx_spark.png`
  - Recommended size: `16x16` or `32x16`
  - Transparent background

## Genesis Art Constraints

- Pixel art only
- No anti-aliasing
- High contrast shapes
- Readable on dark backgrounds
- Keep color count low
- Prefer tiles aligned to `8x8`
- Avoid tiny details that disappear in motion

## Recommended Workflow

1. Generate PNG assets with the exact names above.
2. Put them into these folders.
3. Then Codex can wire them into SGDK resources and code.
