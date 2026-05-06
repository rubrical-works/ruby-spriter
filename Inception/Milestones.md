# Milestones

**Last Updated:** 2026-05-06

## Shipped

| Version | Highlights |
|---------|------------|
| 0.6.7 | Batch processing, max-compression, metadata add |
| 0.7.0 | `--extract` and `--add-meta` workflows |
| 0.7.0.1 | Frame-by-frame processing for varying backgrounds; GIMP 3.x enforcement; headless Linux fixes |

## Active (v0.7.0.x line)

- Stability fixes for GIMP 3.x batch mode
- Headless Linux (Xvfb + Flatpak / native) reliability
- Documentation modularization (in-progress per recent commits)

## Next (proposed, not committed)

- Additional background-removal heuristics per real-world feedback
- Performance tuning for batch + consolidate pipelines
- Optional input-format expansion (deferred until dependency review)

## Tracking

Issues, milestones, and release branches are tracked in GitHub via `gh pmu` per `.gh-pmu.json` configuration.
