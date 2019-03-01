#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/systemd/Sanity/subcomponents
#   Description: Check functionality of various systemd subcomponents.
#   Author: Frantisek Sumsal <fsumsal@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="systemd"
GEN_DIR="/usr/lib/systemd/system-generators"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlImport systemd/basic
    rlPhaseEnd
if false; then
    rlPhaseStartTest "systemd-analyze set-log-level segfault [BZ#1268336]"
        rlRun "systemd-analyze set-log-level" 1
    rlPhaseEnd

    rlPhaseStartTest "udevadm segfault [BZ#1365556]"
        rlRun "udevadm test-builtin path_id /sys/devices/platform" 0,1
    rlPhaseEnd

    rlPhaseStartTest "systemd mounts use deprecated -n option"
        rlFileBackup /etc/fstab
        IMG_PATH="$(mktemp "/diskXXX.img")"
        MNT_PATH="$(mktemp -d /mnt/systemd-testXXX)"
        rlRun "dd if=/dev/zero of=$IMG_PATH bs=1M count=32"
        rlRun "mkfs -t xfs $IMG_PATH"
        rlRun "echo '$IMG_PATH $MNT_PATH xfs defaults 0 0' >> /etc/fstab"
        rlRun "systemctl daemon-reload"
        rlRun "systemctl start $MNT_PATH"
        rlRun "systemctl status $MNT_PATH"
        rlRun "systemctl status $MNT_PATH | grep Process | grep ' \-n '" 1
        rlRun "systemctl stop $MNT_PATH"
        rlRun "rm -vfr $IMG_PATH $MNT_PATH"
        rlFileRestore
        rlRun "systemctl daemon-reload"
    rlPhaseEnd

    rlPhaseStartTest "backport x-systemd.idle-timeout [BZ#1354410]"
        rlFileBackup "/etc/fstab"
        DUMP_DIR="$(mktemp -d mounts.XXX)"
        MOUNT_NAME="$(mktemp -u testmntXXXXXX)"
        rlRun "echo '127.0.0.1:/storage /$MOUNT_NAME nfs noauto,x-systemd.automount,x-systemd.idle-timeout=1800 0 0' >> /etc/fstab"
        rlRun "${GEN_DIR}/systemd-fstab-generator '$DUMP_DIR' '$DUMP_DIR' '$DUMP_DIR'"
        rlRun "ls -la $DUMP_DIR"
        rlRun "cat '${DUMP_DIR}/${MOUNT_NAME}.automount'"
        rlAssertGrep "TimeoutIdleSec=30min" "${DUMP_DIR}/${MOUNT_NAME}.automount"
        rlRun "rm -fr '$DUMP_DIR'"
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartTest "Provides: \$network should pull network.target [BZ#1381769, BZ#1438749]"
        DUMP_DIR="$(mktemp -d sysv-gen.XXX)"
        rlRun "${GEN_DIR}/systemd-sysv-generator '$DUMP_DIR' '$DUMP_DIR' '$DUMP_DIR'"
        rlRun "cat '$DUMP_DIR/network.service'"
        rlAssertGrep "Wants=network.target" "$DUMP_DIR/network.service"
        rlRun "rm -fr '$DUMP_DIR'"
    rlPhaseEnd

    rlPhaseStartTest "Recognize Lustre as a remote filesystem [BZ#1390542]"
        rlFileBackup "/etc/fstab"
        DUMP_DIR="$(mktemp -d sysv-gen.XXX)"
        MOUNT_NAME="$(mktemp -u testmntXXXXXX)"
        rlRun "echo 'localhost:/test /$MOUNT_NAME lustre defaults 0 0' >> /etc/fstab"
        rlRun "${GEN_DIR}/systemd-fstab-generator '$DUMP_DIR' '$DUMP_DIR' '$DUMP_DIR'"
        rlAssertGrep "Type=lustre" "$DUMP_DIR/$MOUNT_NAME.mount"
        rlRun "[[ -h $DUMP_DIR/remote-fs.target.requires/$MOUNT_NAME.mount ]]"
        rlRun "rm -fr '$DUMP_DIR'"
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartTest "System fails to shutdown with /usr on iSCSI [BZ#1446171]"
        rlFileBackup "/etc/fstab"
        DUMP_DIR="$(mktemp -d sysv-gen.XXX)"
        rlRun "echo 'localhost:/test /usr ext4 _netdev 0 0' >> /etc/fstab"
        rlRun "${GEN_DIR}/systemd-fstab-generator '$DUMP_DIR' '$DUMP_DIR' '$DUMP_DIR'"
        rlAssertGrep "Options=_netdev" "$DUMP_DIR/usr.mount"
        rlRun "[[ ! -h $DUMP_DIR/initrd-root-fs.target.requires/usr.mount ]]"
        rlRun "rm -fr '$DUMP_DIR'"
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartTest "systemd-notify --ready fails [BZ#1381743]"
        SCRIPT_FILE="$(mktemp /usr/local/bin/systemd-notify-XXX.sh)"
        SERVICE_FILE="$(mktemp /etc/systemd/system/systemd-notify-XXX.service)"
        SERVICE_NAME="$(basename $SERVICE_FILE)"
cat > $SCRIPT_FILE << EOF
#!/bin/bash

systemd-notify --status="systemd-notify test service startup"
systemd-notify --ready
sleep 1d
EOF

cat > $SERVICE_FILE << EOF
[Unit]
Description=Test that systemd-notify works

[Service]
Type=notify
ExecStart=$SCRIPT_FILE
TimeoutStartSec=1
StartLimitInterval=0
NotifyAccess=all

[Install]
WantedBy=multi-user.target
EOF

        rlRun "cat $SCRIPT_FILE"
        rlRun "cat $SERVICE_FILE"
        rlRun "chmod +x $SCRIPT_FILE"
        rlRun "systemctl daemon-reload"
        rlRun "systemctl status $SERVICE_NAME" 0-255
        rlRun "systemctl start $SERVICE_NAME"

        rlRun "rm -fv $SCRIPT_FILE $SERVICE_FILE"
        rlRun "systemctl daemon-reload"
    rlPhaseEnd

    rlPhaseStartTest "udev: /usr/lib/udev/scsi_id -s switch doesn't work [BZ#1476910]"
        SCSI_BIN="/usr/lib/udev/scsi_id -v"
        DEV_PATH="$(findmnt / --output SOURCE -n)"
        rlLogInfo "Root partition is on $DEV_PATH"
        rlRun "$SCSI_BIN --sg-version=3 $DEV_PATH &> exp.out" 1
        rlLogInfo "Expected output:"
        rlRun "cat exp.out"

        for opt in "-s3" "-s 3"; do
            rm -f opt.out
            rlRun "$SCSI_BIN $opt $DEV_PATH &> opt.out" 1
            rlLogInfo "Output for option: $opt"
            rlRun "cat opt.out"
            rlAssertNotDiffer "exp.out" "opt.out"
        done

        rlRun "rm -fv exp.out opt.out"
    rlPhaseEnd

    rlPhaseStartTest "mount: unmount tmpfs before swap deactivation [BZ#1437518]"
        TMPFS_PATH="$(mktemp -d /tmp/swaptargetXXX)"
        TMPFS_NAME="${TMPFS_PATH##*/}"

        rlFileBackup "/etc/fstab"
        rlRun "echo 'tmpfs $TMPFS_PATH tmpfs defaults 0 0' >> /etc/fstab"
        rlRun "cat /etc/fstab"
        rlRun "systemctl daemon-reload"

        for mount in tmp-$TMPFS_NAME.mount tmp.mount; do
            rlLogInfo "Unit: $mount"
            rlRun "[[ '$(systemctl show -p After $mount)' =~ 'swap.target' ]]"
            if [[ $? -ne 0 ]]; then
                rlRun "systemctl --no-pager show $mount"
            fi
        done

        rlFileRestore
        rlRun "systemctl daemon-reload"
        rlRun "rm -fr $TMPFS_PATH"
    rlPhaseEnd

    rlPhaseStartTest "overlayfs: /etc/machine-id is not on a temporary file system [BZ#1472439]"
        LOWERDIR="$(mktemp -d lowerXXX)"
        UPPERDIR="$(mktemp -d upperXXX)"
        WORKDIR="$(mktemp -d workXXX)"
        MERGEDDIR="$(mktemp -d mergedXXX)"
        LOG_FILE="$(mktemp logXXX)"

        if rlIsRHEL "<=7"; then
            BIN="/usr/lib/systemd/systemd-machine-id-commit"
        else
            BIN="/usr/bin/systemd-machine-id-setup --commit"
        fi

        # Fake root FS for systemd-machine-id-commit
        rlRun "mkdir $LOWERDIR/etc"
        rlRun "cp /etc/machine-id $LOWERDIR/etc/machine-id"

        # Mount overlayfs
        rlRun "mount -t overlay overlay -o lowerdir=$LOWERDIR,upperdir=$UPPERDIR,workdir=$WORKDIR $MERGEDDIR"
        rlRun "stat $MERGEDDIR/etc/machine-id"

        # systemd-machine-id-commit should not fail
        rlRun "script -qec '$BIN --root $MERGEDDIR' &> $LOG_FILE"
        rlRun "cat $LOG_FILE"
        rlAssertNotGrep "not on a temporary file system" "$LOG_FILE"

        # Cleanup
        rlRun "umount $MERGEDDIR"
        rlRun "rm -fr $LOWERDIR $UPPERDIR $WORKDIR $MERGEDDIR $LOG_FILE"
    rlPhaseEnd

    rlPhaseStartTest "automount: ack automount requests even when already mounted [BZ#1535135]"
        rlRun "systemctl stop proc-sys-fs-binfmt_misc.mount"
        rlRun "timeout -s 9 --foreground 10s unshare -m ls -la /proc/sys/fs/binfmt_misc" 0,2
    rlPhaseEnd
fi
    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
