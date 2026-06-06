# Branch Protection E2E Validation

This repo validates that the `Tests / pre-commit-tests` required check blocks
PRs when tests fail.

## Workflow

- `pre-commit-tests` job runs on push to develop, all PRs, and manual dispatch
- Branch protection on `develop` requires this check to pass
- Intentionally failing tests should block PR merge

## Files

- `.github/workflows/tests.yml` — workflow with pre-commit-tests job
- `tests/test_must_fail.py` — intentionally failing test
- `tests/test_passing.py` — passing control test
- `backend/scripts/setup_branch_protection.ps1` — config script
