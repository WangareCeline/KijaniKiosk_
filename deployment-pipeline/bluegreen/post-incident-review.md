# Post-Incident Review: Wrong-Environment Deployment During Investor Demo

## Section 1: Incident Summary

During a live demonstration to investors, the deployment tool sent a new release to the wrong environment. This caused the demo environment to go offline for 48 seconds while visitors were watching. No customer data was affected and the correct version was restored as soon as the mistake was caught.

## Section 2: Timeline

All times are UTC. Times marked estimated are reconstructed from the incident narrative, not from logs, and are flagged accordingly.

| Time | Event |
|---|---|
| 09:10 (estimated, ±2 min, based on the narrative stating the walkthrough was underway when the trigger occurred) | Investor walkthrough begins on the staging environment |
| 09:15 (estimated, ±1 min) | Engineer triggers the deployment pipeline, intending to target a separate internal test environment |
| 09:16 (estimated, ±1 min, based on the narrative stating errors appeared within a minute of the trigger) | The proxy begins returning errors as the deployment pipeline switches traffic on the environment being demoed, not the intended target |
| 09:16:30 (estimated) | Engineer notices the demo has gone unresponsive |
| 09:17 (estimated) | Engineer identifies the environment mismatch and manually switches traffic back to the last known good state |
| 09:17:18 (estimated, derived from the reported 48-second outage window) | Service confirmed restored; demo resumes |

## Section 3: Root Cause

**Why 1: Why did the deployment target the wrong environment?**
Because the environment name was passed as a manually typed value at trigger time, and the engineer typed the name of the wrong environment.

**Why 2: Why was a manual typo able to target production-facing staging infrastructure?**
Because the pipeline has no validation step that confirms the target environment name against a known list before proceeding. Any string is accepted.

**Why 3: Why does the pipeline accept any string without validation?**
Because the environment targeting parameter was added early in the project, when only one environment existed, and the validation step was never added when a second environment was introduced.

**Why 4: Why wasn't validation added when the second environment was introduced?**
Because there was no process step that required infrastructure changes (like adding a new deployable environment) to be reviewed against the pipeline's input handling. The two pieces of work (adding an environment, and the pipeline that targets environments) were treated as unrelated changes made by whoever was available at the time.

**Structural finding:** The root cause is not "the engineer typed the wrong thing." It is that the pipeline's design assumes correct human input with no verification layer, and the process for introducing new deployment targets has no step that revisits that assumption. A typo will happen again; the question is whether the system catches it before it reaches a live audience.

## Section 4: Contributing Factors

- No confirmation prompt exists between typing the target environment name and the pipeline executing the switch. A single keystroke is the only barrier between intent and action.
- The investor demo was scheduled to run on the same staging environment used for engineering work, rather than a fully isolated demo environment. This meant a routine internal deployment action was capable of affecting a live audience-facing session.
- There was no pre-demo freeze window during which deployments were blocked. The pipeline remained fully operational during the exact time it posed the highest risk.

## Section 5: What Went Well

The engineer noticed the outage and diagnosed the environment mismatch within roughly 60-90 seconds, and the manual rollback (switching the proxy back to the last known good environment) took only seconds to execute once the mistake was identified, because the underlying blue/green switch mechanism is itself fast. The total outage was under a minute specifically because the recovery mechanism, once triggered, worked as designed.

## Section 6: Action Items

| Owner | Action | Timeframe |
|---|---|---|
| DevOps engineer | Add an environment-name validation step to the deployment pipeline that checks the requested target against a fixed allowlist of valid environment names, and rejects the run with an explicit error if it does not match | Before next deployment cycle (1 week) |
| Engineering lead | Provision a dedicated demo environment, separate from the staging environment used for routine engineering deployments, so that deployment actions during normal work cannot reach an audience-facing session | Before next investor demo is scheduled (2-3 weeks) |
| DevOps engineer | Add a confirmation step to the pipeline trigger that displays the target environment and requires explicit acknowledgment before the switch executes, for any deployment triggered manually rather than through CI | 2 weeks |

## What We Don't Commit To

This review does not address whether the demo should have been scheduled on a live environment at all as a policy question. That is a scheduling and stakeholder-communication decision outside the scope of a technical post-incident review, and is noted here only as a contributing factor, not something this document resolves.
