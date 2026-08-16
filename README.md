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

## Capstone: Track A - Infrastructure-First Deployment Pipeline

This section documents the final capstone build on top of the provisioning
work above: a staged, gated deployment pipeline for kk-payments with
monitoring and a serverless receipt chain integration.

### Architecture

See `architecture-diagram.png` for the full pipeline flow: merge to main
triggers Jenkins CI, which deploys to the `kijani-staging` namespace, runs a
smoke test, waits for manual approval, then deploys to production. kk-payments
in staging writes receipts that trigger the serverless notifier chain, and
Prometheus watches both environments for restart-rate issues.

### CI/CD Pipeline (Jenkins)

The `Jenkinsfile` at the repo root runs, in order:

1. **Lint** - ESLint against the kk-payments source
2. **Build** - compiles to `dist/`
3. **Verify** (parallel) - Jest tests and `npm audit --audit-level=high`
4. **Archive** - packages a versioned tarball artifact
5. **Publish** - pushes the npm package to Nexus (`kijanikiosk-npm-hosted`)
6. **Deploy to Staging** - deploys kk-payments to the `kijani-staging`
   Kubernetes namespace
7. **Smoke Test** - port-forwards to the staging pod and confirms `/health`
   returns `{"status":"ok"}`
8. **Approval Gate** - pauses for manual input with a required
   `APPROVAL_REASON` field before continuing
9. **Deploy to Production** - deploys the same image to the `default`
   namespace

A merge to `develop` triggers the pipeline automatically; production is never
touched without an explicit, recorded approval.

### Infrastructure (Terraform + Ansible)

`deployment-pipeline/terraform/staging-namespace/` provisions the
`kijani-staging` Kubernetes namespace via the Terraform Kubernetes provider.
`deployment-pipeline/ansible/configure-staging-namespace.yml` then labels it
`managed-by: ansible` to confirm configuration management ran against it.

To reproduce from a clean checkout:

    cd deployment-pipeline/terraform/staging-namespace
    terraform init
    terraform apply

    cd ../../ansible
    ansible-playbook configure-staging-namespace.yml

### Environment-Specific Configuration

`deployment-pipeline/containers/kk-payments-deployment.yaml` is the single
Deployment manifest used for both staging and production. Each environment
gets its own `DB_HOST` via a ConfigMap:

    kubectl apply -f deployment-pipeline/containers/staging-configmap.yaml
    kubectl apply -f deployment-pipeline/containers/production-configmap.yaml

### Monitoring (Prometheus)

`deployment-pipeline/monitoring/kk-payments-alerts.yaml` defines a
`PrometheusRule` (`KkPaymentsHighRestartRate`) that fires when kk-payments
restarts more than twice in 15 minutes, in either namespace. Installed via
the `kube-prometheus-stack` Helm chart:

    helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
    kubectl apply -f deployment-pipeline/monitoring/kk-payments-alerts.yaml

### Serverless Receipt Chain

`deployment-pipeline/serverless/` contains a local simulation of the Week 10
serverless receipt chain (kk-payments writes a receipt, a notifier function
fires in response). See that folder's README for the full scoping
explanation - no live AWS account was available during this build, so the
S3-triggered Lambda is simulated locally with `fs.watch` rather than deployed.

### Known Production Gaps

- The serverless receipt chain runs locally, not on a real cloud provider
  (see `deployment-pipeline/serverless/README.md`)
- The pipeline deploys a known-working image tag rather than building and
  pushing a fresh Docker image per run - CI publishes an npm package, but
  there is currently no container build/push stage
- Kubernetes credentials are copied into the Jenkins container directly
  rather than scoped via a dedicated service account token
