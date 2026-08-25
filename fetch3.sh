#!/usr/bin/env bash
# Wayback wave 3. Runs on GitHub Actions because web.archive.org is unreachable from the office network.
# Public URLs only. Two jobs:
#   (a) targeted CDX for the resolved SightMap API tokens, then fetch any captured JSON responses
#   (b) fan-out fetch of the capture list in wayback_targets.tsv (name<TAB>timestamp<TAB>url)
set -u
OUT=out3; mkdir -p "$OUT/cdx"; LOG="$OUT/log.txt"; : > "$LOG"
UA="Mozilla/5.0 (research; contact via github.com/Jacksonh360)"

ok() {  # a capture is good if it is non-trivial and is not a Wayback error page
  local f=$1
  [ -s "$f" ] || return 1
  [ "$(wc -c < "$f")" -ge 900 ] || return 1
  grep -qiE 'wayback machine has not archived|Job not found|internal server error|BlockedSiteError|<title>Wayback Machine</title>' "$f" && return 1
  return 0
}

grab() {  # grab <outpath> <url> ; 4 tries with backoff
  local f=$1 u=$2 t
  for t in 1 2 3 4; do
    curl -sL -m 180 -A "$UA" -o "$f" "$u" && ok "$f" && { echo "OK   $(basename "$f") $(wc -c < "$f")" >> "$LOG"; return 0; }
    sleep $((t*8))
  done
  echo "FAIL $(basename "$f") $u" >> "$LOG"; rm -f "$f"; return 1
}
export -f grab ok; export UA LOG

echo "== (a) SightMap API CDX ==" | tee -a "$LOG"
while IFS=$'\t' read -r asset token sid; do
  [ -z "${token:-}" ] && continue
  c="$OUT/cdx/cdx_sightmapapi_${token}.txt"
  for t in 1 2 3 4; do
    curl -sL -m 240 -A "$UA" -o "$c" \
      "https://web.archive.org/cdx/search/cdx?url=sightmap.com/app/api/v1/${token}/*&matchType=prefix&from=2024&to=2026&fl=timestamp,original,statuscode,mimetype,length&collapse=digest&limit=2000" \
      && [ -f "$c" ] && break
    sleep $((t*10))
  done
  n=$(wc -l < "$c" 2>/dev/null || echo 0)
  echo "CDX  $asset token=$token sightmap=$sid rows=$n" | tee -a "$LOG"
  # fetch every captured 200 JSON response for this token
  awk '$3=="200"{print $1"\t"$2}' "$c" 2>/dev/null | head -60 | while IFS=$'\t' read -r ts u; do
    grab "$OUT/wb_${ts}_sightmapapi_${token}.json" "https://web.archive.org/web/${ts}id_/${u}"
  done
done < tokens3.tsv

echo "== (b) page captures ==" | tee -a "$LOG"
# name<TAB>ts<TAB>url  ->  "outpath waybackurl" pairs, 4 at a time.
awk -F'\t' -v o="$OUT" '$3 !~ /[ \"\\\\]/ {print o"/"$1, "https://web.archive.org/web/"$2"id_/"$3}' wayback_targets.tsv \
 | xargs -P 4 -n 2 bash -c 'grab "$0" "$1"'

echo "== done ==" | tee -a "$LOG"
echo "captures: $(ls -1 "$OUT" | grep -c '^wb_')" | tee -a "$LOG"
grep -c '^FAIL' "$LOG" | sed 's/^/failures: /' | tee -a "$LOG"
