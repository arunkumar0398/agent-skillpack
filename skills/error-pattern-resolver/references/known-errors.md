# Known Errors Database

Pre-fingerprinted errors with verified resolutions. Each entry includes symptoms, root cause, and fix steps.

---

## 1. spawn gh ENOENT

**Fingerprint:** `spawn.gh.ENOENT`

**Symptoms:**
- Error: `spawn gh ENOENT` or `spawnSync gh ENOENT`
- Occurs when running any `gh` (GitHub CLI) command
- Common in CI/CD pipelines and script automation

**Root Cause:** GitHub CLI (`gh`) is not installed or not in system PATH.

**Fix Steps:**
1. Run `scripts/fix-gh-cli.ps1` (Windows) or install via package manager
2. Verify installation: `gh --version`
3. If installed but not found, add to PATH:
   - Windows: Add `C:\Program Files\GitHub CLI\` to system PATH
   - macOS: `brew install gh`
   - Linux: `sudo apt install gh` or `sudo dnf install gh`
4. Restart terminal/session after installation

**Verification:** `gh auth status` should complete without ENOENT error.

---

## 2. isGuestConnected Timeout

**Fingerprint:** `network.guest-connected.timeout`

**Symptoms:**
- Error: `isGuestConnected timed out after 30000ms`
- Remote development connections fail to establish
- Bridge service becomes unresponsive

**Root Cause:** Network connectivity issue between host and guest, or bridge service hang.

**Fix Steps:**
1. Check network connectivity: `ping <guest-ip>`
2. Restart the bridge service:
   - Stop bridge process
   - Wait 5 seconds
   - Restart bridge
3. Check firewall rules are not blocking bridge ports
4. If persistent, restart the guest VM/container
5. Verify DNS resolution is working

**Verification:** Bridge status shows connected; guest responds to ping within 100ms.

---

## 3. ERR_CONNECTION_RESET

**Fingerprint:** `network.connection.reset`

**Symptoms:**
- Error: `ERR_CONNECTION_RESET` or `ECONNRESET`
- HTTP requests fail mid-transfer
- WebSocket connections drop unexpectedly
- Occurs with proxy or firewall in path

**Root Cause:** Proxy, firewall, or network middleware is terminating the connection.

**Fix Steps:**
1. Check proxy configuration:
   - Verify `HTTP_PROXY` and `HTTPS_PROXY` environment variables
   - Test without proxy: `curl -noproxy '*' <url>`
2. Check firewall rules for target ports (443, 80, custom)
3. If behind corporate proxy, verify proxy allows WebSocket upgrades
4. Check for MTU issues: `ping -f -l 1472 <host>` (Windows) or `ping -M do -s 1472 <host>` (Linux)
5. Try connection with TLS 1.2+ explicitly if legacy TLS is blocked

**Verification:** Connection establishes without reset; sustained data transfer completes.

---

## 4. Deployment is NULL

**Fingerprint:** `deployment.msix.null`

**Symptoms:**
- Error: `Deployment is NULL` or `Deployment not found`
- MSIX-packaged app fails to launch
- `Get-AppxPackage` returns no results for the package

**Root Cause:** MSIX package registration is corrupted or was removed by Windows Update/cleanup.

**Fix Steps:**
1. Check current registration: `Get-AppxPackage -Name <PackageName>`
2. If not found, re-register:
   ```powershell
   Add-AppxPackage -Register "<PackagePath>\AppxManifest.xml" -DisableDevelopmentMode
   ```
3. If registration fails, reinstall the package:
   ```powershell
   Add-AppxPackage -Path "<PackagePath>.msix"
   ```
4. Clear Windows Store cache: `wsreset.exe`
5. Restart the application

**Verification:** `Get-AppxPackage -Name <PackageName>` returns valid package entry.

---

## 5. PluginScan Command Collision

**Fingerprint:** `plugin.scan.command-collision`

**Symptoms:**
- Error: `Command <name> already registered by <plugin>`
- Plugin fails to activate
- Duplicate command entries in extension manifest

**Root Cause:** Two or more extensions register the same command ID.

**Fix Steps:**
1. Identify conflicting commands: check `package.json` contributions.commands
2. Search workspace for all command registrations:
   ```
   grep -r "command.*<command-name>" --include="package.json"
   ```
3. Rename the conflicting command in your extension:
   - Change command ID to be unique (prefix with extension name)
   - Update all references to the command
4. Reload VS Code window: `Developer: Reload Window`
5. If third-party extension, report issue to extension author

**Verification:** No duplicate command warnings in extension host log; command executes correctly.

---

## 6. Apify Server Timeout

**Fingerprint:** `apify.server.timeout`

**Symptoms:**
- Error: `Apify server timeout` or `Request timed out after 60000ms`
- Actor runs hang or fail to return results
- API calls to Apify platform fail

**Root Cause:** Invalid or missing `APIFY_TOKEN` environment variable, or Apify API rate limiting.

**Fix Steps:**
1. Verify token is set: `echo $APIFY_TOKEN` or `echo %APIFY_TOKEN%`
2. If empty, set the token:
   - Windows: `$env:APIFY_TOKEN = "apify_api_<your-token>"`
   - Linux/macOS: `export APIFY_TOKEN="apify_api_<your-token>"`
3. Validate token: call Apify API directly with the token
4. Check Apify dashboard for rate limits or account issues
5. If token is valid but timeout persists, increase timeout in actor config

**Verification:** Apify API call returns 200 OK with valid response.

---

## 7. SSE Connection Reset

**Fingerprint:** `sse.connection.reset`

**Symptoms:**
- Error: `SSE connection reset` or `EventSource connection lost`
- Real-time data stream stops unexpectedly
- Reconnection attempts fail repeatedly

**Root Cause:** Server-side connection drop, network interruption, or proxy timeout on long-lived connections.

**Fix Steps:**
1. Check if server is still running and healthy
2. Implement exponential backoff for reconnection:
   ```
   delay = min(baseDelay * 2^attempt, maxDelay)
   ```
3. Verify proxy timeout settings (default 60s may be too short for SSE)
4. Check for keepalive/heartbeat configuration
5. If behind load balancer, ensure sticky sessions are enabled for SSE

**Verification:** SSE connection re-establishes and receives events within backoff window.

---

## 8. Auto-Update Failed

**Fingerprint:** `update.windows-store.failed`

**Symptoms:**
- Error: `Auto-update failed` or `Windows Store update returned error`
- Application version remains at old version after update attempt
- Store download starts but fails to complete

**Root Cause:** Windows Store cache corruption, insufficient disk space, or store service issue.

**Fix Steps:**
1. Check available disk space (minimum 2GB recommended)
2. Reset Windows Store cache: `wsreset.exe`
3. Run Store troubleshooter: Settings → Update & Security → Troubleshoot
4. Manually check for updates in Windows Store app
5. If persistent, reinstall the application from Store
6. Check Windows Update service is running: `services.msc → Windows Update`

**Verification:** Application shows latest version; Store reports up-to-date.

---

## 9. Memory Pressure

**Fingerprint:** `system.memory.pressure`

**Symptoms:**
- Error: `JavaScript heap out of memory` or `Allocation failed`
- Application becomes unresponsive
- System swap usage spikes to 100%
- Other applications start crashing

**Root Cause:** Insufficient available RAM due to excessive concurrent processes.

**Fix Steps:**
1. Identify memory consumers: Task Manager → Details → Sort by Memory
2. Close non-essential applications (browsers, editors, media players)
3. Increase Node.js heap size if applicable:
   ```
   node --max-old-space-size=4096 <script>
   ```
4. Check for memory leaks: monitor process memory over time
5. If persistent, consider adding RAM or reducing workload
6. Enable garbage collection logging to identify leak source

**Verification:** Memory usage stays below 80% of available RAM; no OOM errors in logs.

---

## 10. Session Timeout

**Fingerprint:** `session.idle.timeout`

**Symptoms:**
- Error: `Session timeout` or `Connection closed due to inactivity`
- Remote session disconnects after period of inactivity
- User must re-authenticate after timeout

**Root Cause:** Session idle timeout configured too aggressively, or no keepalive mechanism.

**Fix Steps:**
1. Check session timeout configuration (default varies by service)
2. Increase idle timeout value:
   - SSH: `ServerAliveInterval 60` in ssh_config
   - Web app: adjust session timeout in application config
   - API: check token expiry settings
3. Implement periodic keepalive/heartbeat if supported
4. If using a proxy, check proxy idle timeout settings
5. Consider using session persistence tokens for long-running tasks

**Verification:** Session remains active through idle periods; no timeout disconnections in logs.

---

## 11. Port Already in Use

**Fingerprint:** `system.port.conflict`

**Symptoms:**
- Error: `EADDRINUSE` or `address already in use`
- Application fails to start on expected port
- Previous process still holding the port

**Root Cause:** Another process (or zombie of previous run) is bound to the required port.

**Fix Steps:**
1. Find process using the port:
   - Windows: `netstat -ano | findstr :<port>`
   - Linux/macOS: `lsof -i :<port>` or `ss -tlnp | grep :<port>`
2. Terminate the process: `kill -9 <PID>` or `taskkill /PID <PID> /F`
3. If it's a zombie process, wait 30 seconds for port release
4. Configure application to use alternative port if primary is unavailable
5. Add port availability check to startup script

**Verification:** Application starts successfully on target port; `netstat` shows port bound to correct process.

---

## 12. Certificate Expired

**Fingerprint:** `tls.cert.expired`

**Symptoms:**
- Error: `certificate has expired` or `ERR_CERT_DATE_INVALID`
- HTTPS connections fail with trust error
- Browser shows security warning

**Root Cause:** SSL/TLS certificate has passed its expiry date.

**Fix Steps:**
1. Check certificate expiry: `openssl s_client -connect <host>:443 | openssl x509 -noout -dates`
2. If self-signed, regenerate certificate
3. If Let's Encrypt, renew: `certbot renew`
4. If managed certificate, check provider dashboard for renewal status
5. Update certificate in application/server configuration
6. Restart services to load new certificate

**Verification:** `openssl s_client` shows valid dates; browser shows secure connection.

---

## Adding New Entries

When encountering a new error not in this database:

1. Extract the fingerprint using the format: `<component>.<error-type>.<specific-detail>`
2. Document symptoms, root cause, and fix steps
3. Add entry to this file following the format above
4. If fix is automatable, create a script in `scripts/`
5. Test the fix before documenting as verified
