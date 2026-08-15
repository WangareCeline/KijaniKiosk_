## Automated Quality Checks for KijaniKiosk Payments: A Plain-Language Overview

### What this system does

Every time a developer finishes a piece of work and saves it to our shared codebase, an automated process immediately checks that change before it becomes part of what we actually run in production. Think of it like a quality inspection line at a factory: nothing moves to the next station until it passes the current one. This happens without anyone needing to remember to run it. It's automatic and consistent, and it happens the same way every single time, regardless of who wrote the code or what time of day it was submitted.

### The five checks, in order

1. **Style check.** The system first confirms the code follows our agreed formatting and structure rules. This catches sloppy or inconsistent code before we spend any more time on it.
2. **Assembly.** The code is compiled into the form we would actually ship, using the same process that would run before any real deployment.
3. **Two checks at once.** The system simultaneously runs our automated tests (does the payment service actually behave correctly?) and a security scan (does anything we depend on have a known vulnerability?). Running these together, rather than one after another, means we get answers faster.
4. **Packaging and labeling.** Once everything passes, the system packages the finished code into a single, uniquely labeled version, similar to how a shipment gets a tracking number. Every version is traceable back to the exact change that produced it.
5. **Filing.** The labeled package is stored in our internal registry, where it stays permanently retrievable. We currently have two such versions stored and retrievable, proving the labeling and storage genuinely works, not just in theory.

| Stage | What it confirms |
|---|---|
| Style check | Code follows our formatting standards |
| Assembly | Code compiles into a runnable, deployable form |
| Tests + Security scan | The service behaves correctly, and nothing it depends on has a known vulnerability |
| Packaging | A uniquely versioned, traceable package is produced |
| Filing | The package is safely stored and retrievable |

### What happens when something goes wrong

We deliberately tested this by introducing a mistake at each of the five stages, one at a time, to confirm the system behaves the way we expect. In every single case, the result was the same: the moment a problem is detected, the process stops immediately and does not proceed to the next stage. A style mistake never reaches the packaging step. A failed test never gets filed into our registry. Nothing broken is ever allowed to progress further than the point where the problem was found.

This matters because it means our stored, retrievable versions are trustworthy by construction: if a version exists in our registry, it necessarily means every single check ahead of it passed. We don't have to take anyone's word for that; the system enforces it automatically, every time, regardless of deadlines or how urgent a change feels. We also confirmed the reverse: once a mistake is fixed, the very next run goes through all five checks cleanly and completes successfully, typically in under two minutes.

### What this does not yet do

This system checks quality before code is stored. It does not yet automatically deploy that code to our live servers. Right now, moving a verified version into production is still a manual step a team member performs. We also don't yet have automated notifications (like a message to the team) when something fails. Right now, a team member has to actively check the system to see the result. Finally, this whole process currently runs on a single machine set up for this project; as our team grows, we'll want this running on shared, always-available infrastructure rather than one person's laptop. These are reasonable next steps, not gaps that undermine what's been built. The core quality-checking system itself is complete, tested under failure conditions, and working.
