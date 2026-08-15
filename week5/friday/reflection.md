## Reflection

**1. Where did two requirements pull against each other, or where was the decision you were most uncertain about?**

The clearest tension showed up between Requirement 1 (a working, production-realistic Jenkinsfile) and Requirement 2 (a versioned artifact containing "the correct build output"). When Publish first succeeded, `npm publish` had packaged almost the entire repository into the tarball by default, including files unrelated to the payments service and, in one run, multi-megabyte Terraform provider binaries from an earlier week's work. Nothing in Requirement 1 said anything about restricting package contents, so the pipeline "worked" while quietly violating Requirement 2's intent. I resolved it by adding a `files` field to `package.json` to explicitly scope what gets published to `dist/` only. The uncertainty wasn't technical, it was noticing that a stage reporting success doesn't mean it did the *right* thing, only that it didn't crash.

A second, smaller version of the same problem showed up in the Publish stage's credential handling: getting `withCredentials` to actually inject a real, expanded token into `.npmrc` (rather than a literal unexpanded placeholder) took two separate attempts, since the first version technically ran without error but silently produced a useless file. Both cases taught me the same thing: a green pipeline is not proof of correctness, only proof that nothing threw an exception.

**2. Rewrite one sentence from the board document in technical language. What's the same, what's different?**

Board document sentence: *"Every time a developer finishes a piece of work and saves it to our shared codebase, an automated process immediately checks that change before it becomes part of what we actually run in production."*

Technical equivalent (Jenkinsfile comment / conversation with Osei): *"On every push to the `feature/week5-ci-pipeline` branch, Jenkins pulls the Jenkinsfile from SCM and runs the declarative pipeline: Lint gates Build via fail-fast ordering, Verify runs Test and Security Audit in parallel, and Archive/Publish only execute if every prior stage exits 0."*

What's the same: the underlying claim is identical, code doesn't move forward unless it passes every check, and this happens automatically and consistently. What's different: the technical version names the actual mechanism (SCM polling, exit codes, parallel branches, stage ordering) that makes that guarantee true. The board version asserts the outcome; the technical version proves it. Nia doesn't need to know what `withCredentials` does to trust the system, but Osei does, because he's the one who has to debug it when it breaks.

**3. If KijaniKiosk grows from four developers to forty, which part of this pipeline breaks first?**

The single Jenkins instance itself, specifically the `disableConcurrentBuilds()` option and the fact that it's running on one person's laptop rather than shared infrastructure. With four developers, it's unlikely two people push to CI-triggering branches within the same few minutes, so a single build executor blocking concurrent runs is a non-issue. At forty developers, simultaneous pushes become routine, and every build would queue behind whichever one happened to start first, turning a two-minute pipeline into a real bottleneck during busy periods. The credential setup would need to change too: right now, one shared `admin` Nexus account works fine for a single trusted maintainer, but at forty developers that's both a security and an accountability problem, since there's no way to tell which person's build published which artifact.

What would need to change: moving Jenkins off a personal laptop onto dedicated infrastructure with multiple build agents/executors so builds can run in parallel across branches, and replacing the shared admin credential with per-team or per-service Nexus accounts scoped to least privilege. Neither is a rewrite of the pipeline logic itself, the five stages and their ordering would stay the same, but both are necessary before this setup could support a team ten times its current size.
