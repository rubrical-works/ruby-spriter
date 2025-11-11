# Use Cases & Examples

## Game Development with Godot

### Character Animation Sprites

```bash
# Export from Blender/animation software to MP4
# Convert to optimized spritesheet with background removal

ruby_spriter --video character_walk.mp4 \
  --frames 16 --columns 4 \
  --scale 50 --remove-bg \
  --sharpen
```

**Workflow:**
1. Export character animation as MP4 from Blender (or similar)
2. Ruby Spriter extracts frames and removes background
3. Output spritesheet ready for Godot AnimatedSprite2D
4. Set HFrames=4, VFrames=4 in Godot inspector

### VFX and Particle Effects

```bash
# High frame count for smooth effects
ruby_spriter --video explosion.mp4 \
  --frames 64 --columns 8 \
  --scale 75 --interpolation nohalo
```

**Use Cases:**
- Explosion animations
- Particle effects (fire, smoke, water)
- Lightning effects
- Magical spells and auras

### Multiple Character Directions

#### Using File List

```bash
# Consolidate walk cycles for 8 directions (file list)
ruby_spriter --consolidate \
  walk_n.png,walk_ne.png,walk_e.png,walk_se.png,\
  walk_s.png,walk_sw.png,walk_w.png,walk_nw.png \
  --output character_walk_all.png
```

#### Using Directory

```bash
# Or consolidate all spritesheets in a directory (v0.6.7+)
ruby_spriter --consolidate --dir "walk_cycles/" \
  --output character_walk_all.png
```

**Godot Integration:**
```gdscript
# In AnimatedSprite2D
HFrames = 4  # 4 walk frames per direction
VFrames = 8  # 8 directions
frame = direction_row * 4 + frame_index
```

---

## Batch Processing Workflows (v0.6.7+)

### Process Entire Animation Library

```bash
# Process all videos in a directory with consistent settings
ruby_spriter --batch --dir "raw_animations/" \
  --outputdir "game_assets/sprites/" \
  --scale 50 --remove-bg --sharpen --max-compress
```

**Features:**
- All MP4s processed with same settings
- Unique filenames prevent overwrites
- Compression reduces file sizes
- Perfect for game asset pipelines

### Create and Consolidate Multiple Character States

```bash
# Process all character state animations
ruby_spriter --batch --dir "character_states/" \
  --frames 8 --columns 4 \
  --batch-consolidate
```

**Output:**
- All states (idle, run, jump, fall, etc.) processed individually
- Final consolidated spritesheet with all states vertically stacked
- Ready to import into Godot

---

## Quality Enhancement

### Downscale High-Res Renders While Maintaining Sharpness

```bash
# Downscale high-resolution renders with quality preservation
ruby_spriter --image 4k_sprite.png \
  --scale 25 --interpolation lohalo \
  --sharpen --sharpen-gain 1.0 \
  --max-compress \
  --output hd_sprite.png
```

**When to Use:**
- Reducing file sizes for web/mobile
- Optimizing for lower-end game platforms
- Maintaining visual quality during downscaling

---

## Frame-by-Frame Processing for Varying Backgrounds (v0.7.0.1+)

### Videos with Changing Backgrounds

```bash
# Perfect for recordings with varying backgrounds
ruby_spriter --video character_walk.mp4 \
  --remove-bg --by-frame \
  --frames 16 --columns 4
```

**Scenarios:**
- Character walks through different environments
- Lighting changes throughout video
- Camera moves or pans
- Studio setup with varied backgrounds

### Batch Process Multiple Videos with Varying Backgrounds

```bash
# Process entire animation library with frame-by-frame
ruby_spriter --batch --dir "animations/" \
  --remove-bg --by-frame \
  --scale 50 --sharpen
```

### Combine with Threshold Stepping for Maximum Quality

```bash
# Ultra-high quality output (very slow)
ruby_spriter --video explosion.mp4 \
  --remove-bg --by-frame --threshold-stepping \
  --frames 32 --columns 8
```

**Performance Note:**
- Standard mode: ~7.5 seconds for 16 frames
- Frame-by-frame: ~120 seconds (16× slower)
- Trade-off: Quality vs processing time

---

## Advanced Workflows

### Complete Processing Pipeline with Compression

```bash
# Full-featured spritesheet creation and optimization
ruby_spriter --video input.mp4 \
  --frames 64 --columns 8 \
  --scale 50 --interpolation nohalo \
  --remove-bg \
  --sharpen --sharpen-gain 0.8 \
  --max-compress
```

**What Happens:**
1. Extracts 64 frames in 8x8 grid
2. Creates spritesheet
3. Scales to 50% using nohalo interpolation
4. Removes background with global color select
5. Applies unsharp mask sharpening
6. Compresses PNG file (9-level compression)
7. Embeds metadata for Godot

### Advanced Background Removal with Multiple Techniques (v0.7.0+)

```bash
# Use all v0.7.0 background removal features
ruby_spriter --image complex_sprite.png \
  --remove-bg \
  --threshold-stepping \
  --try-inner \
  --multi-pass \
  --remove-smoke
```

**Processing Order:**
1. Edge sampling captures background palette
2. Threshold stepping tries multiple thresholds
3. Inner background removal targets center regions
4. Multi-pass cleanup removes ghost edges
5. Smoke detection identifies transparency gradients

---

## Mobile Game Development

### Optimize for Memory-Constrained Devices

```bash
# Create compact spritesheets for mobile
ruby_spriter --video character.mp4 \
  --frames 8 --columns 4 \
  --scale 25 --remove-bg \
  --max-compress \
  --output mobile_character.png
```

**Optimization Strategy:**
- Reduce frames for simpler animations
- Scale to 25-50% of original
- Remove backgrounds (transparency saves memory)
- Apply maximum compression

---

## Web Asset Pipeline

### Create Web-Optimized Spritesheets

```bash
# Optimize for web delivery
ruby_spriter --batch --dir "game_art/" \
  --outputdir "web_assets/" \
  --scale 50 \
  --remove-bg \
  --max-compress
```

**Benefits:**
- Reduced file sizes for faster downloads
- Batch processing saves time
- Compression reduces bandwidth
- Consistent optimization across all assets

---

## Prototyping and Game Jams

### Quick Asset Creation

```bash
# Fast prototyping with reasonable quality
ruby_spriter --video animation.mp4 \
  --preset preview \
  --remove-bg \
  --sharpen
```

**Presets Available:**
- `--preset thumbnail` - 3×?, 9 frames, 240px
- `--preset preview` - 4×?, 16 frames, 400px (recommended for prototypes)
- `--preset detailed` - 10×?, 50 frames, 320px
- `--preset contact` - 8×?, 64 frames, 160px

---

## Asset Refinement and Iteration

### Extract Specific Frames from Finished Spritesheet

```bash
# Extract only the best frames for animation loop
ruby_spriter --image sprite.png --extract 1,2,4,5,8 --columns 3

# Or extract with duplicates for animation slowdown
ruby_spriter --image sprite.png --extract 1,1,2,2,3,3
```

**Workflow:**
1. Process entire animation (generates spritesheet)
2. Review in game
3. Extract only good frames
4. Re-process extracted frames with better settings
5. No need to reprocess entire video

### Add Metadata to External Images

```bash
# You have a hand-crafted spritesheet, just add metadata
ruby_spriter --image hand_drawn_sprite.png --add-meta 4:4

# Or specify partial grid
ruby_spriter --image sprite.png --add-meta 8:8 --frames 60

# Then extract specific frames
ruby_spriter --image hand_drawn_sprite.png --extract 1,3,5,7 --columns 2
```

---

## Pipeline Integration

### CI/CD Automated Asset Processing

```bash
# Automated game asset build step
ruby_spriter --batch --dir "raw_videos/" \
  --outputdir "build/game_assets/" \
  --scale 50 --remove-bg \
  --max-compress \
  --batch-consolidate
```

**Integration:**
- Add to build pipeline
- Automatic on every commit
- Ensures consistent asset processing
- Fail-safe with exit codes

### GitHub Actions Example

```yaml
- name: Process game assets
  run: |
    ruby_spriter --batch --dir "raw_videos/" \
      --outputdir "assets/" \
      --remove-bg --max-compress
```

---

**Next Steps:**
- [Features Overview](FEATURES.md) - Learn all capabilities
- [Usage Guide](USAGE.md) - Detailed command reference
- [Advanced Features](ADVANCED.md) - Explore powerful options
