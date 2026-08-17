# AI Governance Log

This log documents where AI assistance (Claude) was used during the Track A
capstone build, what it produced, what it got wrong, and what was manually
verified or corrected before being committed.

---

## Entry 1: Jenkins pipeline deploy stages

**Date:** 2026-08-16
**Tool:** Claude (chat)
**Task:** Extend the existing Jenkinsfile with staging deploy, smoke test,
and production approval gate stages.

**What it produced:** Four new pipeline stages (Deploy to Staging, Smoke
Test, Approval Gate, Deploy to Production) using `kubectl` commands inside
the existing Docker-agent pipeline.

**What it got wrong:**
1. Assumed `kubectl` and network access to the Minikube cluster would already
   be available inside the Jenkins build container - they weren't. The build
   container is a separate, ephemeral `node:18.20.4-alpine` container that
   doesn't share the host's tooling or network by default.
2. The first version of the deploy stage referenced a fabricated image tag
   (`${ARTIFACT_VERSION}`, built from the git commit) that was never actually
   built or pushed to any container registry - only an npm package is
   published by this pipeline. This caused `ImagePullBackOff` in the staging
   pod.

**What was changed:** Added a `--network=minikube` flag to the pipeline's
Docker agent, added a `kubectl` install step at the start of the deploy
stage, and replaced the fabricated image tag with the known-working,
already-published image tag (`1.4.0-d9f5edc`).

**Verification:** Ran the pipeline five times end-to-end in Jenkins,
inspecting the console output and `kubectl get pods` / `kubectl describe pod`
at each failure until the full pipeline (Lint through Deploy to Production)
completed successfully with the approval gate functioning and recording an
approval reason.

**Governance checklist item referenced:** Control #5, Auditability and
logging. The `APPROVAL_REASON` field on the Jenkins input step directly
implements Nia's requirement that "the audit trail must show who approved
it and when" - Jenkins records the approving user, timestamp, and stated
reason in the build log for every production deployment.

---

## Entry 2: Terraform + Ansible staging namespace

**Date:** 2026-08-16
**Tool:** Claude (chat)
**Task:** Provision the `kijani-staging` Kubernetes namespace via Terraform,
configured by Ansible.

**What it produced:** A `kubernetes_namespace` Terraform resource and an
Ansible playbook to patch a `managed-by: ansible` label onto it.

**What it got wrong:** The first `git push` after running `terraform apply`
included the `.terraform/` provider cache and `terraform.tfstate` file,
adding a 52MB binary to the repository and triggering a GitHub large-file
warning. Terraform state files can also contain sensitive data, which
shouldn't be committed.

**What was changed:** Added a `.gitignore` scoped to the Terraform directory
excluding `.terraform/`, `terraform.tfstate`, and `*.tfvars`, then removed
the already-committed files from git tracking with `git rm --cached`.

**Verification:** Confirmed via `kubectl get namespace kijani-staging
--show-labels` that both the Terraform-applied labels and the
Ansible-applied label were present, and confirmed via `git log` that the
state file and provider binary no longer appear in tracked files going
forward.

**Governance checklist item referenced:** Control #3, No hardcoded secrets.
Not a hardcoded secret in the literal sense, but the same underlying risk:
a Terraform state file can contain sensitive values (resource IDs,
occasionally secrets depending on the resource type), and committing it
to a public-facing repository is the same class of exposure this control
is meant to prevent.

---

## Entry 3: Prometheus alert rule

**Date:** 2026-08-16
**Tool:** Claude (chat)
**Task:** Add a Prometheus alert rule firing on a meaningful kk-payments
health signal (pod restart count).

**What it produced:** A `PrometheusRule` manifest (`KkPaymentsHighRestartRate`)
and the `kube-prometheus-stack` Helm install commands to stand up Prometheus
from scratch.

**What it got wrong:** Did not anticipate that the Prometheus container
image pull would stall partway through (`context canceled`) on first
install, which briefly looked like a permissions or registry issue rather
than a transient network interruption.

**What was changed:** No code change was needed - the pod recovered on its
own after Kubernetes retried the pull. Confirmed this before assuming
anything was broken.

**Verification:** Queried the running Prometheus instance's `/api/v1/rules`
endpoint directly and confirmed `KkPaymentsHighRestartRate` was loaded with
`"health":"ok"`, rather than only trusting that the `kubectl apply` command
succeeded.

**Governance checklist item referenced:** None of the six controls apply
cleanly here - this was an infrastructure availability issue (a slow image
pull), not an AI-generated governance gap. Included for completeness and
honesty rather than forced into a category it doesn't fit.
