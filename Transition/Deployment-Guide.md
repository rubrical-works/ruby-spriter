# Deployment Guide

**Version:** 0.7.0.1
**Last Updated:** 2026-05-06

Ruby Spriter ships as a RubyGem. "Deployment" = gem release.

## Prerequisites

- [ ] Bundler installed (`gem install bundler`)
- [ ] RubyGems credentials configured (`~/.gem/credentials`)
- [ ] All RSpec tests green (`rake test`)
- [ ] CHANGELOG.md updated for this version
- [ ] Version bumped in `lib/ruby_spriter/version.rb`
- [ ] Tag created on `main` (`git tag v0.7.0.x`)

## Environment Configuration

No environment variables required for build or release. Runtime tools (FFmpeg, ImageMagick, GIMP 3.x, Xvfb on Linux) are users' responsibility — `--check-dependencies` reports their availability.

## Release Steps

### Pre-Release
1. `rake test` — full lint + spec
2. Verify CHANGELOG entry exists for new version
3. Confirm `lib/ruby_spriter/version.rb` matches intended tag
4. Commit + push to `main` via PR

### Release
1. `gem build ruby_spriter.gemspec`
2. `gem push ruby_spriter-X.Y.Z.gem`
3. `git tag vX.Y.Z && git push origin vX.Y.Z`
4. Create GitHub release notes referencing CHANGELOG section

### Post-Release
1. Verify install from clean machine: `gem install ruby_spriter`
2. Run `ruby_spriter --check-dependencies`
3. Smoke-test `--video` and `--batch` modes against a known sample MP4

## Rollback

1. `gem yank ruby_spriter -v X.Y.Z` (if a release is broken)
2. Revert offending commits on `main` via PR
3. Cut a fixed `X.Y.Z+1` patch release

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| `gem push` 401 | Refresh RubyGems credentials |
| Tag exists upstream | Bump patch version; never reuse a tag |
| Users report GIMP 2.x | Expected — `DependencyChecker` rejects it; document in release notes |
