# Integration Notes: Conflict Resolutions

## Challenge A: ProtectSystem=strict and the EnvironmentFile

**What the conflict was:**
`ProtectSystem=strict` makes `/`, `/usr`, and `/boot` read-only for the service process.
The concern was whether the EnvironmentFile for kk-payments would be inaccessible.

**Options considered:**
1. Keep EnvironmentFile under `/etc/kijanikiosk/` and add `BindReadOnlyPaths=/etc/kijanikiosk` to allow reads
2. Keep EnvironmentFile under `/opt/kijanikiosk/config/` where ProtectSystem=strict does not apply
3. Use `ProtectSystem=full` instead of `strict` (weaker hardening, would not hit 2.5 target)

**What I chose:**
Option 2. The EnvironmentFile is at `/opt/kijanikiosk/config/payments-api.env`.
`ProtectSystem=strict` only enforces read-only on `/usr`, `/boot`, and the root
filesystem overlay — it does not affect `/opt`. This was confirmed by checking the
systemd documentation and verifying that `sudo -u kk-payments cat /opt/kijanikiosk/config/payments-api.env`
returns successfully.

**Why:**
Keeping config under `/opt/kijanikiosk/` is consistent with the rest of the access
model and avoids adding exceptions to the hardening config. The simpler the unit
file, the more auditable it is. No additional directive was needed.

---

## Challenge B: The Monitoring User and ACL Defaults

**What the conflict was:**
Phase 8 writes a health check JSON file to `/opt/kijanikiosk/health/`. The
provisioning script runs as root, so the file would be owned by root with default
permissions — potentially unreadable by the monitoring system or Amina's user account
without sudo.

Tuesday's access model covered `shared/logs` and `config` but did not define
ownership or ACLs for the `health` directory, which is new this sprint.

**Options considered:**
1. Own the health directory as `kk-logs:kijanikiosk` so the log service can write health data
2. Own as `root:kijanikiosk` with group read permission — provisioning writes, group reads
3. Apply ACLs matching the shared/logs model

**What I chose:**
Option 2 with a group ACL entry. The health directory is:
- Owned: `root:kijanikiosk`
- Permissions: `750` (root writes, group reads, others nothing)
- ACL: `g:kijanikiosk:rx` applied explicitly

The health check JSON file itself is:
- Owned: `root:kijanikiosk`
- Permissions: `640`

This means any member of the kijanikiosk group (kk-api, kk-payments, kk-logs,
and Amina's user if added to the group) can read the health file without sudo.
The provisioning script (root) is the only writer, which is correct — health
check state is written by the provisioning process, not by the services themselves.

**Why:**
The health directory does not need the full ACL model of shared/logs because
it has a single writer (root/provisioning) and multiple readers (group members).
The simpler 750 + group ACL is easier to audit and achieves the same outcome.

---

## Challenge C: logrotate postrotate and PrivateTmp

**What the conflict was:**
logrotate's postrotate script needs to signal kk-logs to reopen its log file
handles after rotation. The standard approach is `systemctl reload kk-logs.service`.

The concern: if kk-logs has `PrivateTmp=true` and does not define `ExecReload=`,
`systemctl reload` sends SIGHUP to the main process but the service may not handle
it correctly, causing it to continue writing to the rotated (renamed) log file
rather than the new one.

**Options considered:**
1. Add `ExecReload=/bin/kill -HUP $MAINPID` to the unit file so reload is well-defined
2. Use `systemctl kill --signal=HUP kk-logs.service` in postrotate (sends signal without requiring ExecReload)
3. Use `systemctl restart kk-logs.service` in postrotate (heavier — causes brief service interruption)
4. Use `copytruncate` in logrotate instead of create (copies log, truncates original — no signal needed)

**What I chose:**
Option 1 + Option 2 as fallback. The kk-logs unit file defines:
```
ExecReload=/bin/kill -HUP $MAINPID
```

The logrotate postrotate script uses:
```
systemctl reload kk-logs.service 2>/dev/null || \
  systemctl kill --signal=HUP kk-logs.service 2>/dev/null || \
  true
```

**Why:**
`PrivateTmp=true` does not affect the service's ability to receive signals — it
only isolates the /tmp namespace. The SIGHUP signal from systemctl reload is
delivered normally through the process signal mechanism, not through the filesystem.
Defining ExecReload in the unit makes the behaviour explicit and auditable.
The fallback to `systemctl kill --signal=HUP` handles the case where the unit
is in a state where reload is not valid. The final `|| true` prevents logrotate
from marking the rotation as failed if the service is not running.

`copytruncate` was rejected because it creates a window where log entries written
between the copy and the truncate are lost — unacceptable for a financial service's
audit log.

---

## Challenge D: The Dirty VM and Package Holds

**What the conflict was:**
When the provisioning script runs on Friday's VM, curl is already on hold from
the apt-mark hold set during dirty state simulation. If the script tries to
install or pin curl at a specific version while it is held, apt will either
refuse silently or error.

Additionally, nginx failed to install during dirty state setup (404 from the
package repository). The script cannot assume nginx is present.

**Options considered:**
1. Fail loudly if held package versions differ from expected — require manual intervention
2. Unhold all target packages before installation, then re-pin at installed version
3. Check installed version against target version; skip install if match, fail if mismatch

**What I chose:**
Option 2. The provisioning script runs `apt-mark unhold curl nginx` before any
installation step, then re-pins at whatever version is currently installed:

```bash
apt-mark unhold curl nginx 2>/dev/null || true
# ... install ...
CURL_VER=$(dpkg -l curl | grep "^ii" | awk '{print $3}')
apt-mark hold curl
```

For nginx specifically: because nginx failed to install from the repository
(404 error — package not available in this Ubuntu 26.04 repository state),
the script warns but does not fail. Port 80 health checks will show "down",
which is expected and documented.

**Why:**
Option 1 (fail loudly) was considered but rejected because the holds are
artifacts of the dirty state simulation, not genuine version conflicts. In a
real production environment, failing loudly and requiring manual intervention
would be correct if versions genuinely differed. In this context, the script
is designed to converge dirty state — so it takes ownership of the hold state
rather than refusing to proceed.

The version pinning approach (re-hold at current version) is honest: we do not
pretend to know the "right" version in advance. We declare the currently
installed version as the pinned version and prevent future drift. This is the
correct idempotent behaviour.
