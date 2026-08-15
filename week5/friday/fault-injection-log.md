# Fault Injection Log — kijanikiosk-payments CI Pipeline

This log documents deliberate faults introduced into each of the five pipeline stages (Lint, Build, Verify, Archive, Publish), the observed downstream behavior, the design rationale for that behavior, and confirmation that the pipeline was restored to green after each fault.

---

## Fault 1: Lint Stage

**Fault injected:** Added an unused variable (`const unusedVariable = 'this will trigger a lint error';`) to `src/index.js`.

**Observed behavior:** The Lint stage failed with:
```
src/index.js
  17:7  error  'unusedVariable' is assigned a value but never used  no-unused-vars

✖ 1 problem (1 error, 0 warnings)
```
All four downstream stages — Build, Verify (both the Test and Security Audit branches), Archive, and Publish — were explicitly marked `"Stage skipped due to earlier failure(s)"`. The pipeline's `post { changed }` and `post { failure }` blocks still ran, correctly reporting `Build status changed from previous run: now FAILURE`.

**Design rationale:** Lint runs first specifically so that trivial code-quality problems are caught before spending time or resources on build, test, and publish steps that would only fail later anyway — this is the fail-fast principle.

**Restored to green:** Yes — the unused variable was removed, committed, and the next run returned `SUCCESS`.

---

## Fault 2: Build Stage

**Fault injected:** Changed the `build` script in `package.json` from `"mkdir -p dist && cp -r src/* dist/"` to `"mkdir -p dist && cp -r nonexistent-folder/* dist/"`.

**Observed behavior:** Lint passed cleanly. Build failed with:
```
cp: can't stat 'nonexistent-folder/*': No such file or directory
```
Verify (both branches), Archive, and Publish were all skipped with `"Stage skipped due to earlier failure(s)"`. The post-block correctly reported `Build status changed from previous run: now FAILURE`.

**Design rationale:** Build failing means there's no valid `dist/` output to test, archive, or publish — skipping the remaining stages avoids wasting time testing or shipping an artifact that was never actually produced.

**Restored to green:** Yes — the `build` script was corrected back to reference `src/*`, committed, and the next run returned `SUCCESS`.

---

## Fault 3: Verify Stage (Test branch)

**Fault injected:** Changed the test assertion in `src/index.test.js` from `expect(res.body.status).toBe('ok')` to `expect(res.body.status).toBe('broken-on-purpose')`.

**Observed behavior:** Lint and Build both passed. Inside Verify, the two parallel branches (Test, Security Audit) started simultaneously and ran independently to completion — Security Audit finished normally and reported its usual findings (2 moderate severity vulnerabilities, below the `--audit-level=high` failure threshold), while Test failed with a clear assertion mismatch:
```
Expected: "broken-on-purpose"
Received: "ok"
```
Jenkins marked the overall Verify stage failed once the Test branch failed. Archive and Publish were both skipped.

**Design rationale:** Running Test and Security Audit in parallel means an unrelated audit finding never blocks or delays test results (and vice versa) — each branch surfaces its own failure independently, so a developer immediately knows which check failed rather than receiving a single ambiguous "Verify failed" message. The log confirms both branches ran to full completion rather than one being cancelled early by the other's failure.

**Restored to green:** Yes — the assertion was corrected back to `'ok'`, committed, and the next run returned `SUCCESS`.

---

## Fault 4: Archive Stage

**Fault injected:** Changed the `tar` command in the Jenkinsfile's Archive stage from `tar -czf dist-archive/${PACKAGE_NAME}-${ARTIFACT_VERSION}.tgz dist/` to reference `nonexistent-dist/` instead of `dist/`.

**Observed behavior:** Lint, Build, and Verify (both branches) all passed normally. Archive failed with:
```
tar: nonexistent-dist: No such file or directory
tar: error exit delayed from previous errors
```
Only Publish was skipped, since it is the sole stage after Archive.

**Design rationale:** Archive failing means there's no valid, fingerprinted artifact to publish — skipping Publish prevents pushing a broken or missing package to Nexus, which would otherwise create a gap between what Jenkins reports as "built" and what's actually retrievable from the registry.

**Restored to green:** Yes — the `tar` command's source path was corrected back to `dist/`, committed, and the next run returned `SUCCESS`.

---

## Fault 5: Publish Stage

**Fault injected:** Changed `NEXUS_CREDENTIAL_ID` in the Jenkinsfile's `environment` block from `'nexus-publisher'` to `'nexus-publisher-nonexistent'`.

**Observed behavior:** Lint, Build, Verify, and Archive all passed normally. Publish failed immediately — Jenkins resolves the `withCredentials` binding before executing any shell commands inside it, so no `sh` step ever ran (no attempt was made to construct an `.npmrc` file, generate a token, or contact Nexus). The failure surfaced as a pipeline-level error rather than a stage-scoped one:
```
ERROR: Could not find credentials entry with ID 'nexus-publisher-nonexistent'
```

**Design rationale:** Failing before any shell code runs means Jenkins never attempts to construct or write credential material it doesn't actually have — this produces a fast, unambiguous failure and avoids any risk of a partially-formed publish attempt or malformed auth data being written to disk.

**Restored to green:** Yes — the credential ID was corrected back to `'nexus-publisher'`, committed, and the final run returned `SUCCESS`.

---

## Summary

| # | Stage | Fault | Result | Restored? |
|---|-------|-------|--------|-----------|
| 1 | Lint | Unused variable | Fail-fast — all downstream stages skipped | ✅ |
| 2 | Build | Missing source folder | Build failed cleanly — downstream skipped | ✅ |
| 3 | Verify (Test) | Wrong assertion | Test failed independently; Security Audit still completed | ✅ |
| 4 | Archive | Missing dist folder for tar | Archive failed cleanly — Publish skipped | ✅ |
| 5 | Publish | Invalid credential ID | Failed before any shell execution — no partial publish attempt | ✅ |

All five pipeline stages were independently verified to fail correctly and in isolation, and the pipeline was returned to a fully green state (`SUCCESS`) after each fault was corrected.
