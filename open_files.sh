#!/bin/bash
# open.sh - show what is holding Unraid array disks / pools busy
# Usage: ./open.sh [-a] [path ...]
#   no path : everything open on array disks, pools, /mnt/user, /mnt/user0
#   path    : only files under that directory, e.g. /mnt/user/Media
#   -a      : also show shfs handles on the disks (hidden by default)

usage() { echo "Usage: $0 [-a] [path ...]"; exit 1; }

# Physical locations: array disks + pools
phys=()
for d in /mnt/disk[0-9]*; do [ -d "$d" ] && phys+=("$d"); done
for cfg in /boot/config/pools/*.cfg; do
  [ -e "$cfg" ] && phys+=("/mnt/$(basename "$cfg" .cfg)")
done
roots=("${phys[@]}" /mnt/user /mnt/user0)

# Parse arguments
SHOW_SHFS=0
filters=()
for arg in "$@"; do
  case "$arg" in
    -a) SHOW_SHFS=1 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $arg"; usage ;;
    *)
      p=${arg%/}
      [ -e "$p" ] || { echo "Path not found: $arg"; exit 1; }
      ok=0
      for r in "${roots[@]}"; do
        if [[ "$p" == "$r" || "$p" == "$r"/* ]]; then ok=1; break; fi
      done
      [ $ok -eq 1 ] || { echo "Not on the array, a pool or a user share: $arg"; exit 1; }
      filters+=("$p")
      # /mnt/user/<x> also matches /mnt/diskN/<x> and /mnt/<pool>/<x>
      case "$p" in
        /mnt/user/*|/mnt/user0/*)
          rel=${p#/mnt/user*/}
          for ph in "${phys[@]}"; do filters+=("$ph/$rel"); done ;;
      esac ;;
  esac
done

# Every mount at or below the roots (includes ZFS child datasets)
mapfile -t targets < <(awk -v r="${roots[*]}" '
  BEGIN { n = split(r, a, " ") }
  { for (i = 1; i <= n; i++)
      if ($2 == a[i] || index($2, a[i] "/") == 1) { print $2; break } }
' /proc/mounts | sort -u)

if [ ${#targets[@]} -eq 0 ]; then
  echo "No array or pool mounts found - is the array started?"
  exit 1
fi

# Container ID -> name
declare -A CNAME PIDCONT PIDNAME
while read -r id name; do
  [ -n "$id" ] && CNAME[$id]=$name
done < <(docker ps --no-trunc --format '{{.ID}} {{.Names}}' 2>/dev/null)

# Pass filters to awk (empty = no filtering)
if [ ${#filters[@]} -gt 0 ]; then
  FILTERS=$(printf '%s\n' "${filters[@]}")
else
  FILTERS=""
fi
export FILTERS

rows=$(lsof -w -n -P +c 0 -F pcLfn -- "${targets[@]}" 2>/dev/null | awk -v show="$SHOW_SHFS" '
  BEGIN {
    nf = 0
    if (ENVIRON["FILTERS"] != "") nf = split(ENVIRON["FILTERS"], flt, "\n")
  }
  /^p/ { pid = substr($0, 2) }
  /^c/ { cmd = substr($0, 2) }
  /^L/ { usr = substr($0, 2) }
  /^f/ { fd  = substr($0, 2) }
  /^n/ {
    file = substr($0, 2)
    if (cmd == "shfs" && show == 0) next
    if (nf > 0) {
      hit = 0
      for (i = 1; i <= nf; i++)
        if (flt[i] != "" && (file == flt[i] || index(file, flt[i] "/") == 1)) { hit = 1; break }
      if (!hit) next
    }
    print pid "\t" cmd "\t" usr "\t" fd "\t" file
  }
' | sort -t$'\t' -u -k1,1n -k5,5 -k4,4)

if [ -z "$rows" ]; then
  if [ ${#filters[@]} -gt 0 ]; then
    echo "No open files under: ${filters[0]}"
  else
    echo "No open files on array disks or pools."
  fi
else
  printf "%-7s %-20s %-8s %-5s %-16s %-8s %s\n" PID PROCESS USER FD CONTAINER/VM DISK FILE
  printf "%-7s %-20s %-8s %-5s %-16s %-8s %s\n" --- ------- ---- -- ------------ ---- ----
  while IFS=$'\t' read -r pid cmd usr fd file; do
    if [ -z "${PIDCONT[$pid]+x}" ]; then
      owner="-"
      args=$(ps -o args= -p "$pid" 2>/dev/null)
      cid=$(grep -oE '[0-9a-f]{64}' /proc/"$pid"/cgroup 2>/dev/null | head -1)
      if [ -n "$cid" ] && [ -n "${CNAME[$cid]+x}" ]; then
        owner=${CNAME[$cid]}
      elif [[ "$cmd" == virtiofsd* ]]; then
        # Find the running VM that shares this path via virtiofs
        while IFS= read -r v; do
          [ -z "$v" ] && continue
          while IFS= read -r d; do
            [ -z "$d" ] && continue
            if [[ "$file" == "$d" || "$file" == "$d"/* ]]; then owner="VM:$v"; break 2; fi
          done < <(virsh dumpxml "$v" 2>/dev/null | sed -nE "s/.*<source dir='([^']+)'.*/\1/p")
        done < <(virsh list --name 2>/dev/null)
      fi
      PIDCONT[$pid]=$owner

      pname=$cmd
      if [[ "$cmd" == smbd* ]]; then
        ip=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<< "$args" | head -1)
        [ -n "$ip" ] && pname="smbd[$ip]"
      fi
      PIDNAME[$pid]=$pname
    fi

    case "$file" in
      /mnt/user/*|/mnt/user0/*)
        rel=${file#/mnt/user*/}
        disk="?"
        for ph in "${phys[@]}"; do
          if [ -e "$ph/$rel" ]; then disk=$(basename "$ph"); break; fi
        done ;;
      *) disk=$(echo "$file" | cut -d/ -f3) ;;
    esac

    printf "%-7s %-20s %-8s %-5s %-16s %-8s %s\n" \
      "$pid" "${PIDNAME[$pid]}" "$usr" "$fd" "${PIDCONT[$pid]}" "$disk" "$file"
  done <<< "$rows"
fi

# Loop devices (docker.img / libvirt.img) also block unmounting
if [ ${#filters[@]} -eq 0 ]; then
  loops=$(losetup -a 2>/dev/null | grep '/mnt/')
  if [ -n "$loops" ]; then
    echo
    echo "Loop devices backed by array/pool files (stop Docker/VM service to release):"
    echo "$loops"
  fi
fi
