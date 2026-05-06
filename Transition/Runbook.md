# Operations Runbook

**Last Updated:** 2026-05-06

Ruby Spriter is a CLI tool — there is no service to operate. This runbook covers user-facing diagnostic procedures and maintainer-side incident response.

## Service Overview

- Distribution: RubyGems (`ruby_spriter`)
- Source: https://github.com/rubrical-works/ruby-spriter
- Issue tracker: GitHub Issues on the same repo

## Health Checks

| Check | Command | Expected Result |
|-------|---------|-----------------|
| Tool install | `gem list ruby_spriter` | Lists installed version |
| Dependencies | `ruby_spriter --check-dependencies` | Exit 0 if all present |
| Smoke test | `ruby_spriter --video sample.mp4` | PNG produced with embedded metadata |

## Common Operations

### A user reports GIMP errors

**When:** Issue mentions GIMP 2.x or "interpolation" / Python-fu errors
**Steps:**
1. Confirm version: ask user to run `gimp --version` (must be 3.x)
2. Have them run `ruby_spriter --check-dependencies`
3. On Linux, verify Xvfb is installed and `--no-interface` is in command logs
4. If Flatpak GIMP, confirm path detection: `Platform.gimp_path`

### A user reports background-removal artifacts

**Steps:**
1. Ask for input MP4 / PNG sample if shareable
2. Reproduce with `--debug --keep-temp` to inspect intermediate frames
3. Try alternate selection: `--no-fuzzy` vs default fuzzy
4. Check `BackgroundSampler` / `GhostEdgeCleaner` / `SmokeDetector` outputs in temp dir

### Release smoke fails

**Steps:**
1. `gem yank` the broken version
2. Reproduce locally on a clean Ruby
3. File regression issue, fix on a release branch, ship a patch

## Incident Response

### Broken release shipped to RubyGems

**Symptoms:** Multiple user reports of `gem install` failures or immediate runtime crash
**Response:**
1. `gem yank ruby_spriter -v X.Y.Z`
2. Pin recommended version in README
3. Open `bug:` issue, branch off `main`, ship patch within 24h if possible
**Escalation:** Sole maintainer — escalation = open public GitHub issue

## Maintenance Tasks

### Dependency Tool Drift

**Frequency:** Quarterly
**Steps:**
1. Verify `--check-dependencies` still detects current FFmpeg / ImageMagick / GIMP releases
2. Update `Platform.gimp_paths` if new install locations emerge
3. Re-run full RSpec suite against latest tool versions on at least one OS
