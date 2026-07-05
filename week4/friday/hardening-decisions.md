# KijaniKiosk Staging Environment: Hardening Decisions

Prepared for Nia

## Summary

This document explains the security decisions built into KijaniKiosk's staging
environment now that the provisioning pipeline is automated end to end. Every
decision below is enforced by the pipeline itself, not by a person
remembering to configure something correctly afterward. Running the pipeline
twice produces an identical result, which is our proof that the environment
is not held together by manual steps.

## What we built

The pipeline creates three separate servers: one for the customer-facing API,
one for payment processing, and one for aggregating logs. Splitting these
across three servers, rather than one machine running all three, means a
problem on one cannot spread to another. The payment service, handling the
most sensitive data, gets extra protection beyond the other two.

Every server is built from the same reusable blueprint, so the API, payments,
and logs servers are constructed identically, with no manual one-off
differences. The record of what infrastructure exists is stored separately
from any single laptop, so it survives even if a laptop is lost or replaced.

## Key controls

| Control | What it does | Risk mitigated |
|---|---|---|
| Reusable server blueprint | Builds all three servers from one verified template instead of three separate manual setups | Prevents accidental misconfiguration when a server is rebuilt or a new one added |
| Externally stored infrastructure record | Keeps a record of what is deployed in a separate, dedicated storage location, not on any one laptop | Protects against losing track of the environment if a machine is lost or wiped |
| No hardcoded settings | Every environment-specific detail must be explicitly declared rather than assumed | Reduces the risk of accidentally shipping test settings or wrong values to a real environment |
| Strict filesystem confinement | Locks each service into writing only within its own designated area of the server | Contains the damage if a service is ever compromised, preventing it from tampering with the rest of the machine |
| Removed administrative powers | Strips each service of the ability to change users, load system extensions, or gain elevated control | Even a compromised service cannot escalate to take over the server |
| Restricted low-level operations | Limits which fundamental operating system actions each service is allowed to perform | Blocks entire categories of attack technique that rely on privileged low-level access |
| Extra network restriction on payments | Limits the payments service to ordinary internet traffic only, blocking unusual network behaviour | Shrinks the ways an intruder could try to open unexpected connections from that service |
| Default-deny firewall | Blocks all incoming connections except the small number we explicitly allow | Ensures no service is reachable from outside unless we intended it to be |
| Payments service network isolation | Allows only our internal monitoring system to check on the payments service; everyone else is refused | Keeps the most sensitive service invisible from the public internet |
| Log rotation ownership check | Refuses to rotate logs unless it can confirm exactly which service account owns them | Stops a permissions mistake in log handling from becoming a way to gain unauthorised access |

The payments service was measured against an industry-standard security
scoring tool and scored 1.4 out of a scale where lower is better, well ahead
of the target of 2.5 we set for ourselves. The other two services received a
solid baseline level of the same protections, with the payments service
carrying additional restrictions given the sensitivity of what it handles.

## A known limitation worth flagging

The record of what infrastructure exists is stored in a system that does not
currently prevent two people from changing the environment at the exact same
moment. For a solo engineer this is not a practical problem today, but it is
worth naming honestly: if a second engineer joined and ran a change at the
same time, both changes could be applied without either person being warned.
Larger deployments solve this with a dedicated locking mechanism designed for
exactly this situation, and adding one here would be a natural next step
before more than one person works on this environment at once.

## A real issue we caught and fixed

While building this, our log rotation step initially failed a safety check:
the tool responsible for rotating log files refused to run because it could
not confirm which account was supposed to own the resulting files. Rather
than loosen that check to make the error go away, we explicitly told the tool
which service account should be trusted, so the safety check now passes for
the right reason instead of being bypassed. We consider this a good sign, not
a weakness: it means the tooling caught a genuine ambiguity before it became a
production problem.

## What this does not protect against

This hardening work secures the servers themselves: how they are built, how
locked-down each service is, and what can reach them over the network. It
does not protect against weaknesses inside the application code running on
top of this infrastructure. If the payments application itself has a bug that
mishandles data, no amount of server hardening will catch that on its own.

It also does not include active monitoring or alerting. We know the servers
are configured correctly today, but nothing yet watches them continuously to
flag suspicious changes after deployment. Similarly, we have not addressed
what happens if an engineer's own access credentials are stolen. Strong
server-side controls do nothing to stop someone impersonating a legitimate
user who already holds the keys.

Finally, this environment currently has no built-in redundancy. Each service
runs on exactly one server, so losing any single server takes that service
offline until rebuilt. Since rebuilding takes minutes rather than hours,
thanks to the automation described above, this is a reasonable tradeoff for
staging, but not one we would carry into production without discussion.
