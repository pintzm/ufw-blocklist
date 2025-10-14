#!/bin/sh
set -eu

# ---- config ----
V4_OUT="/etc/ufw/blocklist.txt"
V6_OUT="/etc/ufw/blocklist6.txt"    # optional
TMPDIR="$(mktemp -d)"
V4_TMP="$TMPDIR/v4.txt"
V6_TMP="$TMPDIR/v6.txt"
ALLOWLIST_V4="/etc/ufw/blocklist-allow.txt"  # optional: IPs/CIDRs to exclude
ALLOWLIST_V6="/etc/ufw/blocklist6-allow.txt" # optional
USE_RELOAD=${USE_RELOAD:-false}

# Example sources (replace with what you actually want to use)
SOURCES_V4="
https://raw.githubusercontent.com/stamparm/ipsum/master/levels/4.txt
https://raw.githubusercontent.com/ktsaou/blocklist-ipsets/master/firehol_level1.netset
"
SOURCES_V6=""

log(){ logger -t ufw-blocklist-update -- "$@"; }

fetch_all() {
  out="$1"; shift
  : > "$out"
  for url in "$@"; do
    [ -n "$url" ] || continue
    log "pulling from $url"
    curl -fsSL "$url" | sed 's/\r$//' >> "$out" || log "warn: failed $url"
  done
}

# Fetch into tmp files
fetch_all "$V4_TMP" $SOURCES_V4
fetch_all "$V6_TMP" $SOURCES_V6

# Clean, keep only IPs/CIDRs, drop comments/blank, normalize & dedupe
clean_list() {
  infile="$1"; allow="$2"; outfile="$3"; family="$4"
  [ -s "$infile" ] || { return 0; } # if infile not exists, return without creating file
  # keep IPv4 or IPv6, allow CIDR
  case "$family" in
    4) grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$infile" ;;
    6) grep -Ei '([0-9a-f:]+:+)+[0-9a-f]+(/[0-9]{1,3})?' "$infile" ;;
  esac | awk 'NF' \
     | sort -u \
     | { [ -s "$allow" ] && grep -vxF -f "$allow" || cat; } \
     > "$outfile"
}

clean_list "$V4_TMP" "$ALLOWLIST_V4" "$V4_TMP.cleaned" 4
clean_list "$V6_TMP" "$ALLOWLIST_V6" "$V6_TMP.cleaned" 6

# Atomic replace if changed
replace_if_changed() {
  src="$1"; dst="$2"
  if [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; then
    if [ ! -f "$src" ]; then
      log "cannot stat $src: no such file"
    fi
    install -m 0644 "$src" "$dst"
    log "changed blocklist file $dst"
    return 0
  fi
  return 1
}

changed=false
[ -s "$V4_TMP.cleaned" ] && replace_if_changed "$V4_TMP.cleaned" "$V4_OUT" && changed=true || true
[ -s "$V6_TMP.cleaned" ] && replace_if_changed "$V6_TMP.cleaned" "$V6_OUT" && changed=true || true

# Rebuild ipsets only if lists changed (uses your after.init)
if $changed; then
  if $USE_RELOAD; then
    sudo ufw reload
    log "called ufw reload (atleast one blocklist changed and USE_RELOAD=true)"
  else
    /etc/ufw/after.init start
    log "called after.init start (atleast one blocklist changed)"
  fi
else
  log "no changes in blocklists"
fi

rm -rf "$TMPDIR"
