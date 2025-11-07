# Ruby Spriter v0.7.0.1 Requirements 

Requirements Revision #: 7
Release Type: PATCH RELEASE (builds upon v0.7.0)
Status: IN PROGRESS - Performance Optimization Complete
Date: 2025-11-05  
Prerequisite: Upload this requirements document directly or through the TypingMind KB as a direct file upload.

***

## Performance Optimization (COMPLETED)

**Status:** ✅ COMPLETE (2025-11-05)

**Objective:** Optimize inner background removal performance from ~65 seconds to under 15 seconds for typical sprite images.

**Achievement:**
- **Target:** 15 seconds
- **Achieved:** 7.5 seconds (50% under target)
- **Improvement:** 90% faster (75s → 7.5s)

**Performance Breakdown:**
- Edge Sampling: 6.7s → 0.5s (93% faster)
- Inner Processing: 65s → 1.0s (98.5% faster)
- Total Workflow: 75s → 7.5s (90% faster)

**Test Image:** 320×187 pixels with 8 inner background regions

**Technical Implementation:**

1. **Batch Pixel Loading (EdgeSampler)**
   - Replaced 320+ individual `magick identify` calls with single `magick txt:` call
   - Loads all ~60K pixels into Ruby hash cache in one operation
   - O(1) pixel lookup via `@pixel_cache[[x, y]]`

2. **Cached Grid Sampling (InnerBackgroundProcessor)**
   - Reuses pixel cache from EdgeSampler
   - Eliminated 252+ ImageMagick calls for grid point checking
   - Direct hash lookup instead of subprocess spawning

3. **Ruby-based Flood Fill Algorithm**
   - Replaced 472 ImageMagick flood fill calls with Ruby implementation
   - Uses pixel cache for contiguous region detection
   - Early termination at 2× minimum area threshold
   - Set-based visited tracking for performance

**Files Modified:**
- `lib/ruby_spriter/edge_sampler.rb` (+65 lines)
  - Added `load_pixel_cache()` method
  - Modified `sample_pixel()` to use cache
  - Added `pixel_cache` attribute reader

- `lib/ruby_spriter/inner_background_processor.rb` (+143 lines)
  - Added `load_pixel_cache()` method
  - Added `estimate_region_area_from_cache()` method
  - Added `colors_match?()` helper method
  - Modified `process()` to load cache before detection
  - Modified `point_matches_color?()` to use cache

**Testing:**
- Added 12 new EdgeSampler unit tests
- Added 4 new InnerBackgroundProcessor unit tests
- All 32 unit tests passing
- Production verified with `has_inner_bg.png` fixture

**Commit:** bedaf0f34d987c631363e55b9c3a637f831aba82

**Branch:** rs_0701

***

## Feature: Fix Threshold Stepping to Use Edge-Based Background Removal

***

## Problem Statement

The current `--threshold-stepping` implementation (v0.7.0) has critical issues that prevent it from working correctly:

### Issue 1: Incorrect Tool Usage ✅ FIXED

**Problem:** The threshold stepping incorrectly used ImageMagick's `-transparent white` command, which only removes white pixels with varying fuzz tolerances. This does NOT match the documented behavior of performing edge-based fuzzy selection with multiple thresholds.

**Solution Implemented:**

1. ✅ Sample background colors from the edges (like GIMP's 4-corner fuzzy select)
2. ✅ Apply multiple threshold values to progressively remove background using GIMP
3. ✅ Layer the results for gradual refinement using ImageMagick compositing

### Issue 2: Ineffective Edge Sampling ⚠️ PARTIALLY FIXED

**Problem:** The current edge sampling implementation samples too sparsely and too deeply, missing color variations in highly varied backgrounds.

**Current State (from diff):**

- ✅ Edge sampling pattern changed from hardcoded intervals to configurable patterns
- ⚠️ **REGRESSION**: `edge_sample_interval` was removed, reverted to `edge_sample_pattern`
- ⚠️ **REGRESSION**: `edge_sample_depth` default reverted from 2 to 10
- ⚠️ Sampling still uses every 10% of width/height (step = width/10)
- ⚠️ Does NOT implement dense shallow sampling (every 5px at depth=2)

**Valid Assumptions:**

1. The actual sprite is well inside a 10-pixel boundary from the edge, so there is no risk of sampling from the sprite
2. The background can be highly varied with similar colors that need to be captured

**Required Solution (NOT YET IMPLEMENTED):**

- Dense shallow sampling: sample every 5 pixels at depth 1-2
- Avoid pixel 0 to prevent compression artifacts
- Capture comprehensive color palette for highly varied backgrounds

### Issue 3: Incorrect Processing Order ✅ FIXED

**Problem:** The `--try-inner` previously ran AFTER GIMP edge removal, which means EdgeSampler cannot detect background colors (edges are already transparent).

**Solution Implemented:**

- ✅ Edge sampling now happens BEFORE any removal
- ✅ Inner removal runs in correct order
- ✅ Processing workflow corrected

### Issue 4: ImageMagick Flood Fill Risk ⚠️ ACKNOWLEDGED

**Problem:** ImageMagick flood fill can hang on complex images. GIMP's selection algorithms are more reliable and have built-in safeguards against infinite loops.

**Current State:**

- ✅ GIMP used for threshold stepping
- ⚠️ ImageMagick still used for inner background removal (acceptable risk)
- ⚠️ No timeout protection implemented yet

***

## Implementation Status Summary

### ✅ Completed in rs_0701 Branch

1. **ThresholdStepper - GIMP Integration**

- ✅ Changed from ImageMagick `-transparent white` to GIMP Python-fu
- ✅ Uses `gimp-image-select-color` with threshold parameter
- ✅ Uses edge-sampled background palette (not hardcoded white)
- ✅ Generates GIMP scripts for each threshold value
- ✅ Uses `Gegl.Color.new('rgb(r, g, b)')` with normalized values (0.0-1.0)
- ✅ Composites results with ImageMagick DstOver

2. **Processor - Correct Workflow**

- ✅ Scenario A (`--remove-bg --try-inner`): Sample → GIMP → Inner removal
- ✅ Scenario B (`--remove-bg --threshold-stepping --try-inner`): Sample → GIMP threshold → Inner removal
- ✅ Scenario C (`--remove-bg --threshold-stepping`): Sample → GIMP threshold → Done

3. **EdgeSampler - Pattern-Based Sampling**

- ✅ Supports `linear` and `weighted` sampling patterns
- ✅ Samples from all four edges
- ✅ Builds comprehensive color palette
- ⚠️ Uses 10% intervals (not dense 5px intervals)
- ⚠️ Uses 10px depth (not shallow 2px depth)

4. **CLI Parameters**

- ✅ `--try-inner` flag added
- ✅ `--inner-min-area N` added
- ✅ `--adaptive-min-area` added
- ✅ `--edge-sample-depth N` added (default: 10)
- ✅ `--edge-sample-pattern PATTERN` added (linear/weighted)
- ✅ `--color-space SPACE` added (rgb/lab)
- ✅ `--threshold-stepping` flag added
- ✅ `--remove-smoke` flag added
- ✅ `--bg-fuzz N` added (default: 10)
- ✅ `--ghost-threshold N` added (default: 30)
- ✅ `--multi-pass` / `--prevent-ghost-edges` added
- ❌ `--edge-sample-interval N` NOT implemented (removed in diff)
- ❌ `--threshold-timeout N` NOT implemented (removed in diff)
- ❌ `--total-threshold-timeout N` NOT implemented (removed in diff)

5. **Version**

- ⚠️ Version in diff shows `0.7.0` (not `0.7.0.1`)
- ⚠️ Version date shows `2025-10-30` (not current)

### ⚠️ Pending Requirements (NOT YET IMPLEMENTED)

1. **Dense Shallow Edge Sampling (FR-1)**

- ❌ Sample every 5 pixels along each edge
- ❌ Sample at depth 1-2 pixels (currently 10)
- ❌ Avoid pixel 0 to prevent compression artifacts
- ❌ `--edge-sample-interval` parameter

2. **Timeout Protection (FR-5)**

- ❌ Per-threshold timeout (default: 60 seconds)
- ❌ Total process timeout (default: 300 seconds)
- ❌ Graceful timeout handling
- ❌ `--threshold-timeout` parameter
- ❌ `--total-threshold-timeout` parameter

3. **Version Update**

- ❌ Update version to `0.7.0.1` in `lib/ruby_spriter/version.rb`
- ❌ Update version date to release date

4. **Documentation**

- ❌ Update README.md with corrected workflow
- ❌ Update CHANGELOG.md with v0.7.0.1 changes

***

## Functional Requirements

### FR-1: Dense Shallow Edge Sampling with High Color Capture ⚠️ PENDING

**Status:** Partially implemented (pattern-based sampling exists, but not dense shallow)

System SHALL implement dense shallow sampling strategy:

- **Sampling Interval:** Sample every 5 pixels along each edge (configurable via `--edge-sample-interval`)
- **Sampling Depth:** Sample only 1-2 pixels from edge (configurable via `--edge-sample-depth`, default: 2)
- **Edge Artifact Avoidance:** Skip the absolute edge (pixel 0) to avoid compression artifacts
- **Sample at depth=1:** Use the second pixel from edge for all samples

**Implementation Required:**

```ruby
def sample_top_edge
  depth = 2  # Only 2 pixels deep (well within 10px safe zone)
  samples = []
  interval = @config.edge_sample_interval || 5  # Sample every 5 pixels

  (0...@image_width).step(interval) do |x|
    # Sample at depth=1 (second pixel from edge, avoiding edge artifacts)
    samples << sample_pixel(x, 1)
  end

  samples.compact
end

def sample_bottom_edge
  depth = 2
  samples = []
  interval = @config.edge_sample_interval || 5

  (0...@image_width).step(interval) do |x|
    samples << sample_pixel(x, @image_height - 2)  # 2nd pixel from bottom
  end

  samples.compact
end

def sample_left_edge
  depth = 2
  samples = []
  interval = @config.edge_sample_interval || 5

  (0...@image_height).step(interval) do |y|
    samples << sample_pixel(1, y)  # 2nd pixel from left
  end

  samples.compact
end

def sample_right_edge
  depth = 2
  samples = []
  interval = @config.edge_sample_interval || 5

  (0...@image_height).step(interval) do |y|
    samples << sample_pixel(@image_width - 2, y)  # 2nd pixel from right
  end

  samples.compact
end
```

**Why This Works:**

- ✅ High sampling density: Every 5 pixels captures subtle color variations
- ✅ Shallow depth: Only 1-2 pixels from edge avoids sprite contamination
- ✅ Avoids edge artifacts: Skips the absolute edge (pixel 0) which may have compression artifacts
- ✅ Comprehensive coverage: For a 1000px wide image, gets 200 samples from top edge alone
- ✅ Fast execution: Single sample per position = minimal ImageMagick calls

**For Highly Varied Backgrounds:**

The `build_color_palette()` method will naturally capture all color variations:

```ruby
# This already exists and will preserve all unique colors
def build_color_palette(samples)
  unique_colors = samples.uniq { |color| "#{color[:r]},#{color[:g]},#{color[:b]}" }
  unique_colors
end
```

Example: If background has 50 different shades of green, you'll get all 50 in the palette for threshold stepping.

- System SHALL sample background colors from all four edges before any removal
- System SHALL use the sampled background palette for threshold stepping and for inner removal
- System SHALL use GIMP Python-fu for threshold-based selection and removal (NOT ImageMagick flood fill)
- System SHALL use ImageMagick only for final compositing of threshold results

### FR-2: Correct Processing Order ✅ IMPLEMENTED

When `--remove-bg --threshold-stepping --try-inner` are ALL specified:

1. ✅ Sample edges to build background palette (currently 10px depth, 10% interval)
2. ✅ Apply GIMP threshold stepping with sampled colors
3. ✅ Apply ImageMagick inner background removal with sampled colors
4. ✅ Done (NO additional GIMP edge removal)

When ONLY `--remove-bg --threshold-stepping`:

1. ✅ Sample edges to build background palette
2. ✅ Apply GIMP threshold stepping with sampled colors
3. ✅ Done (NO additional GIMP edge removal)

When ONLY `--remove-bg --try-inner`:

1. ✅ Sample edges to build background palette
2. ✅ Apply ImageMagick inner background removal with sampled colors
3. ✅ Apply GIMP fuzzy select from 4 corners (existing behavior)
4. ✅ Done

When ONLY `--remove-bg` (v0.6.7.1 behavior):

1. ✅ GIMP fuzzy select from 4 corners (existing behavior)
2. ✅ Done

### FR-3: GIMP-Based Threshold Stepping Implementation ✅ IMPLEMENTED

- ✅ System SHALL process image with 6 default thresholds: [0.0, 0.5, 1.0, 3.0, 5.0, 10.0]
- ✅ For EACH threshold value:
- ✅ Generate GIMP Python-fu script with threshold tolerance
- ✅ Use `gimp-image-select-color()` with background palette colors
- ✅ Apply threshold as color matching tolerance
- ✅ Delete selected regions (make transparent via `gimp-drawable-edit-clear`)
- ✅ Export intermediate result to temporary PNG
- ✅ System SHALL composite all threshold results using ImageMagick DstOver layering
- ✅ System SHALL support custom threshold values via `--threshold-values` (comma-separated)
- ✅ GIMP scripts SHALL use GIMP 3.x API (`Gimp.get_pdb()`, procedure lookup, config objects)

### FR-4: GIMP Usage Strategy ✅ IMPLEMENTED

- ✅ When `--threshold-stepping` specified, GIMP SHALL be used for threshold-based removal
- ✅ When `--remove-bg` alone specified, GIMP SHALL be used for fuzzy select (v0.6.7.1 behavior)
- ✅ When `--try-inner` specified with `--remove-bg` (no `--threshold-stepping`), GIMP SHALL be used after inner removal
- ✅ ImageMagick SHALL be used for: compositing, inner background removal, final output operations
- ✅ Backward compatibility: `--remove-bg` alone (without new flags) SHALL continue using GIMP fuzzy select

### FR-5: Timeout Protection ❌ NOT IMPLEMENTED

- ❌ System SHALL implement per-threshold timeout (default: 60 seconds)
- ❌ System SHALL implement total process timeout (default: 300 seconds)
- ❌ When per-threshold timeout occurs:
- Skip that threshold value
- Log warning message
- Continue processing remaining thresholds
- ❌ When total timeout occurs:
- Use partial results (thresholds completed so far)
- If no thresholds completed, copy input to output (no processing)
- Report timeout in processing summary
- ❌ Timeout values SHALL be configurable via `--threshold-timeout` and `--total-threshold-timeout`

### FR-6: Video and Batch Mode Support ✅ IMPLEMENTED

- ✅ `--threshold-stepping` SHALL work with `--video` mode
- ✅ `--threshold-stepping` SHALL work with `--batch` mode
- ✅ `--try-inner` SHALL work with `--video` mode
- ✅ `--try-inner` SHALL work with `--batch` mode
- ✅ All processing modes SHALL support the full background removal pipeline

***

## Technical Implementation

### Architecture Changes

#### 1. EdgeSampler class (lib/ruby_spriter/edge_sampler.rb) ⚠️ NEEDS UPDATE

**Current State:**

- ✅ Pattern-based sampling (linear/weighted) implemented
- ✅ Samples from all four edges
- ✅ Builds comprehensive color palette
- ⚠️ Uses 10% intervals (step = width/10)
- ⚠️ Uses 10px depth (default)
- ⚠️ Does NOT avoid pixel 0

**Required Changes:**

- Replace pattern-based sampling with dense shallow sampling approach
- Set default `edge_sample_interval`: 5 pixels
- Set default `edge_sample_depth`: 2 pixels
- Implement new sampling logic:
- `sample_top_edge`: Sample at y=1, every 5 pixels across width
- `sample_bottom_edge`: Sample at y=height-2, every 5 pixels across width
- `sample_left_edge`: Sample at x=1, every 5 pixels down height
- `sample_right_edge`: Sample at x=width-2, every 5 pixels down height
- Keep `build_color_palette` unchanged - it already preserves all unique colors
- Update report method to show sampling density statistics

#### 2. ThresholdStepper class (lib/ruby_spriter/threshold_stepper.rb) ✅ IMPLEMENTED

**Current State:**

- ✅ Accepts background_palette parameter (from EdgeSampler)
- ✅ Accepts gimp_processor instance for script execution
- ✅ Generates GIMP Python-fu scripts for each threshold value
- ✅ Executes GIMP scripts via GimpProcessor
- ✅ Uses ImageMagick for compositing results (flatten_results method)
- ❌ Per-threshold timeout NOT implemented
- ❌ Total process timeout NOT implemented

**Required Changes:**

- Implement per-threshold timeout using Ruby's Timeout module
- Implement total process timeout
- Track skipped thresholds and timeout occurrences
- Add timeout reporting to report method

#### 3. ThresholdStepperGimpScript module ✅ IMPLEMENTED

**Current State:**

- ✅ `generate_threshold_script(input, output, threshold, palette)` implemented
- ✅ Uses `gimp-image-select-color()` for each color in palette
- ✅ Applies threshold as color matching tolerance
- ✅ Uses `CHANNEL_OP_ADD` to accumulate selections
- ✅ Clears selection (makes transparent)
- ✅ Exports result
- ✅ Follows GIMP 3.x API patterns

**No changes required.**

#### 4. Processor class (lib/ruby_spriter/processor.rb) ✅ IMPLEMENTED

**Current State:**

- ✅ Correct processing order implemented
- ✅ Edge sampling happens BEFORE any removal
- ✅ Inner background removal runs BEFORE GIMP (when appropriate)
- ✅ GIMP skipped when `--threshold-stepping` used
- ✅ GIMP used after inner removal when `--try-inner` without `--threshold-stepping`
- ✅ Full pipeline in `execute_video_workflow`
- ✅ Full pipeline in `execute_batch_workflow` (via BatchProcessor)

**No changes required.**

#### 5. InnerBgConfig class (lib/ruby_spriter/inner_bg_config.rb) ⚠️ NEEDS UPDATE

**Current State (from diff):**

- ✅ Has `edge_sample_pattern` attribute (linear/weighted)
- ✅ Has `edge_sample_depth` attribute (default: 10)
- ⚠️ Does NOT have `edge_sample_interval` attribute
- ✅ Validates `edge_sample_pattern`
- ✅ Validates numeric ranges

**Required Changes:**

- Add `edge_sample_interval` attribute (default: 5)
- Change `edge_sample_depth` default from 10 to 2
- Remove `edge_sample_pattern` validation (will be removed)
- Add validation for `edge_sample_interval > 0`

#### 6. CLI class (lib/ruby_spriter/cli.rb) ⚠️ NEEDS UPDATE

**Current State (from diff):**

- ✅ All 12 inner background removal flags added
- ✅ `--edge-sample-depth N` added (default: 10)
- ✅ `--edge-sample-pattern PATTERN` added
- ⚠️ `--edge-sample-interval N` NOT present (removed in diff)
- ⚠️ `--threshold-timeout N` NOT present (removed in diff)
- ⚠️ `--total-threshold-timeout N` NOT present (removed in diff)

**Required Changes:**

- Add `--edge-sample-interval N` parameter (default: 5)
- Change `--edge-sample-depth` default to 2
- Remove `--edge-sample-pattern` parameter
- Add `--threshold-timeout N` parameter (default: 60)
- Add `--total-threshold-timeout N` parameter (default: 300)

### GIMP Python-fu Script Structure ✅ IMPLEMENTED

The current implementation generates scripts following this pattern:

```python
import gi
gi.require_version('Gimp', '3.0')
from gi.repository import Gimp, Gio, Gegl
import sys

def threshold_step():
    try:
        # Load image
        img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,
                            Gio.File.new_for_path(r'INPUT_PATH'))
        layer = img.get_layers()[0]
        
        # Add alpha channel if needed
        if not layer.has_alpha():
            layer.add_alpha()
        
        pdb = Gimp.get_pdb()
        
        # For each color in background palette
        for i, color in enumerate(BACKGROUND_PALETTE):
            # Create Gegl.Color with normalized RGB values (0.0-1.0)
            gegl_color = Gegl.Color.new('rgb(r, g, b)')
            
            # Select color with threshold tolerance
            select_proc = pdb.lookup_procedure('gimp-image-select-color')
            config = select_proc.create_config()
            config.set_property('image', img)
            config.set_property('operation',
                Gimp.ChannelOps.REPLACE if i == 0 else Gimp.ChannelOps.ADD)
            config.set_property('drawable', layer)
            config.set_property('color', gegl_color)
            config.set_property('threshold', THRESHOLD_VALUE)
            select_proc.run(config)
        
        # Delete selection (make transparent)
        edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear')
        config = edit_clear.create_config()
        config.set_property('drawable', layer)
        edit_clear.run(config)
        
        # Deselect
        select_none = pdb.lookup_procedure('gimp-selection-none')
        config = select_none.create_config()
        config.set_property('image', img)
        select_none.run(config)
        
        # Export
        export_proc = pdb.lookup_procedure('file-png-export')
        config = export_proc.create_config()
        config.set_property('image', img)
        config.set_property('file', Gio.File.new_for_path(r'OUTPUT_PATH'))
        export_proc.run(config)
        
        print("SUCCESS - Threshold step complete!")
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)

sys.exit(threshold_step())
```

### Processing Pipeline

#### When `--remove-bg --threshold-stepping --try-inner`: ✅ IMPLEMENTED

```javascript
┌─────────────────────────────────────────┐
│ 1. Edge Sampling (CURRENT)             │
│ - Sample every 10% at depth=10         │
│ - Top/Bottom/Left/Right edges          │
│ - Build comprehensive color palette    │
│ - Report: samples, unique colors       │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ 2. GIMP Threshold Stepping              │
│ - For each threshold (0.0-10.0):       │
│   * Generate GIMP Python-fu script     │
│   * Select ALL palette colors          │
│   * Apply threshold tolerance          │
│   * Delete selection (transparent)     │
│   * Export intermediate PNG            │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ 3. ImageMagick Compositing              │
│ - Layer all threshold results          │
│ - Use DstOver composite mode           │
│ - Create single output image           │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ 4. Inner Background Removal             │
│ - Use same background palette          │
│ - ImageMagick flood fill               │
│ - Detect interior regions              │
│ - Remove regions > min area            │
│ - Report regions removed               │
└─────────────────────────────────────────┘
                   ↓
                 DONE
```

#### When `--remove-bg --try-inner` (no `--threshold-stepping`): ✅ IMPLEMENTED

```javascript
┌─────────────────────────────────────────┐
│ 1. Edge Sampling                        │
│ - Sample every 10% at depth=10         │
│ - Build comprehensive color palette    │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ 2. Inner Background Removal             │
│ - Use background palette               │
│ - ImageMagick flood fill               │
│ - Detect interior regions              │
│ - Remove regions > min area            │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│ 3. GIMP Fuzzy Select (4 corners)       │
│ - Existing v0.6.7.1 behavior           │
│ - Remove edge-connected background     │
└─────────────────────────────────────────┘
                   ↓
                 DONE
```

#### When `--remove-bg` ONLY (v0.6.7.1 backward compatibility): ✅ IMPLEMENTED

```javascript
┌─────────────────────────────────────────┐
│ GIMP Fuzzy Select (4 corners)          │
│ - Existing behavior unchanged          │
└─────────────────────────────────────────┘
                   ↓
                 DONE
```

***

## Command-Line Interface

### Flag Behavior Changes

#### `--remove-bg` (modified behavior): ✅ IMPLEMENTED

- Alone: Uses GIMP fuzzy select (v0.6.7.1 behavior)
- With `--threshold-stepping`: Uses edge sampling + GIMP threshold stepping (NO additional GIMP)
- With `--try-inner`: Uses edge sampling + inner removal + GIMP fuzzy select
- With both: Uses edge sampling + GIMP threshold stepping + inner removal (NO additional GIMP)

#### `--threshold-stepping` (fixed behavior): ✅ IMPLEMENTED

- Requires `--remove-bg`
- Uses edge-sampled background palette (NOT hardcoded white)
- Uses GIMP Python-fu for each threshold pass (NOT ImageMagick flood fill)
- Applies multiple color selection thresholds (0.0, 0.5, 1.0, 3.0, 5.0, 10.0)
- Composites results with ImageMagick
- Skips additional GIMP fuzzy select

#### `--try-inner` (fixed behavior): ✅ IMPLEMENTED

- Requires `--remove-bg`
- Now runs BEFORE GIMP (not after)
- Uses edge-sampled background palette
- Can work standalone (with GIMP) or with `--threshold-stepping` (without additional GIMP)

### Configuration Parameters

#### Modified parameters:

- **`--edge-sample-depth N`** ⚠️ NEEDS UPDATE
- Type: Integer (pixels)
- Current Default: 10
- Required Default: 2
- Purpose: How many pixels from edge to sample
- Recommendation: Keep at 2 for dense shallow sampling

#### New parameters (PENDING):

- **`--edge-sample-interval N`** ❌ NOT IMPLEMENTED
- Type: Integer (pixels)
- Default: 5
- Purpose: Pixel interval between samples along each edge
- Example: For 1000px width with interval=5, takes 200 samples
- Lower values = more samples = better color variation capture
- **`--threshold-timeout N`** ❌ NOT IMPLEMENTED
- Type: Integer (seconds)
- Default: 60
- Purpose: Maximum time per individual threshold processing
- Behavior: Skip threshold if exceeded, continue with remaining
- **`--total-threshold-timeout N`** ❌ NOT IMPLEMENTED
- Type: Integer (seconds)
- Default: 300 (5 minutes)
- Purpose: Maximum total time for all threshold stepping
- Behavior: Abort if exceeded, use partial results or fallback to input

#### Existing parameters (IMPLEMENTED):

- ✅ `--inner-min-area` (default: 100)
- ✅ `--adaptive-min-area` (boolean)
- ✅ `--bg-fuzz` (default: 10)
- ✅ `--threshold-values` (custom thresholds, comma-separated)
- ✅ `--edge-sample-pattern` (linear/weighted) - **TO BE REMOVED**
- ✅ `--color-space` (rgb/lab)
- ✅ `--multi-pass` / `--prevent-ghost-edges`
- ✅ `--remove-smoke`
- ✅ `--ghost-threshold` (default: 30)

***

## Usage Examples

### v0.7.0.1 - Threshold stepping with GIMP (FIXED) ✅

```bash
ruby_spriter --image sprite.png --remove-bg --threshold-stepping
```

### v0.7.0.1 - Inner removal with edge sampling + GIMP (FIXED ORDER) ✅

```bash
ruby_spriter --image sprite.png --remove-bg --try-inner
```

### v0.7.0.1 - Combined: GIMP threshold stepping + inner removal (CORRECT WORKFLOW) ✅

```bash
ruby_spriter --image sprite.png --remove-bg --threshold-stepping --try-inner
```

### v0.7.0.1 - Custom sampling density (more samples) ⚠️ PENDING

```bash
ruby_spriter --image sprite.png --remove-bg --threshold-stepping --edge-sample-interval 3
```

### v0.7.0.1 - Custom timeout values ❌ NOT IMPLEMENTED

```bash
ruby_spriter --image sprite.png --remove-bg --threshold-stepping --threshold-timeout 90 --total-threshold-timeout 600
```

### v0.7.0.1 - Video mode with new features (NOW SUPPORTED) ✅

```bash
ruby_spriter --video input.mp4 --remove-bg --threshold-stepping --try-inner
```

### v0.7.0.1 - Batch mode with new features (NOW SUPPORTED) ✅

```bash
ruby_spriter --batch --dir videos/ --remove-bg --threshold-stepping --try-inner
```

### v0.6.7.1 backward compatibility (UNCHANGED) ✅

```bash
ruby_spriter --image sprite.png --remove-bg
```

***

## Testing Requirements

### RSpec Test Updates

#### 1. Update edge_sampler_spec.rb: ⚠️ NEEDS UPDATE

- ❌ Test dense shallow sampling (every 5px at depth=2)
- ❌ Test sample_top_edge samples at y=1
- ❌ Test sample_bottom_edge samples at y=height-2
- ❌ Test sample_left_edge samples at x=1
- ❌ Test sample_right_edge samples at x=width-2
- ❌ Test edge_sample_interval configuration
- ❌ Test comprehensive color palette building
- ❌ Test sampling density: 1000px width → 200 samples
- ❌ Remove edge_sample_pattern tests (no longer used)
- ❌ Test that absolute edge (pixel 0) is avoided

#### 2. Update threshold_stepper_spec.rb: ⚠️ PARTIALLY COMPLETE

- ✅ Test GIMP script generation for each threshold
- ✅ Test background palette integration
- ✅ Test multiple threshold processing with GIMP
- ✅ Test ImageMagick compositing of GIMP results
- ❌ Test per-threshold timeout handling
- ❌ Test total timeout handling
- ❌ Test partial results when timeout occurs
- ✅ Mock GIMP execution via GimpProcessor

#### 3. Update processor_spec.rb: ✅ COMPLETE

- ✅ Test correct processing order (edge sampling → threshold → inner → done)
- ✅ Test GIMP is used for threshold stepping (not ImageMagick flood fill)
- ✅ Test GIMP is skipped when `--threshold-stepping` used (no additional fuzzy select)
- ✅ Test GIMP is used when only `--remove-bg` or `--remove-bg --try-inner` specified
- ✅ Test video workflow includes full pipeline
- ✅ Test batch workflow includes full pipeline

#### 4. Update inner_background_removal_spec.rb: ✅ COMPLETE

- ✅ Test inner removal runs BEFORE GIMP (not after)
- ✅ Test edge colors are available for sampling

#### 5. Update gimp_processor_spec.rb: ✅ COMPLETE

- ✅ Test threshold stepping script generation
- ✅ Test gimp-image-select-color usage with threshold parameter
- ✅ Test CHANNEL_OP_ADD for multiple color selections
- ✅ Test GIMP 3.x API compliance

#### 6. Add integration tests: ⚠️ PARTIALLY COMPLETE

- ✅ Test `--remove-bg --threshold-stepping --try-inner` full workflow (GIMP + ImageMagick)
- ✅ Test `--remove-bg --try-inner` workflow (with GIMP)
- ✅ Test video mode with new flags
- ✅ Test batch mode with new flags
- ❌ Test timeout scenarios (mock slow GIMP execution)
- ❌ Test dense sampling captures highly varied backgrounds

#### 7. Backward compatibility tests: ✅ COMPLETE

- ✅ Verify `--remove-bg` alone produces identical output to v0.6.7.1
- ✅ Verify all existing tests still pass

### Test Results (Current State)

**Total Tests:** 474 examples  
**Passing:** 471  
**Failing:** 3 (pre-existing CLI spec issues, unrelated to v0.7.0.1)  
**Pending:** 3

**New Tests Added:**

- EdgeSampler: 8 tests ✅
- ThresholdStepper: 12 tests ✅
- InnerBgConfig: 26 tests ✅
- Processor integration: 7 tests ✅

***

## Acceptance Criteria

| #    | Criterion                                                    | Status            |
| ---- | ------------------------------------------------------------ | ----------------- |
| 1    | All existing v0.7.0 tests pass without modification          | ✅ 471/474         |
| 2    | `--remove-bg` alone produces identical output to v0.6.7.1 (GIMP fuzzy select) | ✅ PASS            |
| 3    | Edge sampling uses dense shallow strategy (every 5px at depth=2) | ⚠️ PENDING         |
| 4    | Edge sampling avoids absolute edge (pixel 0) to prevent artifacts | ⚠️ PENDING         |
| 5    | Edge sampling captures comprehensive color palette (all unique colors preserved) | ✅ PASS            |
| 6    | For 1000px image, edge sampling collects ~200 samples per edge | ⚠️ PENDING         |
| 7    | `--threshold-stepping` uses GIMP Python-fu (NOT ImageMagick "-transparent white") | ✅ PASS            |
| 8    | `--threshold-stepping` uses edge-sampled background palette  | ✅ PASS            |
| 9    | `--threshold-stepping` processes 6 thresholds with GIMP color selection | ✅ PASS            |
| 10   | ThresholdStepper generates valid GIMP 3.x Python-fu scripts  | ✅ PASS            |
| 11   | GIMP scripts use gimp-image-select-color with threshold parameter | ✅ PASS            |
| 12   | ImageMagick composites GIMP threshold results correctly      | ✅ PASS            |
| 13   | `--try-inner` runs BEFORE GIMP (edge colors available for sampling) | ✅ PASS            |
| 14   | `--remove-bg --threshold-stepping --try-inner` executes: sample → GIMP threshold → inner → done | ✅ PASS            |
| 15   | `--remove-bg --try-inner` executes: sample → inner → GIMP → done | ✅ PASS            |
| 16   | GIMP is NOT used for additional fuzzy select when `--threshold-stepping` specified | ✅ PASS            |
| 17   | GIMP IS used when only `--remove-bg` or `--remove-bg --try-inner` specified | ✅ PASS            |
| 18   | Per-threshold timeout (60s) skips slow thresholds and continues | ❌ NOT IMPLEMENTED |
| 19   | Total timeout (300s) uses partial results or fallback        | ❌ NOT IMPLEMENTED |
| 20   | Timeout occurrences reported in processing summary           | ❌ NOT IMPLEMENTED |
| 21   | Video mode supports `--threshold-stepping` and `--try-inner` | ✅ PASS            |
| 22   | Batch mode supports `--threshold-stepping` and `--try-inner` | ✅ PASS            |
| 23   | `--edge-sample-interval` configurable (default: 5)           | ❌ NOT IMPLEMENTED |
| 24   | `--edge-sample-depth` default changed to 2                   | ⚠️ PENDING         |
| 25   | `--edge-sample-pattern` removed (no longer needed)           | ⚠️ PENDING         |
| 26   | Processing order verified: edge sampling happens FIRST, before any removal | ✅ PASS            |
| 27   | User report displays: samples collected, unique colors, thresholds processed, regions removed, timeouts | ⚠️ PARTIAL         |
| 28   | README.md updated with corrected workflow documentation      | ❌ PENDING         |
| 29   | CHANGELOG.md includes v0.7.0.1 fix details                   | ❌ PENDING         |
| 30   | Version number updated to 0.7.0.1 in all files               | ❌ PENDING         |
| 31   | TDD discipline followed: RED → GREEN → REFACTOR cycle        | ✅ PASS            |

**Summary:**

- ✅ **Implemented:** 20/31 (65%)
- ⚠️ **Partially Complete:** 5/31 (16%)
- ❌ **Not Implemented:** 6/31 (19%)

***

## Resolved Issues

1. **GIMP Threshold Behavior (Nov 6, 2025)** ✅ FIXED
   - Issue: `--remove-bg --threshold 52.0` removed more pixels than GUI
   - Cause: 4-corner selection with ADD operations compounding threshold
   - Fix: Single-point interior selection with REPLACE mode
   - Status: Working correctly

## Implementation Complete (Nov 6, 2025)

### BackgroundSampler Feature

**Implemented:**
- ? BackgroundSampler class for intelligent background color sampling
- ? Samples interior regions (5-10px from edge) avoiding compression artifacts
- ? Collects up to 10 unique background colors across multiple rows
- ? Pixel cache optimization (65x performance improvement)
- ? Two-pass GIMP integration (outer + inner background removal)
- ? --no-fuzzy is now DEFAULT for --remove-bg
- ? --fuzzy flag for contiguous-only selection (backward compatibility)
- ? CLI options: --bg-sample-offset, --bg-sample-count

**Removed (Deprecated):**
- ? EdgeSampler class (replaced by BackgroundSampler)
- ? InnerBackgroundProcessor class (replaced by GIMP integration)
- ? --try-inner flag (functionality now in --no-fuzzy default)
- ? --threshold-stepping flag (superseded by BackgroundSampler)
- ? --inner-min-area, --adaptive-min-area, --multi-pass flags
- ? --edge-sample-depth, --edge-sample-pattern flags
- ? --color-space, --remove-smoke, --bg-fuzz, --ghost-threshold flags

**Test Coverage:**
- 507 examples, 0 failures, 3 pending
- BackgroundSampler: 12 unit tests
- No-fuzzy mode: 4 integration tests
- Single-point selection: 3 unit tests

## Known Issues

### Minor Usability Issues (Not Blocking Release)

1. **`--remove-smoke` alone does nothing**

- Expected: Run smoke detection on image
- Actual: Silently does nothing (requires `--remove-bg`)
- Workaround: Use `--remove-bg --remove-smoke`
- Priority: Low (edge case)

2. **`--try-inner` alone does nothing**

- Expected: Show error message
- Actual: Silently does nothing (requires `--remove-bg`)
- Workaround: Use `--remove-bg --try-inner`
- Priority: Low (validation improvement)

3. **CLI spec failures (3 tests)**

- File path handling edge cases
- Pre-existing issues from v0.7.0
- Not introduced by v0.7.0.1
- Priority: Low (existing behavior)

4. **GIMP 3.0.4 cosmetic warnings**

- LibGimp-CRITICAL warnings appear in output
- Processing completes successfully
- Windows-specific GIMP 3.0.4 issue
- Priority: Low (cosmetic only)

### Regressions Identified in rs_0701 Branch

1. **Edge sampling reverted to sparse sampling**

- `edge_sample_interval` removed, replaced with `edge_sample_pattern`
- Sampling uses 10% intervals (not dense 5px intervals)
- Impact: May miss color variations in highly varied backgrounds

2. **Edge sampling depth not optimized**

- Default depth is 10 pixels (not shallow 2 pixels)
- Impact: May sample sprite pixels instead of pure background

3. **Timeout protection not implemented**

- No per-threshold timeout
- No total process timeout
- Impact: GIMP can hang indefinitely on complex images

***

## **CRITICAL ISSUE: GIMP Threshold Behavior (Nov 6, 2025)**

### **Problem Statement**

The `--remove-bg` feature with `--threshold` parameter does not fully match GIMP GUI behavior at higher threshold values.

### **Current Status**

**Partially Working:**
- ✅ `--remove-bg` (no threshold) now works correctly
- ✅ `--remove-bg --threshold 15.0` matches GUI at threshold 15.0
- ✅ Context setters implemented (`context_set_sample_threshold_int`, `context_set_antialias`, etc.)
- ✅ Default grow changed from 1 to 0 pixels
- ✅ Feather parameter separated from threshold

**Fixed:**
- ✅ `--remove-bg --threshold 52.0` now works correctly (matches GUI behavior)
- ✅ Single-point selection implemented (5 pixels inward from top-left)
- ✅ Removed 4-corner ADD operations that were compounding threshold effect
- ✅ Uses REPLACE mode only (matches GUI selection behavior)

### **Investigation Findings**

1. **Threshold API**: Using `Gimp.context_set_sample_threshold_int(int(threshold))` which expects 0-100 scale
2. **Context Settings Applied**:
   - `Gimp.context_set_antialias(True)`
   - `Gimp.context_set_feather(False)`
   - `Gimp.context_set_sample_merged(False)`
   - `Gimp.context_set_sample_criterion(Gimp.SelectCriterion.COMPOSITE)`
   - `Gimp.context_set_sample_threshold_int(int(threshold))`
   - `Gimp.context_set_sample_transparent(True)`
   - `Gimp.context_set_diagonal_neighbors(False)`

3. **Observations**:
   - At threshold 15.0: Script matches GUI ✅
   - At threshold 52.0: Script removes more than GUI ❌
   - Suggests non-linear relationship or additional factor

### **Hypotheses to Investigate**

1. **Scale Mismatch**: `context_set_sample_threshold_int()` might use 0-255 scale (not 0-100)
   - Test: Try `int(threshold * 255 / 100)` conversion

2. **Grow/Feather Interference**: Despite setting to 0, might still be applied
   - Verify: Check GIMP output logs for actual grow/feather operations

3. **Multiple Corner Selection**: Selecting 4 corners with ADD operation might compound threshold
   - Test: Try single corner selection to isolate behavior

4. **GIMP State Accumulation**: Previous operations might affect threshold interpretation
   - Test: Add `Gimp.context_push()` / `Gimp.context_pop()` to isolate state

5. **API Documentation Gap**: GIMP 3.0 API docs may be incomplete/incorrect
   - Action: Test empirically with known values to determine actual scale

### **Recommended Next Steps**

1. **Empirical Testing**: Create test script that tries different conversions:
   ```python
   # Test 1: Direct value (current)
   Gimp.context_set_sample_threshold_int(15)
   
   # Test 2: 0-255 scale
   Gimp.context_set_sample_threshold_int(int(15 * 255 / 100))
   
   # Test 3: Float version
   Gimp.context_set_sample_threshold(15.0 / 100.0)
   ```

2. **Isolate Selection**: Test with single corner instead of 4 corners with ADD

3. **Context Isolation**: Wrap selections in `context_push()` / `context_pop()`

4. **GIMP Log Analysis**: Enable verbose GIMP logging to see actual threshold values used

5. **Binary Search**: Use binary search to find exact threshold value that matches GUI behavior at different target levels

### **Impact Assessment**

- **Low thresholds (0-20)**: Works correctly ✅
- **Medium thresholds (21-40)**: Unknown, needs testing ⚠️
- **High thresholds (41-100)**: Removes too much ❌
- **User workaround**: Use lower threshold values until fixed
- **Priority**: Medium (affects quality but has workaround)

### **Resolution (Nov 6, 2025)**

**Root Cause:** Multiple corner selection with ADD operations was compounding the threshold effect, causing more aggressive removal than GIMP GUI single-point selection.

**Fix Implemented:**
- Changed from 4-corner sampling to single interior point (5, 5)
- Removed ChannelOps.ADD operations
- Uses only ChannelOps.REPLACE mode
- Avoids edge compression artifacts by sampling 5 pixels inward

**Result:** `--remove-bg --threshold 52.0` now matches GUI behavior. Threshold values work consistently across the 0-100 range.

***

## Performance Improvements

| Metric                     | Before          | After           | Improvement   |
| -------------------------- | --------------- | --------------- | ------------- |
| Inner removal time         | 180+ seconds    | ~20 seconds     | 9x faster     |
| Edge samples (1000px)      | 10              | ~100            | 10x more      |
| Background color detection | Hardcoded white | All edge colors | Comprehensive |

**Note:** Dense shallow sampling (200 samples per edge) not yet implemented.

***

## Files Modified in rs_0701 Branch

### Core Implementation:

- ✅ `lib/ruby_spriter/edge_sampler.rb` - Pattern-based sampling (needs dense shallow update)
- ✅ `lib/ruby_spriter/threshold_stepper.rb` - GIMP integration (needs timeout protection)
- ✅ `lib/ruby_spriter/gimp_processor.rb` - Added execute_python_script
- ✅ `lib/ruby_spriter/processor.rb` - Correct processing order
- ✅ `lib/ruby_spriter/inner_bg_config.rb` - New parameters (needs edge_sample_interval)
- ⚠️ `lib/ruby_spriter/version.rb` - Version 0.7.0 (needs update to 0.7.0.1)
- ✅ `lib/ruby_spriter/cli.rb` - New CLI parameters (needs edge_sample_interval, timeout params)

### Tests:

- ✅ `spec/unit/edge_sampler_spec.rb` - 8 tests (needs dense shallow tests)
- ✅ `spec/unit/threshold_stepper_spec.rb` - 12 tests (needs timeout tests)
- ✅ `spec/unit/inner_bg_config_spec.rb` - 26 tests
- ✅ `spec/ruby_spriter/processor_spec.rb` - 7 integration tests

### Documentation:

- ❌ `CHANGELOG.md` - Needs v0.7.0.1 release notes
- ❌ `README.md` - Needs workflow documentation update
- ⚠️ `ruby_spriter.gemspec` - Needs version bump

***

## Release Checklist

### Implementation

- [x] All v0.7.0 tests pass (existing test suite) - 471/474
- [x] Backward compatibility verified (`--remove-bg` alone = v0.6.7.1 output)
- [ ] Dense shallow edge sampling implemented (every 5px at depth=2)
- [ ] Edge sampling avoids pixel 0 (uses pixel 1 and height-2/width-2)
- [x] Comprehensive color palette captured from varied backgrounds
- [x] ThresholdStepper uses GIMP Python-fu (not ImageMagick flood fill)
- [x] GIMP scripts use gimp-image-select-color with threshold parameter
- [x] Processing order correct (sample → GIMP/inner → GIMP if needed)
- [x] GIMP skipped for additional fuzzy select when `--threshold-stepping` used
- [x] GIMP used when only `--remove-bg` or `--remove-bg --try-inner`
- [ ] Per-threshold timeout implemented and tested
- [ ] Total timeout implemented and tested
- [ ] Timeout fallback behavior verified
- [x] Video mode supports full pipeline
- [x] Batch mode supports full pipeline

### Configuration

- [ ] `--edge-sample-interval` parameter added (default: 5)
- [ ] `--edge-sample-depth` default changed to 2
- [ ] `--edge-sample-pattern` removed
- [ ] `--threshold-timeout` parameter added (default: 60)
- [ ] `--total-threshold-timeout` parameter added (default: 300)

### Documentation

- [ ] README.md updated with corrected workflow and new parameters
- [ ] CHANGELOG.md updated with v0.7.0.1 changes
- [ ] Version number updated to 0.7.0.1 in all files
- [ ] `--help` content accurate (includes new parameters, removed old ones)

### Testing

- [x] Manual testing of all feature combinations
- [ ] Manual testing of timeout scenarios
- [ ] Manual testing with highly varied backgrounds
- [ ] Regression testing complete

### Release

- [ ] Git tags created: v0.7.0.1
- [ ] Pull request created from rs_0701 to main
- [ ] Release notes published
- [ ] Gem published to RubyGems.org

***

## [START-DATA: Interactive Development Process Framework]

Github repo:  https://github.com/scooter-indie/ruby-spriter  
Target branch: rs_0701 (branch exists, in progress)  
Verify Repo Structure: Yes  
Git Diff in KB: Yes
Web Scraping URLs in KB: Yes
Baseline version to build upon: v0.7.0 
Requirements in /requirements: Ruby Spriter v0.7.0.1 Requirements.md
Requirement in KB: Yes
Test Framework Location: /spec  
Local access to target repository: Yes  
Necessary prerequisites installed: Yes  
Current branch [version] [status]: rs_0701 [v0.7.0.1-dev] [in progress]  
Git status: gh and git installed  

**Implementation Status:**

- Core GIMP integration: ✅ Complete
- Processing order fixes: ✅ Complete
- Dense shallow sampling: ⚠️ Pending
- Performance optimization: ✅ Complete (90% improvement)
- Timeout protection: ❌ Not implemented
- Documentation updates: ❌ Pending
- Regression testing: ⚠️ In progress

**Next Steps:**

1. ✅ ~~Complete regression testing~~ (Done)
2. ✅ ~~Performance optimization~~ (Complete - 90% faster)
3. ? ~~Implement dense shallow edge sampling~~ (BackgroundSampler)
4. ? ~~Fix GIMP threshold behavior~~ (Single-point selection)
5. ? Implement timeout protection (Deferred to v0.7.0.2)
6. ?? Update documentation (In progress)
7. ?? Update version to 0.7.0.1 (Pending)
8. ?? Create pull request (Pending)

## [END-DATA: Interactive Development Process Framework]

***

## END OF REQUIREMENTS DOCUMENT

***

**Ready**

I have created a comprehensive requirements document that combines:

1. ✅ The Base requirements structure and format
2. ✅ Implementation status from Revision 3
3. ✅ Actual changes from the rs0701.diff.txt file
4. ✅ Identified regressions and pending work
5. ✅ Current test results and known issues

The document clearly marks what is:

- ✅ **Implemented** (GIMP integration, processing order, core functionality)
- ⚠️ **Partially Complete** (edge sampling exists but needs dense shallow update)
- ❌ **Not Implemented** (timeout protection, documentation updates)

Please respond with **"First-Step"** when you're ready to begin addressing the pending requirements, or let me know if you need any clarifications about the consolidated document.