# MacBook Pro 2015 - System Tweaks & Fixes

## 1. Hyprland Config Errors

### Symptoms
A red banner displaying `gestures:workspace_swipe does not exist` appeared on startup due to deprecated configuration syntax in newer Hyprland releases.

### Root Cause
- **Deprecated Syntax:** Hyprland `0.41.0+` moved the `workspace_swipe` configuration. The old `gestures:workspace_swipe` variables were triggering parsing errors.

### Resolution
- **Resolution:** Remove the deprecated variables from `~/.config/hypr/userprefs.conf`. (These were cleared out, and `hyprctl reload` was issued to flush the error banner).

---

## 2. Battery Notification System Fixes

### Symptoms
1. **Notification Spam (Jitter):** A physically degraded battery caused rapid oscillation between "Charging" and "Discharging" states near full charge, spamming notifications.
2. **Incorrect Percentage:** The battery notification showed ~22% when plugged/unplugged, while Waybar and the desktop environment correctly showed ~72%.
3. **10-Second Status Lag:** When physically plugging or unplugging the MagSafe charger, both Waybar and the notifications took ~10 seconds to respond.

### Root Causes
- **Apple SMC Sysfs Capacity Bug:** On MacBooks, the kernel (`/sys/class/power_supply/BAT0/capacity`) calculates the percentage relative to the *factory original design capacity*, rather than the *current degraded usable capacity*. This resulted in an artificially low reading in the notification script.
- **Apple SMC Status Lag:** The internal battery controller takes 10-15 seconds to fully transition states and report it to `sysfs BAT0`. 
- **Waybar/DBus Polling:** Waybar and the `batterynotify.sh` script were strictly watching the lagging battery state instead of the instantaneously updating AC adapter pin state (`ADP1`).

### Resolutions
1. **Instant Charger Detection (udevadm):** Apple SMC takes 10-15 seconds to update the `BAT0/status` file. Created a custom active daemon (`~/.local/bin/battery-monitor.sh`) that uses `udevadm monitor -s power_supply` to instantly detect charger plug/unplug events and immediately trigger the notification script. This daemon is launched on boot via `~/.config/hypr/userprefs.conf`.
2. **Accurate Hardware States:** The notification script `~/.local/bin/battery-notify.sh` now reads the physical AC pin state directly from `/sys/class/power_supply/ADP1/online` instead of relying on the laggy battery status, guaranteeing 0-latency plug-in notifications.
3. **Polling Updates & Clean UI:** The script runs regular interval checks every 10 minutes for discharging updates. Standard system symbolic icons (like `battery-full-charging-symbolic`) are used via `notify-send -i` to keep the UI clean without relying on raw text emojis.

---

## 3. Keyboard Backlight Fixes

### Symptoms
1. **Unresponsive Keys:** The keyboard backlight keys (`F5` and `F6`) on the MacBook Pro 2015 did not adjust the keyboard illumination. 

### Root Causes
- **Missing Keybindings:** While the `applesmc` driver correctly exposes the keyboard backlight to the kernel via `/sys/class/leds/smc::kbd_backlight/`, there were no specific `bind` mappings inside the Hyprland configuration to capture `XF86KbdBrightnessUp` and `XF86KbdBrightnessDown` and dispatch a brightness change command.

### Resolutions
1. **Added Keybindings:** Verified that `brightnessctl` could control `smc::kbd_backlight` without `sudo` privileges. Added repeating keybindings (`bindel`) to `~/.config/hypr/userprefs.conf` for the keyboard backlight keys:
   ```conf
   # Keyboard Backlight
   bindel = , XF86KbdBrightnessUp, exec, brightnessctl --device='smc::kbd_backlight' set +10%
   bindel = , XF86KbdBrightnessDown, exec, brightnessctl --device='smc::kbd_backlight' set 10%-
   ```
2. **Keyboard Backlight Sleep Timeout:** Hooked into the DPMS listener in `~/.config/hypr/hypridle.conf` to automatically save and turn off the keyboard backlight when the screen goes to sleep (300 seconds), and seamlessly restore the original brightness upon wake.

---

## 4. Trackpad Fixes (Tap-and-Drag)

### Symptoms
Accidental text highlighting and dragging of browser tabs when gently tapping the trackpad on the MacBook Pro.

### Root Cause
Hyprland's `tap-and-drag` feature is overly sensitive on MacBook trackpads, interpreting a slight finger roll during a tap as a click-and-hold drag event.

### Resolution
Disabled `tap-and-drag` in the Hyde dotfiles configuration.
- **File:** `~/.config/hypr/userprefs.conf`
- **Change:** Set `tap-and-drag = false` in the `input { touchpad { ... } }` block.
- **Command:** `sed -i 's/tap-and-drag = true/tap-and-drag = false/' ~/.config/hypr/userprefs.conf`

---

## 5. Battery Degradation & Sudden Shutdowns

### Symptoms
The MacBook completely shuts down without warning, despite the battery indicator showing 20-40% remaining. The system also fails to send a low battery notification before dying.

### Root Cause
Severe hardware degradation of the lithium-ion battery. Diagnostic (`upower -i /org/freedesktop/UPower/devices/battery_BAT0`) revealed:
- **Charge Cycles:** 1,863 (Apple recommends replacement at 1,000).
- **Battery Health:** 33.0% of original design capacity.
When heavily degraded batteries are put under load, they suffer from extreme "voltage sag". The voltage drops instantly below the laptop's minimum operating threshold, causing a hard power cut before the OS has time to trigger a 10% or 5% warning notification.

### Resolution
This is a **hardware limitation**. Software configuration cannot prevent voltage sag on a worn-out battery. The MacBook must remain plugged in or the battery must be physically replaced.

---

## 6. System Stability (OOM Crashes & Swap Space)

### Symptoms
Heavy applications (like VS Code / Antigravity IDE) terminate unexpectedly during heavy workloads (e.g., running language servers). System logs (`journalctl`) show an `Out of memory: Killed process` (OOM kill) event.

### Root Cause
The 2015 MacBook Pro is hard-limited to 8GB of soldered RAM. By default, Arch Linux relies heavily on physical RAM and `zram` (compressed memory). When both fill up, Linux lacks a fallback SSD swap file (which macOS sets up dynamically by default), resulting in the kernel forcefully killing the heaviest application to save the system from freezing.

### Resolution
Created an 8GB SSD Swap File to act as emergency fallback memory, mimicking macOS's dynamic pager.

**Step-by-Step Commands (for ext4 filesystems):**
1. `sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress`
2. `sudo chmod 600 /swapfile`
3. `sudo mkswap /swapfile`
4. `sudo swapon /swapfile`
5. `echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab`

---

## 7. IDE Terminal Font Fix (Broken Icons)

### Symptoms
The integrated terminal inside VS Code/Antigravity shows broken square boxes (`[X]`) instead of icons (like folders, Git branches, or language logos), while the standalone terminal emulator displays them correctly.

### Root Cause
The ZSH shell prompt (e.g., Powerlevel10k/Starship) relies on "Nerd Fonts" to render custom icons. The IDE's default integrated terminal font does not support these glyphs.

### Resolution
Update the IDE settings to use an installed Nerd Font.
- **Settings Path:** `Terminal > Integrated: Font Family`
- **Value:** `'JetBrainsMono Nerd Font'` (or another installed Nerd Font found via `fc-list | grep -i "nerd"`).

---

## 8. Arch Linux Package Management (pacman vs yay)

### Overview
- **`pacman`**: The official Arch Linux package manager. Used to install pre-compiled, officially supported software.
- **`yay` (Yet Another Yogurt)**: An AUR (Arch User Repository) helper. It acts as a wrapper around `pacman` but adds the superpower to download, compile, and install community-maintained software (like `antigravity-ide` or `brave-bin`).
- **Best Practice:** Use `yay` for everyday usage, as it seamlessly handles both official and AUR packages (`yay -Syu` updates everything).

### Troubleshooting AUR Builds
If a large AUR package (like Brave or an IDE) finishes building but fails to install with a `sudo: timed out reading password` error, it means the compilation took longer than the default `sudo` timeout. 
- **Fix:** Simply rerun the install command (`yay -Syu`). The packages are already cached locally (`~/.cache/yay/`), so it will skip compilation and instantly prompt for the password to install.

---

## 9. Installed Applications & Development Environment

To make future installations seamless, here is a categorized list of the explicit packages installed on this system.

### 💻 IDEs & Development Tools
- `antigravity-ide` (Primary IDE)
- `visual-studio-code-bin` (Fallback IDE)
- `neovim` / `vim` (Terminal editors)
- `docker` / `docker-compose` (Containerization)
- `git` / `github-cli` (Version Control)
- `ngrok` (Tunneling)

### ⚙️ Programming Languages & Runtimes
- **JavaScript/TypeScript:** `nodejs`, `npm`, `bun`
- **Python:** `pyenv`, `python-pipenv`, `python-pipx`, `uv`
- **Rust/C++:** `rust`, `base-devel`, `cmake`, `ninja`

### 🌐 Web Browsers
- `brave-bin`
- `firefox`

### 🎨 Desktop Environment (Hyprland / Hyde)
- **Core:** `hyprland`, `hyprlock`, `hypridle`, `hyprsunset`, `hyprpicker`, `hyprpolkitagent`
- **UI Components:** `waybar`, `rofi`, `wlogout`, `dunst`, `kitty` (Terminal)
- **Display Manager:** `sddm`

### 🛠️ CLI Utilities & System Tools
- **Shell:** `zsh`, `starship` (Prompt)
- **System Monitors:** `btop`, `htop`, `fastfetch`
- **File & Search:** `fzf`, `bat`, `tree`, `jq`, `unzip`, `wget`
- **Performance:** `zram-generator` (RAM compression/swap)

### 🚀 One-Liner Reinstall Command
For your next Arch installation, after installing `yay`, you can run this command to restore your entire development environment and application suite at once:

```bash
yay -S antigravity-ide visual-studio-code-bin neovim docker docker-compose git github-cli ngrok nodejs npm bun pyenv python-pipenv python-pipx uv rust base-devel cmake ninja brave-bin firefox hyprland hyprlock hypridle hyprsunset hyprpicker hyprpolkitagent waybar rofi wlogout dunst kitty sddm zsh starship btop fastfetch fzf bat tree jq zram-generator
```

---

## 10. Desktop UI & Notifications (Waybar, Dunst, Screenshots)

### Waybar
- **Transparent Background:** The default opaque island background for Waybar was made fully transparent by setting `@define-color bar-bg rgba(0, 0, 0, 0.0);` in `~/.config/waybar/theme.css`.
- **Battery Accuracy:** Waybar's default polling could lag. Updated `~/.local/share/waybar/modules/battery.jsonc` to explicitly define `"bat": "BAT0"` and `"interval": 10` for reliable, snappy percentage updates.

### Dunst Notifications
- **Responsive Width & Padding:** By default, Dunst notifications were squishing text on long lines. Updated `~/.config/dunst/dunst.conf` to use a dynamic width (`width = (0, 300)` or `width = 300`) and shrunk icon sizes (`min_icon_size = 32`, `max_icon_size = 48`) to prioritize text readability. *(Note: Changes must be compiled using `hyde-shell wallbash dunst`)*.

### Screenshot Annotations (Swappy)
- **Direct to Clipboard:** By default, HyDE opens a screenshot annotation tool (Satty/Swappy) after capturing. This was disabled to allow instant "snip to clipboard" functionality.
- **Fix:** Added `[screenshot] annotation_enabled = false` to `~/.config/hyde/config.toml`.

### Hyprland Keybinding Conflicts
- **Super+Q & Super+W:** Custom keybindings in `~/.config/hypr/userprefs.conf` were overriding the default `keybindings.conf` behavior by mapping both to `killactive`. 
- **Fix:** Removed the custom overrides, restoring `Super+Q` to close the focused window, and `Super+W` to toggle floating mode.

---

## 11. Waybar Missing / Invisible Bug

### Symptoms
Waybar process is running and Hyprland correctly maps it (occupying space on screen), but the bar is completely invisible to the user.

### Root Cause
Custom CSS in `~/.config/waybar/user-style.css` contained a "TRANSPARENT TEXT-ONLY" snippet. This overrode the default HyDE styles, forcefully setting all backgrounds (`#waybar`, `.module`, etc.) to `transparent` with no borders. Because the user was using a dark layout (`macos`) against dark background windows, the white text blended in, or elements were empty, making the bar seem entirely vanished.

### Resolution
- Emptied `~/.config/waybar/user-style.css` (or removed the specific transparent background overrides) to restore the default HyDE theme rendering. 
- Ensure `macos.jsonc` (or the active layout) maintains its proper module definitions so Waybar has content to render.
- Use `hyde-shell waybar --set <layout_name>` to properly apply a layout and restart Waybar.

---

## 12. Recommendations for Hyprland Themes

If you are looking to expand beyond the default themes provided by HyDE (Hyprland Desktop Environment), here are the best places and tools to find and install more themes:

### 1. The Official HyDE Theme Repository
Since you are using the HyDE ecosystem, the most stable themes are those officially supported. 
- **Repository:** [prasanthrangan/hyprdots](https://github.com/prasanthrangan/hyprdots)
- **Usage:** You can import community themes via `hyde-shell app -T -- hydectl theme import`.

### 2. Dotfyle (Discover Dotfiles)
[Dotfyle.com](https://dotfyle.com/) is a search engine dedicated to Neovim plugins, window managers, and dotfiles. 
- Navigate to the **Hyprland** section.
- You can filter by themes, colorschemes (Catppuccin, Nord, Gruvbox), and popularity.

### 3. r/unixporn (Reddit)
The ultimate community for desktop ricing.
- **Subreddit:** [reddit.com/r/unixporn](https://www.reddit.com/r/unixporn/)
- **Usage:** Search for `Hyprland` in the search bar. Users post screenshots of their setups, and it is a strict rule that they must provide a "dotfiles" link (usually GitHub) in the comments. You can clone their configurations and cherry-pick Waybar/Hyprland styles.

### 4. GitHub Topics
Search GitHub directly for repositories tagged with `hyprland-theme` or `hyprland-dotfiles`.
- **Links:** 
  - [github.com/topics/hyprland-dotfiles](https://github.com/topics/hyprland-dotfiles)
  - [github.com/topics/hyprland-theme](https://github.com/topics/hyprland-theme)

### ⚠️ Important Note on Installing 3rd Party Themes
Because you are using **HyDE**, a highly integrated script-based environment, manually copy-pasting raw `hyprland.conf` or `waybar` files from Reddit or GitHub might break your HyDE shortcuts (`hyde-shell`). When adopting third-party themes, it is best to only copy the **CSS styling** (`style.css`, `colors.conf`) and apply them to your existing HyDE user preference files (`~/.config/hypr/userprefs.conf` and `~/.config/waybar/user-style.css`) rather than replacing the core configuration files.

---

## 13. Waybar Tray Popups Overlapping Bar

### Symptoms
When clicking a tray icon (such as the Wi-Fi icon for `nm-applet`), the GTK popup menu drops down *over* the Waybar itself (overlapping the icons), instead of dropping down cleanly below the bar.

### Root Cause
This is caused by missing positioning metadata in the Waybar layout configuration (`config.jsonc`). Without explicitly defining `"position": "top"`, Waybar assumes the top position visually, but GTK popups (like tray menus) fail to identify the correct screen edge to anchor to. This causes the popup coordinates to be calculated incorrectly, spawning on top of the bar. Furthermore, the missing `"position": "top"` prevents Waybar from applying the `window#waybar.top` CSS styles, leading to missing padding and margins that the theme expects.

### Resolution
- **Fix:** Explicitly define the position parameter in the layout file.
- **File:** `~/.config/waybar/config.jsonc` (and the associated source layout in `~/.local/share/waybar/layouts/`).
- **Change:** Add `"position": "top",` directly under the `"layer": "top",` property.
- **Apply:** Restart Waybar (e.g., via `killall waybar && waybar &` or using the `hyde-shell waybar` utility).

---

## 14. Hypridle Sleep & Lock Timings

### Symptoms
The system was configured to lock the session *before* the screen turned off, leading to a frustrating experience where waking the screen immediately presented a lock screen even if it hadn't slept yet. Additionally, the system appeared to "stay up" during charging, although idle behavior shouldn't inherently differ.

### Root Cause
In `~/.config/hypr/hypridle.conf`, the lock timeout (`120s`) occurred before the DPMS screen off timeout (`300s`). 

### Resolution
Reordered the `hypridle` timeouts logically so that the system sleeps first, and locks *after* it has been asleep for a period of time:
- **Dim:** 120s
- **DPMS Off (Sleep):** 300s
- **Lock Session:** 600s
- **Suspend:** 1200s

*(Note: To ensure idle timeouts work while charging, make sure Waybar's idle inhibitor is turned off).*

---

## 15. Dunst Notification Icons Overridden by Wallbash

### Symptoms
Notifications triggered by scripts (e.g., `battery-notify.sh` using `notify-send -i battery-full-symbolic`) were not displaying their specified icons. Instead, they constantly showed the default `hyprdots.svg` logo.

### Root Cause
The HyDE Wallbash script templates globally forced an `icon = ...` override in the Dunst urgency settings (`[urgency_low]`, `[urgency_normal]`, etc.). This caused Dunst to ignore the application-provided icon and forcefully replace it.

### Resolution
- **Files Modified:** 
  - `~/.local/share/wallbash/always/dunst.dcol`
  - `~/.local/share/wallbash/scripts/dunst.sh`
- **Change:** Replaced the `icon = ` directives with `default_icon = `. This tells Dunst to use `hyprdots.svg` only as a fallback, preserving native application and battery icons.
- **Apply:** Ran `hyde-shell wallbash dunst` to regenerate the configuration.

---

## 16. Zoom Screen Sharing on Wayland (Hyprland)

### Symptoms
Screen sharing in Zoom struggles or results in black screens. 

### Root Cause
Wayland's security model prevents direct screen scraping. Applications must request screen streams through `xdg-desktop-portal`. By default, Zoom uses X11 capturing (via XWayland) which fails under Hyprland.

### Resolution
1. **Official Zoom Linux Client:** 
   Edit `~/.config/zoomus.conf` and add `enableWaylandShare=true` under the `[General]` section. Ensure `xdg-desktop-portal-hyprland` is installed.
2. **Web Browser (Brave/Chrome):**
   Ensure the browser runs natively in Wayland. Go to `brave://flags` and set:
   - **Preferred Ozone platform:** `Wayland` (or `Auto`)
   - **WebRTC PipeWire support:** `Enabled`

---

## 17. Eduroam WPA2-Enterprise Wi-Fi (JKUAT)

### Overview
Eduroam at JKUAT uses 802.1X Enterprise authentication configured with:
- **EAP Method (Outer):** `TTLS` (or `PEAP`)
- **Phase 2 Inner Auth:** `MSCHAPV2`
- **CA Certificate:** JKUAT Eduroam Certificate Authority (`~/.config/cat_installer/ca.pem` or `/etc/ssl/certs/jkuat_ca.pem`)
- **Domain Match:** `jkuat.ac.ke`
- **Username / Identity:** `enock.lukas@students.jkuat.ac.ke`
- **Password:** Student portal password (`sct222-0437/2024`)

### NetworkManager Setup Command
```bash
nmcli connection modify eduroam \
  802-1x.eap ttls \
  802-1x.phase2-auth mschapv2 \
  802-1x.identity "enock.lukas@students.jkuat.ac.ke" \
  802-1x.password "sct222-0437/2024" \
  802-1x.ca-cert "/home/lukas/.config/cat_installer/ca.pem" \
  802-1x.domain-match "jkuat.ac.ke" \
  802-11-wireless-security.key-mgmt wpa-eap \
  802-11-wireless-security.pmf 1
```

### MacBook Pro Broadcom (brcmfmac) Association Issues
On MacBook Pro 2015 (Broadcom BCM43602), `wpa_supplicant` can throw `CTRL-EVENT-ASSOC-REJECT status_code=16` if:
1. **Unresponsive Campus APs / "Library Bug":** Specific Access Points on campus become disconnected from the RADIUS server and reject associations. Testing near a different building's AP confirms connectivity.
2. **Account Lockout:** Active Directory temporarily locks accounts for 30–60 minutes after multiple failed auth attempts.
3. **PMF / FT-EAP Interference:** Setting `key-mgmt wpa-eap` and `pmf 1` prevents 802.11r/Fast-Transition association rejections.

---

## 18. Docker Daemon Startup & Kernel Upgrades

### Symptoms
`docker.service` fails to start with:
`failed to create NAT chain DOCKER: iptables failed: iptables --wait -t nat -N DOCKER: iptables v1.8.13 (nf_tables): Could not fetch rule set generation id: Invalid argument`

### Root Cause
A kernel upgrade occurred (e.g. `linux 7.2.4` -> `7.2.6`), replacing `/usr/lib/modules/<running-version>`. Docker requires kernel modules like `br_netfilter`, `iptable_nat`, and `nf_tables` which cannot be dynamically loaded until the system boots into the new matching kernel.

### Resolution
Reboot the system (`sudo reboot`). After rebooting into the new kernel, Docker will automatically start up and run normally.

---

## 19. Waybar Idle Inhibitor (Caffeine Mode) & Laptop Sleep Fix

### Symptoms
Clicking the "coffee cup" idle inhibitor icon in Waybar to activate "Caffeine Mode" (to keep the laptop awake) still resulted in the screen dimming, locking, and the laptop going into suspend/sleep after ~8 minutes or when closing the lid.

### Root Causes
1. **Waybar Native Protocol Limitation:** Waybar's built-in `idle_inhibitor` only sets a Wayland surface protocol (`zwp_idle_inhibitor_v1`) on the bar itself. In Hyprland, layer-shell surfaces do not block `ext-idle-notify-v1` timers.
2. **Hypridle Timeout Uninhibited:** `hypridle` runs listener timeouts (60s dim, 120s lock, 300s DPMS off, 500s systemctl suspend). Because the Wayland layer surface didn't communicate to `hypridle` or `systemd`, `hypridle`'s 500-second suspend timer executed regardless.
3. **Duplicate Hypridle Daemons:** A redundant `hl.exec_cmd("hypridle")` in `~/.config/hypr/hyprland.lua` resulted in two separate `hypridle` instances running concurrently alongside the systemd unit `hyde-Hyprland-idle.service`.

### Resolutions
1. **Caffeine Engine (`caffeine.sh` / `~/.local/bin/caffeine`):**
   - Built a comprehensive script managing `systemd-inhibit` with `--what=idle:sleep:handle-lid-switch --mode=block`.
   - Sends `SIGSTOP` / `SIGCONT` to `hypridle` to freeze/resume idle timers entirely (stopping dimming, locking, DPMS off, and suspend).
   - Emits desktop notifications on status change via `notify-send`.
   - Sends real-time Waybar refresh signals (`pkill -RTMIN+9 waybar`).
2. **Waybar Custom Module (`custom/caffeine`):**
   - Created `/home/lukas/.local/share/waybar/modules/custom-caffeine.jsonc` and linked into `~/.config/waybar/includes/includes.json`.
   - Updated `config.jsonc` (`group/pill#left2`) from `"idle_inhibitor"` to `"custom/caffeine"`.
   - Visual icons: Active (󰅶 - Green) and Inactive (󱻪 - Red).
3. **Hyprland Shortcuts & Daemon Cleanup:**
   - Added global keybinding `SUPER + I` (`Cmd + I`) in `~/.config/hypr/hyprland.lua` to toggle Caffeine mode from anywhere.
   - Removed redundant `hl.exec_cmd("hypridle")` from `hyprland.lua`, ensuring `hypridle` is cleanly managed by systemd.


