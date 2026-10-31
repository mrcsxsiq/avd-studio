# AVD Studio website

The public landing page for AVD Studio. Plain HTML, CSS and a little vanilla JavaScript: no framework, no build
step, no CDN, no web fonts, no analytics. The only request the page makes is one call to the GitHub Releases API
from the download button (see "Download button" below).

It is published with GitHub Actions by [`.github/workflows/pages.yml`](../.github/workflows/pages.yml) and has to
work, unchanged, at both:

- `https://mrcsxsiq.github.io/avd-studio/` (a project site under a path prefix), and
- `https://avdstudio.dev/` (a domain root, once DNS exists).

## Layout

```
website/
  index.html            the page
  404.html              not-found page (the one page that uses absolute URLs)
  robots.txt            uses __SITE_URL__
  sitemap.xml           uses __SITE_URL__
  site.webmanifest      relative URLs only
  .nojekyll             tells Pages to serve the files as they are
  assets/
    style.css, main.js  the whole front end
    *.webp              screenshots (light and dark pairs, 800 and 1600 px wide)
    icon-*.png, favicon*, apple-touch-icon.png, og.png
  tools/
    make-og.swift       renders assets/og.png (run with `swift website/tools/make-og.swift`)
    check-site.py       link checker (run with `python3 -I website/tools/check-site.py`)
```

`tools/` and this README are not published: the workflow leaves them out of the Pages artifact.

## The two URL rules

1. **Everything is a relative URL** (`assets/style.css`, `./`, `#install`), never root-relative (`/assets/...`).
   A root-relative URL points at `mrcsxsiq.github.io/assets/...` on the project site and breaks it. The
   workflow runs `check-site.py` on the built site and fails on any root-relative link, missing file or
   third-party request.
2. **Absolute URLs exist only where they are required**: canonical, Open Graph and Twitter tags, `sitemap.xml`,
   `robots.txt`, and the 404 page (its URL depth is unknown, so it cannot use relative links). In the source they
   are written as the placeholder `__SITE_URL__` with no trailing slash, for example
   `__SITE_URL__/assets/og.png`. The workflow replaces it with the repository variable `SITE_URL`, or with
   `https://mrcsxsiq.github.io/avd-studio` when the variable is not set, and fails if any placeholder is left.

Never commit a `website/CNAME` file. With Actions-based deployment GitHub ignores it; the custom domain is a
setting of the repository's Pages configuration (see below).

## Preview locally

```sh
# 1. As a project site, under a path prefix (what github.io/avd-studio/ does):
mkdir -p /tmp/preview && rm -rf /tmp/preview/avd-studio && cp -R website /tmp/preview/avd-studio
python3 -m http.server 8080 --bind 127.0.0.1 --directory /tmp/preview
# open http://127.0.0.1:8080/avd-studio/

# 2. At a domain root (what avdstudio.dev will do):
python3 -m http.server 8081 --bind 127.0.0.1 --directory website
# open http://127.0.0.1:8081/
```

Open the source copy and `404.html` shows unstyled (its stylesheet is `__SITE_URL__/...`, which only resolves
after the workflow's replacement). To check the whole page, including 404, build it like the workflow does, with
`SITE_URL` set to your local address, for example `http://127.0.0.1:8080/avd-studio` (the workflow itself accepts
only `https://` URLs).

Check links any time:

```sh
python3 -I website/tools/check-site.py
```

## Regenerating assets

- **Screenshots**: copy the PNGs from the snapshot tests, shrink with `sips -Z 1600 in.png --out out.png` (and
  `-Z 800` for the small variant), then encode with
  `cwebp -q 84 -m 6 -sharp_yuv -metadata icc out.png -o assets/name.webp`. Keep `width`/`height` in the HTML in
  step with the real pixel size.
- **Icons**: `icon-192.png`, `icon-512.png`, `favicon-*.png` and `favicon.ico` are the app icon trimmed to its
  squircle (824 px square inside the 1024 px canvas) and scaled with `sips`. `apple-touch-icon.png` is the same art
  zoomed so it bleeds to the corners, because iOS fills transparent pixels with black.
- **Social image**: `swift website/tools/make-og.swift` rewrites `assets/og.png` (1200 x 630) from `icon-512.png`.
  It is a standalone script; it does not touch the Swift package.

## Publishing

### First time (the repository is private today)

GitHub Pages is not available for a private repository on a free plan, so this waits until the repository is public
(or the plan supports private Pages).

1. Make the repository public.
2. Turn on Pages with the Actions source: **Settings, Pages, Build and deployment, Source: GitHub Actions**, or

   ```sh
   gh api --method POST repos/mrcsxsiq/avd-studio/pages -f build_type=workflow
   ```

3. Run the workflow once, because the push that added the site happened before Pages existed:

   ```sh
   gh workflow run pages.yml --ref main
   gh run watch
   ```

   From then on every push to `main` that touches `website/**` or the workflow redeploys the site.

The site then lives at `https://mrcsxsiq.github.io/avd-studio/`.

### Custom domain: avdstudio.dev (when DNS exists)

The domain has no DNS records yet, so nothing in the repository mentions it except the documentation. When you are
ready:

1. **DNS.** At the registrar, add these records.

   | Host | Type | Value |
   | --- | --- | --- |
   | `@` (apex) | A | `185.199.108.153` |
   | `@` | A | `185.199.109.153` |
   | `@` | A | `185.199.110.153` |
   | `@` | A | `185.199.111.153` |
   | `@` | AAAA | `2606:50c0:8000::153` |
   | `@` | AAAA | `2606:50c0:8001::153` |
   | `@` | AAAA | `2606:50c0:8002::153` |
   | `@` | AAAA | `2606:50c0:8003::153` |
   | `www` | CNAME | `mrcsxsiq.github.io` |

2. **Tell GitHub about the domain** (this is the Pages setting that replaces a `CNAME` file):

   ```sh
   gh api --method PUT repos/mrcsxsiq/avd-studio/pages -f cname=avdstudio.dev
   ```

3. **Wait for the TLS certificate.** GitHub requests it automatically once DNS resolves; it can take from a few
   minutes to about an hour. Then enforce HTTPS:

   ```sh
   gh api --method PUT repos/mrcsxsiq/avd-studio/pages -F https_enforced=true
   ```

4. **Switch the absolute URLs** (canonical, Open Graph, sitemap, robots, 404) to the new domain, then re-run the
   workflow so they are rebuilt:

   ```sh
   gh variable set SITE_URL --body https://avdstudio.dev
   gh workflow run pages.yml --ref main
   ```

Once the custom domain is active, GitHub redirects `https://mrcsxsiq.github.io/avd-studio/` (and the `www`
host) to `https://avdstudio.dev/`. Because every internal URL is relative, the same files work at both addresses
with no change.

`robots.txt` and `sitemap.xml` are only read by crawlers at the root of a host, so they take effect on the custom
domain; on the project site they are harmless.

## Download button

The static HTML links to `https://github.com/mrcsxsiq/avd-studio/releases`, so it works with JavaScript off. With
JavaScript on, `assets/main.js` asks `https://api.github.com/repos/mrcsxsiq/avd-studio/releases/latest` once per
visit (cached for 10 minutes in `sessionStorage`):

| Answer | What the hero shows |
| --- | --- |
| A release with a `.dmg` asset | "Download AVD Studio vX.Y.Z", linking straight to the DMG |
| A release without a DMG | "See AVD Studio vX.Y.Z on GitHub" |
| 404 (no release yet), offline, timeout, other errors | "First release coming soon" plus "Star / watch on GitHub" |
| 403 or 429 (GitHub is rate-limiting this visitor) | the neutral "Open GitHub Releases" that shipped in the HTML |

The last row is deliberate: when GitHub refuses to answer we know nothing, so the page does not claim that no
release exists. The script never throws and every state leaves a working link.

## After the first release

Revisit these, which are written for "before the first release":

- the hero note and the "Can I download it today?" FAQ answer (`index.html`);
- the "With the first release" badges for Homebrew and the command-line tool in the install section, once the tap
  and formula are live (the DMG badge flips to "Available now" by itself when the API returns a `.dmg`);
- the build-from-source card, which points to the repository README for build steps.

## Content rules

Only state what the product does today. The roadmap items (creating virtual devices, installing system images,
installing the Android SDK) stay under "Coming next" until they ship. No download counts, stars, testimonials or
awards. No Android or Apple logos. The trademark notice in the footer must stay.
