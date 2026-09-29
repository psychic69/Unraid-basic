# Unraid-basic
Basic tools and automation to enhance Unraid

## Unraid Go Script

The `go` script optimizes kernel I/O settings for enterprise SATA drives (both HDD and SSD) to improve performance and reliability. The script:

- Detects all connected storage drives (excluding USB devices)
- Automatically configures the I/O scheduler to `mq-deadline` for enterprise-class performance
- Sets the number of requests (`nr_requests`) to 512 for optimal queue depth
- Displays a formatted table of configured drives with their models, serial numbers, and applied settings
- Maintains a persistent log of configuration changes with automatic rotation

### Optional Sections

The script includes two optional paste sections at the bottom that are dependent on your Unraid configuration:

- **UNRAID SPECIFIC** (line 62-63): Restarts the Unraid HTTP daemon. Include this if you want the script to restart Unraid services after configuration.
- **NAS ONLY** (line 65-66): Applies additional sysctl settings from `/boot/config/sysctl.conf`. Include this only if you have custom sysctl configurations defined.

- open.shA diagnostic Bash script for Unraid that identifies processes, open files, Docker containers, VMs, and loop devices holding array disks or cache/storage pools busy. It helps pinpoint why an array cannot stop or why specific disks fail to spin down or unmount.What the Script DoesScans Target Mounts: Discovers physical array disks (/mnt/disk*), custom pools (/boot/config/pools/*.cfg), and user share mounts (/mnt/user, /mnt/user0), including nested ZFS datasets.Identifies Open Handles: Uses lsof to find every open file on the discovered targets.Resolves Process Context:Docker Containers: Correlates process PIDs to container names via cgroups and docker ps.Virtual Machines: Identifies virtiofsd processes to map open files directly to the running VM name (VM:<name>).SMB Connections: Resolves smbd processes to the connected client IP (e.g., smbd[192.168.1.50]).Maps Files to Physical Media: Translates high-level /mnt/user/... paths to their actual underlying disk or pool.Detects Loop Devices: When run globally, checks for loopback mounts (such as docker.img or libvirt.img) anchored on /mnt/ that prevent unmounting.UsageBash./open.sh [-a] [-h|--help] [path ...]
Options and FlagsFlag / ArgumentDescriptionpath ...Restricts the check to one or more directories (e.g., /mnt/user/Media or /mnt/disk1). When omitted, checks all array disks, pools, and user shares.-aIncludes shfs file handles. By default, Unraid's user share filesystem driver handles are hidden to reduce noise.-h, --helpDisplays usage syntax and exits.Examples1. Scan everything preventing the array from stoppingBash./open.sh
2. Check what is locking a specific user shareBash./open.sh /mnt/user/Media
Note: Specifying a /mnt/user/<share> path automatically checks both the fuse mount and the underlying physical disks hosting that share.3. Check a specific physical diskBash./open.sh /mnt/disk2
4. Include shfs handlesBash./open.sh -a
Output FieldsColumnDescriptionPIDProcess ID holding the open file handle.PROCESSProcess name (shows client IP for smbd).USERLinux user running the process.FDFile descriptor type/number (e.g., cwd, txt, 3r, 12w).CONTAINER/VMDocker container name, VM identifier (VM:<name>), or - if a host process.DISKPhysical storage location (disk1, pool name, or ? if unresolved).FILEAbsolute path to the file or directory held open.
