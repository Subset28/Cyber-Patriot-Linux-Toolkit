#!/bin/bash
# Test suite for the Linux toolkit. Run from the toolkit folder: bash tests/run-tests.sh
# Runs on Linux (CI and real machines) and in Git Bash. Nothing here changes the system: apply-mode checks use
# temp files and harmless commands. Checks that need a real Linux install are in the CI workflow.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); echo "  ok    $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  skip  $1"; }
check() { local name=$1; shift; if "$@"; then ok "$name"; else bad "$name"; fi; }
check_not() { local name=$1; shift; if "$@"; then bad "$name"; else ok "$name"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== static checks"
for f in cp_harden.sh lib.sh cp_menu.sh modules/*.sh; do
    check "syntax: $f" bash -n "$f"
done
has_cr() { [ "$(tr -d '' < "$1" | wc -c)" -ne "$(wc -c < "$1")" ]; }
for f in cp_harden.sh lib.sh cp_menu.sh modules/*.sh config.env tests/run-tests.sh; do
    check_not "LF line endings: $f" has_cr "$f"
done
for f in cp_harden.sh lib.sh cp_menu.sh modules/*.sh; do
    check "ASCII only: $f" bash -c '! LC_ALL=C grep -q "[^[:print:][:space:]]" "$1"' _ "$f"
done

MODULES=$(sed -n 's/^MODULES="\(.*\)"$/\1/p' cp_harden.sh)
for m in $MODULES; do
    check "module file exists: $m" test -f "modules/$m.sh"
    check "module defines mod_$m: $m" grep -q "^mod_${m}() {" "modules/$m.sh"
done
for f in modules/*.sh; do
    m=$(basename "$f" .sh)
    check "module is in MODULES list: $m" bash -c 'for x in $1; do [ "$x" = "$2" ] && exit 0; done; exit 1' _ "$MODULES" "$m"
done

echo "== shellcheck"
SC=${SHELLCHECK:-$(command -v shellcheck 2>/dev/null)}
if [ -n "$SC" ]; then
    check "shellcheck (warning level) passes" "$SC" -x -S warning cp_harden.sh lib.sh cp_menu.sh modules/*.sh
else
    skip "shellcheck not installed (set SHELLCHECK=path or install it; CI runs it)"
fi

echo "== helpers (lib.sh, no root needed)"
export APPLY=0
export RUN_DIR="$TMP/run"
mkdir -p "$RUN_DIR"
# shellcheck source=/dev/null
. ./lib.sh
# shellcheck source=/dev/null
. ./config.env
# shellcheck source=/dev/null
. ./modules/packages.sh

check "inlist finds a whole word" inlist "ssh cron" cron
check_not "inlist ignores a partial word" inlist "ssh cron" cro
check_not "inlist ignores a missing word" inlist "ssh cron" nmap

APPLY=0 act "dry run does not run" touch "$TMP/should-not-exist"
check "act dry run leaves the system alone" test ! -e "$TMP/should-not-exist"

APPLY=1
act "primary command works" true
check "act returns 0 when the primary works" act "primary works again" true
check "act falls back when the primary fails" act "fallback" false --fallback true
check_not "act returns 1 when everything fails" act "fail" false --fallback false
APPLY=0

printf 'PermitRootLogin yes\n#Port 22\n' > "$TMP/sshd_config"
APPLY=1
setline "$TMP/sshd_config" PermitRootLogin "PermitRootLogin no"
setline "$TMP/sshd_config" MaxAuthTries "MaxAuthTries 3"
APPLY=0
check "setline replaces an existing key" grep -qx 'PermitRootLogin no' "$TMP/sshd_config"
check "setline removes the old value" bash -c '! grep -q "PermitRootLogin yes" "$1"' _ "$TMP/sshd_config"
check "setline appends a missing key" grep -qx 'MaxAuthTries 3' "$TMP/sshd_config"

out=$(printf '1,3\n' | pick_numbers "Pick" "alpha" "beta" "gamma" 2>/dev/null)
check "pick_numbers returns the chosen items" test "$out" = $'alpha\ngamma'
out=$(printf 'none\n' | pick_numbers "Pick" "alpha" 2>/dev/null)
check "pick_numbers 'none' picks nothing" test -z "$out"
out=$(printf '\n9\nnone\n' | pick_numbers "Pick" "alpha" 2>/dev/null)
check "pick_numbers rejects Enter and bad numbers" test -z "$out"
timeout 10 bash -c '. ./lib.sh; pick_numbers Pick a b' </dev/null >/dev/null 2>&1; rc=$?
check "pick_numbers ends at end of input (no hang)" test "$rc" -ne 124
echo y | ask_yn "q"; check "ask_yn answers y" test $? -eq 0
echo n | ask_yn "q"; check "ask_yn answers n" test $? -eq 1
timeout 10 bash -c '. ./lib.sh; ask_yn q' </dev/null >/dev/null 2>&1; rc=$?
check "ask_yn ends at end of input (no hang)" test "$rc" -ne 124

pw=$(gen_password)
check "generated password is 16 characters" test "${#pw}" -eq 16
check "generated password has upper, lower, digit, symbol" bash -c '[[ $1 =~ [A-Z] && $1 =~ [a-z] && $1 =~ [0-9] && $1 =~ [!#%^\&*_=+-] ]]' _ "$pw"

echo "== README parsing (fixture)"
cat > "$TMP/readme.txt" <<'EOF'
Competition README

Authorized Administrators:
  benjamin
  jpearson

Authorized Users:
  mlee

Critical Services: ssh, cron

Prohibited Software:
  Wireshark
  Ophcrack
  nmap

Forensic Questions:
  What is the name of the file on the Desktop?
EOF
README="$TMP/readme.txt"
svc=$(parse_services)
check "README: critical services parsed" bash -c '[[ " $1 " == *" ssh "* && " $1 " == *" cron "* ]]' _ "$svc"
pn=$(prohibited_readme_names)
check "README: prohibited names parsed" bash -c '[[ " $1 " == *" Wireshark "* && " $1 " == *" Ophcrack "* && " $1 " == *" nmap "* ]]' _ "$pn"
check_not "README: forensic section is not read as prohibited" bash -c '[[ "$1" == *What* ]]' _ "$pn"

echo "== protected packages"
check "openssh-server is protected" protected_pkg openssh-server
check "chromium-browser is protected" protected_pkg chromium-browser
check_not "nmap is not protected" protected_pkg nmap

echo "== prohibited software matching (fake package list)"
# shellcheck disable=SC2329
dpkg-query() { printf '%s\n' nmap nmap-common wireshark-qt chromium-browser openssh-server htop; }
out=$(mod_packages 2>&1)
check "packages: exact name matched (nmap)" bash -c '[[ "$1" == *"nmap  (matched"* ]]' _ "$out"
check "packages: name-suffix package matched (nmap-common)" bash -c '[[ "$1" == *"nmap-common  (matched"* ]]' _ "$out"
check "packages: built-in list matched (wireshark-qt)" bash -c '[[ "$1" == *"wireshark-qt  (matched"* ]]' _ "$out"
check_not "packages: protected chromium not offered" bash -c '[[ "$1" == *"chromium-browser  (matched"* ]]' _ "$out"
check_not "packages: unrelated package not offered (htop)" bash -c '[[ "$1" == *htop* ]]' _ "$out"
check "packages: dry run changes nothing" bash -c '[[ "$1" == *"Dry run"* || "$1" == *"dry-run"* ]]' _ "$out"
check "packages: README name not installed is reported (Ophcrack)" bash -c '[[ "$1" == *"not installed"*Ophcrack* ]]' _ "$out"
unset -f dpkg-query

echo "== CLI"
check "cp_harden --list prints modules" bash -c 'bash ./cp_harden.sh --list | grep -qx users'
check "cp_harden rejects unknown argument" bash -c '! bash ./cp_harden.sh --bogus >/dev/null 2>&1'

echo
echo "passed: $PASS   failed: $FAIL   skipped: $SKIP"
[ "$FAIL" -eq 0 ]
