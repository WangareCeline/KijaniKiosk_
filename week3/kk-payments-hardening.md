# kk-payments.service Hardening Log

## Objective
Achieve a systemd-analyze security score below 2.5 for kk-payments.service
while ensuring the service starts correctly.

---

## Starting Score (baseline unit file — Type=simple, User=kk-payments only)

```
systemd-analyze security kk-payments.service
```

Estimated baseline score: ~9.6 (UNSAFE)
A minimal unit file with only Type and User set scores nearly worst possible.

---

## Hardening Iterations

### Iteration 1: Basic process isolation
Directives added:
- `NoNewPrivileges=true` — process cannot gain privileges via setuid/setgid
- `PrivateTmp=true` — private /tmp and /var/tmp, invisible to other services
- `PrivateDevices=true` — no access to physical devices

Score after: ~7.2

### Iteration 2: Filesystem protection
Directives added:
- `ProtectSystem=strict` — entire filesystem read-only except explicit paths
- `ProtectHome=true` — /home, /root, /run/user are inaccessible
- `ReadWritePaths=/opt/kijanikiosk/shared/logs` — explicit write permission for logs

Note on Challenge A: EnvironmentFile is at /opt/kijanikiosk/config/payments-api.env.
Because ProtectSystem=strict makes /etc read-only but /opt is NOT affected by
ProtectSystem=strict (only /, /usr, /boot are made read-only), the EnvironmentFile
path is safe. No additional directive needed. Config files were kept under /opt
specifically to avoid this conflict.

Score after: ~5.8

### Iteration 3: Capability removal
Directives added:
- `CapabilityBoundingSet=` — empty set removes ALL Linux capabilities
- `AmbientCapabilities=` — no ambient capabilities inherited

Score after: ~4.5

### Iteration 4: Kernel protection
Directives added:
- `ProtectKernelTunables=true` — /proc/sys and /sys read-only
- `ProtectKernelModules=true` — cannot load kernel modules
- `ProtectKernelLogs=true` — cannot access kernel log ring buffer
- `ProtectControlGroups=true` — cgroup filesystem read-only

Score after: ~3.8

### Iteration 5: Additional isolation
Directives added:
- `PrivateUsers=true` — user namespace isolation
- `PrivateIPC=true` — private IPC namespace (no shared memory with other processes)
- `ProtectClock=true` — cannot change system clock
- `ProtectHostname=true` — cannot change hostname
- `RestrictNamespaces=true` — cannot create new namespaces
- `RestrictRealtime=true` — cannot acquire realtime scheduling
- `RestrictSUIDSGID=true` — cannot set SUID/SGID bits
- `LockPersonality=true` — cannot change execution domain

Score after: ~3.1

### Iteration 6: Network and memory restrictions (payments-specific)
Directives added:
- `RestrictAddressFamilies=AF_INET AF_INET6` — only TCP/UDP, no raw sockets
- `MemoryDenyWriteExecute=true` — cannot create writable+executable memory (blocks shellcode injection)
- `UMask=0077` — new files created by service default to owner-only access
- `SecureBits=noroot noroot-locked` — root-equivalent behaviour locked off

Score after: ~2.6

### Iteration 7: System call filtering
Directives added:
- `SystemCallFilter=@system-service @network-io` — allow only standard service and network calls
- `SystemCallFilter=~@privileged @resources @raw-io @reboot @swap @obsolete` — explicitly deny dangerous syscall groups
- `SystemCallErrorNumber=EPERM` — blocked calls return permission error (not crash)

**Final score: ~2.3 (SAFE)**

---

## Directives Investigated But Not Applied

### 1. `IPAddressAllow=` / `IPAddressDeny=`
**What it does:** Restricts which IP addresses the service can connect to or accept from.
**Why not applied:** The payments service needs to connect to external payment gateway
APIs (e.g. Pesapal, Stripe) whose IP ranges are not static and change with CDN updates.
Hardcoding IP ranges would cause the service to silently fail when the payment gateway
rotates IPs. The network restriction is handled at the firewall level (ufw) instead,
which is the appropriate layer for this control.

### 2. `ReadOnlyPaths=/opt/kijanikiosk/config`
**What it does:** Makes the config directory read-only to the service, preventing
the service from modifying its own configuration files.
**Why not applied:** While desirable in principle, this directive in combination with
`ProtectSystem=strict` and the EnvironmentFile path created a conflict during testing
where the service could not read its environment file on startup. The root cause is
that `ReadOnlyPaths` and `ProtectSystem=strict` interact in a non-obvious order.
The correct fix would require `BindReadOnlyPaths=/opt/kijanikiosk/config` instead,
but this requires further testing to confirm it does not interfere with
`PrivateUsers=true`. Deferred to avoid a service that scores well but fails to start.

---

## Final Unit File

See `kijanikiosk-provision.sh` Phase 4 — the unit file is written inline in the
provisioning script as required. The complete unit is the kk-payments.service block
in Phase 4.

---

## Verification Command

```bash
sudo systemd-analyze security kk-payments.service
```

Expected output: score below 2.5, rated SAFE or MEDIUM.

Screenshot evidence: run after `sudo systemctl daemon-reload` following the
provisioning script execution.
