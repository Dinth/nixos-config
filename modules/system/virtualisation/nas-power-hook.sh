#!/run/current-system/sw/bin/bash
# (interpreter is also supplied by pkgs.writeShellScript when wired into
#  libvirtd hooks; this shebang keeps the file runnable standalone for tests)
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
# Backing disk QEMU needs (vdc in linuxmint.xml). This file living on the
# CIFS share is the real precondition for starting the VM — gate on it, not
# on ping, because the QNAP answers ICMP long before this is reachable.
VM_DISK="/mnt/VM/LargeDrive.qcow2"

logger="/run/current-system/sw/bin/logger"
ping="/run/current-system/sw/bin/ping"
wakeonlan="/run/current-system/sw/bin/wakeonlan"
date="/run/current-system/sw/bin/date"
sleep="/run/current-system/sw/bin/sleep"
systemctl="/run/current-system/sw/bin/systemctl"
systemd_run="/run/current-system/sw/bin/systemd-run"
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
            log "NAS responds to ping"
            return 0
        fi
        $sleep 5
    done
    log "ERROR: NAS did not respond to ping within 180 s"
    return 1
}

remount_nas() {
    $systemctl reset-failed mnt-VM.automount mnt-VM.mount 2>/dev/null || true
    $systemctl start mnt-VM.mount 2>/dev/null || true
}

# Ping coming up is not enough: the QNAP exports the SMB share — and mounts
# the storage pool underneath it — tens of seconds after the network stack is
# alive. Keep (re)mounting and checking the actual backing disk until QEMU can
# open it, so the VM never starts against a missing/half-ready share.
wait_for_vm_disk() {
    local deadline=$(( $($date +%s) + 240 ))
    while (( $($date +%s) < deadline )); do
        remount_nas
        if [ -r "$VM_DISK" ]; then
            log "VM backing disk $VM_DISK is ready"
            return 0
        fi
        log "Waiting for $VM_DISK — share not exporting it yet"
        $sleep 5
    done
    log "ERROR: $VM_DISK not readable within 240 s — aborting VM start"
    return 1
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
        # Cancel a shutdown still pending from a stop inside the delay window.
        $systemctl stop nas-power-shutdown.timer 2>/dev/null || true
        if nas_reachable; then
            log "NAS already up, skipping WoL"
        else
            wake_nas
        fi
        # Block here (and fail the hook under set -e) until the backing disk is
        # actually present — libvirt aborts the start cleanly instead of QEMU
        # racing ahead and dying on a missing /mnt/VM/LargeDrive.qcow2.
        wait_for_vm_disk
        ;;

    release)
        [ "$sub_op" = "end" ] || exit 0
        # Schedule the shutdown via a transient systemd timer rather than a
        # backgrounded subshell. A child of this hook inherits libvirt's stdout
        # pipe, so libvirt would block on VM cleanup until the delay elapsed.
        # systemd-run fully detaches the job and makes it cancellable from the
        # prepare branch when the VM restarts inside the delay window.
        log "LinuxMint released — scheduling NAS shutdown in 600 s"
        $systemctl stop nas-power-shutdown.timer 2>/dev/null || true
        $systemctl reset-failed nas-power-shutdown.service nas-power-shutdown.timer 2>/dev/null || true
        $systemd_run --quiet --collect \
            --unit=nas-power-shutdown \
            --description="Shut down QNAP NAS 600 s after LinuxMint stopped" \
            --on-active=600 \
            "$0" "$VM_DOMAIN" deferred-shutdown end \
            || log "ERROR: failed to schedule NAS shutdown timer"
        ;;

    deferred-shutdown)
        # Fired by the nas-power-shutdown systemd timer (see release branch).
        if any_vm_running; then
            log "A VM is still running — skipping NAS shutdown"
        else
            shutdown_nas
        fi
        ;;
esac
