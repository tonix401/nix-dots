#!/bin/sh
# Password prompt for `sudo -A` and anything else that honours SUDO_ASKPASS (set in hypr/env.lua).
# Hands the request to the Quickshell askpass menu (quickshell/Askpass.qml) and prints the typed
# password; exits 1 when it is cancelled or the shell isn't there. $1 is the prompt text.
fifo="${XDG_RUNTIME_DIR:-/tmp}/askpass.$$"
mkfifo -m 600 "$fifo" || exit 1
trap 'rm -f "$fifo"' EXIT

[ "$(qs ipc call askpass ask "$fifo" "${1:-Password}" 2>/dev/null)" = ok ] || exit 1

# The menu always answers (an empty line = cancelled); the timeout only guards against a crashed shell.
# The password goes through the FIFO and shell builtins, never through an argument list.
timeout 600 head -n 1 "$fifo" | {
    IFS= read -r secret
    [ -n "$secret" ] || exit 1
    printf '%s\n' "$secret"
}
