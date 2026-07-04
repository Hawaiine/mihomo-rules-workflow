#!/usr/bin/env bash
# sync-upstream.sh — 从 v2fly + Loyalsoldier 同步上游规则数据
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULESET_DIR="$PROJECT_ROOT/ruleset"
mkdir -p "$RULESET_DIR"
RAW_V2FLY="https://raw.githubusercontent.com/v2fly/domain-list-community/master/data"
RAW_LOYAL_BASE="https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release"

now() { TZ=Asia/Shanghai date +'%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(now)] $*"; }
to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }
cleanup_dir() { rm -rf "$1" 2>/dev/null || true; }

parse_rules() {
  local file="$1"; local -n _d=$2; local -n _s=$3
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue; [[ "$line" =~ ^payload: ]] && continue; [[ "$line" =~ ^include: ]] && continue
    line="${line%%#*}"; line="$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | xargs)"
    [[ -z "$line" ]] && continue
    if   [[ "$line" =~ ^\+\.(.+)$ ]]; then _s+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^047(.+)047$ ]]; then _d+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|IP-CIDR|IP-CIDR6)[[:space:]]*, ]]; then
      local t="$(echo "$line" | cut -d',' -f1 | xargs)"; local v="$(echo "$line" | cut -d',' -f2- | xargs)"
      [[ "$t" == "DOMAIN" ]] && _d+=("$v") || _s+=("$v")
    elif [[ "$line" =~ ^(full:)?([^@[:space:]]+) ]]; then
      local p="${BASH_REMATCH[1]:-}"; local v="${BASH_REMATCH[2]}"; [[ -z "$v" ]] && continue
      [[ "$p" == "full:" ]] && _s+=("$v") || _d+=("$v")
    fi
  done < "$file"
}

write_ruleset() {
  local file="$1" brand="$2"; local -n d=$3 s=$4
  mapfile -t d < <(printf '%s\n' "${d[@]}" | sort -u)
  mapfile -t s < <(printf '%s\n' "${s[@]}" | sort -u)
  local dc=${#d[@]} sc=${#s[@]}
  { echo "# ==========================================="; echo "# Rule Name: $brand"; echo "# Author: mihomo-rules-workflow"; echo "# Updated: $(now)"; echo "# DOMAIN: $dc"; echo "# DOMAIN-SUFFIX: $sc"; echo "# ==========================================="; echo "payload:"; echo "  # --- DOMAIN 条目（按字母序） ---"; for i in "${d[@]}"; do echo "  - DOMAIN,$i"; done; echo "  # --- DOMAIN-SUFFIX 条目（按字母序） ---"; for i in "${s[@]}"; do echo "  - DOMAIN-SUFFIX,$i"; done; } > "$file"
  log "  Wrote $file (DOMAIN=$dc, SUFFIX=$sc)"
}

sync_brand() {
  local brand="$1"; local file="$RULESET_DIR/${brand}.yaml"
  local lower="$(to_lower "$brand")" v2fly_lower="$lower"
  case "$brand" in Porn) v2fly_lower="category-porn" ;; NHK) v2fly_lower="nhk" ;; esac
  log "Syncing $brand ..."
  local tmp="$(mktemp -d)" domains=() suffixes=() fetched=0

  # 1. v2fly
  if curl -fsSL --connect-timeout 20 --max-time 60 "$RAW_V2FLY/$v2fly_lower" -o "$tmp/v2fly.txt" 2>/dev/null; then
    log "  Fetched v2fly: $RAW_V2FLY/$v2fly_lower"
    local depth=0; cp "$tmp/v2fly.txt" "$tmp/all.txt" 2>/dev/null || true
    while grep -q "^include:" "$tmp/v2fly.txt" 2>/dev/null && [[ $depth -lt 5 ]]; do
      depth=$((depth+1))
      for inc in $(grep "^include:" "$tmp/v2fly.txt" | sed 's/^include://' | sort -u); do
        [[ -f "$tmp/done_${inc}" ]] && continue
        if curl -fsSL --connect-timeout 20 --max-time 60 "$RAW_V2FLY/$inc" -o "$tmp/include_${inc}.txt" 2>/dev/null; then
          cat "$tmp/include_${inc}.txt" >> "$tmp/all.txt"; touch "$tmp/done_${inc}"
          log "    [depth $depth] include: $inc"
        fi
      done
      [[ -f "$tmp/all.txt" ]] && mv "$tmp/all.txt" "$tmp/v2fly.txt"
    done
    grep -v "^include:" "$tmp/v2fly.txt" > "$tmp/clean.txt" 2>/dev/null || true
    mv "$tmp/clean.txt" "$tmp/v2fly.txt" 2>/dev/null || true
    parse_rules "$tmp/v2fly.txt" domains suffixes; fetched=1
  fi

  # 2. Loyalsoldier
  for fname in "$lower" "proxy-$lower" "$lower.txt" "proxy-$lower.txt"; do
    local url="$RAW_LOYAL_BASE/$fname"
    if curl -fsSL --connect-timeout 20 --max-time 60 "$url" -o "$tmp/loyal.txt" 2>/dev/null; then
      log "  Fetched Loyalsoldier: $url"
      mapfile -t ld < <(awk -F"'" '/^[[:space:]]*-[[:space:]]*'\''[^+]/ {print $2}' "$tmp/loyal.txt")
      for d in "${ld[@]}"; do domains+=("$d"); done
      mapfile -t ls < <(awk -F"'" '/^[[:space:]]*-[[:space:]]*'\''\+\./{sub(/^\+\./,"",$2); print $2}' "$tmp/loyal.txt")
      for s in "${ls[@]}"; do suffixes+=("$s"); done
      break
    fi
  done

  cleanup_dir "$tmp"
  write_ruleset "$file" "$brand" domains suffixes
}

sync_base() {
  local bases=(Direct Proxy Reject Private LanCIDR CNCIDR Telegram Applications)
  for base in "${bases[@]}"; do
    local file="$RULESET_DIR/${base}.yaml" lower="$(to_lower "$base")"
    log "Syncing base $base ..."
    local tmp="$(mktemp -d)" domains=() suffixes=() ipcidrs=() loyal_url="" fetched=0

    case "$base" in
      Direct)   loyal_url="$RAW_LOYAL_BASE/direct.txt" ;;
      Proxy)    loyal_url="$RAW_LOYAL_BASE/proxy.txt" ;;
      Reject)   loyal_url="$RAW_LOYAL_BASE/reject.txt" ;;
      Private)  loyal_url="$RAW_LOYAL_BASE/private.txt" ;;
      CNCIDR)   loyal_url="$RAW_LOYAL_BASE/cncidr.txt" ;;
      Applications) loyal_url="$RAW_LOYAL_BASE/apple.txt" ;;
    esac

    [[ -n "$loyal_url" ]] && curl -fsSL --connect-timeout 20 --max-time 60 "$loyal_url" -o "$tmp/source.txt" 2>/dev/null && fetched=1

    if [[ "$base" == "LanCIDR" ]]; then
      ipcidrs=(10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32 ::1/128 fc00::/7 fe80::/10)
    fi

    if [[ $fetched -eq 1 ]] && [[ "$loyal_url" == *.txt ]]; then
      mapfile -t domains < <(awk -F"'" '/^[[:space:]]*-[[:space:]]*'\''[^+]/ {print $2}' "$tmp/source.txt")
      mapfile -t suffixes < <(awk -F"'" '/^[[:space:]]*-[[:space:]]*'\''\+\./{sub(/^\+\./,"",$2); print $2}' "$tmp/source.txt")
      mapfile -t ipcidrs < <(awk -F"'" '/^[[:space:]]*-[[:space:]]*'\''[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{print $2}' "$tmp/source.txt")
    fi

    cleanup_dir "$tmp"
    mapfile -t domains < <(printf '%s\n' "${domains[@]}" | sort -u)
    mapfile -t suffixes < <(printf '%s\n' "${suffixes[@]}" | sort -u)
    mapfile -t ipcidrs < <(printf '%s\n' "${ipcidrs[@]}" | sort -u)

    local dc=${#domains[@]} sc=${#suffixes[@]} ic=${#ipcidrs[@]}
    {
      echo "# ==========================================="; echo "# Rule Name: $base"; echo "# Author: mihomo-rules-workflow"; echo "# Updated: $(now)"; echo "# DOMAIN: $dc"; echo "# DOMAIN-SUFFIX: $sc"; echo "# IP-CIDR: $ic"; echo "# ==========================================="; echo "payload:"; echo "  # --- DOMAIN 条目 ---"; for d in "${domains[@]}"; do echo "  - DOMAIN,$d"; done; echo "  # --- DOMAIN-SUFFIX 条目 ---"; for s in "${suffixes[@]}"; do echo "  - DOMAIN-SUFFIX,$s"; done; echo "  # --- IP-CIDR 条目 ---"; for ip in "${ipcidrs[@]}"; do echo "  - IP-CIDR,$ip"; done
    } > "$file"
    log "  Wrote $file (DOMAIN=$dc, SUFFIX=$sc, IP-CIDR=$ic)"
  done
}

auto_discover() {
  log "Checking for empty ruleset files..."
  while IFS= read -r file; do
    local base="$(basename "$file" .yaml)"
    case "$base" in Direct|Proxy|Reject|Private|LanCIDR|CNCIDR|Telegram|Applications) continue ;; esac
    [[ $(grep -c "^  - DOMAIN," "$file" || true) -gt 0 || $(grep -c "^  - DOMAIN-SUFFIX," "$file" || true) -gt 0 ]] && continue
    sync_brand "$base" > /dev/null 2>&1 || true
    nd=$(grep -c "^  - DOMAIN," "$file" || true); ns=$(grep -c "^  - DOMAIN-SUFFIX," "$file" || true)
    [[ $nd -gt 0 || $ns -gt 0 ]] && log "  ✅ $base: auto-filled (DOMAIN=$nd, SUFFIX=$ns)" || log "  ⚠️  $base: no upstream source"
  done < <(find "$RULESET_DIR" -name '*.yaml' -type f)
}

main() {
  cd "$PROJECT_ROOT"
  if [[ $# -eq 0 ]]; then
    log "Syncing all..."
    sync_base
    local brands=(OpenAI Anthropic Google YouTube Netflix Disney X Facebook Microsoft iCloud Amazon Spotify Hulu HBO PrimeVideo Reddit GitHub Cloudflare)
    for b in "${brands[@]}"; do sync_brand "$b" & done; wait
    auto_discover
  else
    sync_brand "$1"
  fi
}

main "$@"