# KijaniKiosk Payments Service: Server Security Decisions

**Prepared for:** Nia Kamau, Head of Product  
**Date:** 25 June 2026  
**Subject:** Security posture of the dedicated payments production node

---

## What We Built and Why It Matters

Before this sprint, the payments service ran on shared infrastructure that had accumulated changes over months — some planned, some emergency fixes, none documented in a way you could hand to an auditor. What we delivered this week is different: a server that builds itself from a single document of intent, where every security decision is recorded and every deviation from that intent causes the build to fail visibly.

This means the next time someone asks "why is that port open?" or "who can read that file?", the answer is not "we think it was set during Thursday's incident" — it is a line in a document with a named author and a stated reason.

That is what a defensible security posture looks like.

---

## Security Decisions

| Control | What it does | Risk mitigated |
|---|---|---|
| Dedicated service identities | Each service runs as its own user account with no login shell and no home directory. The payments service cannot touch the API service's files and vice versa. | Limits the damage if one service is compromised — an attacker cannot move laterally to other services. |
| Read-only system | The payments service can only write to its designated log folder. Everything else on the server — system files, configuration, other services — is read-only from the payments service's perspective. | Prevents malicious code running inside the service from modifying the system or planting backdoors. |
| No elevated privileges | The payments service starts with the minimum permissions needed to run and cannot acquire more, even if the application code requests them. | Eliminates an entire class of privilege escalation attacks. |
| Isolated process environment | The payments service has its own private view of temporary storage and cannot see or touch the temporary files of other services. | Prevents data leakage between services through shared temporary directories. |
| Network access restricted | The payments service can only communicate over standard internet protocols. It cannot open raw network sockets or communicate through unusual channels. | Reduces the risk of data exfiltration if the service is compromised. |
| Internal-only port | The port the payments service listens on is not reachable from the public internet. Only our internal monitoring infrastructure and the web layer on the same machine can reach it. | A member of the public cannot probe or attack the payments service directly. |
| Controlled log rotation | When log files are rotated nightly, the new files are created with exactly the right permissions automatically. No manual intervention is required and no window exists where logs are unreadable or unwritable. | Prevents silent log loss after rotation, which would break audit trails and alerting. |
| Configuration kept separate from code | Environment-specific secrets and settings live in files that only the relevant service account can read. They are never included in the codebase. | Prevents secrets from appearing in version control or being accidentally shared. |
| Persistent audit logs | System logs are written to permanent storage and capped to prevent the disk from filling. Logs are retained for 30 days. | Ensures post-incident investigation has a complete record of what happened and when. |
| Firewall with documented intent | Every firewall rule includes a written explanation of why it exists. Rules are applied from a clean baseline each time the server is provisioned, not accumulated from history. | Prevents "rule debt" where old rules exist because nobody knows whether it is safe to remove them. |

---

## What This Posture Protects Against

The controls above address the most common categories of risk for a payments service:

**Compromised application code.** If a vulnerability in the payments application is exploited, the attacker inherits only the payments service's permissions. They cannot read other services' configuration, modify system files, or persist across a reboot.

**Accidental misconfiguration.** Because the server rebuilds itself from a specification, a misconfiguration introduced manually will be corrected the next time the provisioning script runs. There is no permanent drift from the intended state.

**Audit gaps.** Log rotation, retention, and access controls are configured so that the audit trail for financial transactions is never interrupted and never accessible to unauthorised parties.

**Lateral movement.** Service isolation means a breach of one component does not automatically grant access to others. The payments service cannot reach the API service's files, logs, or configuration.

---

## What This Posture Does Not Protect Against

Honest gaps matter more than overclaiming.

**Application-layer vulnerabilities.** The controls here harden the operating environment, not the application code itself. A payment processing bug, an injection vulnerability, or a broken authentication flow in the application code is outside the scope of this specification. That requires code review, dependency scanning, and penetration testing of the application.

**Compromised deployment credentials.** If an attacker obtains the credentials used to run the provisioning script, they can rewrite the server's configuration. Protecting those credentials — through secret management, multi-factor authentication, and access review — is a separate workstream.

**Insider threats with root access.** A system administrator with root access on this server can bypass all of the above controls. Mitigating this requires separation of duties, access logging, and privileged access management, none of which are in scope for this sprint.

**Network-layer attacks between services.** The firewall controls traffic entering the server from outside. Traffic between services on the same machine is not filtered. If the API service were compromised, it could reach the payments service internally. Addressing this requires network segmentation or a service mesh, which is recommended as a next step before handling production payment volumes.

---

*This document reflects the security decisions made during the Week 3 production foundation sprint. It should be reviewed before the payments service handles live transactions.*
