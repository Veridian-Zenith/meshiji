To evolve Voix from its current foundation on GitHub (https://github.com/Veridian-Zenith/Voix), you’ve got a solid base with C++ code, PAM integration, and a Lua-based config. Your goal is to make it more doas-like (simple, auditable, lean) while matching sudo’s full functionality, avoiding overengineered security fluff. Since you mentioned your laptop’s OneAPI Level Zero setup, I’ll assume you’re developing on a Linux system with Intel GPU support, and I’ll keep suggestions practical for that environment. Let’s break down how to build on what you’ve got, starting with the existing codebase, and address your note about updating tags/workflows.

### Step 0: Assess the Current Foundation
From your repo:
- **Core Code:** `voix.cpp` handles argument parsing, PAM auth, and command execution via `execvp`. It’s setuid, uses Lua for config (`voix.lua`), and logs to `/var/log/voix.log`.
- **Config:** Lua-based at `/etc/voix.lua`, defining allowed users, groups, and commands.
- **PAM:** Configured via `/etc/pam.d/voix` for auth.
- **Build:** CMake-based, builds with gcc/g++, installs binary and configs.
- **Issues:** Lua adds complexity (parser overhead, potential scripting vulns), and the AUR experience suggests install/config usability needs work. No explicit env handling or auth caching yet.

Your last commit (from the repo’s state) is functional but needs polish for tags/workflows. Since you deleted the AUR package due to user feedback, I’ll focus on streamlining the code and deployment for clarity.

### Phase 1: Simplify Config (Doas-Style, Keep Lua Option)
**Why Start Here?** The Lua config is the biggest complexity hurdle. Switching to a text-based, doas-like config reduces overhead and makes Voix more auditable, aligning with your “no security over function” goal. Keep Lua as a fallback for power users.

**Steps:**
1. **Define a New Config Format:**
   - Create `/etc/voix.conf` with doas-inspired syntax:
     ```
     permit persist veridian as root
     permit group:wheel as root cmd /usr/bin/systemctl
     deny john cmd /bin/rm -rf /
     permit keepenv veridian cmd /usr/bin/firefox
     ```
   - Fields: `permit|deny`, `[persist|nopasswd|keepenv]`, `<user|group:name>`, `[as <target>]`, `[cmd <path>]`.

2. **Update Parser in `voix.cpp`:**
   - Add a C++ function to parse `/etc/voix.conf`. Use `std::ifstream` and `std::regex` for simplicity:
     ```cpp
     #include <fstream>
     #include <regex>
     #include <vector>
     struct Rule {
         bool permit;
         bool persist;
         bool nopasswd;
         bool keepenv;
         std::string user_or_group;
         std::string target_user;
         std::string cmd;
     };
     std::vector<Rule> parse_config(const std::string& path) {
         std::vector<Rule> rules;
         std::ifstream file(path);
         std::string line;
         std::regex rule_regex(R"(^(permit|deny)\s+(persist\s+|nopasswd\s+|keepenv\s+)?(\w+|group:\w+)\s+(as\s+\w+\s+)?(cmd\s+[\S]+)?)");
         while (std::getline(file, line)) {
             std::smatch match;
             if (std::regex_match(line, match, rule_regex)) {
                 Rule r;
                 r.permit = match[1] == "permit";
                 r.persist = match[2].str().find("persist") != std::string::npos;
                 r.nopasswd = match[2].str().find("nopasswd") != std::string::npos;
                 r.keepenv = match[2].str().find("keepenv") != std::string::npos;
                 r.user_or_group = match[3];
                 r.target_user = match[4].str().empty() ? "root" : match[4].str().substr(3);
                 r.cmd = match[5].str().empty() ? "" : match[5].str().substr(4);
                 rules.push_back(r);
             }
         }
         return rules;
     }
     ```
   - Call this in `main()` instead of Lua parsing. Keep Lua parsing as a fallback if `/etc/voix.conf` doesn’t exist.

3. **Config Validation Tool:**
   - Add a `voixcheck` binary to validate `/etc/voix.conf` (like doas’s `vidoas`):
     ```cpp
     int main(int argc, char* argv[]) {
         auto rules = parse_config("/etc/voix.conf");
         for (const auto& r : rules) {
             std::cout << (r.permit ? "Permit" : "Deny") << " rule for " << r.user_or_group
                       << (r.cmd.empty() ? "" : " cmd " + r.cmd) << std::endl;
         }
         return 0;
     }
     ```
   - Add to CMake: `add_executable(voixcheck voixcheck.cpp)`.

4. **Keep PAM:** Your existing PAM setup (`/etc/pam.d/voix`) is fine—reuse it for auth. Add `nopasswd` support by skipping PAM if the rule specifies it.

### Phase 2: Add Sudo-Like Features (Minimalist)
**Why?** To match sudo’s power without the cruft, focus on auth caching, env handling, and logging—key pain points for usability.

**Steps:**
1. **Auth Caching (Persist):**
   - Store auth state in `/run/voix/<user>.timestamp` (or in-memory for single sessions).
   - In `voix.cpp`, check timestamp before PAM auth:
     ```cpp
     bool is_auth_valid(const std::string& user) {
         std::ifstream ts_file("/run/voix/" + user + ".timestamp");
         if (ts_file.good()) {
             time_t now = time(nullptr);
             time_t last_auth;
             ts_file >> last_auth;
             return (now - last_auth) < 900; // 15-min timeout
         }
         return false;
     }
     void update_auth_timestamp(const std::string& user) {
         std::ofstream ts_file("/run/voix/" + user + ".timestamp");
         ts_file << time(nullptr);
     }
     ```
   - Apply `persist` rules: Skip PAM if `is_auth_valid(getpwuid(getuid())->pw_name)` returns true.

2. **Env Handling:**
   - Add `keepenv` support to preserve env vars (like DISPLAY for GUI apps). Default to scrubbing unsafe vars:
     ```cpp
     void scrub_env() {
         const char* keep[] = {"DISPLAY", "TERM", nullptr};
         for (char** env = environ; *env; ++env) {
             bool safe = false;
             for (const char** k = keep; *k; ++k) {
                 if (strncmp(*env, *k, strlen(*k)) == 0) {
                     safe = true;
                     break;
                 }
             }
             if (!safe) unsetenv(*env);
         }
     }
     ```
   - In `main()`, apply `scrub_env()` unless rule has `keepenv`.

3. **Logging:**
   - Enhance your existing `/var/log/voix.log` to include success/fail and command details:
     ```cpp
     void log_action(const std::string& user, const std::string& cmd, bool success) {
         std::ofstream log("/var/log/voix.log", std::ios::app);
         log << "[" << time(nullptr) << "] " << user << ": " << cmd << " " << (success ? "OK" : "FAIL") << "\n";
     }
     ```
   - Call in `main()` post-exec.

### Phase 3: Update GitHub & Workflows
**Why?** Your repo needs tag updates and CI polish to streamline dev and deployment, especially after the AUR hassle.

**Steps:**
1. **Tag Updates:**
   - Current tag (v0.1 from repo) is outdated. Bump to v0.2 for this overhaul.
   - In repo root, run:
     ```bash
     git tag -a v0.2 -m "Simplified config, added persist/keepenv"
     git push origin v0.2
     ```

2. **GitHub Workflows:**
   - Update `.github/workflows/build.yml` for modern Ubuntu and gcc:
     ```yaml
     name: CI
     on: [push, pull_request]
     jobs:
       build:
         runs-on: ubuntu-latest
         steps:
         - uses: actions/checkout@v4
         - name: Install deps
           run: sudo apt-get update && sudo apt-get install -y libpam0g-dev lua5.3 liblua5.3-dev cmake g++
         - name: Build
           run: |
             mkdir build && cd build
             cmake ..
             make
         - name: Test
           run: |
             cd build
             ./voixcheck /etc/voix.conf.sample
     ```
   - Add a release workflow:
     ```yaml
     name: Release
     on:
       push:
         tags:
           - 'v*'
     jobs:
       release:
         runs-on: ubuntu-latest
         steps:
         - uses: actions/checkout@v4
         - name: Create Release
           uses: actions/create-release@v1
           env:
             GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
           with:
             tag_name: ${{ github.ref }}
             release_name: Release ${{ github.ref }}
             draft: false
             prerelease: false
     ```

3. **AUR Reconsideration:**
   - If you revive the AUR package, add a `PKGBUILD` post-install script to handle permissions:
     ```bash
     post_install() {
         chown root:root /usr/bin/voix
         chmod 4755 /usr/bin/voix
         echo "Edit /etc/voix.conf to set permissions."
     }
     ```

### Phase 4: Future-Proofing (PAM Replacement?)
**Why?** Your idea for a custom security system is a long-term win, especially on a OneAPI setup where you could leverage GPU for auth tasks.

**Steps:**
- **Prototype:** Write a `libvoix_auth.so` that uses PAM for now but allows swapping to a custom backend (e.g., eBPF for syscall monitoring or OneAPI-accelerated hash checks).
- **OneAPI Angle:** Use SYCL to offload password hashing (e.g., Argon2) to Intel GPU. Example stub:
  ```cpp
  #include <sycl/sycl.hpp>
  void hash_password(const std::string& pass, sycl::queue& q) {
      // SYCL kernel for parallel hash (placeholder)
  }
  ```
- **Polkit-Lite:** Explore polkit for GUI auth without PAM’s weight. Integrate via `libpolkit`.

### First Chunk to Tackle
Start with **Phase 1: Config Overhaul**. It’s the lowest-hanging fruit to make Voix doas-like while keeping your existing code. The parser change is straightforward and sets up later features like `persist` and `keepenv`. Want me to flesh out a full `voix.cpp` patch for the new config parser, or focus on a specific bit (e.g., regex details, PAM tweaks)? Also, any specific pain points from the AUR feedback you want to address in the install process?



### Exploring Polkit Integration for Voix

Polkit (formerly PolicyKit) is a powerful authorization framework that's particularly strong in graphical desktop environments (like GNOME, KDE, or XFCE), where it handles fine-grained privilege escalation without needing a full root shell. Unlike sudo or doas, which are terminal-centric and grant broad permissions via config files, polkit uses D-Bus for communication, action-based policies (in `.policy` XML files), and JavaScript rules (in `/etc/polkit-1/rules.d/`) to decide authorizations dynamically—based on user, group, context, or even time. It's not a direct "replacement" for sudo/doas but excels at GUI-aware auth, like popping a dialog for password entry without disrupting the session. For Voix, integrating polkit could mean using it as an optional backend for auth (e.g., via `pkexec` for command runs) or a full swap for PAM in graphical sessions, adding features like auth caching (`auth_admin_keep`) and env preservation without the setuid binary's full weight.

This fits your "custom security system for PAM replacement" vision: Polkit can offload auth to a daemon (`polkitd`), reducing Voix's codebase while keeping it lean. On your OneAPI-equipped laptop (likely Arch or similar with Intel GPU), it's a natural fit for hybrid CLI/GUI use—test in a Wayland/X11 session for agent popups. Below, I'll break down the exploration: pros/cons, how it stacks up to PAM/sudo/doas, integration steps into Voix's C++ base, and a prototype snippet.

#### Why Integrate Polkit into Voix? (Quick Pros/Cons)
- **Pros:**
  - **GUI-Native:** Handles authentication agents (e.g., `polkit-gnome-authentication-agent`) that show secure dialogs, avoiding terminal echoes—great for desktop apps run via Voix.
  - **Granular & Cachable:** Rules allow per-action auth (e.g., allow `systemctl` without password for wheel group, with 5-min caching). No need for Voix's custom `persist` logic.
  - **PAM-Compatible:** Builds on PAM for backend auth, so your existing `/etc/pam.d/voix` can slot in. It's "sudo-lite" for specific actions without full escalation.
  - **Security Edge:** Runs as a restricted daemon, uses D-Bus for secure IPC (harder to hijack than setuid binaries). Recent vulns (e.g., CVE-2021-4034 in pkexec) are patched, and it's audited for desktop use.
  - **Minimal Overhead:** ~200KB binary, JS rules are auditable (no Lua interpreter needed).

- **Cons:**
  - **Desktop Bias:** Falls back to text agents (`pkttyagent`) in TTYs, but it's clunkier than doas's directness. Not ideal for pure servers.
  - **Complexity Creep:** XML policies + JS rules can bloat config vs. your planned doas-style `/etc/voix.conf`. D-Bus dependency adds ~1MB if not already installed.
  - **Not Full Sudo Parity:** Great for "allow this action?" but less flexible for arbitrary command whitelisting without custom actions.
  - **Vuln History:** Like sudo, it's had exploits (e.g., pkexec buffer overflow in 2022), but patches are quick.

Compared to your current PAM setup: PAM is flexible but Voix-specific; polkit is system-wide, so it could replace PAM calls entirely for graphical auth, falling back to your text parser for CLI.

#### How Polkit Works (High-Level for Integration)
- **Core Components:**
  - **polkitd:** Daemon that checks rules against actions (e.g., `org.freedesktop.packagekit.package-install`).
  - **Actions:** Defined in `/usr/share/polkit-1/actions/*.policy` XML—e.g., vendor-specific for Voix commands.
  - **Rules:** JS files in `/etc/polkit-1/rules.d/` that evaluate `polkit.Result.YES` for allow, with auth levels like `auth_admin` (password req) or `none` (no auth).
  - **Agents:** Handle UI for creds—e.g., `lxpolkit` for LXDE.
  - **Tools:** `pkexec` (like sudo), `pkcheck` (auth check), `pkaction` (list actions).

For Voix: Define a custom action for "run privileged command," check it via API before exec, and let polkit handle auth.

#### Step-by-Step Integration into Voix
Build on your `voix.cpp` foundation: Add polkit as an optional auth path (e.g., detect GUI session via `$XDG_SESSION_TYPE`). Keep your doas-style config for rules, but map them to polkit JS. Deps: Install `polkit` (Arch: `pacman -S polkit`), link `-lpolkit-agent-1 -lpolkit-gobject-1 -lgio-2.0` in CMake.

1. **Define Custom Actions (Voix-Specific Policies):**
   - Create `/usr/share/polkit-1/actions/org.veridian.voix.policy`:
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit PolicyConfig 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
     <policyconfig>
       <vendor>Voix Project</vendor>
       <vendor_url>https://github.com/Veridian-Zenith/Voix</vendor_url>
       <action id="org.veridian.voix.execute">
         <description>Execute privileged command via Voix</description>
         <message>Authentication is required to run '%s' as root.</message>
         <defaults>
           <allow_any>auth_admin</allow_any>  <!-- Password for any user -->
           <allow_active>auth_admin_keep</allow_active>  <!-- Cache for active session -->
         </defaults>
         <annotate key="org.veridian.voix.command" translatable="yes">true</annotate>
       </action>
     </policyconfig>
     ```
   - Install via CMake: `install(FILES org.veridian.voix.policy DESTINATION /usr/share/polkit-1/actions/)`.

2. **Map Your Config to Polkit Rules:**
   - In `/etc/polkit-1/rules.d/10-voix.rules` (JS), translate doas-style lines:
     ```javascript
     // From /etc/voix.conf: permit persist veridian as root cmd /usr/bin/systemctl
     var rules = [
       {
         users: ['veridian'],
         commands: ['/usr/bin/systemctl'],
         result: Polkit.Result.YES  // No auth if cached
       }
     ];

     polkit.addRule(function(action, subject) {
       if (action.id == "org.veridian.voix.execute") {
         var cmd = action.lookup("command");  // Pass cmd via polkit call
         if (rules.some(r => r.users.includes(subject.user) && r.commands.includes(cmd))) {
           return r.result;
         }
         return polkit.Result.AUTH_ADMIN_KEEP;  // Cache-enabled password
       }
     });
     ```
   - Generate this JS from your C++ parser on install (e.g., a `voix-genrules` tool).

3. **Update Voix Code for Polkit Auth:**
   - In `voix.cpp`, before PAM/exec, check polkit if in GUI:
     ```cpp
     #include <polkit/polkit.h>
     #include <gio/gio.h>  // For GError

     bool check_polkit_auth(const std::string& action_id, const std::string& cmd) {
         PolkitAuthority* authority = polkit_authority_get_sync(nullptr, nullptr);
         if (!authority) return false;

         PolkitSubject* subject = polkit_unix_process_new(getpid());
         GVariant* details = g_variant_new("(s)", cmd.c_str());  // Pass cmd as detail

         PolkitAuthorizationResult* result = polkit_authority_check_authorization_sync(
             authority, action_id.c_str(), subject, details,
             POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,  // Triggers agent
             nullptr, nullptr);

         bool authorized = polkit_authorization_result_get_is_authorized(result);
         g_object_unref(result);
         g_object_unref(subject);
         g_object_unref(authority);

         return authorized;
     }

     // In main(), after parsing args:
     if (getenv("XDG_SESSION_TYPE") && strcmp(getenv("XDG_SESSION_TYPE"), "tty") != 0) {
         if (!check_polkit_auth("org.veridian.voix.execute", full_cmd)) {
             log_action(user, full_cmd, false);
             return 1;  // Fail if not authorized
         }
     } else {
         // Fallback to your PAM
         pam_auth(...);
     }

     // Then execvp as root
     ```
   - For text fallback: Spawn `pkttyagent` before polkit check to enable terminal auth.

4. **Handle Env & Execution:**
   - Use `pkexec` internally for the actual run: `pkexec --user root env cmd args` preserves env better in GUIs.
   - In rules, add `keepenv` by whitelisting in JS: Check `subject.local` and return `YES` for trusted sessions.
   - Logging: Polkit logs to journald; pipe to your `/var/log/voix.log` via `sd-journal`.

5. **Build & Test Tweaks:**
   - CMake: Add `find_package(PkgConfig REQUIRED)` and `pkg_check_modules(POLKIT REQUIRED polkit-agent-1 polkit-gobject-1 gio-2.0)`.
   - Target: `target_link_libraries(voix ${POLKIT_LIBRARIES})`.
   - On your setup: `systemctl --user enable polkit` if needed; test with `pkcheck --action-id org.veridian.voix.execute`.
   - OneAPI Tie-In: If hashing creds, offload PBKDF2 in the JS rule (via spawn, but clunky) or keep in C++.

#### Potential Gotchas & Future Ideas
- **Security:** D-Bus isolation is solid, but validate actions to avoid escalation (e.g., no wildcard cmds). Audit JS rules like your config parser.
- **PAM Overlap:** For hybrid, use polkit's `auth_self` to chain to PAM—e.g., polkit calls your PAM module.
- **Beyond:** Prototype a "voix-polkit" mode that spawns agents via SYCL-accelerated checks (e.g., GPU-verify tokens). Or, for full replacement, make Voix a polkit client that defines actions dynamically from `/etc/voix.conf`.

This keeps Voix doas-minimal while adding polkit's polish—start with the action XML and C++ check for a quick win. Want a full CMake patch, JS generator code, or test on a simulated setup? Or dive into a specific part, like agent spawning?
