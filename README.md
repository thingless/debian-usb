This is the build script for a custom live USB of Debian. It supports a wide variety of overlay and in-RAM boot options. The USB has two data partitions:
- "System", which has a debian install. The author also recommends you install any additional packages to the system partition.
- "Config", which has all your changes after the install (home directory, configs, new installed packages)

==Requirements
- an internet connection
- sudo permissions (required to mount the image and to chown files as root in the chroot)
- debootstrap requirements: ar, wget, and sh
- fdisk
- BIOS that supports GPT, which includes all modern computers (UEFI is supported but not required)

==INSTALL
1. Edit the install script to match the size of your USB. Make sure to go a little under if you're unsure.
2. Run `sh bootstrap.sh`. The final printed line should be the location of the image (usually `/tmp/forget-base.img`).
3. Copy this onto your usb. For example, `dd if=/tmp/forget-base.img of=/dev/sdx status=progress`

==Build Script Features
- Single build file with few requirements
- Single USB boots both on EFI and non-EFI systems
- Generates a sparse image (only takes up the space of the files on disk, not the empty space in the filesystem)
- Customizable (any size image you want, and any packages you want)

==Overlay filesystems
An "overlay" filesystem is a combination of two filesystems. Ususally there is "lower" base filesystem which is essentially static. For example, in this live USB, this is where we store the entire base debian install. On top of that is a smaller and more frequently changed "upper" filesystem, which takes precedence. All changes to the running filesystem are written to the upper filesystem.

Common use cases for overlays include:
- Throwing away changes to return to a working system (Live CDs do this by keeping the upper filesystem in RAM, so it is thrown away after every reboot)
- Having several overlays of the same base filesystem, to save on space
- Tracking changes by looking at the upper filesystem (for example, the upper filesystem may consist only of newly installed packages, or of config file changes)
- Separating "system" data and "user" data

==USB Features
The USB has a "system" and a "config" partition. The "config" partition is initially empty. You can put whatever you want on the config partition of course--it's your system. The author keeps user and config data on the config partition, and installs new packages to the system partition.

The main feature of the USB are the varied and flexible boot modes allowed by the data partitions.

The boot modes are:
- **rw System Maintenance Boot** Boot only the system partition. Changes can be made. This is recommended for the very first boot, to customize your installed packages, and change the root password.
- **memfs In-memory System Boot** Boot only the system partition, but run entirely in RAM. Very fast, but all changes will be lost on reboot. The USB can be safely removed.
- **tmpfs/ro Temporary Overlay** This is the classic Live CD boot. On boot only the system partition is loaded, and any changes you make are discarded when you reboot.
- **rw/ro Persistent Overlay** Mounts the "config" partition as an overlay on the base system. All changes are written to "config" and will persist across reboots. The author uses this as their primary mode.
- **memfs/memfs In-memory Overlay** Mounts the "config" partition as an overlay on the base system, but runs entirely in RAM. Very fast, but all changes will be lost on reboot. The USB can be safely removed. Included to preserve the overlay information if you want to reformat/resize the USB partitions from a running system. The two bootloader partitions are not loaded into memory!
- **memfs Flat memory boot (of rw/ro overlay)** Mounts the "config" and "system" partitions, and runs entirely in RAM. Very fast, but all changes will be lost on reboot. The USB can be safely removed. Overlay information is not preserved.
- **tmpfs/ro/ro Temporary+Persistent Overlay** Extended Live CD mode. Mounts the "config" and "system" partitions, keeping your persistent changes from other boots. But for this boot only, all changes will be stored in memory and lost on reboot.
- MemTest86 and MemTest86+. These are standard memory test tools. They're nice to have on every boot USB.

Boot mode                                 |System files?|Config files?|Changes write to|Can remove USB|Memory use|/ is
-------------------------------------------------------------------------------------------------------------------------
rw System Maintenance Boot                |yes          |no           |system          |no            |0.25G     |ext4   
memfs In-memory System Boot               |yes          |no           |memory          |yes           |2.25G     |tmpfs  
tmpfs/ro Temporary Overlay                |yes          |no           |memory          |no            |0.25G     |overlay
rw/ro Persistent Overlay                  |yes          |yes          |config          |no            |0.25G     |overlay
memfs/memfs In-memory Overlay             |yes          |yes          |memory          |yes           |6.25G     |overlay
memfs Flat memory boot (of rw/ro overlay) |yes          |yes          |memory          |yes           |6.25G     |tmpfs  
tmpfs/ro/ro Temporary+Persistent Overlay  |yes          |yes          |memory          |no            |0.25G     |overlay

==Known Bugs
- grub.cfg is not automatically generated. Make sure to update it whenever you upgrade the kernel, or your boot will fail.
- The system is not especially secure--it's an unmodified debian install. There is only one user (root) with no password required. Also, ssh is enabled and automatically runs. If you harden the system (recommended), make sure to do it under the system partition--otherwise any "system" boots will ignore your changes.
- When using this script from the finished system, partitions will auto-mount during the build process

==HACKING

Live-booting other distros
--
You'll have to hack on it. The boot process is not really debian-specific. The installation and setup on the other hand are. You should be able to adapt this to something similar for any distro with some kind of chroot bootstrapping process (an equivalent to 'debootstrap' on debian).

Adding boot options
--
grub.cfg is completely hand-rolled because I think `update-grub` is a bad idea. But, that also means it's very readable. Take a look!
