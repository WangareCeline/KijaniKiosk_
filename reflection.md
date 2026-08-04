# Reflection

## 1. The demo script and overclaiming

The line "no one had to notice, no one had to react, it just happened" is the moment that oversimplifies. It's true for this specific failure mode: a health check stops responding, the monitor catches it, and traffic switches back. But it makes the system sound like it protects against every kind of failure, when really it only protects against the one failure it's built to detect. If the new version was slow instead of dead, or silently returning wrong data instead of erroring, this exact mechanism wouldn't catch it at all.

To be more precise without losing a non-technical board member, I'd add one sentence: "This works because we told the system exactly what 'broken' looks like ahead of time. If something breaks in a way we didn't anticipate, a person still needs to be watching." That keeps the plain language but stops the demo from implying the system is smarter than it actually is.

## 2. Highest-value action item and confidence

The highest-value action item is the environment-name validation step (checking the deployment target against a fixed allowlist before the pipeline runs). I'm fairly confident it would prevent this exact recurrence, since it directly closes the gap that let a typo reach a live environment.

I'm less confident it prevents the next incident with a different shape. To be certain, I'd need to know whether the pipeline has other places where unvalidated input controls something consequential, not just the environment name. I built the environment used in this project myself today, so I know its exact failure surface. A real production pipeline built by a team over months likely has other unvalidated inputs I haven't seen and can't reason about from this review alone.

## 3. What carries forward vs. becomes redundant

The state files (.active-env, .previous-env) and the switch script become entirely redundant in the container world. Kubernetes tracks which Pods are running and what image they're running as part of its own internal state; there's no need for a separate file on disk to declare what's "active," because the cluster's actual running state is the source of truth.

The rollback script's underlying logic partially carries forward, but not the script itself. The concept of "detect a failure, then revert to a known-good version" still applies, but Kubernetes implements the detection half through built-in health checks and restarts failed containers automatically, without any custom polling script. The revert-to-known-good half becomes a redeploy of the previous image tag rather than a file rewrite and a proxy reload.

The monitor's core idea (something has to define what "healthy" means and watch for it) carries forward directly into the container world's HEALTHCHECK and readiness probes. What changes is that this becomes a declared property of the container instead of a separate process someone has to remember to start.

## 4. Hardcoded values in the deployment manifest

- **VERSION environment variable** (currently set to "1.4.0-d9f5edc" directly in the manifest): this duplicates the image tag already specified in the image field. If they ever drift apart, the app reports a version that doesn't match what's actually running, which makes any incident investigation confusing. This belongs in a ConfigMap that's generated at deploy time from the same source as the image tag, not typed twice.
- **PORT environment variable** (hardcoded to "3001"): not dangerous today, but it means changing the port requires editing and reapplying the whole manifest rather than changing one config value that could be shared across multiple services or environments.
- **Resource requests and limits** (100m/64Mi request, 250m/128Mi limit, hardcoded per environment): fine for one environment, but if we ever run a staging and production version of this manifest, these numbers should probably differ, and hardcoding them means copy-pasting and editing the whole file instead of overriding one value.

None of these are credentials, so the risk here isn't a leak, it's operational: every one of these requires editing YAML directly to change a value that arguably shouldn't require touching the deployment definition at all.
