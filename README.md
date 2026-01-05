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
