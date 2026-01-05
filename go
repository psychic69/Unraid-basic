#!/bin/bash

# 1. Define the Table Function (solves the "command not found" error)
generate_table() {
    printf "  %-5s | %-25s | %-15s | %-12s | %-7s\n" "DEV" "MODEL" "SERIAL" "SCHEDULER" "NR_REQ"
    echo "--------------------------------------------------------------------------------------------"
    for i in "${!DRIVES_TO_MODIFY[@]}"; do
        drive="${DRIVES_TO_MODIFY[$i]}"
        IFS='|' read -r d_name d_type d_tran d_model d_serial <<< "${DRIVE_DETAILS[$i]}"
        if [ -e "/sys/block/$drive" ]; then
            # Apply Settings
            echo mq-deadline > "/sys/block/$drive/queue/scheduler" 2>/dev/null
            echo 512 > "/sys/block/$drive/queue/nr_requests" 2>/dev/null
            # Read back
            current_sch=$(cat "/sys/block/$drive/queue/scheduler" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
            current_nr=$(cat "/sys/block/$drive/queue/nr_requests" 2>/dev/null)
            printf "  %-5s | %-25.25s | %-15.15s | %-12s | %-7s\n" "$drive" "$d_model" "$d_serial" "$current_sch" "$curr
ent_nr"
        fi
    done
}

# 2. Collect Drive Data
DRIVES_TO_MODIFY=()
DRIVE_DETAILS=()
while IFS= read -r line; do
    eval "$line"
    if [ "$TRAN" != "usb" ]; then
        DRIVES_TO_MODIFY+=("$NAME")
        [ "$ROTA" = "1" ] && type="HDD" || type="SSD"
        DRIVE_DETAILS+=("$NAME|$type|$TRAN|$MODEL|$SERIAL")
    fi
done < <(lsblk -d -n -P -o NAME,ROTA,TRAN,MODEL,SERIAL | grep 'NAME="sd')

# 3. Output to Console
echo "Configuring I/O settings for detected storage drives..."
echo "--------------------------------------------------------------------------------------------"
generate_table
echo "--------------------------------------------------------------------------------------------"
echo "I/O configuration complete"

# 4. Persistent Logging with Auto-Rotate
LOG_DIR="/boot/config/logs/io_settings"
LOG_FILE="$LOG_DIR/history.log"

# Create directory if it doesn't exist
mkdir -p "$LOG_DIR"

# If log is over 500 lines (approx 10-15 boots), trim it to keep the last 100 lines
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 500 ]; then
    sed -i '1,400d' "$LOG_FILE"
fi

{
    echo "--- Boot Record: $(date '+%Y-%m-%d %H:%M:%S') ---"
    generate_table
    echo "--------------------------------------------------------------------------------------------"
    echo ""
} >> "$LOG_FILE"


##########UNRAID SPECIFIC
/usr/local/sbin/emhttp

##########NAS ONLY CUT HERE
sysctl -p /boot/config/sysctl.conf