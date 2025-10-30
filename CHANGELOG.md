
---

### **CHANGELOG.md**
```markdown
# Changelog

All notable changes to Ruby Spriter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.7.0] - 2025-10-30

### 🎨 Inner Background Removal Release

Major feature release introducing advanced background removal capabilities with multi-stage processing pipeline for superior sprite edge quality.

#### Added

##### Inner Background Removal System (`--try-inner`)
- **Flood Fill-Based Background Removal**: Targets interior transparent regions missed by edge-based methods
  - Detects fully transparent pixels (alpha = 0)
  - Samples pixel colors from surrounding opaque regions
  - Uses flood fill to remove matching colors from transparent areas
  - Preserves sprite edges and anti-aliasing
  - Configurable tolerance and opacity thresholds
- **Edge Sampling Algorithm**: Intelligent color detection from sprite boundaries
  - Scans 8-directional neighbors (N, S, E, W, NE, NW, SE, SW)
  - Configurable search radius (default: 10 pixels, up to 50)
  - Returns most common color from opaque edge pixels
  - Handles cases with no opaque neighbors gracefully
- **Configuration Options**:
  - `--inner-tolerance VALUE`: Flood fill color matching tolerance (0.0-100.0%, default: 10.0%)
  - `--inner-opacity VALUE`: Minimum opacity threshold for edge sampling (0.0-1.0, default: 0.9)
  - `--inner-radius VALUE`: Edge sampling search radius in pixels (1-50, default: 10)

##### Threshold Stepping (`--threshold-stepping`)
- **Multi-Threshold Processing**: Applies background removal with multiple fuzzy select thresholds
  - Default thresholds: [0.0, 0.5, 1.0, 3.0, 5.0, 10.0]
  - Processes image separately with each threshold
  - Combines results using ImageMagick DstOver composite
  - Improves edge detection compared to single threshold
- **Automatic Result Combination**: Layers threshold results from highest to lowest
- **Configurable Thresholds**: Can override defaults via InnerBgConfig

##### Ghost Edge Prevention (`--multi-pass`)
- **Multi-Pass Alpha Cleanup**: Removes semi-transparent "ghost" pixels from edges
  - Iterative processing (up to 3 passes)
  - Detects pixels with alpha below threshold (default: 30/255 = ~12%)
  - Sets low-alpha pixels to fully transparent
  - Converges when no more ghost pixels detected
- **Convergence Detection**: Stops early when cleanup complete
- **Configuration**:
  - `--ghost-threshold VALUE`: Alpha threshold for ghost detection (0-255, default: 30)

##### Smoke Detection and Removal (`--remove-smoke`)
- **Transparency Gradient Detection**: Identifies smoke-like semi-transparent regions
  - Detects alpha values between 20-80% (MIN_ALPHA to MAX_ALPHA)
  - Filters by minimum contiguous area (50 pixels)
  - Grid-based sampling for performance (20-pixel steps)
  - Reports region coordinates, areas, and alpha ranges
- **Optional Removal**: Remove detected smoke effects with `--remove-smoke`
- **Detection Reports**: Always reports smoke regions when background removal active

##### Enhanced Color Space Support
- **RGBA Enforcement**: All modules force RGBA color space with `-define png:color-type=6`
  - Handles grayscale input images correctly
  - Ensures alpha channel availability for all operations
  - Prevents colorspace-related processing failures

##### Comprehensive Reporting
- **Detailed Processing Reports**: Each module provides timing and statistics
  - ThresholdStepper: Lists processed thresholds and timing
  - InnerBackgroundProcessor: Reports pixels removed, regions processed, edge sampling stats
  - GhostEdgeCleaner: Reports passes performed, ghost pixels detected/removed
  - SmokeDetector: Reports smoke regions detected, removal status, processing time
- **Pipeline Visibility**: Clear output formatting for each processing stage

#### Changed

##### Processing Pipeline Order
1. **Threshold Stepping** (if `--threshold-stepping` and `--remove-bg`)
2. **GIMP Edge-Based Removal** (if `--remove-bg` or `--scale`)
3. **Inner Background Removal** (if `--try-inner` and `--remove-bg`)
4. **Ghost Edge Cleaning** (if `--multi-pass` and `--remove-bg`)
5. **Smoke Detection** (always active when `--remove-bg`)

##### GIMP Version Requirement
- **Minimum Version**: Now requires GIMP 3.0+ for best results
  - GIMP 2.10 still supported but may have compatibility issues with new features
  - Recommend upgrading to GIMP 3.x for full feature compatibility

#### Performance

##### Benchmark Results (Windows 11, i7-12700K)
- **Edge Sampling**: ~0.015s per transparent pixel
- **Inner Background Removal**: ~2-5s for typical sprite (depends on transparent regions)
- **Threshold Stepping**: ~10-15s (6 thresholds × ~2s per threshold)
- **Ghost Edge Cleaning**: ~1-2s per pass (typically 1-2 passes)
- **Smoke Detection**: ~5-10s for typical sprite (grid sampling)

##### Total Pipeline Time
- **Basic Pipeline** (edge removal only): ~5-10s
- **Full Pipeline** (all features): ~25-40s
- **Recommended**: Enable only features needed for your sprites to optimize performance

#### Backward Compatibility

##### Fully Backward Compatible
- All existing CLI flags and workflows continue to work unchanged
- Default behavior (without new flags) identical to v0.6.7.1
- Existing spritesheets and metadata formats fully supported
- No breaking changes to public APIs or file formats

##### Opt-In Features
- All v0.7.0 features disabled by default
- Must explicitly enable with command-line flags
- Safe to upgrade without workflow changes

#### Testing

##### Test Coverage
- **102 Unit Tests**: All passing (35 new tests added)
  - 12 tests for ThresholdStepper
  - 16 tests for GhostEdgeCleaner
  - 20 tests for SmokeDetector
  - 14 tests for EdgeSampler
  - 17 tests for InnerBackgroundProcessor
  - 4 tests for InnerBgConfig
- **3 Feature Tests**: Integration tests for complete workflows
- **471 Total Examples**: Comprehensive coverage across entire codebase
- **Test Duration**: ~3 minutes 8 seconds for full suite

##### Test Quality
- TDD methodology (RED-GREEN-REFACTOR) used throughout
- ImageMagick command mocking for unit tests
- Real image processing in feature tests
- Performance tests ensure reasonable processing times

#### Documentation

##### Updated Documentation
- **README.md**: Added comprehensive v0.7.0 features section
  - 11 new command-line flags documented
  - 3 usage examples (basic, full pipeline, advanced)
  - Processing order diagram
  - Performance considerations
- **CHANGELOG.md**: This comprehensive release documentation
- **Code Comments**: Extensive inline documentation in all new modules

#### Technical Details

##### New Modules
- `lib/ruby_spriter/inner_bg_config.rb` (134 lines)
- `lib/ruby_spriter/edge_sampler.rb` (141 lines)
- `lib/ruby_spriter/inner_background_processor.rb` (256 lines)
- `lib/ruby_spriter/threshold_stepper.rb` (133 lines)
- `lib/ruby_spriter/ghost_edge_cleaner.rb` (153 lines)
- `lib/ruby_spriter/smoke_detector.rb` (224 lines)

##### New Test Files
- `spec/unit/inner_bg_config_spec.rb` (61 lines, 4 tests)
- `spec/unit/edge_sampler_spec.rb` (137 lines, 14 tests)
- `spec/unit/inner_background_processor_spec.rb` (188 lines, 17 tests)
- `spec/unit/threshold_stepper_spec.rb` (164 lines, 12 tests)
- `spec/unit/ghost_edge_cleaner_spec.rb` (217 lines, 16 tests)
- `spec/unit/smoke_detector_spec.rb` (246 lines, 20 tests)
- `spec/features/inner_background_removal_spec.rb` (139 lines, 3 tests)

##### Modified Files
- `lib/ruby_spriter/processor.rb`: Added 5-stage pipeline integration (3 new methods)
- `lib/ruby_spriter/cli.rb`: Added 11 new command-line options
- `lib/ruby_spriter.rb`: Added requires for new modules

#### Known Issues

##### Performance Considerations
- Full pipeline (all features enabled) takes 25-40s for typical sprites
- Smoke detection uses grid sampling - may miss very small smoke regions
- Inner background removal performance depends on transparent region size

##### Recommended Usage
- Enable `--try-inner` for sprites with complex interior backgrounds
- Use `--threshold-stepping` for sprites with subtle edge colors
- Enable `--multi-pass` for sprites with noticeable ghost edges
- Use `--remove-smoke` only if smoke effects detected in report
- For best performance, enable only features you need

#### Migration Guide

##### Upgrading from v0.6.7.1

**No Changes Required**
```bash
# Existing workflows continue to work unchanged
ruby_spriter --video input.mp4 --remove-bg --scale 50%
```

**Opt-In to New Features**
```bash
# Basic inner background removal
ruby_spriter --video input.mp4 --remove-bg --try-inner

# Full pipeline with all features
ruby_spriter --video input.mp4 --remove-bg \
  --threshold-stepping \
  --try-inner \
  --multi-pass \
  --remove-smoke

# Advanced configuration
ruby_spriter --video input.mp4 --remove-bg \
  --try-inner \
  --inner-tolerance 15.0 \
  --inner-opacity 0.85 \
  --inner-radius 15 \
  --ghost-threshold 40
```

**Performance Optimization**
```bash
# For simple sprites: edge removal only (fastest)
ruby_spriter --video input.mp4 --remove-bg

# For sprites with interior backgrounds: add --try-inner (moderate)
ruby_spriter --video input.mp4 --remove-bg --try-inner

# For complex sprites: full pipeline (slowest but highest quality)
ruby_spriter --video input.mp4 --remove-bg --threshold-stepping --try-inner --multi-pass
```

---

## [0.6.7.1] - 2025-10-24

### 🐧 Linux Support Enhancement Release

#### Added
- **Linux GIMP 3.x Support**: Full support for GIMP 3.x on Linux via Flatpak
  - Automatic detection of Flatpak GIMP installation (`flatpak:org.gimp.GIMP`)
  - Automatic Xvfb integration for completely headless GIMP operation
  - Virtual display provided by Xvfb eliminates display connection requirement
  - Flatpak socket isolation (`--nosocket=x11 --nosocket=wayland`) prevents GUI from appearing
  - Python-fu batch mode works correctly with `python-fu-eval` interpreter
  - Background removal, scaling, and all GIMP features fully functional
  - Perfect for desktop use (no GUI distraction) and server environments (CI/CD, Docker, SSH)
- **GIMP Version Detection**: Detect and report GIMP version (2.x or 3.x)
  - `Platform.detect_gimp_version(version_output)` - Parse version from `--version` output
  - `Platform.get_gimp_version(gimp_path)` - Get version from executable or Flatpak
  - Works with both regular executables and Flatpak installations
- **Xvfb Dependency Checking**: Added Xvfb to dependency checker (Linux only)
  - Marked as required on Linux, optional on Windows/macOS
  - Provides clear installation instructions if missing
  - Validates availability before GIMP operations
- **DependencyChecker Version Tracking**: Store and report detected GIMP version
- **Xvfb Integration**: Transparent Xvfb usage when GIMP Flatpak detected
  - Command format: `xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' flatpak run --nosocket=x11 --nosocket=wayland org.gimp.GIMP --no-splash --quit --batch-interpreter=python-fu-eval`
  - No user configuration required - works automatically
  - Completely headless - no GUI windows appear on screen

#### Changed
- **Platform Detection**: Enhanced to detect Flatpak GIMP alongside traditional installations
- **GimpProcessor**: Updated to support both GIMP 2.x and 3.x APIs (version-aware)
- **Unix GIMP Execution**: Automatically uses Xvfb with socket isolation for Flatpak installations
- **Alternative GIMP Paths**: Added `flatpak:org.gimp.GIMP` to Linux search paths
- **Warning Filters**: Enhanced to filter Xvfb, Wayland, and Flatpak cosmetic warnings
- **DependencyChecker**: Now supports platform-specific optional dependencies

#### Technical Details
- **GIMP Flatpak Detection**: Uses `flatpak list --app | grep` to verify installation
- **Version Parsing**: Regex-based parsing of `GIMP version X.Y.Z` output
- **Python Interpreter**: Correct name is `python-fu-eval` (not `python-eval`)
- **Xvfb Flags**:
  - `--auto-servernum` - Automatically finds free display number
  - `--server-args='-screen 0 1024x768x24'` - Configures virtual display
- **Flatpak Socket Isolation**:
  - `--nosocket=x11` - Prevents access to host X11 display socket
  - `--nosocket=wayland` - Prevents access to host Wayland display socket
  - Ensures GIMP runs only in Xvfb virtual display
- **Platform Module**: New methods for version detection and Flatpak handling
- **Warning Filtering**: Filters Gdk-WARNING, LibGimp-WARNING, Gimp-Core-WARNING, X11 socket messages

#### Installation Requirements (Linux)
```bash
# Ubuntu/Debian
sudo apt install flatpak xvfb -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gimp.GIMP -y

# Fedora/RHEL
sudo dnf install flatpak xorg-x11-server-Xvfb -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gimp.GIMP -y
```

#### Example Output
```bash
$ ruby_spriter --check-dependencies
============================================================
Dependency Check
============================================================

✅ FFMPEG
   Found: 6.1.1

✅ FFPROBE
   Found: 6.1.1

✅ IMAGEMAGICK
   Found: Version: ImageMagick 6.9.12-98 Q16 x86_64

✅ XVFB
   Found: Usage: xvfb-run [OPTION ...] COMMAND

✅ GIMP
   Found: flatpak:org.gimp.GIMP
   Version: GIMP 3.0.6

============================================================

$ ruby_spriter --image sprite.png --remove-bg
============================================================
GIMP Processing
============================================================
📝 Using GIMP via Xvfb (virtual display)
      Removing background (fuzzy select)...
      === GIMP Messages ===
      Loading image...
      Image size: 1280x748
      Added alpha channel
      Sampling 4 corners...
      Using FUZZY SELECT (contiguous regions only)
        Corner 1 at (0, 0)
        Corner 2 at (1279, 0)
        Corner 3 at (0, 747)
        Corner 4 at (1279, 747)
      Selection complete
      Growing selection by 1 pixels...
      Selection grown
      Removing background...
      Background removed
      Deselecting...
      Exporting...
      SUCCESS - Background removed!
      ====================
✅ Background Removal complete (142.15 KB)
```

**Note**: No GIMP GUI window appears on screen - completely headless operation!

---

## [0.6.7] - 2025-10-24

### 🚀 Batch Processing, Compression, Directory Consolidation & Frame Extraction Release

#### Added
- **Batch Processing Mode** (`--batch`): Process multiple MP4 files in a directory (Issue #16)
  - `--dir DIRECTORY`: Specify directory containing MP4 files to process
  - `--outputdir DIRECTORY`: Optional output directory (defaults to input directory)
  - `--batch-consolidate`: Automatically consolidate all resulting spritesheets
  - Supports all existing processing options: `--scale`, `--remove-bg`, `--sharpen`, `--interpolation`, etc.
  - Enforces unique filenames unless `--overwrite` is specified
  - Continues processing remaining videos if one fails
  - Provides detailed summary of successes and failures
- **Maximum Compression** (`--max-compress`): Apply maximum PNG compression (Issue #14)
  - Uses ImageMagick with optimal compression settings (level 9, filter 5, strategy 1, quality 95)
  - Preserves embedded metadata through compression
  - Works with all processing modes: `--video`, `--image`, `--batch`, `--consolidate`
  - Displays compression statistics (original size, compressed size, savings, reduction percentage)
- **Directory-Based Consolidation**: `--consolidate` now supports `--dir` option to automatically consolidate all spritesheets in a directory
  - Scans directory for PNG files with embedded spritesheet metadata
  - Automatically filters out non-spritesheet PNG files
  - Sorts files alphabetically by filename before consolidation
  - Requires at least 2 valid spritesheets in directory
  - Works with all existing consolidation options: `--output`, `--outputdir`, `--overwrite`, `--max-compress`, `--no-validate-columns`
  - Mutual exclusivity validation: Cannot use both comma-separated file list and `--dir` with `--consolidate`
- **Enhanced Context-Sensitive Help System**: Mode-specific help displays only relevant options
  - `ruby_spriter --video --help`: Shows video mode options (spritesheet generation, processing, output)
  - `ruby_spriter --image --help`: Shows image mode options (processing, frame extraction, output)
  - `ruby_spriter --consolidate --help`: Shows consolidation options (input methods, validation, output)
  - `ruby_spriter --batch --help`: Shows batch processing options (directory processing, applied options)
  - `ruby_spriter --split --help`: Shows frame extraction options (split format, metadata behavior, output)
  - General `--help`: Shows mode-specific help hints and directs users to detailed help
  - **Parent-Child Option Hierarchy**: Visual hierarchy (└─) shows modifier options grouped under parent options
    - `--interpolation`, `--sharpen*` modifiers shown under `--scale`
    - `--fuzzy`, `--threshold`, `--grow` modifiers shown under `--remove-bg`
    - `--override-md` modifier shown under `--split`
    - `--validate-columns` modifier shown under `--consolidate --dir`
  - Organized by function (Image Processing, Output Options) instead of by tool (GIMP Processing Options)
- **Frame Extraction** (`--extract`): Extract specific frames and create new spritesheet
  - `--extract FRAMES`: Comma-separated frame numbers (e.g., `1,2,4,5,8`)
  - `--columns NUM`: Specify output grid columns (default: 4)
  - Supports duplicate frame numbers for animation sequences
  - 1-indexed frame numbering (left-to-right, top-to-bottom)
  - Requires spritesheet metadata (works with `--verify` output)
  - Works with all `--image` processing options: `--scale`, `--remove-bg`, `--sharpen`, `--max-compress`
  - Automatic output naming with `_extracted` suffix or custom via `--output`
  - Temporary frames deleted after reassembly unless `--save-frames` specified
  - Minimum 2 frames required
  - Out-of-bounds validation against spritesheet metadata
  - Mutual exclusivity with `--split`
- **Metadata Management** (`--add-meta`): Add spritesheet metadata to images without metadata
  - `--add-meta R:C`: Specify grid layout (rows:columns, e.g., `4:4`)
  - `--overwrite-meta`: Replace existing metadata
  - `--frames COUNT`: Custom frame count for partial grids (fewer frames than grid size)
  - In-place modification by default (respects `--overwrite` flag)
  - Optional `--output` for copying to new file
  - Dimension validation: Image dimensions must divide evenly by grid
  - Enables `--extract`, `--consolidate`, `--verify`, `--split` on external spritesheets
  - Standalone mode: Cannot combine with `--scale`, `--remove-bg`, `--sharpen`
- **Enhanced `--save-frames`**: Now works with both `--video` and `--extract`
- **New Modules**:
  - `BatchProcessor` (lib/ruby_spriter/batch_processor.rb): Orchestrates batch video processing
  - `CompressionManager` (lib/ruby_spriter/compression_manager.rb): Handles PNG compression with metadata preservation
- **New Public Method**: `Consolidator#find_spritesheets_in_directory(directory)` for directory scanning
- **Comprehensive Test Coverage**: 68 new tests (13 for BatchProcessor, 11 for CompressionManager, 15 for directory consolidation, 7 for context-sensitive help, 22 for frame extraction and metadata management)

#### Changed
- **CLI**: Updated `--consolidate` description to mention `--dir` option
- **CLI**: Renamed "GIMP Processing Options" to "Processing Options" for tool-agnostic organization
- **CLI**: Updated image mode help with Frame Extraction & Reassembly section
- **CLI**: Added Metadata Management section to image mode help
- **Processor**: Refactored consolidation workflow to support both file list and directory modes
- **Test Suite**: Increased from 274 to 365 examples (all passing), 75.8% line coverage
- **CLI**: Added parent-child visual hierarchy to all context-sensitive help displays
- **CLI**: Corrected `--sharpen` to show as standalone option (not under `--scale`)

#### Examples
```bash
# Get context-sensitive help for specific modes
ruby_spriter --video --help
ruby_spriter --image --help
ruby_spriter --consolidate --help
ruby_spriter --batch --help
ruby_spriter --split --help

# Process all videos in directory
ruby_spriter --batch --dir "videos/"

# Process with output to different directory
ruby_spriter --batch --dir "videos/" --outputdir "output/"

# Process and consolidate all results
ruby_spriter --batch --dir "videos/" --batch-consolidate

# Process with scaling and compression
ruby_spriter --batch --dir "videos/" --scale 50 --max-compress

# Compress video output
ruby_spriter --video "input.mp4" --max-compress

# Compress image processing output
ruby_spriter --image "sprite.png" --scale 50 --max-compress

# Directory-based consolidation
ruby_spriter --consolidate --dir "spritesheets/"
ruby_spriter --consolidate --dir "spritesheets/" --outputdir "output/"
ruby_spriter --consolidate --dir "spritesheets/" --max-compress

# File list consolidation still works
ruby_spriter --consolidate file1.png,file2.png,file3.png

# Extract specific frames and create new spritesheet
ruby_spriter --image sprite.png --extract 1,2,4,5,8 --columns 3

# Extract with duplicates for animation loops
ruby_spriter --image sprite.png --extract 1,1,2,2,3,3 --save-frames

# Extract and process
ruby_spriter --image sprite.png --extract 1,3,5,7 --scale 50 --sharpen

# Add metadata to external spritesheet
ruby_spriter --image sprite.png --add-meta 4:4

# Add metadata with partial grid
ruby_spriter --image sprite.png --add-meta 4:4 --frames 14 --output sprite_meta.png

# Replace existing metadata
ruby_spriter --image existing.png --add-meta 8:8 --overwrite-meta

# Workflow: Add metadata, then extract frames
ruby_spriter --image external.png --add-meta 4:4
ruby_spriter --image external.png --extract 1,5,9,13 --columns 2
```

Closes #14, #16

---

## [0.6.6] - 2025-10-23

### 🔒 File Protection & Frame Extraction Release

#### Added
- **Automatic Unique Filenames**: By default, generates timestamped filenames to prevent accidental overwrites
  - Format: `filename_YYYYMMDD_HHMMSS_mmm.ext` (includes milliseconds)
  - Applies to all output modes: `--video`, `--image`, `--consolidate`
  - Works with both auto-generated and `--output` specified filenames
- **`--overwrite` Flag**: Optional flag to explicitly allow overwriting existing files
- **`--split R:C` Option**: Split spritesheets into individual frames for `--image` workflow
  - Format: `--split 4:4` (rows:columns, e.g., 4 rows × 4 columns)
  - Validation: Rows and columns must be 1-99, total frames < 1000
  - Frame naming: `FRddd_filename.png` (3-digit zero-padded format: FR001, FR002, ..., FR999)
  - Output directory: `filename_frames/`
  - Metadata priority: Uses embedded metadata if available, unless `--override-md` flag is provided
  - Dimension validation: Image dimensions must divide evenly by specified rows and columns
- **`--override-md` Flag**: Override embedded metadata when using `--split` with images that have metadata
- **Intermediate File Cleanup**: Fixed cleanup of intermediate files from GIMP processing
  - Now correctly removes files with dash separator (e.g., `file-nobg-fuzzy.png`, `file-scaled-40pct.png`)
  - Added Windows-compatible path normalization for file comparison
- **Frame Extraction Tests**: 17 new comprehensive tests for split functionality
  - CLI option tests for `--split` and `--override-md`
  - Format and range validation tests (10 tests)
  - Metadata priority logic tests (5 tests)
  - Updated SpritesheetSplitter tests for FR%03d format

#### Changed
- **Default Behavior**: Changed from overwriting to creating unique files (breaking change, but safer)
- **GimpProcessor**: Now respects `--overwrite` flag for scaled and background-removed images
- **Consolidate Workflow**: Default filename changed from `consolidated_spritesheet_TIMESTAMP.png` to `consolidated_spritesheet.png` (uniqueness handled by flag)
- **Frame Naming Format**: Changed from FR%02d (2 digits) to FR%03d (3 digits) to support up to 999 frames
- **Intermediate File Pattern**: Fixed glob pattern from underscore to dash separator for GIMP output files

#### Technical Details
- New utility methods in `Utils::FileHelper`:
  - `unique_filename(path)` - Generates timestamped filename if file exists
  - `ensure_unique_output(path, overwrite:)` - Applies overwrite logic
- New methods in `Processor`:
  - `validate_split_option!` - Validates split format and ranges during initialization
  - `determine_split_parameters(image_file)` - Implements metadata priority logic
  - `validate_image_dimensions(image_file, rows, columns)` - Validates even division
- Processor workflows updated to use `ensure_unique_output` for all output paths
- `SpritesheetSplitter` updated to use 3-digit frame format (FR%03d)
- Test coverage increased to 72.27% (688/952 lines)

Closes #17, #19, #30

---

## [0.6.5] - 2025-10-23

### 📦 Distribution & Packaging Release

**Note**: Version 0.6.5 is functionally identical to 0.6.4, which was yanked from RubyGems due to RubyGems policy preventing re-publication of yanked versions.

#### Added
- **GitHub Actions CI/CD Pipeline**: Automated testing across Ruby 2.7-3.3 on Ubuntu, macOS, and Windows
- **Automated RubyGems Publishing**: Auto-publish gem to RubyGems.org on version tag push
- **Release Automation Workflow**: Multi-platform gem builds with artifact uploads to GitHub Releases
- **Code Coverage Reporting**: SimpleCov integration in CI with PR summaries

#### Changed
- **Installation Options**: Two installation methods (RubyGems for all platforms, from source)
- **README Structure**: Simplified installation section focusing on gem distribution
- **Gemspec Author Info**: Updated from placeholders to actual author details

#### Distribution
- **RubyGems**: Published gem with all runtime files (works on Windows, macOS, Linux)
- **Source Install**: Git clone with local gem build option

#### Deferred
- **Windows Standalone Executable**: Deferred due to OCRA incompatibility with Ruby 3.x
  - OCRA 1.3.11 (last version, 2019) fails with Ruby 3.2+ due to internal fiber changes
  - Windows users can use `gem install ruby_spriter` after installing Ruby
  - Will revisit when better Windows packaging tools become available

Closes #18

---

## [0.6.4] - 2025-10-23 [YANKED]

Version yanked from RubyGems. Use 0.6.5 instead.

### 📦 Distribution & Packaging Release

#### Added
- **GitHub Actions CI/CD Pipeline**: Automated testing across Ruby 2.7-3.3 on Ubuntu, macOS, and Windows
- **Automated RubyGems Publishing**: Auto-publish gem to RubyGems.org on version tag push
- **Release Automation Workflow**: Multi-platform gem builds with artifact uploads to GitHub Releases
- **Code Coverage Reporting**: SimpleCov integration in CI with PR summaries

#### Changed
- **Installation Options**: Two installation methods (RubyGems for all platforms, from source)
- **README Structure**: Simplified installation section focusing on gem distribution
- **Gemspec Author Info**: Updated from placeholders to actual author details

#### Distribution
- **RubyGems**: Published gem with all runtime files (works on Windows, macOS, Linux)
- **Source Install**: Git clone with local gem build option

#### Deferred
- **Windows Standalone Executable**: Deferred due to OCRA incompatibility with Ruby 3.x
  - OCRA 1.3.11 (last version, 2019) fails with Ruby 3.2+ due to internal fiber changes
  - Windows users can use `gem install ruby_spriter` after installing Ruby
  - Will revisit when better Windows packaging tools become available

Closes #18

---

## [0.6.3] - 2025-10-23

### 🧪 Testing & Quality Assurance Release

#### Added
- **155 New RSpec Tests**: Comprehensive test coverage for CLI, GimpProcessor, Consolidator, PathHelper
- **Test Fixtures**: Real spritesheet fixtures (4x2, 6x2, 4x4), PNG images, MP4 video
- **Code Coverage Reporting**: SimpleCov tracking showing 57.09% coverage

#### Fixed
- **CLI Preset Bug**: Fixed OptionParser limitation preventing all 4 presets from working
- **PathHelper Quote Escaping**: Fixed single quote escaping in Unix paths (needed 4 backslashes)
- **Spec Helper Bug**: Changed instance variable to global variable for cross-context access
- **PathHelper Tests**: Made drive letter detection flexible for E: drive compatibility

#### Testing
- **CLI Tests (97)**: --help, --version, --check-dependencies, --image, --video, --consolidate, --verify
- **GimpProcessor Tests (48)**: Initialization, operations, interpolation, output filtering, script generation
- **Consolidator Tests (33)**: File validation, metadata, column validation, consolidation logic
- **PathHelper Tests (7)**: Quote paths, normalize for Python, native format conversion
- **Coverage**: Increased from 22.52% to 57.09% (+34.57 percentage points)

Closes #5

---

## [0.6.2] - 2025-10-22

### ✨ Quality Enhancement & Tooling Release

#### Added
- **Interpolation Options**: 5 interpolation methods for scaling (none, linear, cubic, nohalo, lohalo)
- **Sharpening Support**: Unsharp mask with configurable radius, gain, and threshold
- **`--version` Flag**: Display version, platform, and date information
- **`--check-dependencies` Flag**: Verify all external tools are installed with platform-specific guidance
- **File Extension Validation**: Runtime validation for MP4 (video) and PNG (images)
- **GIMP Investigation Documentation**: Comprehensive documentation of GIMP sharpen attempts and solutions

#### Changed
- **Automatic Operation Order**: Auto-optimize to remove background before scaling for better quality
- **Sharpening via ImageMagick**: Use ImageMagick instead of GIMP for reliable cross-platform sharpening
- **Alpha Channel Preservation**: Use merge instead of flatten to preserve transparency
- **Conservative Sharpen Defaults**: radius: 2.0, gain: 0.5, threshold: 0.03 to minimize halo artifacts
- **Parameter Terminology**: Changed "amount" to "gain" to match ImageMagick documentation

#### Fixed
- **Gem Build Error**: Removed .rb extension from `bin/ruby_spriter` executable
- **Clear Error Messages**: File extension validation provides helpful feedback

#### Documentation
- **README.md**: Added interpolation and sharpening documentation, file format requirements
- **CLAUDE.md**: Updated with new features and validation details
- **GIMP_SHARPEN_INVESTIGATION.md**: Documents 8 failed GIMP attempts and architectural decisions

---

## [0.6.1] - 2025-10-22

### 🎉 Major Refactoring Release

#### Added
- **Modular Architecture**: Split monolithic script into organized modules
- **RSpec Testing Framework**: Comprehensive unit test coverage
- **Dependency Checking**: Automatic validation of external tools
- **Better Error Handling**: Custom exception classes
- **Code Documentation**: Inline comments and YARD-compatible docs
- **SimpleCov Integration**: Code coverage reporting
- **RuboCop Support**: Code style enforcement

#### Changed
- **Project Structure**: Reorganized into `lib/`, `spec/`, and `bin/` directories
- **Class Organization**:
  - `Platform` - Platform detection and configuration
  - `DependencyChecker` - External tool validation
  - `VideoProcessor` - FFmpeg operations
  - `GimpProcessor` - GIMP operations
  - `MetadataManager` - PNG metadata handling
  - `Consolidator` - Spritesheet consolidation
  - `Processor` - Main orchestration
  - `CLI` - Command-line interface
  - Utilities: `PathHelper`, `FileHelper`, `OutputFormatter`

#### Fixed
- Path handling edge cases on Windows
- Improved error messages with actionable guidance
- Better temp file cleanup

#### Developer Experience
- Gemfile for dependency management
- RSpec test suite with fixtures
- Comprehensive README with examples
- Troubleshooting guide
- Contributing guidelines

---

## [0.6.0] - 2024-XX-XX

### Added
- Metadata embedding in PNG files
- Spritesheet consolidation feature
- Metadata verification command (`--verify`)
- Debug mode for troubleshooting

### Changed
- Improved GIMP script generation
- Better cross-platform path handling

---

## [0.5.0] - 2024-XX-XX

### Added
- Background removal with GIMP
- Fuzzy select and global color select options
- Image scaling support
- Configurable operation order

---

## [0.4.0] - 2024-XX-XX

### Added
- Video to spritesheet conversion
- FFmpeg integration
- Customizable grid layouts

---

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Basic video processing
- Cross-platform support

---

[0.6.2]: https://github.com/scooter-indie/ruby-spriter/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/scooter-indie/ruby-spriter/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/scooter-indie/ruby-spriter/releases/tag/v0.6.0
