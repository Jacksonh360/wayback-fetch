#!/usr/bin/env bash
mkdir -p out2; UA="Mozilla/5.0 (research; jacksonh_360@yahoo.com)"
q(){ n=$1; u=$2; for t in 1 2 3; do curl -sL -m 240 -A "$UA" "https://web.archive.org/cdx/search/cdx?url=$u&from=2025&to=2026&fl=timestamp,original,statuscode,mimetype,length&collapse=digest&limit=500" -o "out2/$n.txt" && [ -s "out2/$n.txt" ] && break; sleep 20; done; echo "$n $(wc -l < out2/$n.txt) rows" | tee -a out2/log.txt; sleep 3; }
q sightmap_embed_ap "sightmap.com/embed/y8px5r93v19*"
q sightmap_embed_hv "sightmap.com/embed/n9w616dmv71*"
q sightmap_api "sightmap.com/app/api/*"
q sightmap_all_2026 "sightmap.com/*"
q funnel_ap "*.funnelleasing.com/*proseavalon*"
q funnel_any "api.funnelleasing.com/*"
q prose_ap_all "proseavalonpointe.com/*"
q prose_hv_all "prosehorizonsvillage.com/*"
q tesora_all "livetesora.com/*"
# fetch the most recent sightmap embed capture pages if any
for n in sightmap_embed_ap sightmap_embed_hv; do head -3 "out2/$n.txt" | while read -r ts orig rest; do curl -sL -m 240 -A "$UA" -o "out2/${n}_$ts.html" "https://web.archive.org/web/${ts}id_/$orig"; echo "$n $ts $(wc -c < out2/${n}_$ts.html) bytes" | tee -a out2/log.txt; sleep 3; done; done
