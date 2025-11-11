# Documentation Index

Welcome to Ruby Spriter documentation! This directory contains comprehensive guides organized by topic. Choose the guide that matches your needs:

---

## 🚀 Getting Started

**New to Ruby Spriter?** Start here:

1. **[Installation Guide](INSTALLATION.md)** - Install Ruby Spriter and verify all dependencies
2. **[Usage Guide](USAGE.md)** - Learn the command-line interface and common commands
3. **[Features Overview](FEATURES.md)** - Understand all capabilities and features

---

## 📚 Reference Documentation

### For Daily Usage

- **[Usage Guide](USAGE.md)** - Complete CLI options reference with examples
  - Input/output options
  - Scaling and sharpening parameters
  - Background removal options
  - Batch processing and consolidation
  - Metadata management

- **[Use Cases & Examples](USE_CASES.md)** - Real-world scenarios and workflows
  - Game development with Godot
  - Batch processing pipelines
  - Quality enhancement techniques
  - Frame-by-frame processing
  - Mobile and web optimization

### For Advanced Usage

- **[Advanced Features](ADVANCED.md)** - Deep dive into powerful features
  - Batch processing with consolidation
  - PNG compression and file protection
  - Directory-based consolidation
  - Metadata management
  - Headless Linux operation
  - Debug mode

- **[Features Overview](FEATURES.md)** - Complete feature descriptions
  - Image processing capabilities
  - Background removal techniques
  - v0.7.0+ advanced features
  - Frame-by-frame processing
  - Cell-based cleanup (experimental)

### For Developers

- **[Architecture Guide](ARCHITECTURE.md)** - System design and internals
  - Processing modes
  - Component descriptions
  - Data flow diagrams
  - Version-specific features
  - Technology stack

- **[Development Guide](DEVELOPMENT.md)** - Contributing and development
  - Setup development environment
  - Project structure
  - Running tests
  - Contributing workflow
  - Code quality practices

---

## 📋 Installation Methods

### Windows
- [Chocolatey (Recommended)](INSTALLATION.md#windows-chocolatey---recommended)
- [Manual Installation](INSTALLATION.md#alternative-manual-installation-on-windows)

### macOS
- [Homebrew](INSTALLATION.md#macos-homebrew)

### Linux
- [Ubuntu/Debian](INSTALLATION.md#linux-ubuntudebian)
- [Fedora/RHEL](INSTALLATION.md#linux-fedorarhel)

### From Source
- [Development Installation](INSTALLATION.md#%EF%B8%8F-option-b-from-source-development)

---

## 🎯 Quick Recipes

### Video to Spritesheet

```bash
ruby_spriter --video input.mp4
```
[See more examples](USAGE.md#basic-video-to-spritesheet)

### Remove Background

```bash
ruby_spriter --video input.mp4 --remove-bg
```
[Learn background removal options](FEATURES.md#background-removal)

### Batch Processing

```bash
ruby_spriter --batch --dir "videos/" --remove-bg --max-compress
```
[Explore batch workflows](ADVANCED.md#batch-processing-v0.6.7)

### Frame-by-Frame Processing

```bash
ruby_spriter --video input.mp4 --remove-bg --by-frame
```
[When to use frame-by-frame](FEATURES.md#%EF%B8%8F-frame-by-frame-processing-v0701)

---

## 🔍 Find What You Need

### By Feature

| Feature | Documentation |
|---------|---|
| Video to Spritesheet | [Usage](USAGE.md), [Features](FEATURES.md) |
| Background Removal | [Features](FEATURES.md#background-removal), [Advanced](ADVANCED.md) |
| Scaling & Sharpening | [Features](FEATURES.md#scaling-with-quality-control) |
| Frame-by-Frame | [Features](FEATURES.md#-frame-by-frame-processing-v0701) |
| Batch Processing | [Advanced](ADVANCED.md#batch-processing-v0.6.7) |
| Consolidation | [Advanced](ADVANCED.md#directory-based-consolidation-v0.6.7) |
| Compression | [Advanced](ADVANCED.md#maximum-compression-v0.6.7) |
| Metadata | [Advanced](ADVANCED.md#metadata-management) |
| Cell Cleanup | [Features](FEATURES.md#-cell-based-background-cleanup-v0701---experimental) |

### By Workflow

| Use Case | Documentation |
|----------|---|
| Game Development | [Use Cases](USE_CASES.md#game-development-with-godot) |
| Mobile Games | [Use Cases](USE_CASES.md#mobile-game-development) |
| Batch Workflows | [Use Cases](USE_CASES.md#batch-processing-workflows-v0.6.7), [Advanced](ADVANCED.md#batch-processing-v0.6.7) |
| Prototyping | [Use Cases](USE_CASES.md#prototyping-and-game-jams) |
| Asset Refinement | [Use Cases](USE_CASES.md#asset-refinement-and-iteration) |
| Web Optimization | [Use Cases](USE_CASES.md#web-asset-pipeline) |
| CI/CD Pipeline | [Use Cases](USE_CASES.md#cicd-automated-asset-processing) |

### By Role

| Role | Start Here |
|------|---|
| **Game Developer** | [Installation](INSTALLATION.md) → [Use Cases](USE_CASES.md) → [Usage](USAGE.md) |
| **Tool Administrator** | [Installation](INSTALLATION.md) → [Advanced](ADVANCED.md) → [Development](DEVELOPMENT.md) |
| **Contributor** | [Development](DEVELOPMENT.md) → [Architecture](ARCHITECTURE.md) |
| **DevOps/Pipeline** | [Advanced](ADVANCED.md#batch-processing-v0.6.7) → [Use Cases](USE_CASES.md#cicd-automated-asset-processing) |

---

## 🆕 What's New in v0.7.0.1

- ✨ **Cell-Based Background Cleanup** - Post-process residual backgrounds per-cell (experimental)
- 🎞️ **Frame-by-Frame Processing** - Better results for videos with varying backgrounds
- 🐛 **Bug Fixes** - Resolution of `--by-frame` runtime errors
- 🔧 **Performance** - BatchProcessor optimization (20× faster dependency checking)

[See full changelog](../CHANGELOG.md)

---

## 🔗 Related Resources

- **[Main README](../README.md)** - Project overview and quick start
- **[CHANGELOG](../CHANGELOG.md)** - Complete version history
- **[CLAUDE.md](../CLAUDE.md)** - Developer architecture documentation
- **[GitHub Issues](https://github.com/scooter-indie/ruby-spriter/issues)** - Report bugs, request features

---

## ❓ Frequently Asked Questions

### Installation

**Q: How do I install prerequisites on Windows?**
A: [See Windows installation guide](INSTALLATION.md#windows-chocolatey---recommended)

**Q: What if I don't have GIMP installed?**
A: [See dependency checking](INSTALLATION.md#verify-installation)

### Usage

**Q: How do I process multiple videos at once?**
A: [See batch processing guide](ADVANCED.md#batch-processing-v0.6.7)

**Q: When should I use `--by-frame`?**
A: [See frame-by-frame documentation](FEATURES.md#-frame-by-frame-processing-v0701)

**Q: How do I optimize file sizes?**
A: [See compression guide](ADVANCED.md#maximum-compression-v0.6.7)

### Development

**Q: How do I set up a development environment?**
A: [See development setup](DEVELOPMENT.md#setup-development-environment)

**Q: How are tests structured?**
A: [See development guide](DEVELOPMENT.md#code-quality)

---

## 📞 Getting Help

1. **Check the relevant documentation guide** (above)
2. **Search [GitHub Issues](https://github.com/scooter-indie/ruby-spriter/issues)** for similar problems
3. **Create a new issue** with:
   - Ruby version (`ruby --version`)
   - Dependency status (`ruby_spriter --check-dependencies`)
   - Exact command used
   - Full error message

---

## 🎓 Learning Path

### Beginner Path (First Time Users)
1. [Installation Guide](INSTALLATION.md) - Install and verify
2. [Usage Guide](USAGE.md) - Learn basic commands
3. [Quick Start](../README.md#-quick-start) - Try first examples

### Intermediate Path (Regular Users)
1. [Features Overview](FEATURES.md) - Understand capabilities
2. [Use Cases](USE_CASES.md) - Learn workflows
3. [Advanced Features](ADVANCED.md) - Explore powerful options

### Advanced Path (Power Users)
1. [Architecture Guide](ARCHITECTURE.md) - Understand internals
2. [Advanced Features](ADVANCED.md) - Master all options
3. [Development Guide](DEVELOPMENT.md) - Contribute improvements

---

**Quick Navigation:** [Installation](INSTALLATION.md) | [Usage](USAGE.md) | [Features](FEATURES.md) | [Advanced](ADVANCED.md) | [Architecture](ARCHITECTURE.md) | [Development](DEVELOPMENT.md) | [Use Cases](USE_CASES.md)
