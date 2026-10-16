#!/usr/bin/env bash
# Nasazení na GitHub Pages: webhunter-navrhy/<slug>, zdroje ve větvi main, sestavený web (dist/) ve větvi gh-pages.
#   ./deploy.sh              # build, commit, push, počkat na Pages, ověřit HTTP 200, spustit QA
#   ./deploy.sh --dry        # jen build + výpis, co by se stalo (nic se nepushne)
#   ./deploy.sh --bez-qa     # bez závěrečného qa.py
# Token: ~/.webhunter-gh-token (neukládá se do remote). Repo musí existovat (novy_web.py <slug> --repo).
set -euo pipefail
cd "$(dirname "$0")"
DRY=0; QA=1
for a in "$@"; do case "$a" in --dry) DRY=1;; --bez-qa) QA=0;; esac; done

PY="${PY:-/Library/Frameworks/Python.framework/Versions/3.14/bin/python3}"
export SSL_CERT_FILE="$($PY -c 'import certifi;print(certifi.where())')"
SLUG="$($PY -c 'import json;print(json.load(open("_data/site.json"))["slug"])')"
ORG="webhunter-navrhy"
REPO="$ORG/$SLUG"
URL="https://$ORG.github.io/$SLUG/"
TOKEN="$(cat ~/.webhunter-gh-token)"
export GH_TOKEN="$TOKEN"
REMOTE="https://github.com/$REPO.git"
PUSH_URL="https://x-access-token:${TOKEN}@github.com/$REPO.git"

[ "$SLUG" = "SLUG" ] && { echo "CHYBA: site.json má slug SLUG, nastav ho (novy_web.py to dělá)"; exit 2; }
echo "== build"; "$PY" build.py

if [ "$DRY" = 1 ]; then
  echo "DRY: pushnul bych zdroje do $REPO (main), dist/ do větve gh-pages, počkal na Pages a ověřil $URL, pak QA."
  exit 0
fi

echo "== main (zdroje)"
[ -d .git ] || git init -q -b main
git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$REMOTE" || git remote add origin "$REMOTE"
git add -A
git -c user.name="WebHunter" -c user.email="info@webhunter.cz" commit -q -m "Aktualizace webu $(date +%F\ %H:%M)" || echo "(nic nového k commitu)"
git push -q "$PUSH_URL" HEAD:main

echo "== gh-pages (dist/)"
TMP="$(mktemp -d)"; cp -R dist/. "$TMP/"; touch "$TMP/.nojekyll"
( cd "$TMP" && git init -q -b gh-pages && git add -A \
  && git -c user.name="WebHunter" -c user.email="info@webhunter.cz" commit -q -m "build $(date +%F\ %H:%M)" \
  && git push -q -f "$PUSH_URL" gh-pages )
rm -rf "$TMP"

echo "== Pages zapnuté?"
if ! gh api "repos/$REPO/pages" >/dev/null 2>&1; then
  gh api "repos/$REPO/pages" -X POST -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null
  echo "Pages zapnuty (gh-pages)"
fi

echo "== čekám na build Pages"
OPRAVENO=0
for i in $(seq 1 40); do
  ST="$(gh api "repos/$REPO/pages/builds/latest" --jq .status 2>/dev/null || echo unknown)"
  echo "  [$i] status: $ST"
  if [ "$ST" = "built" ]; then break; fi
  if [ "$ST" = "errored" ] && [ "$OPRAVENO" = 0 ]; then
    echo "  errored -> jednou znovu spouštím build"; gh api "repos/$REPO/pages/builds" -X POST >/dev/null || true; OPRAVENO=1
  elif [ "$ST" = "errored" ]; then echo "CHYBA: Pages build znovu selhal"; exit 3; fi
  sleep 8
done
[ "$ST" = "built" ] || { echo "CHYBA: Pages se nepostavily v limitu"; exit 3; }

echo "== HTTP 200 na $URL"
"$PY" - "$URL" <<'PYEOF'
import ssl, sys, time, urllib.request, certifi
u = sys.argv[1]; ctx = ssl.create_default_context(cafile=certifi.where())
for i in range(30):
    try:
        r = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), context=ctx, timeout=20)
        if r.status == 200:
            print("  200 OK"); sys.exit(0)
    except Exception as e:
        print("  čekám:", e)
    time.sleep(6)
print("CHYBA: web nevrací 200"); sys.exit(4)
PYEOF

if [ "$QA" = 1 ]; then
  echo "== QA"
  "$PY" ~/wh-navrhy-ops/tools/qa.py "$URL" "$PWD/qa" || { echo "QA našlo chyby (viz qa/qa.json)"; exit 1; }
fi
echo "HOTOVO: $URL"
