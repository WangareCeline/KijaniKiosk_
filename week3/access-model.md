# KijaniKiosk Access Model — Final

**Updated:** 25 June 2026  
**Sprint:** Week 3 Production Foundation  
**Changes from Tuesday:** Added /health directory; added logrotate interaction notes

---

## Service Accounts

| Account | UID | Primary Group | Shell | Purpose |
|---|---|---|---|---|
| kk-api | 999 | kijanikiosk | /usr/sbin/nologin | Runs the API service |
| kk-payments | 997 | kijanikiosk | /usr/sbin/nologin | Runs the payments service |
| kk-logs | 994 | kijanikiosk | /usr/sbin/nologin | Runs the log aggregation service |

All accounts: no login shell, no home directory access, no sudo rights.

---

## Directory Access Model

### /opt/kijanikiosk/ (base)
- Owner: root:kijanikiosk
- Mode: 750
- Who can access: root (full), kijanikiosk group members (read+execute/traverse)

### /opt/kijanikiosk/config/
- Owner: root:kijanikiosk
- Mode: 750
- Who can access: root (full), kijanikiosk group members (read+traverse)
- **Was 777 in dirty state — fixed by provisioning script**

Individual environment files:

| File | Owner | Mode | Readable by |
|---|---|---|---|
| api.env | root:kk-api | 640 | kk-api only |
| payments-api.env | root:kk-payments | 640 | kk-payments only |
| logs.env | root:kk-logs | 640 | kk-logs only |

### /opt/kijanikiosk/shared/logs/
- Owner: kk-logs:kijanikiosk
- Mode: 770
- ACLs:
  - u:kk-api:rwx (writes log entries)
  - u:kk-payments:rx (reads for audit correlation)
  - u:kk-logs:rwx (manages log files)
- **Default ACLs (propagate to new files on creation):**
  - d:u:kk-api:rw
  - d:u:kk-payments:r
  - d:u:kk-logs:rw
  - d:g:kijanikiosk:r

**Logrotate interaction:** When logrotate rotates a log file, it creates a new
empty file using the `create 0640 kk-logs kijanikiosk` directive. The new file
gets standard ownership (kk-logs:kijanikiosk, mode 0640). The default ACLs on
the directory then propagate automatically to the new file, meaning kk-api can
resume writing immediately after rotation without any manual permission fix.

Verified with: `sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp`
run after `sudo logrotate --force /etc/logrotate.d/kijanikiosk`

### /opt/kijanikiosk/health/ (NEW — added this sprint)
- Owner: root:kijanikiosk
- Mode: 750
- ACL: g:kijanikiosk:rx
- Who writes: root (provisioning script only)
- Who reads: all kijanikiosk group members (kk-api, kk-payments, kk-logs, monitoring)

| File | Owner | Mode | Readable by |
|---|---|---|---|
| last-provision.json | root:kijanikiosk | 640 | kijanikiosk group |

**Rationale:** The health directory has a single writer (root/provisioning) and
multiple readers. The simpler 750 + group ACL model is sufficient and more
auditable than the full per-user ACL model used for shared/logs.

---

## What the Access Model Prevents

- kk-payments cannot write to kk-api's log files (no write ACL)
- kk-api cannot read payments configuration (payments-api.env owned by kk-payments)
- No service account can log in interactively (nologin shell)
- No service account can read other services' environment files
- External users cannot read /opt/kijanikiosk/ without being in the kijanikiosk group
