#!/usr/bin/env bash
set -u
PX="http://144.79.173.66:1297"
U="https://core-gmc.freefiremobile.com/live/ABHotUpdates/ios/1.132.14"

echo "== proxy song? =="
timeout 8 bash -c "cat </dev/null >/dev/tcp/144.79.173.66/1297" 2>/dev/null && echo "  TCP OPEN" || echo "  TCP CLOSED"

echo
echo "== fileinfo 1.132.14 =="
curl -s -m 25 -x "$PX" -k -o /tmp/mz.fi -w "  http=%{http_code} size=%{size_download}\n" "$U/fileinfo"
echo -n "  lines: "; wc -l < /tmp/mz.fi 2>/dev/null
grep -a "^codepatch/" /tmp/mz.fi 2>/dev/null | head -3

echo
echo "== fileinfo 1.132.13 =="
curl -s -m 25 -x "$PX" -k -o /tmp/mz13.fi -w "  http=%{http_code} size=%{size_download}\n" "https://core-gmc.freefiremobile.com/live/ABHotUpdates/ios/1.132.13/fileinfo"
grep -a "^codepatch/" /tmp/mz13.fi 2>/dev/null | head -2
rm -f /tmp/mz13.fi
