
---

### **CHANGELOG.md**
```markdown
# Changelog

All notable changes to Ruby Spriter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.6.6] - 2025-10-23

### 🔒 File Protection & Safety Release

#### Added
- **Automatic Unique Filenames**: By default, generates timestamped filenames to prevent accidental overwrites
  - Format: `filename_YYYYMMDD_HHMMSS_mmm.ext` (includes milliseconds)
  - Applies to all output modes: `--video`, `--image`, `--consolidate`
  - Works with both auto-generated and `--output` specified filenames
- **`--overwrite` Flag**: Optional flag to explicitly allow overwriting existing files
- **File Protection Tests**: 19 new comprehensive tests for filename uniqueness and overwrite behavior
  - CLI integration tests for `--overwrite` flag
  - Output filename behavior tests for all modes
  - FileHelper utility tests for unique filename generation

#### Changed
- **Default Behavior**: Changed from overwriting to creating unique files (breaking change, but safer)
- **GimpProcessor**: Now respects `--overwrite` flag for scaled and background-removed images
- **Consolidate Workflow**: Default filename changed from `consolidated_spritesheet_TIMESTAMP.png` to `consolidated_spritesheet.png` (uniqueness handled by flag)

#### Technical Details
- New utility methods in `Utils::FileHelper`:
  - `unique_filename(path)` - Generates timestamped filename if file exists
  - `ensure_unique_output(path, overwrite:)` - Applies overwrite logic
- Processor workflows updated to use `ensure_unique_output` for all output paths
- Test coverage increased to 61.8% (500/809 lines)

Closes #17

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
