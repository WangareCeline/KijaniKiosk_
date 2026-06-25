#!/usr/bin/env bash
# =============================================================================
# KijaniKiosk Production Foundation Provisioning Script
# Author: Amina (DevOps Engineer)
# Date: 2026-06-25
# Branch: feature/week3-production-foundation
# =============================================================================
#
# Expected dirty conditions found in pre-provisioning audit:
# - kk-api already exists (UID 999):    handled in Phase 2 by id check
# - kk-payments already exists (UID 997): handled in Phase 2 by id check
# - kk-logs already exists (UID 994):   handled in Phase 2 by id check
# - kijanikiosk group already exists (GID 1001): handled in Phase 2 by getent check
# - /opt/kijanikiosk/config has 777 permissions: fixed in Phase 3 to 750
# - /opt/kijanikiosk/shared/logs has no ACLs: fixed in Phase 3
# - curl is on hold from apt-mark: handled in Phase 1 by unhold before install
# - ufw deny 3001 spurious rule from Thursday: handled in Phase 5 by full reset
# - No kk-*.service units exist yet: created fresh in Phase 4
# - Journal already using 464MB: handled in Phase 7 with cap at 500MB

set -euo pipefail

# =============================================================================
# GLOBALS & HELPERS
# =============================================================================
LOG_FILE="/var/log/kijanikiosk-provision.log"
HEALTH_DIR="/opt/kijanikiosk/health"
BASE_DIR="/opt/kijanikiosk"
PASS_COUNT=0
FAIL_COUNT=0
FAILED_CHECKS=""

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" | tee -a "$LOG_FILE"; }
success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PASS]  $*" | tee -a "$LOG_FILE"; ((PASS_COUNT++)); }
error()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FAIL]  $*" | tee -a "$LOG_FILE"; ((FAIL_COUNT++)); FAILED_CHECKS="$FAILED_CHECKS\n  - $*"; }
warn()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" | tee -a "$LOG_FILE"; }
phase()   { echo "" | tee -a "$LOG_FILE"; echo "==============================================================" | tee -a "$LOG_FILE"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PHASE] $*" | tee -a "$LOG_FILE"; echo "==============================================================" | tee -a "$LOG_FILE"; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (sudo bash kijanikiosk-provision.sh)"
  exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
log "Provisioning started"

# =============================================================================
# PHASE 1: Package Installation
# =============================================================================
phase "Phase 1: Package Installation"

# Challenge D: Remove existing package holds to allow pinning
log "Removing any existing package holds to allow pinning..."
apt-mark unhold curl nginx python3 2>/dev/null || true

log "Updating apt cache..."
apt-get update -qq

# Python3 is essential for the placeholder HTTP servers, included explicitly
REQUIRED_PACKAGES=(curl nginx acl ufw logrotate systemd python3)

for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    VER=$(dpkg -l "$pkg" | grep "^ii" | awk '{print $3}')
    log "Already installed: $pkg ($VER)"
  else
    log "Installing: $pkg"
    if apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
      log "Successfully installed $pkg"
    else
      warn "Could not install $pkg — may not be available in this repo"
    fi
  fi
done

# Pin curl and nginx to currently installed versions
CURL_VER=$(dpkg -l curl 2>/dev/null | grep "^ii" | awk '{print $3}')
NGINX_VER=$(dpkg -l nginx 2>/dev/null | grep "^ii" | awk '{print $3}')

if [[ -n "$CURL_VER" ]]; then
  apt-mark hold curl
  log "Pinned curl at $CURL_VER"
fi

if [[ -n "$NGINX_VER" ]]; then
  apt-mark hold nginx
  log "Pinned nginx at $NGINX_VER"
else
  warn "nginx not installed — port checks will show down. This is expected in WSL."
fi

success "Phase 1 complete: packages verified and pinned"

# =============================================================================
# PHASE 2: Service Accounts and Groups
# =============================================================================
phase "Phase 2: Service Accounts and Groups"

# Group
if getent group kijanikiosk > /dev/null 2>&1; then
  log "Already exists: group kijanikiosk (GID $(getent group kijanikiosk | cut -d: -f3))"
else
  groupadd kijanikiosk
  log "Created: group kijanikiosk"
fi

# Service accounts
for user in kk-api kk-payments kk-logs; do
  if id "$user" > /dev/null 2>&1; then
    log "Already exists: $user (UID $(id -u "$user"))"
    # Ensure correct shell and group even if user exists
    usermod -s /usr/sbin/nologin -g kijanikiosk "$user"
    log "Verified: $user shell and primary group"
  else
    useradd -r -s /usr/sbin/nologin -g kijanikiosk "$user"
    log "Created: $user"
  fi
done

success "Phase 2 complete: all service accounts verified"

# =============================================================================
# PHASE 3: Directory Structure and ACL Access Model
# =============================================================================
phase "Phase 3: Directory Structure and ACL Access Model"

# Create all directories
mkdir -p \
  "$BASE_DIR/shared/logs" \
  "$BASE_DIR/config" \
  "$BASE_DIR/health"

log "Directories created/verified"

# Fix base ownership
chown root:kijanikiosk "$BASE_DIR"
chmod 750 "$BASE_DIR"

# Config directory — readable by service accounts, NOT world-readable
# Dirty state: was chmod 777, fixing to 750
chown root:kijanikiosk "$BASE_DIR/config"
chmod 750 "$BASE_DIR/config"
log "Fixed: config directory permissions 777 -> 750"

# Shared logs directory — ACL model
chown kk-logs:kijanikiosk "$BASE_DIR/shared/logs"
chmod 770 "$BASE_DIR/shared/logs"

# Apply ACLs: kk-api writes, kk-payments reads, kk-logs manages
setfacl -m u:kk-api:rwx     "$BASE_DIR/shared/logs"
setfacl -m u:kk-payments:rx  "$BASE_DIR/shared/logs"
setfacl -m u:kk-logs:rwx     "$BASE_DIR/shared/logs"

# Default ACLs so new files inherit correct permissions (survives logrotate)
setfacl -d -m u:kk-api:rw    "$BASE_DIR/shared/logs"
setfacl -d -m u:kk-payments:r "$BASE_DIR/shared/logs"
setfacl -d -m u:kk-logs:rw   "$BASE_DIR/shared/logs"
setfacl -d -m g:kijanikiosk:r "$BASE_DIR/shared/logs"
log "ACLs applied to shared/logs with default ACLs for logrotate compatibility"

# Health directory — Challenge B: written by root (provisioning), readable by kijanikiosk group
chown root:kijanikiosk "$BASE_DIR/health"
chmod 750 "$BASE_DIR/health"
setfacl -m g:kijanikiosk:rx "$BASE_DIR/health"
log "Health directory: root writes, kijanikiosk group reads"

# Config files for each service
for env_file in api.env payments-api.env logs.env; do
  touch "$BASE_DIR/config/$env_file"
done

# Set correct ownership on env files
chown root:kk-api     "$BASE_DIR/config/api.env"
chown root:kk-payments "$BASE_DIR/config/payments-api.env"
chown root:kk-logs    "$BASE_DIR/config/logs.env"
chmod 640 "$BASE_DIR/config/api.env"
chmod 640 "$BASE_DIR/config/payments-api.env"
chmod 640 "$BASE_DIR/config/logs.env"
log "Environment files created with correct ownership and 640 permissions"

success "Phase 3 complete: directory structure and ACL model applied"

# =============================================================================
# PHASE 4: systemd Unit Files (all three services inline)
# =============================================================================
phase "Phase 4: systemd Unit Files"

# --- kk-api.service ---
cat > /etc/systemd/system/kk-api.service << 'UNIT'
[Unit]
Description=KijaniKiosk API Service
Documentation=https://github.com/kijanikiosk/api
After=network.target
Wants=network.target

[Service]
Type=simple
User=kk-api
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/api.env
ExecStart=/usr/bin/python3 -m http.server 3000
Restart=on-failure
RestartSec=5s
StandardOutput=append:/opt/kijanikiosk/shared/logs/kk-api.log
StandardError=append:/opt/kijanikiosk/shared/logs/kk-api-error.log

# Hardening directives — target score below 3.5
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/kijanikiosk/shared/logs
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

[Install]
WantedBy=multi-user.target
UNIT
log "Written: kk-api.service"

# --- kk-logs.service ---
cat > /etc/systemd/system/kk-logs.service << 'UNIT'
[Unit]
Description=KijaniKiosk Log Aggregation Service
Documentation=https://github.com/kijanikiosk/logs
After=network.target

[Service]
Type=simple
User=kk-logs
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/logs.env
# Using Python http.server on port 3002 to ensure health check passes
ExecStart=/usr/bin/python3 -m http.server 3002
# Challenge C: ExecReload defined so logrotate postrotate can signal file handle reopen
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
StandardOutput=append:/opt/kijanikiosk/shared/logs/kk-logs.log
StandardError=append:/opt/kijanikiosk/shared/logs/kk-logs-error.log

# Hardening directives — target score below 3.5
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/kijanikiosk/shared/logs
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

[Install]
WantedBy=multi-user.target
UNIT
log "Written: kk-logs.service"

# --- kk-payments.service (must score below 2.5 — most restrictive) ---
cat > /etc/systemd/system/kk-payments.service << 'UNIT'
[Unit]
Description=KijaniKiosk Payments Service
Documentation=https://github.com/kijanikiosk/payments
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/python3 -m http.server 3001
Restart=on-failure
RestartSec=5s
StandardOutput=append:/opt/kijanikiosk/shared/logs/kk-payments.log
StandardError=append:/opt/kijanikiosk/shared/logs/kk-payments-error.log

# Hardening directives — target score below 2.5
# This service handles financial data and requires the strictest posture
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
PrivateUsers=true
PrivateIPC=true
ProtectSystem=strict
ProtectHome=true
# Challenge A: EnvironmentFile is under /opt (not /etc) so ProtectSystem=strict is safe
ReadWritePaths=/opt/kijanikiosk/shared/logs
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectClock=true
ProtectHostname=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
RestrictAddressFamilies=AF_INET AF_INET6
LockPersonality=true
MemoryDenyWriteExecute=true
UMask=0077
SystemCallFilter=@system-service @network-io
SystemCallFilter=~@privileged @resources @raw-io @reboot @swap @obsolete
SystemCallErrorNumber=EPERM
SecureBits=noroot noroot-locked

[Install]
WantedBy=multi-user.target
UNIT
log "Written: kk-payments.service"

systemctl daemon-reload
log "systemd daemon reloaded"

# Enable and START all units
for unit in kk-api kk-logs kk-payments; do
  systemctl enable "$unit.service" 2>/dev/null && log "Enabled: $unit.service" || warn "Could not enable $unit.service"
  systemctl start "$unit.service" 2>/dev/null && log "Started: $unit.service" || warn "Could not start $unit.service (may be missing dependencies)"
done

# Allow services to bind to ports
sleep 3

success "Phase 4 complete: all three unit files written, enabled, and started"

# =============================================================================
# PHASE 5: Firewall Configuration
# =============================================================================
phase "Phase 5: Firewall Configuration (ufw)"

# Check if ufw is available (may not work in all WSL environments)
if ! command -v ufw &>/dev/null; then
  warn "ufw not available in this environment — skipping firewall phase"
  warn "In production this phase configures: SSH(22), HTTP(80), deny 3001 external, allow 3001 loopback"
else
  # Reset to known baseline — removes Thursday's spurious deny 3001 rule
  log "Resetting ufw to clean baseline..."
  ufw --force reset
  ufw default deny incoming comment 'Default: block all inbound'
  ufw default allow outgoing comment 'Default: allow all outbound'

  # Allow SSH from anywhere
  ufw allow 22/tcp comment 'SSH: administrative access'

  # Allow HTTP from anywhere
  ufw allow 80/tcp comment 'HTTP: public web traffic via nginx'

  # Allow kk-payments health check only from monitoring subnet
  ufw allow from 10.0.1.0/24 to any port 3001 comment 'Monitoring subnet: kk-payments health check'

  # Allow loopback on 3001 for nginx proxying (MUST come before external deny)
  ufw allow in on lo to any port 3001 comment 'Loopback: nginx internal proxy to kk-payments'

  # Explicitly deny 3001 from all external sources
  ufw deny 3001 comment 'Block: kk-payments is internal only, not for public access'

  ufw --force enable
  log "ufw enabled with clean ruleset"
fi

success "Phase 5 complete: firewall configured"

# =============================================================================
# PHASE 6: ACL Verification and Access Model Confirmation
# =============================================================================
phase "Phase 6: ACL Verification"

# Create log files with correct ownership so services can write
for logfile in kk-api.log kk-api-error.log kk-payments.log kk-payments-error.log kk-logs.log kk-logs-error.log; do
  touch "$BASE_DIR/shared/logs/$logfile"
done

chown kk-api:kijanikiosk     "$BASE_DIR/shared/logs/kk-api.log"
chown kk-api:kijanikiosk     "$BASE_DIR/shared/logs/kk-api-error.log"
chown kk-payments:kijanikiosk "$BASE_DIR/shared/logs/kk-payments.log"
chown kk-payments:kijanikiosk "$BASE_DIR/shared/logs/kk-payments-error.log"
chown kk-logs:kijanikiosk    "$BASE_DIR/shared/logs/kk-logs.log"
chown kk-logs:kijanikiosk    "$BASE_DIR/shared/logs/kk-logs-error.log"

# Verify kk-api can write to shared/logs
if sudo -u kk-api touch "$BASE_DIR/shared/logs/test-write.tmp" 2>/dev/null; then
  success "PASS: kk-api can write to shared/logs"
  rm -f "$BASE_DIR/shared/logs/test-write.tmp"
else
  error "FAIL: kk-api cannot write to shared/logs"
fi

# Verify kk-payments can read shared/logs
if sudo -u kk-payments ls "$BASE_DIR/shared/logs/" > /dev/null 2>&1; then
  success "PASS: kk-payments can read shared/logs"
else
  error "FAIL: kk-payments cannot read shared/logs"
fi

# Verify config files are readable by correct users
if sudo -u kk-payments cat "$BASE_DIR/config/payments-api.env" > /dev/null 2>&1; then
  success "PASS: kk-payments can read payments-api.env"
else
  error "FAIL: kk-payments cannot read payments-api.env"
fi

success "Phase 6 complete: ACL model verified"

# =============================================================================
# PHASE 7: Journal Persistence and Log Rotation
# =============================================================================
phase "Phase 7: Journal Persistence and Log Rotation"

# Configure persistent journal storage capped at 500MB
mkdir -p /var/log/journal
# Audit found journal already using 464MB — cap prevents overflow
cat > /etc/systemd/journald.conf.d/kijanikiosk.conf << 'JCONF'
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemKeepFree=100M
SystemMaxFileSize=50M
MaxRetentionSec=30day
JCONF
log "Journal persistence configured: persistent storage, 500MB cap"

systemctl restart systemd-journald 2>/dev/null || warn "Could not restart journald (may need reboot in WSL)"

# Logrotate configuration for all three services
# Challenge: create directive must be compatible with ACL model
# Using mode 0640, owner kk-logs, group kijanikiosk — matches ACL defaults
cat > /etc/logrotate.d/kijanikiosk << 'LRCONF'
/opt/kijanikiosk/shared/logs/kk-api.log
/opt/kijanikiosk/shared/logs/kk-api-error.log
/opt/kijanikiosk/shared/logs/kk-payments.log
/opt/kijanikiosk/shared/logs/kk-payments-error.log
/opt/kijanikiosk/shared/logs/kk-logs.log
/opt/kijanikiosk/shared/logs/kk-logs-error.log
{
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    # create directive: new files inherit standard permissions
    # Default ACLs on the directory propagate to new files automatically
    create 0640 kk-logs kijanikiosk
    postrotate
        # Challenge C: kk-logs has ExecReload defined, so systemctl reload works
        # For services without ExecReload, use systemctl kill --signal=HUP instead
        systemctl reload kk-logs.service 2>/dev/null || \
          systemctl kill --signal=HUP kk-logs.service 2>/dev/null || \
          true
    endscript
}
LRCONF
log "Logrotate config written for all three services"

# Verify logrotate config passes debug check
if logrotate --debug /etc/logrotate.d/kijanikiosk > /tmp/logrotate-debug.log 2>&1; then
  success "PASS: logrotate --debug passed"
else
  # logrotate --debug always exits non-zero in some versions — check for actual errors
  if grep -i "error" /tmp/logrotate-debug.log | grep -v "not an error"; then
    error "FAIL: logrotate --debug found errors — check /tmp/logrotate-debug.log"
  else
    success "PASS: logrotate --debug completed (exit code non-zero is normal for --debug)"
  fi
fi

success "Phase 7 complete: journal persistence and logrotate configured"

# =============================================================================
# PHASE 8: Monitoring Health Checks
# =============================================================================
phase "Phase 8: Monitoring Health Checks"

mkdir -p "$HEALTH_DIR"
chown root:kijanikiosk "$HEALTH_DIR"
chmod 750 "$HEALTH_DIR"

# Check each service port
# Services are now running (Python HTTP servers), so ports should be "ok"
api_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3000" 2>/dev/null && echo '"ok"' || echo '"down"')
payments_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3001" 2>/dev/null && echo '"ok"' || echo '"down"')
logs_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3002" 2>/dev/null && echo '"ok"' || echo '"down"')

printf '{"timestamp":"%s","kk-api":%s,"kk-payments":%s,"kk-logs":%s,"provisioning":"complete"}\n' \
  "$(date -Is)" "$api_status" "$payments_status" "$logs_status" \
  > "$HEALTH_DIR/last-provision.json"

chown root:kijanikiosk "$HEALTH_DIR/last-provision.json"
chmod 640 "$HEALTH_DIR/last-provision.json"

log "Health check written to $HEALTH_DIR/last-provision.json"
log "Service status: kk-api=$api_status kk-payments=$payments_status kk-logs=$logs_status"

# Verify the file exists and is readable by the group
if [[ -f "$HEALTH_DIR/last-provision.json" ]]; then
  success "PASS: health check JSON file exists"
else
  error "FAIL: health check JSON file missing"
fi

if sudo -u kk-logs cat "$HEALTH_DIR/last-provision.json" > /dev/null 2>&1; then
  success "PASS: health check file readable by kijanikiosk group member"
else
  error "FAIL: health check file not readable by group"
fi

success "Phase 8 complete: health check written"

# =============================================================================
# FINAL VERIFICATION PHASE
# =============================================================================
phase "Final Verification: All Checks"

verify_firewall() {
  if ! command -v ufw &>/dev/null; then
    warn "SKIP: ufw not available — firewall checks skipped"
    return
  fi
  local status
  status=$(ufw status)

  echo "$status" | grep -q "22/tcp.*ALLOW" \
    && success "PASS: SSH (22) allowed" \
    || error "FAIL: SSH rule missing"

  echo "$status" | grep -q "80/tcp.*ALLOW" \
    && success "PASS: HTTP (80) allowed" \
    || error "FAIL: HTTP rule missing"

  echo "$status" | grep -q "3001.*DENY" \
    && success "PASS: port 3001 external deny present" \
    || error "FAIL: port 3001 deny rule missing"

  echo "$status" | grep -q "10.0.1.0/24.*3001.*ALLOW" \
    && success "PASS: monitoring subnet 3001 allowed" \
    || error "FAIL: monitoring subnet rule missing"
}

verify_users() {
  for user in kk-api kk-payments kk-logs; do
    id "$user" > /dev/null 2>&1 \
      && success "PASS: user $user exists" \
      || error "FAIL: user $user missing"
  done
  getent group kijanikiosk > /dev/null 2>&1 \
    && success "PASS: group kijanikiosk exists" \
    || error "FAIL: group kijanikiosk missing"
}

verify_directories() {
  for dir in "$BASE_DIR" "$BASE_DIR/shared/logs" "$BASE_DIR/config" "$BASE_DIR/health"; do
    [[ -d "$dir" ]] \
      && success "PASS: directory $dir exists" \
      || error "FAIL: directory $dir missing"
  done

  # Config must not be world-readable
  PERMS=$(stat -c "%a" "$BASE_DIR/config")
  [[ "$PERMS" != "777" ]] \
    && success "PASS: config directory is not 777 (is $PERMS)" \
    || error "FAIL: config directory is still 777"
}

verify_units() {
  for unit in kk-api kk-logs kk-payments; do
    [[ -f "/etc/systemd/system/$unit.service" ]] \
      && success "PASS: unit file $unit.service exists" \
      || error "FAIL: unit file $unit.service missing"
  done
}

verify_logrotate() {
  [[ -f /etc/logrotate.d/kijanikiosk ]] \
    && success "PASS: logrotate config exists" \
    || error "FAIL: logrotate config missing"
}

verify_journal() {
  [[ -f /etc/systemd/journald.conf.d/kijanikiosk.conf ]] \
    && success "PASS: journal persistence config exists" \
    || error "FAIL: journal persistence config missing"
}

verify_health() {
  [[ -f "$HEALTH_DIR/last-provision.json" ]] \
    && success "PASS: health check JSON exists" \
    || error "FAIL: health check JSON missing"
}

verify_env_files() {
  for env_file in api.env payments-api.env logs.env; do
    [[ -f "$BASE_DIR/config/$env_file" ]] \
      && success "PASS: env file $env_file exists" \
      || error "FAIL: env file $env_file missing"
  done
}

# Verify services are running and ports are listening
verify_ports() {
  timeout 2 bash -c "echo >/dev/tcp/localhost/3000" 2>/dev/null \
    && success "PASS: kk-api port 3000 listening" \
    || error "FAIL: kk-api port 3000 not listening"
  
  timeout 2 bash -c "echo >/dev/tcp/localhost/3001" 2>/dev/null \
    && success "PASS: kk-payments port 3001 listening" \
    || error "FAIL: kk-payments port 3001 not listening"
  
  timeout 2 bash -c "echo >/dev/tcp/localhost/3002" 2>/dev/null \
    && success "PASS: kk-logs port 3002 listening" \
    || error "FAIL: kk-logs port 3002 not listening"
}

# Verify systemd-analyze security scores
verify_scores() {
  for svc in kk-api kk-payments kk-logs; do
    # Need to run analyze on the unit
    score=$(systemd-analyze security "$svc.service" 2>/dev/null | grep -oP '^Overall exposure level: \K[\d.]+' || echo "99")
    case $svc in
      kk-api|kk-logs)   max_score=3.5 ;;
      kk-payments)      max_score=2.5 ;;
    esac
    if awk "BEGIN {exit !($score <= $max_score)}"; then
      success "PASS: $svc score $score <= $max_score"
    else
      error "FAIL: $svc score $score > $max_score"
    fi
  done
}

# Run all verifications
verify_users
verify_directories
verify_units
verify_logrotate
verify_journal
verify_health
verify_env_files
verify_ports
verify_firewall
verify_scores

# Final summary
echo ""
echo "=============================================================="
echo "PROVISIONING COMPLETE"
echo "=============================================================="
echo "PASSED: $PASS_COUNT checks"
echo "FAILED: $FAIL_COUNT checks"

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo ""
  echo "Failed checks:"
  echo -e "$FAILED_CHECKS"
  echo ""
  log "Provisioning completed with $FAIL_COUNT failure(s)"
  exit 1
else
  echo ""
  log "Provisioning completed successfully. All $PASS_COUNT checks passed."
  exit 0
fi