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
umount="/run/current-system/sw/bin/umount"
mktemp="/run/current-system/sw/bin/mktemp"
chmod="/run/current-system/sw/bin/chmod"
rm="/run/current-system/sw/bin/rm"

log() { $logger -t "nas-power-hook" "$*"; }

# systemd-run gives this script a PATH built from the mount units' dependencies
# — coreutils is not on it. Every external command must therefore be called by
# absolute path; a bare one fails ENOENT and, under `set -e`, kills the script
# with no output at all. This trap makes that failure mode visible instead of
# silent, which is what hid the missing mktemp for three rounds of fixes.
trap 'log "ERROR: hook aborted (exit $?) at line $LINENO: ${BASH_COMMAND}"' ERR

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
    local deadline=$(( $($date +%s) + 420 ))
    while (( $($date +%s) < deadline )); do
        remount_nas
        if [ -r "$VM_DISK" ]; then
            log "VM backing disk $VM_DISK is ready"
            return 0
        fi
        log "Waiting for $VM_DISK — share not exporting it yet"
        $sleep 5
    done
    log "ERROR: $VM_DISK not readable within 420 s — aborting VM start"
    return 1
}

any_vm_running() {
    $virsh --connect qemu:///system list --state-running --name 2>/dev/null \
        | $grep -q '[^[:space:]]'
}

unmount_nas() {
    # Tear down /mnt/VM before the NAS disappears. A CIFS mount left pointing
    # at a powered-off server goes stale: every stat() against it (df, file
    # managers, shell path completion) blocks for the CIFS timeout, and the
    # x-systemd.automount trigger re-arms on access so it keeps coming back —
    # this is what makes the whole system lag once the QNAP is off. Stop the
    # automount first so nothing re-triggers, then unmount while the share is
    # still reachable so it flushes cleanly.
    log "Unmounting /mnt/VM ahead of NAS poweroff"
    $systemctl stop mnt-VM.automount 2>/dev/null || true
    $systemctl stop mnt-VM.mount 2>/dev/null || true
    # Belt-and-braces: force + lazy unmount in case systemd left a stale handle
    # behind (e.g. the NAS vanished before this ran).
    $umount -f -l /mnt/VM 2>/dev/null || true
}

shutdown_nas() {
    if nas_reachable; then
        log "Sending detached poweroff to NAS via SSH"
        # id_ed25519 is passphrase-protected; feed the passphrase via SSH_ASKPASS
        # so ssh can unlock it non-interactively (same trick as the sshfs mount).
        local _askpass rc
        _askpass=$($mktemp)
        printf '#!/bin/sh\nexec /run/current-system/sw/bin/cat /run/agenix/id-ed25519-passphrase\n' > "$_askpass"
        $chmod 0700 "$_askpass"
        # QTS `poweroff` is a busybox applet that signals init. Run plainly as
        # `ssh host poweroff` the shutdown tears down sshd and SIGHUPs poweroff
        # before it completes, so the box never goes down. Detach it with setsid
        # (+ a short delay so ssh returns first) into its own session, and log
        # the ssh exit code rather than swallowing it so failures leave evidence.
        SSH_ASKPASS="$_askpass" SSH_ASKPASS_REQUIRE=force \
            $ssh \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=10 \
            -i /home/michal/.ssh/id_ed25519 \
            admin@"$NAS_IP" \
            'setsid sh -c "sleep 2; /sbin/poweroff" </dev/null >/dev/null 2>&1 &' \
            && rc=0 || rc=$?
        $rm -f "$_askpass"
        log "NAS poweroff dispatched (ssh rc=$rc) — verifying"
        # Confirm it actually powered off; harmless to block here since this runs
        # in the transient nas-power-shutdown service, and it records a verdict.
        local deadline=$(( $($date +%s) + 120 ))
        while (( $($date +%s) < deadline )); do
            $sleep 5
            if ! nas_reachable; then
                log "NAS confirmed powered off"
                return 0
            fi
        done
        log "WARNING: NAS still reachable 120 s after poweroff dispatch"
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
            unmount_nas
            shutdown_nas
        fi
        ;;
esac
