# Reset Linux Root Password

Reset the root password of an installed Linux system from SystemRescue, then reboot into that OS.

This script is designed for bare-metal Linux servers, dedicated servers, rescue environments and recovery operations. It detects the installed Linux operating system, mounts the root filesystem, changes only the `root` password, sets the installed OS as the next UEFI boot target where possible, and reboots automatically.

## Supported Operating Systems

* Ubuntu
* Debian
* CentOS
* AlmaLinux
* Rocky Linux
* RHEL-compatible systems

## Supported Filesystems

* ext2
* ext3
* ext4
* xfs

## Supported Disk Layouts

* Plain partitions
* LVM-based installations

## Features

* Resets the root password from SystemRescue
* Automatically detects the installed Linux root filesystem
* Supports Ubuntu, Debian, CentOS, AlmaLinux, Rocky Linux and RHEL-compatible systems
* Supports ext2, ext3, ext4 and xfs root filesystems
* Supports plain partitions and LVM
* Uses `/etc/os-release` for content-based OS detection
* Uses `/usr/sbin/chpasswd` with absolute path for better SystemRescue compatibility
* Mounts the installed OS and runs password reset inside `chroot`
* Sets UEFI BootNext to the installed OS when possible
* Forces reboot after success or failure
* Only changes the root password
* Does not reinstall, format or delete any data

## Important Security Notice

Do not upload a real root password to a public GitHub repository.

Before publishing the script, change the password line to a placeholder:

```
NEWPW='CHANGE_ME'
```

Then edit it before running the script in rescue mode.

The script contains the password in plain text while it runs. Use it only on servers you own or are authorized to manage.

## Repository Files

```
reset-linux-root-password/
├── reset-linux-root.sh
└── README.md
```

## How to Run

The script must be run as root inside SystemRescue or another compatible rescue environment.

Common usage methods:

* Direct execution from GitHub raw URL
* Download and run manually
* Clone the repository and run the script

## Direct Execution

Run directly with curl:

```
curl -fsSL https://raw.githubusercontent.com/oguzhaze/reset-linux-root-password/main/reset-linux-root.sh | bash
```

Run directly with wget:

```
wget -qO- https://raw.githubusercontent.com/oguzhaze/reset-linux-root-password/main/reset-linux-root.sh | bash
```

Before using direct execution, make sure the script in the repository contains the correct `NEWPW` value.

## Download and Run

Download the script:

```
wget -O reset-linux-root.sh https://raw.githubusercontent.com/oguzhaze/reset-linux-root-password/main/reset-linux-root.sh
```

Edit the password value:

```
nano reset-linux-root.sh
```

Set the new root password:

```
NEWPW='CHANGE_ME'
```

Make the script executable:

```
chmod +x reset-linux-root.sh
```

Run the script:

```
bash reset-linux-root.sh
```

## Clone and Run

Clone the repository:

```
git clone https://github.com/oguzhaze/reset-linux-root-password.git
cd reset-linux-root-password
```

Edit the password value:

```
nano reset-linux-root.sh
```

Set the new root password:

```
NEWPW='CHANGE_ME'
```

Make the script executable:

```
chmod +x reset-linux-root.sh
```

Run the script:

```
bash reset-linux-root.sh
```

## Script Configuration

Edit this line before running the script:

```
NEWPW='CHANGE_ME'
```

Example:

```
NEWPW='MyNewSecurePassword123'
```

Do not leave the default example password in production usage.

## What the Script Does

The script performs the following steps:

1. Activates LVM volume groups
2. Clears SystemRescue auto-mounted partitions
3. Scans block devices with `lsblk`
4. Checks supported filesystems
5. Mounts each candidate filesystem read-only for probing
6. Detects the installed OS using `/etc/os-release`
7. Verifies the Linux root filesystem using `/etc/shadow` and `/usr`
8. Mounts the detected root filesystem
9. Bind-mounts `/dev`, `/dev/pts`, `/proc` and `/sys`
10. Enters the installed OS using `chroot`
11. Changes the root password using `/usr/sbin/chpasswd`
12. Sets UEFI BootNext to the installed OS where possible
13. Reboots the server automatically

## Requirements

The script is intended to run inside SystemRescue.

Required tools:

```
bash
lsblk
mount
umount
chroot
lvm
udevadm
efibootmgr
reboot
```

The installed operating system must contain:

```
/usr/sbin/chpasswd
/etc/shadow
/etc/os-release
/usr
```

## LVM Support

The script activates LVM before searching for the installed OS root filesystem.

It runs:

```
lvm vgchange -a y
udevadm settle
```

This allows the script to detect root filesystems located inside LVM logical volumes.

## XFS Support

For xfs filesystems, the script supports read-only probing.

It first tries:

```
mount -o ro
```

If needed, it also tries:

```
mount -o ro,norecovery
```

This helps detect xfs root filesystems that may have an unclean log in rescue mode.

## UEFI BootNext Support

On UEFI systems, the script attempts to set the installed OS as the next boot target using `efibootmgr`.

It searches for boot entries matching:

```
ubuntu
debian
centos
alma
rocky
rhel
red hat
```

If a matching boot entry is found, the script sets it as the next boot target.

This helps prevent the server from booting back into rescue or PXE mode after the password reset.

## Automatic Reboot

The script always attempts to reboot after execution.

The reboot is handled through an EXIT trap, so it runs on both success and failure.

Reboot methods used:

```
reboot -f
systemctl reboot -ff
echo b > /proc/sysrq-trigger
```

## Safety Notes

The script only changes the `root` password inside the installed operating system.

It does not:

* Reinstall the OS
* Format disks
* Delete files
* Modify partitions
* Change users other than root
* Change SSH configuration
* Change firewall rules
* Change network settings

## Example Output

```
========================================================
RESET LINUX ROOT PASSWORD
========================================================
[*] Activating LVM and clearing rescue auto-mounts...
[*] Finding the OS root filesystem...
[OK] OS root: /dev/mapper/ubuntu--vg-root  (Ubuntu 24.04 LTS)
[OK] root password updated.
[+] Done. Reboot into the installed OS.
[*] Next boot set to the OS (Boot0001).
```

## Troubleshooting

If no supported Linux root is found, verify that the installed OS uses one of the supported filesystems:

```
ext2 ext3 ext4 xfs
```

If the password reset fails, make sure the installed operating system contains:

```
/usr/sbin/chpasswd
/etc/shadow
/etc/os-release
```

If the server boots back into rescue mode, check:

* UEFI boot entries
* PXE boot order
* Rescue boot configuration
* Whether `efibootmgr` is available
* Whether the installed OS has a valid bootloader entry

If the root filesystem is inside LVM, verify that LVM volumes are visible:

```
lvs
vgs
lsblk
```

## License

MIT License
