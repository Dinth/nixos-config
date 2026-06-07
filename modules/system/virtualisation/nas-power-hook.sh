#!/run/current-system/sw/bin/bash
#
# Wake QNAP NAS (10.10.1.19) before LinuxMint starts, shut it down
# 600 s after it stops (if no other VMs are still running).
#
# SSH: uses /home/michal/.ssh/id_ed25519 — pubkey must be in admin@10.10.1.19 authorized_keys.

set -euo pipefail

domain="$1"
operation="$2"
sub_op="$3"

NAS_IP="10.10.1.19"
NAS_MAC="00:08:9b:da:78:e2"
VM_DOMAIN="LinuxMint"

logger="/run/current-system/sw/bin/logger"
ping="/run/current-system/sw/bin/ping"
wakeonlan="/run/current-system/sw/bin/wakeonlan"
date="/run/current-system/sw/bin/date"
sleep="/run/current-system/sw/bin/sleep"
systemctl="/run/current-system/sw/bin/systemctl"
virsh="/run/current-system/sw/bin/virsh"
grep="/run/current-system/sw/bin/grep"
ssh="/run/current-system/sw/bin/ssh"

log() { $logger -t "nas-power-hook" "$*"; }

nas_reachable() {
    $ping -c 1 -W 2 "$NAS_IP" &>/dev/null
}

wake_nas() {
    log "Sending WoL to $NAS_MAC"
    $wakeonlan "$NAS_MAC"
    local deadline=$(( $($date +%s) + 180 ))
    while (( $($date +%s) < deadline )); do
        if nas_reachable; then
            log "NAS is reachable — waiting 5 s for SMB to settle"
            $sleep 5
            return 0
        fi
        $sleep 5
    done
    log "ERROR: NAS did not respond within 180 s"
    return 1
}

remount_nas() {
    log "Remounting mnt-VM.mount"
    $systemctl reset-failed mnt-VM.automount mnt-VM.mount 2>/dev/null || true
    $systemctl start mnt-VM.mount || true
}

any_vm_running() {
    $virsh --connect qemu:///system list --state-running --name 2>/dev/null \
        | $grep -q '[^[:space:]]'
}

shutdown_nas() {
    if nas_reachable; then
        log "Sending poweroff to NAS via SSH"
        # id_ed25519 is passphrase-protected; feed the passphrase via SSH_ASKPASS
        # so ssh can unlock it non-interactively (same trick as the sshfs mount).
        local _askpass
        _askpass=$(mktemp)
        printf '#!/bin/sh\nexec cat /run/agenix/id-ed25519-passphrase\n' > "$_askpass"
        chmod 0700 "$_askpass"
        SSH_ASKPASS="$_askpass" SSH_ASKPASS_REQUIRE=force \
            $ssh \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=10 \
            -i /home/michal/.ssh/id_ed25519 \
            admin@"$NAS_IP" poweroff 2>/dev/null || true
        rm -f "$_askpass"
    else
        log "NAS already unreachable — skipping SSH poweroff"
    fi
}

[ "$domain" = "$VM_DOMAIN" ] || exit 0

case "$operation" in
    prepare)
        [ "$sub_op" = "begin" ] || exit 0
        if nas_reachable; then
            log "NAS already up, skipping WoL"
        else
            wake_nas
        fi
        remount_nas
        ;;

    release)
        [ "$sub_op" = "end" ] || exit 0
        # Return immediately so libvirt is not blocked during VM cleanup.
        (
            log "LinuxMint released — waiting 600 s before NAS shutdown"
            $sleep 600
            if any_vm_running; then
                log "A VM is still running — skipping NAS shutdown"
            else
                shutdown_nas
            fi
        ) &
        disown $!
        ;;
esac
