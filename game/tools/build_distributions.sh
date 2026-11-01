#!/usr/bin/env bash
# Export portable Windows and Linux builds on a Linux CI host with Godot 4.5.1.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
project="$root/game"
godot="${GODOT:?GODOT must point to the verified Godot 4.5.1 editor}"
work="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/aod-export"
out="$root/dist"
template_url="https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz"
# Official release asset SHA-256 digest (published by godotengine/godot-builds).
template_sha256="1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86"
rm -rf -- "$work" "$out"
mkdir -p "$work" "$out/windows" "$out/linux"
archive="$work/export_templates.tpz"
curl --fail --location --retry 4 --retry-all-errors --silent --show-error \
  "$template_url" --output "$archive"
echo "$template_sha256  $archive" | sha256sum --check --status

# Install only the Windows x64 and Linux x86_64 official release templates.
export XDG_DATA_HOME="$work/xdg-data"
template_dir="$XDG_DATA_HOME/godot/export_templates/4.5.1.stable"
mkdir -p "$template_dir"
unzip -j -o "$archive" templates/version.txt templates/linux_release.x86_64 \
  templates/windows_release_x86_64.exe -d "$template_dir" >/dev/null
[[ "$(tr -d '\r\n' < "$template_dir/version.txt")" == "4.5.1.stable" ]] || {
  echo "Unexpected export template version" >&2; exit 1;
}
rm -- "$archive"

check_log() {
  local stage="$1" logfile="$2"
  if grep -E '^[[:space:]]*(SCRIPT ERROR:|ERROR:|FAIL )' "$logfile"; then
    echo "ERROR: $stage emitted a Godot error" >&2
    exit 1
  fi
}
if ! "$godot" --headless --path "$project" --import > "$work/import.log" 2>&1; then
  cat "$work/import.log"; exit 1
fi
check_log import "$work/import.log"

for preset in "Windows Desktop" "Linux/X11"; do
  if [[ "$preset" == "Windows Desktop" ]]; then
    target="$out/windows/AshesOfDominion.exe"
    log="$work/windows-export.log"
  else
    target="$out/linux/AshesOfDominion.x86_64"
    log="$work/linux-export.log"
  fi
  if ! "$godot" --headless --path "$project" --export-release "$preset" "$target" > "$log" 2>&1; then
    cat "$log"; exit 1
  fi
  check_log "$preset export" "$log"
  [[ -s "$target" && -s "${target%.*}.pck" ]] || {
    echo "ERROR: exported $preset executable or PCK missing" >&2
    cat "$log"; exit 1
  }
done

chmod +x "$out/linux/AshesOfDominion.x86_64"
if ! (cd "$out/linux" && timeout 45 ./AshesOfDominion.x86_64 --headless --quit-after 60) \
  > "$work/linux-smoke.log" 2>&1; then
  cat "$work/linux-smoke.log"; exit 1
fi
check_log "Linux exported executable" "$work/linux-smoke.log"

cat > "$out/windows/START_HERE.txt" <<'EOF'
ASHES OF DOMINION - PLAYABLE PROTOTYPE (WINDOWS 64-BIT)
1. Extract the entire ZIP to a folder.
2. Double-click AshesOfDominion.exe.
3. Keep AshesOfDominion.pck alongside the EXE.
No Godot editor or separate game installer is required.
This is an unsigned prototype: Windows may show a SmartScreen warning.
Controls: WASD/arrows move, left click/Space attack, E interact, Esc pause.
Saves and optional diagnostic logs are kept in per-user application data.
EOF
cat > "$out/linux/START_HERE.txt" <<'EOF'
ASHES OF DOMINION - PLAYABLE PROTOTYPE (LINUX x86_64)
1. Extract the entire ZIP to a folder.
2. Run ./AshesOfDominion.x86_64 (chmod +x if required).
3. Keep AshesOfDominion.pck alongside the executable.
No Godot editor is required. Linux graphics support varies.
Controls: WASD/arrows move, left click/Space attack, E interact, Esc pause.
Saves and optional diagnostic logs are kept in per-user application data.
EOF

# System zip preserves the Linux executable bit. Both PCK files must be included.
(cd "$out/windows" && zip -q -9 "$out/Ashes-of-Dominion-Windows-x64.zip" \
  AshesOfDominion.exe AshesOfDominion.pck START_HERE.txt)
(cd "$out/linux" && zip -q -9 "$out/Ashes-of-Dominion-Linux-x64.zip" \
  AshesOfDominion.x86_64 AshesOfDominion.pck START_HERE.txt)
(cd "$out" && sha256sum Ashes-of-Dominion-Windows-x64.zip \
  Ashes-of-Dominion-Linux-x64.zip > SHA256SUMS.txt)
unzip -tqq "$out/Ashes-of-Dominion-Windows-x64.zip"
unzip -tqq "$out/Ashes-of-Dominion-Linux-x64.zip"
echo "EXPORT PASSED: Windows x64 and Linux x86_64 portable ZIPs"
