# Reflection

## 1. When did I discover two requirements were in conflict?

The conflict between `ProtectSystem=strict` and the EnvironmentFile path became
apparent during Phase 4 when writing the kk-payments unit file. The hardening
requirement pushed toward `ProtectSystem=strict` to hit the 2.5 score target,
but I knew the EnvironmentFile had to be readable by the service process.

The resolution taught me something concrete: understanding *what exactly* a
directive restricts matters more than knowing the directive exists. ProtectSystem=strict
does not make all of /opt read-only — it targets /usr, /boot, and the root overlay.
I had to look it up rather than assume. The lesson is that security directives
interact with the filesystem layout, and the layout decisions made earlier in the
script (keeping config under /opt, not /etc) had downstream consequences for what
hardening was possible without additional exceptions.

## 2. One sentence rewritten for Tendo

**For Nia (in the document):**
"The payments service can only communicate over standard internet protocols — it
cannot open raw network sockets or communicate through unusual channels."

**For Tendo:**
"`RestrictAddressFamilies=AF_INET AF_INET6` eliminates raw socket access and
prohibits AF_UNIX, AF_PACKET, and AF_NETLINK, which removes a significant class
of local privilege escalation and covert channel vectors."

**What is lost in translation to Nia's version:** Precision. The technical version
names exactly which address families are blocked and why each matters. A security
auditor reading the technical version knows immediately what was tested.

**What is gained:** Accessibility. Nia does not need to know what AF_PACKET is
to understand that the payments service is not doing anything unusual with the
network. The risk statement ("communicate through unusual channels") maps to
her mental model of what a well-behaved service should look like.

## 3. The most fragile part of the provisioning script

The logrotate postrotate block that signals kk-logs to reopen file handles.

The current implementation:
```bash
systemctl reload kk-logs.service 2>/dev/null || \
  systemctl kill --signal=HUP kk-logs.service 2>/dev/null || \
  true
```

The final `|| true` means logrotate will report success even if neither signal
was delivered. In a production environment where the service is actually running
and writing financial transaction logs, a silent failure here means the service
continues writing to the rotated (renamed) file, new log entries are lost from
the active log file, and the monitoring system sees no logs — but no alert fires.

To make this robust in a real production environment, I would need to know:
- Whether the application has a built-in log reopening mechanism (some runtimes
  watch the file inode and reopen automatically)
- Whether the service runs under a supervisor (PM2, gunicorn) that handles
  SIGHUP differently from the main process
- Whether the log writes are buffered or unbuffered (buffered writes make the
  window of log loss larger)

The correct fix is to remove the `|| true` and instead have logrotate's failure
trigger an alert, and to add a post-rotation verification step that confirms the
new log file is being written to within N seconds of rotation.
