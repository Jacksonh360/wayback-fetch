#!/usr/bin/env bash
# Wave 5 - harvest the 288 captures the un-collapsed CDX query revealed.
# Wave 4 was rate-limited into 20 empty files, so this runs SLOW on purpose: -P 2, long backoff.
set -u
OUT=out5; mkdir -p "$OUT"; LOG="$OUT/log.txt"; : > "$LOG"
UA="Mozilla/5.0 (research; contact via github.com/Jacksonh360)"
ok(){ local f=$1; [ -s "$f" ] || return 1; [ "$(wc -c < "$f")" -ge 900 ] || return 1
  grep -qiE 'wayback machine has not archived|Job not found|internal server error|BlockedSiteError' "$f" && return 1; return 0; }
grab(){ local f=$1 u=$2 t
  for t in 1 2 3 4 5; do
    curl -sL -m 180 -A "$UA" -o "$f" "$u" && ok "$f" && { echo "OK   $(basename "$f") $(wc -c < "$f")" >> "$LOG"; sleep 1; return 0; }
    sleep $((t*10))
  done
  echo "FAIL $(basename "$f") $u" >> "$LOG"; rm -f "$f"; return 1; }
export -f grab ok; export UA LOG
awk -F'\t' -v o="$OUT" '$3 !~ /[ \"\\\\]/ {print o"/"$1, "https://web.archive.org/web/"$2"id_/"$3}' wayback_targets5.tsv \
 | xargs -P 2 -n 2 bash -c 'grab "$0" "$1"'
echo "captures: $(ls -1 "$OUT" | grep -c '^wb_')  failures: $(grep -c '^FAIL' "$LOG")" | tee -a "$LOG"
