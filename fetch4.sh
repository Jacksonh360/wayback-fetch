#!/usr/bin/env bash
# Wave 4 - DISCOVERY ONLY. No page fetching. Answers: what else does the archive actually hold?
# Fixes three things wave 1-3 got wrong or never tried:
#   1. collapse=digest hid captures, and limit=500 silently truncated 3 queries -> paginate with resumeKey, no collapse
#   2. only the marketing host was queried -> add matchType=domain to catch leasing-backend subdomains
#   3. ILS listing pages were never checked in the ARCHIVE (archived captures are permitted; live scraping is not)
# Plus archive.today, which stores a RENDERED snapshot and would therefore contain JS-injected pricing.
set -u
OUT=out4; mkdir -p "$OUT/cdx"; LOG="$OUT/log.txt"; : > "$LOG"
UA="Mozilla/5.0 (research; contact via github.com/Jacksonh360)"

cdxq(){ # name url extra
  local n=$1 u=$2 extra=${3:-} out="$OUT/cdx/cdx_$n.txt" rk="" page=0 tmp
  : > "$out"
  while [ $page -lt 8 ]; do
    tmp=$(mktemp)
    local q="https://web.archive.org/cdx/search/cdx?url=${u}&fl=timestamp,original,statuscode,mimetype,length&limit=1000&showResumeKey=true${extra}"
    [ -n "$rk" ] && q="${q}&resumeKey=${rk}"
    curl -sL -m 300 -A "$UA" "$q" -o "$tmp" || { rm -f "$tmp"; break; }
    awk 'f{next} /^[[:space:]]*$/{f=1;next} {print}' "$tmp" >> "$out"
    rk=$(awk '/^[[:space:]]*$/{f=1;next} f{print;exit}' "$tmp")
    rm -f "$tmp"; page=$((page+1))
    [ -z "$rk" ] && break
    sleep 3
  done
  echo "CDX $n rows=$(wc -l < "$out") pages=$page" | tee -a "$LOG"
}

echo "== 1. no-collapse, paginated re-query of the four sites ==" | tee -a "$LOG"
cdxq tesora_full  "livetesora.com/*"           "&from=2024&to=2026"
cdxq tesora_dom   "livetesora.com"             "&matchType=domain&from=2024&to=2026"
cdxq ap_full      "proseavalonpointe.com/*"    "&from=2024&to=2026"
cdxq ap_dom       "proseavalonpointe.com"      "&matchType=domain&from=2024&to=2026"
cdxq hv_full      "prosehorizonsvillage.com/*" "&from=2024&to=2026"
cdxq hv_dom       "prosehorizonsvillage.com"   "&matchType=domain&from=2024&to=2026"
cdxq sp_full      "prosestevenspointe.com/*"   "&from=2024&to=2026"

echo "== 2. leasing-backend + pricing-API hosts ==" | tee -a "$LOG"
cdxq securecafe   "securecafe.com"   "&matchType=domain&filter=original:.*(tesora|livetesora).*&from=2023&to=2026"
cdxq rentcafe     "rentcafe.com"     "&matchType=domain&filter=original:.*(tesora|8131).*&from=2023&to=2026"
cdxq funnel_prose "funnelleasing.com" "&matchType=domain&filter=original:.*(proseavalon|prosehorizons|prosestevens|avalonpointe|horizonsvillage|stevenspointe).*&from=2024&to=2026"

echo "== 3. SightMap API by resolved token, no collapse ==" | tee -a "$LOG"
while IFS=$'\t' read -r asset token sid; do
  [ -z "${token:-}" ] && continue
  cdxq "smapi_${token}" "sightmap.com/app/api/v1/${token}/*" "&from=2023&to=2026"
  cdxq "smembed_${asset}" "sightmap.com/embed/*" "&filter=original:.*${token}.*&from=2023&to=2026"
done < tokens4.tsv

echo "== 4. ILS listing pages IN THE ARCHIVE (not live) ==" | tee -a "$LOG"
for h in apartments.com rent.com zillow.com forrent.com apartmentguide.com apartmentfinder.com padmapper.com hotpads.com apartmenthomeliving.com; do
  cdxq "ils_${h%%.*}" "$h" "&matchType=domain&filter=original:.*(tesora|avalon-pointe|avalonpointe|horizons-village|horizonsvillage|stevens-pointe|stevenspointe).*&from=2024&to=2026&limit=300"
done

echo "== 5. archive.today (stores a RENDERED snapshot, so JS-injected prices would be baked in) ==" | tee -a "$LOG"
i=0
for u in "https://www.livetesora.com/floor-plans/" "https://proseavalonpointe.com/floorplans/" "https://prosehorizonsvillage.com/floorplans/" "https://prosestevenspointe.com/floorplans/"; do
  i=$((i+1))
  for host in archive.ph archive.is archive.today; do
    curl -sL -m 90 -A "$UA" -o "$OUT/cdx/archivetoday_${i}_${host}.txt" "https://${host}/timemap/${u}" && \
      { echo "AT   $host #$i bytes=$(wc -c < "$OUT/cdx/archivetoday_${i}_${host}.txt")" | tee -a "$LOG"; break; }
  done
  sleep 2
done

echo "== summary ==" | tee -a "$LOG"
for f in "$OUT"/cdx/cdx_*.txt; do printf '%-34s %6s rows  %6s 200s  %4s json\n' "$(basename "$f" .txt)" "$(wc -l < "$f")" "$(awk '$3==200' "$f" | wc -l)" "$(awk '$4 ~ /json/' "$f" | wc -l)"; done | tee -a "$LOG"
