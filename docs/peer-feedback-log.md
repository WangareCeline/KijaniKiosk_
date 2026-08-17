# Feedback Log (Self-Review)

No classmate was available for a peer session, so this is a documented
self-review instead.

## Test plan (written before review)

- Run terraform apply and confirm namespace created
- Trigger Jenkins build and confirm it reaches the approval gate
- Check git history for anything that shouldn't be committed
- Confirm README matches what was actually built

## Issues found

### 1. Terraform state file committed to repository
**Severity:** High
**Resolution:** Added .gitignore for .terraform/ and terraform.tfstate,
removed from tracking with git rm --cached.
**Evidence:** commit a786009
**GitHub Issue:** https://github.com/WangareCeline/KijaniKiosk_/issues/7

### 2. Pipeline deploys a fixed image tag instead of the freshly built one
**Severity:** Medium
**Resolution:** Not yet resolved. The pipeline's CI stage only publishes
an npm package; there is no Docker build/push step, so the deploy stages
use a known-working tag (1.4.0-d9f5edc) instead of the artifact just built.
**Evidence:** noted in README under Known Production Gaps

### 3. Root README was briefly overwritten by an unrelated commit
**Severity:** Low
**Resolution:** Caught before the mistake compounded; restored from git
history (commit 0982b7a) and the new content was moved to the correct
location instead.
**Evidence:** commit a55ef7e restores it correctly

## Improvement committed

Issue #1 above is the resolved improvement, tied to the GitHub Issue and
visible via commit a786009.
