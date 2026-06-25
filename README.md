# KijaniKiosk.

This repository contains everything needed to provision a hardened, auditable server for the KijaniKiosk payments service – starting from a **dirty** VM that has accumulated four days of manual fixes and inconsistencies.

## Why this exists

Before this, our staging server had become a patchwork of lab exercises, emergency fixes, and manual tweaks. The payments team needed a dedicated production node, but we couldn't hand them a server whose state was a mystery. This project delivers a **single, idempotent provisioning script** that:

- Detects and corrects all partial/incorrect state left over from previous labs
- Builds three systemd services (`kk‑api`, `kk‑payments`, `kk‑logs`) with production‑grade hardening
- Sets up persistent journaling, log rotation, and a health check endpoint
- Documents every security decision so that Nia can explain it to the board

## Available files

| File | What it does |
|------|--------------|
| `pre_provisioning_audit.txt` | Output of the audit commands, with commentary on each dirty condition found on the target VM |
| `kijanikiosk_provision.sh` | The main provisioning script – 8 phases, inline unit files, and full verification |
| `provision_run_dirty.log` | Full timestamped output from a run on the dirty VM (shows partial‑state detection) |
| `provision_run_clean.log` | Output from a second run (idempotency proof) |
| `access_model_final.md` | Complete access model, including the new health directory and logrotate interaction |
| `kk_payments_hardening.md` | Iterative hardening log: starting score, each directive, rejected directives, final score |
| `hardening_decisions.md` | Board‑presentable security summary – no technical jargon, just risk and intent |
| `post_remediation_verification.txt` | Commands and output that confirm ACLs survive logrotate (the touch test) |
| `integration_notes.md` | Resolutions for the four integration challenges that the requirements intentionally create |
| `reflection.md` | Honest self‑assessment of conflicts, translation gaps, and the script's most fragile part |

---

## Prerequisites

- A VM running **Ubuntu 22.04 LTS** (or a WSL environment with systemd support)
- Root/sudo access (the script must be run as `root`)
- The VM should **not** be freshly reset
  
If you're starting from a clean machine, the `pre_provisioning_audit.txt` describes what dirty conditions to simulate before running the script.

---

## How to use it

1. **Clone the repository** 

2. **Audit your environment** (run the commands from `pre_provisioning_audit.txt` to see what state you're starting from).

3. **Run the provisioning script** as root:
   ```bash
   sudo bash kijanikiosk_provision.sh

The script logs everything to /var/log/kijanikiosk-provision.log and also prints progress to the console.

4.  **After it finishes**, the verification phase will report a summary of PASS/FAIL checks. A successful run exits with code 0.
    
5.  **Run it a second time** to confirm idempotency – you should see no errors and no structural changes.
    
6.  bashcat /opt/kijanikiosk/health/last-provision.jsonAll three services should report "ok" (they run Python's built‑in HTTP server as a placeholder).
    

Key design choices
-------------------------------------

*   **Dirty‑state resilience** – The script doesn't assume a clean slate. It checks for existing users, groups, permissions, and package holds, then corrects them. Every dirty condition found in the audit is explicitly handled.
    
*   **Hardening without breaking** – The payments service scores **2.3** on systemd-analyze security (below the 2.5 target) and still starts correctly.
    
*   **Log rotation that works** – The access model survives rotation because the create directive matches the directory's default ACLs. The script forces a rotation and confirms that kk-api can still write to the log directory.
    
*   **Firewall as intent, not history** – ufw is reset to a clean baseline and re‑apply rules with comments. The order ensures loopback and monitoring subnet traffic is allowed before the external deny.
    
*   **documentation** – The hardening decisions document is written for Nia. It explains risks without technical jargon, and it explicitly calls out what the controls do **not** protect against.
    

What you should see after a successful run
------------------------------------------

*   All three services are **enabled** and **running** (listening on ports 3000, 3001, 3002).
    
*   The health JSON file exists and is readable by the kijanikiosk group.
    
*   logrotate --debug passes without errors.
    
*   sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp succeeds.
    
*   The final verification summary shows FAILED: 0.
    

A note about WSL
----------------

If you're running this in Windows Subsystem for Linux, ufw may not be available. The script detects this and skips the firewall phase with a warning, that's fine for development. In production, ufw will be present and the rules will be applied.

One thing I'd improve with more time
------------------------------------

The logrotate postrotate signal handling is the most fragile part. Right now it falls back to || true, which means a failed signal won't cause logrotate to error. In a real production environment, I'd remove that fallback and add a monitoring check that verifies the new log file is being written to within a few seconds after rotation. That way, we'd know immediately if logs were lost.
