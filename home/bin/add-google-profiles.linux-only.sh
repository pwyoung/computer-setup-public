#!/usr/bin/env bash
# add-google-profile.sh
#
# Creates a .desktop entry for every Chrome profile that has an email address
# but doesn't already have an entry in ~/.local/share/applications/.
#
# Usage:
#   bash /tmp/add-google-profile.sh          # create entries for all missing profiles
#   bash /tmp/add-google-profile.sh --list   # just list profiles, create nothing
#   bash /tmp/add-google-profile.sh --force  # recreate entries even if they already exist

set -euo pipefail

CHROME_BIN="/usr/bin/google-chrome-stable"
CHROME_CONFIG_DIR="${HOME}/.config/google-chrome"
DESKTOP_DIR="${HOME}/.local/share/applications"
LIST_ONLY=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)  LIST_ONLY=true ;;
        --force) FORCE=true ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
    shift
done

mkdir -p "$DESKTOP_DIR"

# ---------------------------------------------------------------------------
# Read all Chrome profiles and their emails via Python (Preferences is JSON)
# ---------------------------------------------------------------------------
python3 - "$CHROME_CONFIG_DIR" "$DESKTOP_DIR" "$CHROME_BIN" "$LIST_ONLY" "$FORCE" <<'PYEOF'
import sys, json, os, re, subprocess

chrome_config, desktop_dir, chrome_bin, list_only, force = sys.argv[1:]
list_only = list_only == 'true'
force = force == 'true'

profiles = []
for entry in sorted(os.listdir(chrome_config)):
    prefs_path = os.path.join(chrome_config, entry, 'Preferences')
    if not os.path.isfile(prefs_path):
        continue
    if entry in ('System Profile',):
        continue
    try:
        with open(prefs_path) as f:
            prefs = json.load(f)
    except Exception:
        continue

    account_info = prefs.get('account_info', [])
    email = account_info[0].get('email', '') if account_info else ''
    display_name = prefs.get('profile', {}).get('name', entry)

    profiles.append({
        'dir':          entry,
        'email':        email,
        'display_name': display_name,
    })

print(f"{'PROFILE DIR':<20}  {'EMAIL':<40}  {'DISPLAY NAME'}")
print(f"{'-'*20}  {'-'*40}  {'-'*30}")
for p in profiles:
    print(f"{p['dir']:<20}  {p['email']:<40}  {p['display_name']}")

if list_only:
    sys.exit(0)

print()
created = 0
skipped = 0
for p in profiles:
    email = p['email']
    if not email:
        print(f"  SKIP  {p['dir']:<20}  (no email address)")
        skipped += 1
        continue

    # Derive a safe filename from the email address
    safe = re.sub(r'[^a-z0-9]', '-', email.lower()).strip('-')
    desktop_path = os.path.join(desktop_dir, f'google-chrome-{safe}.desktop')

    if os.path.exists(desktop_path) and not force:
        print(f"  EXISTS  {email}  →  {os.path.basename(desktop_path)}")
        skipped += 1
        continue

    content = f"""[Desktop Entry]
Version=1.0
Name=Chrome ({email})
Comment=Google Chrome – {email}
Exec={chrome_bin} --profile-directory="{p['dir']}" %U
StartupNotify=true
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;
"""
    with open(desktop_path, 'w') as f:
        f.write(content)
    os.chmod(desktop_path, 0o644)
    print(f"  CREATED  {email}  →  {desktop_path}")
    created += 1

print()
print(f"Done: {created} created, {skipped} skipped.")
print("Updating desktop database...")
PYEOF

# ---------------------------------------------------------------------------
# Refresh the desktop database so pickers pick up the new entries immediately
# ---------------------------------------------------------------------------
if [[ "$LIST_ONLY" == "false" ]]; then
    update-desktop-database "$DESKTOP_DIR"
    echo "Done — new profiles should now appear in URL pickers."
fi
