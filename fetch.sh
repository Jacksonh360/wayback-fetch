#!/usr/bin/env bash
mkdir -p out; UA="Mozilla/5.0 (research; jacksonh_360@yahoo.com)"
i=0
while read -r u; do i=$((i+1)); for t in 1 2 3 4; do curl -sL -m 240 -A "$UA" -o "out/cap$i.html" -w "cap$i try$t %{http_code} %{size_download} %{url_effective}\n" "$u" | tee -a out/log.txt | grep -q " 200 " && break; sleep 20; done; sleep 3; done <<'U'
https://web.archive.org/web/20260121094642id_/https://proseavalonpointe.com/floorplans/
https://web.archive.org/web/20251014id_/https://proseavalonpointe.com/floorplans/
https://web.archive.org/web/20260312164741id_/https://prosehorizonsvillage.com/floorplans/
https://web.archive.org/web/20250908id_/https://prosehorizonsvillage.com/floorplans/
https://web.archive.org/web/20250621170954id_/https://www.livetesora.com/floor-plans/
https://web.archive.org/web/20260115id_/https://prosestevenspointe.com/floorplans/
https://web.archive.org/web/20251015id_/https://prosestevenspointe.com/floorplans/
U
for s in proseavalonpointe.com prosehorizonsvillage.com prosestevenspointe.com livetesora.com; do
  curl -sL -m 180 -A "$UA" "https://web.archive.org/cdx/search/cdx?url=$s/*&from=202506&to=202608&fl=timestamp,original,statuscode,digest&filter=statuscode:200&collapse=digest" -o "out/cdx_$s.txt" || true; for t in 1 2 3; do [ -s "out/cdx_$s.txt" ] && break; sleep 20; curl -sL -m 240 -A "$UA" "https://web.archive.org/cdx/search/cdx?url=$s/*&from=202506&to=202608&fl=timestamp,original,statuscode,digest&filter=statuscode:200&collapse=digest" -o "out/cdx_$s.txt"; done; echo "cdx $s $(wc -l < out/cdx_$s.txt) rows" | tee -a out/log.txt; sleep 3
done
for f in out/cap*.html; do echo "$f prices: $(grep -oE 'priceDisplayNoFees":"\$[0-9,]+|base-rent">\$[0-9,]+' "$f" | wc -l)" | tee -a out/log.txt; done
