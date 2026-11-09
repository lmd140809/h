#!/usr/bin/env bash
set -u
PX="http://144.79.173.66:1297"
U="https://core-gmc.freefiremobile.com/live/ABHotUpdates/ios/1.132.14"
SUF="C8FlSR9GjT~2BYX4te4JKgpru0llA~3D"

echo "== tai codepatch =="
curl -s -m 120 -x "$PX" -k -o /tmp/mz.cp -w "  http=%{http_code} size=%{size_download}\n" \
  "$U/gameassetbundles/codepatch/assembly-csharp-patch.$SUF"
echo -n "  sha1: "; openssl dgst -sha1 -binary /tmp/mz.cp | base64
echo -n "  gzip test: "; gzip -t /tmp/mz.cp 2>/dev/null && echo OK || echo FAIL

echo
echo "== gunzip =="
gunzip -c /tmp/mz.cp > /tmp/mz.raw 2>/dev/null || cp /tmp/mz.cp /tmp/mz.raw
echo -n "  raw size: "; stat -c%s /tmp/mz.raw
head -c 8 /tmp/mz.raw | od -An -c | head -1
