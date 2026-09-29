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

# open.sh

A diagnostic Bash script for Unraid that identifies processes, open files, Docker containers, VMs, and loop devices holding array disks or cache/storage pools busy. It helps pinpoint why an array cannot stop or why specific disks fail to spin down or unmount.

---

## What the Script Does

1. **Scans Target Mounts:** Discovers physical array disks (`/mnt/disk*`), custom pools (`/boot/config/pools/*.cfg`), and user share mounts (`/mnt/user`, `/mnt/user0`), including nested ZFS datasets.
2. **Identifies Open Handles:** Uses `lsof` to find every open file on the discovered targets.
3. **Resolves Process Context:**
   - **Docker Containers:** Correlates process PIDs to container names via cgroups and `docker ps`.
   - **Virtual Machines:** Identifies `virtiofsd` processes to map open files directly to the running VM name (`VM:<name>`).
   - **SMB Connections:** Resolves `smbd` processes to the connected client IP (e.g., `smbd[192.168.1.50]`).
4. **Maps Files to Physical Media:** Translates high-level `/mnt/user/...` paths to their actual underlying disk or pool.
5. **Detects Loop Devices:** When run globally, checks for loopback mounts (such as `docker.img` or `libvirt.img`) anchored on `/mnt/` that prevent unmounting.

---

## Usage

```bash
./open.sh [-a] [-h|--help] [path ...]
```

### Options and Flags

| Flag / Argument | Description |
| --- | --- |
| `path ...` | Restricts the check to one or more directories (e.g., `/mnt/user/Media` or `/mnt/disk1`). When omitted, checks all array disks, pools, and user shares. |
| `-a` | Includes `shfs` file handles. By default, Unraid's user share filesystem driver handles are hidden to reduce noise. |
| `-h`, `--help` | Displays usage syntax and exits. |

---

## Examples

**1. Scan everything preventing the array from stopping**
```bash
./open.sh
```

**2. Check what is locking a specific user share**
```bash
./open.sh /mnt/user/Media
```
*Note: Specifying a `/mnt/user/<share>` path automatically checks both the fuse mount and the underlying physical disks hosting that share.*

**3. Check a specific physical disk**
```bash
./open.sh /mnt/disk2
```

**4. Include `shfs` handles**
```bash
./open.sh -a
```

---

## Output Fields

| Column | Description |
| --- | --- |
| **PID** | Process ID holding the open file handle. |
| **PROCESS** | Process name (shows client IP for `smbd`). |
| **USER** | Linux user running the process. |
| **FD** | File descriptor type/number (e.g., `cwd`, `txt`, `3r`, `12w`). |
| **CONTAINER/VM** | Docker container name, VM identifier (`VM:<name>`), or `-` if a host process. |
| **DISK** | Physical storage location (`disk1`, pool name, or `?` if unresolved). |
| **FILE** | Absolute path to the file or directory held open. |

# Docker Network Backup & Recovery Script

An automation Bash script for Unraid (and general Docker hosts) that inspects all custom Docker networks and generates an idempotent recovery script (`/boot/config/docker_network_restore.sh`) on the persistent flash drive.

---

## What the Script Does

1. **Discovers Custom Networks:** Uses `docker network ls` filtered to `type=custom` to isolate user-created networks (ignoring default system networks like `bridge`, `host`, and `none`).
2. **Inspects Network Metadata:** For each discovered network, extracts key configuration parameters:
   - **Driver:** The network driver in use (e.g., `bridge`, `macvlan`, `ipvlan`).
   - **IPAM Settings:** Configured subnets and gateways.
   - **Parent Interfaces:** Parent interface assignments (essential for `macvlan` or `ipvlan` configurations on Unraid, e.g., `br0` or `eth0`).
3. **Generates an Executable Restore Script:** Constructs the corresponding `docker network create` commands and writes them to `/boot/config/docker_network_restore.sh`.
4. **Idempotent Restoration:** Each generated command includes an existence check (`if [ ! "$(docker network ls | grep <net>)" ]; then ...; fi`) so the restore script can be run safely without errors or duplicating existing networks.
5. **Sets Permissions:** Ensures the generated restore script is immediately executable (`chmod +x`).

---

## File Locations

| Script | Default Path | Purpose |
| :--- | :--- | :--- |
| **Backup Script** | User-defined (e.g., User Scripts plugin) | Scans Docker and outputs the restore script. |
| **Recovery Script** | `/boot/config/docker_network_restore.sh` | Stored on the persistent Unraid flash boot drive for restoration after Docker image rebuilds or network resets. |

---

## Usage

### 1. Taking a Backup

Run the backup script directly from the Unraid terminal or configure it to run on a schedule using the **User Scripts** community application:

```bash
chmod +x docker_network_backup.sh
./docker_network_backup.sh
```

Upon completion, you will see:
```text
Network state saved to /boot/config/docker_network_restore.sh
```

### 2. Restoring Networks

If your Docker image file (`docker.img`) becomes corrupted, gets deleted, or if custom networks disappear after a system upgrade/reconfiguration, restore them by executing the generated file:

```bash
/boot/config/docker_network_restore.sh
```

---

## Best Practices & Tips

- **Automate with User Scripts:** Schedule the backup script to run periodically (e.g., weekly or at array start/stop) to guarantee any newly added custom Docker networks are automatically captured.
- **Persistent Flash Storage:** Saving to `/boot/config/` ensures the restore script survives Unraid OS reboots and array shutdowns, even if array pools or Docker services are offline.



