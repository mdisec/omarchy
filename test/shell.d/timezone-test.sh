#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

timezone_menu="$ROOT/bin/omarchy-menu-timezone"
sudoers_file="$ROOT/etc/sudoers.d/omarchy-tzupdate"
timezone_args_regex='^set-timezone [A-Za-z0-9_+][A-Za-z0-9_+.-]*(/[A-Za-z0-9_+][A-Za-z0-9_+.-]*)*$'
sudoers_rule="%wheel ALL=(root) NOPASSWD: /usr/bin/timedatectl $timezone_args_regex"

grep -Fx "$sudoers_rule" "$sudoers_file" >/dev/null ||
  fail "timezone sudoers rule allows exactly one timezone argument"

visudo -cf "$sudoers_file" >/dev/null ||
  fail "timezone sudoers rule parses successfully"

for args in \
  'set-timezone UTC' \
  'set-timezone America/New_York' \
  'set-timezone Etc/GMT+5'; do
  [[ $args =~ $timezone_args_regex ]] ||
    fail "timezone sudoers regex accepts $args"
done

for args in \
  'set-timezone UTC --host=repro.invalid' \
  'set-timezone UTC -Hrepro.invalid' \
  'set-timezone UTC --machine=attacker' \
  'set-timezone UTC extra' \
  'set-timezone ../UTC'; do
  [[ ! $args =~ $timezone_args_regex ]] ||
    fail "timezone sudoers regex rejects $args"
done

! grep -F 'tzupdate' "$sudoers_file" >/dev/null ||
  fail "timezone sudoers rule does not grant passwordless tzupdate"

grep -F 'sudo /usr/bin/timedatectl set-timezone "$timezone"' "$timezone_menu" >/dev/null ||
  fail "timezone menu pins the passwordless command to the trusted system binary"

grep -F 'omarchy-shell -q omarchy.clock refresh' "$timezone_menu" >/dev/null ||
  fail "timezone menu refreshes the namespaced clock IPC target"

! grep -F 'omarchy-shell -q Clock refresh' "$timezone_menu" >/dev/null ||
  fail "timezone menu no longer refreshes the retired Clock IPC target"

pass "timezone sudoers rule accepts one timezone and rejects transport options"
