# Production Readiness Assessment: kk-payments / kk-api

## External routing

The current Ingress is not production-ready as configured: it terminates HTTP only, with no TLS. That means kk-payments' credentials (card details, `STRIPE_API_KEY` calls, session tokens) cross the network in plaintext between the client and the Ingress controller. Anyone positioned on the network path, whether that's a compromised router, a shared Wi-Fi network, or a malicious proxy, can read or alter that traffic. To close this, I'd add a `tls:` block to the Ingress spec referencing a TLS Secret (`kubernetes.io/tls` type, containing the cert and key), and use the `cert-manager.io/cluster-issuer` annotation with cert-manager installed so certificates are issued and renewed automatically rather than managed by hand.

Beyond TLS, the Ingress has no rate limiting. A payment endpoint with no request cap is exposed to both accidental retry storms and deliberate abuse, like card-testing fraud or credential stuffing. The `nginx.ingress.kubernetes.io/limit-rps` annotation would cap requests per second per client IP at the Ingress layer, before load even reaches the pods.

## Health signalling

The current probe values (readiness: 5s delay, 10s period, 3 failures; liveness: 15s delay, 20s period, 3 failures) are tuned for a fast-starting stand-in container, not a real payment service. A real kk-payments instance likely needs to open a DB connection pool and validate its Stripe API key on startup, both of which can take longer than 5 to 15 seconds under load, especially during a cold start after a node restart. I'd raise `initialDelaySeconds` on both probes based on measured real startup time, and likely widen `periodSeconds` slightly to avoid probing during setup.

The bigger risk is `failureThreshold: 3` on a 10s period. That's only 30 seconds before Kubernetes pulls a pod's endpoint. If the database has a brief failover or connection pool exhaustion under load (exactly the conditions end-of-month traffic spikes create), healthy pods could get yanked from rotation simultaneously, shrinking capacity right when it's needed most, and potentially cascading into the liveness probe restarting pods that just needed a few more seconds to recover.

## Capacity

Three replicas with manual scaling is not sufficient for load spikes. Someone has to notice the spike and act before capacity catches up, which is too slow for a payment path. Making autoscaling viable requires metrics-server running in the cluster (already needed for HPA to read CPU metrics), the resource requests already defined in the Deployment (present here), and an HPA object targeting `kk-payments` with a defined min/max replica range and target CPU percentage.

The target percentage matters more than it looks. Set it too high, say 90%, and pods are already saturated, with queuing and slow responses, before new pods finish scheduling and passing readiness, so users feel the spike before the fix arrives. Set it too low, say 20%, and the HPA scales up on routine traffic noise, over-provisioning constantly and potentially flapping between scale-up and scale-down, which is wasteful and can itself destabilize a service under real load.
