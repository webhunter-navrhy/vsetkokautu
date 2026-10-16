# Startér webu WebHunter

Neutrální základ bez designu. Design (koncept, typografie, barvy, layout) vymýšlíš pro konkrétního klienta v `src/` a `static/css/`.

    python3 build.py            # _data/*.json + src/*.html + img/ + static/  ->  dist/
    python3 build.py --serve    # + server na http://localhost:8765/<base>
    ./deploy.sh [--dry|--bez-qa] # push (main = zdroje, gh-pages = dist), čekání na Pages, HTTP 200, qa.py

Struktura: `_data/site.json` (firma, kontakt, base/url, `navrh`, formulář), `_data/*.json` (obsah, v šabloně `data.<soubor>`),
`src/*.html` (Jinja2; `_base.html`, `_formular.html`; stránka `kontakt.html` -> `/kontakt/`), `img/` (zdrojové fotky), `static/` (css, js, fonty).

Co build dělá sám: WebP + srcset 640/1280/1920 (`{{ img('foto.jpg', 'alt', sizes='...') }}`, alt je povinný, `alt=''` u dekoru),
první `img()` na stránce eager, ostatní lazy, `?v=<hash>` u CSS/JS (`{{ asset('css/style.css') }}`), `noindex` + `Disallow` pro `site.navrh=true`
(před ostrým spuštěním `navrh: false`, `base: "/"`, `url`, `domena`), JSON-LD z site.json, og:image 1200x630 z `site.og_image`,
sitemap.xml, robots.txt, 404.html, `.nojekyll`. Formulář: `site.formular.demo=true` nic neodesílá; ostrý režim potřebuje `endpoint`.

Pravidla: logo klienta vlevo v hlavičce (`site.logo` = soubor v `static/`), fonty self-host a test háčků, žádná vymyšlená čísla.
`img/placeholder.jpg` je jen zástupná fotka, nahraď ji.
