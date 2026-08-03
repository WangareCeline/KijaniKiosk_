# kk-payments: Service Level Indicators and Objectives

## Purpose

This document defines how we measure the health of kk-payments in production, what "healthy" means as a number, and the thresholds that trigger an automated rollback. It is the specification for what we would build against production traffic. Where a target is based on staging or simulator data rather than real production traffic, it is labeled **proposed target** and should be re-validated once live traffic is flowing.

---

## SLI 1: Availability

**What it measures:** The percentage of health check requests that receive a successful response from the active environment.

**Data source:** The `/health` endpoint on the active blue or green service, polled by the deployment monitor.

**Calculation method:** `(successful health checks / total health checks) × 100`, over the measurement window. A successful check is an HTTP response received within 2 seconds with `status: ok` in the body.

**Measurement window:** 30 days, rolling.

**SLO target:** 99.5% availability over 30 days (proposed target — based on staging measurements, not yet validated against production traffic volume).

---

## SLI 2: Latency

**What it measures:** How long the `/health` endpoint takes to respond, as a proxy for overall service responsiveness.

**Data source:** Response time recorded by the monitor on each poll, or nginx access log `$request_time` field in a production deployment.

**Calculation method:** 95th percentile (p95) response time across all requests in the window. p95 is used instead of average because averages hide the slow outliers that actually affect users.

**Measurement window:** 30 days, rolling.

**SLO target:** p95 under 300ms (proposed target — staging runs on a single low-resource VM, so this number will need re-baselining once running on production-scale infrastructure).

---

## SLI 3: Payment Error Rate

**What it measures:** The percentage of payment-related requests that fail with a server error (5xx) or a payment-specific failure response.

**Data source:** Application logs or nginx access logs, filtered to payment endpoints. In the current staging setup, this is simulated using the health check as a stand-in signal, since no real payment traffic exists yet.

**Calculation method:** `(failed payment requests / total payment requests) × 100`, over the measurement window.

**Measurement window:** 30 days, rolling.

**SLO target:** Under 0.1% error rate (proposed target — this is the tightest of the three SLOs because payment failures have direct financial and trust consequences, unlike a slow page load).

---

## Rollback Threshold Table

The SLO targets above are 30-day commitments. The rollback thresholds below are short-window triggers, deliberately much stricter, because a rollback decision has to be made in seconds, not over a month.

| SLI | Rollback threshold (short window) | Relationship to SLO target |
|---|---|---|
| Availability | 2 consecutive failed health checks within a 10-second window (current monitor: 5s poll interval, 2-check threshold) | Far stricter than the 99.5%/30-day target. A single short outage is invisible in a 30-day average but must still trigger an immediate response, because it is the leading signal of a bad deployment. |
| Latency | Health check response exceeding 2 seconds (effectively a timeout, not a p95 measurement) | The 300ms p95 target is a steady-state expectation; the rollback threshold is a hard ceiling that indicates the service is failing, not just slow. |
| Payment error rate | Not currently implemented as an automated rollback trigger in staging | This is a gap, not a design choice — see exclusions below. |

**Why the thresholds are stricter than the SLOs:** an SLO is a target measured over time; a rollback threshold is a tripwire measured over seconds. The rollback threshold exists to catch the failure before it accumulates enough bad requests to threaten the SLO at all.

---

## What We Do Not Commit To

- **Payment error rate as an automated rollback trigger.** The current monitor only checks the `/health` endpoint, not actual payment transaction outcomes. A deployment could pass every health check while still silently failing payments (for example, a broken connection to a payment processor that doesn't affect the health endpoint). Closing this gap requires the monitor to poll a payment-specific test transaction, which is not yet built.

- **Client-side or network latency.** The latency SLI measures server response time only, from the monitor's vantage point on the same machine. It does not account for a real user's network conditions, mobile connectivity, or DNS resolution time. A user could experience a slow payment flow even when every server-side number looks healthy.
