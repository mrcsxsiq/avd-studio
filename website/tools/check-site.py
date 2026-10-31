#!/usr/bin/env python3
"""Checks a built or source copy of the AVD Studio website for link problems.

    python3 -I website/tools/check-site.py [DIRECTORY] [--site-url URL]

DIRECTORY defaults to the website folder this script lives in. The check fails (exit status 1) when an HTML file has

  * a root-relative href/src/srcset (starts with "/"), which breaks the github.io/avd-studio/ project site;
  * a local href/src/srcset whose file does not exist, or a "#fragment" with no matching id;
  * an external stylesheet, script, image, font or icon (the site makes no third-party requests);
  * an <img> without alt, width or height, or a duplicate id.

The 404 page is the one place that uses absolute URLs, built from the __SITE_URL__ placeholder. Those are allowed
for subresources and are mapped back to local files, so they are checked too. Pass --site-url to do the same for a
copy where the placeholder has already been replaced.

Standard library only.
"""

import argparse
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

PLACEHOLDER = "__SITE_URL__"
URL_ATTRS = ("href", "src", "srcset", "poster")
EXTERNAL_SCHEMES = ("http:", "https:", "mailto:", "tel:")


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.refs = []  # (tag, attr, url, is_subresource)
        self.ids = []
        self.images = []  # attrs dicts
        self.meta_urls = []  # canonical / og:image / twitter:image values

    def handle_starttag(self, tag, attrs):
        a = {k: (v if v is not None else "") for k, v in attrs}
        if "id" in a:
            self.ids.append(a["id"])
        rel = a.get("rel", "").lower().split()
        subresource_link = tag == "link" and any(
            r in rel for r in ("stylesheet", "icon", "apple-touch-icon", "manifest", "preload", "modulepreload")
        )
        for attr in URL_ATTRS:
            if attr not in a:
                continue
            value = a[attr].strip()
            urls = [c.strip().split()[0] for c in value.split(",") if c.strip()] if attr == "srcset" else [value]
            for url in urls:
                is_sub = (
                    subresource_link
                    or (tag in ("script", "img", "source", "video", "audio", "iframe", "embed") and attr in ("src", "srcset"))
                    or attr == "poster"
                )
                self.refs.append((tag, attr, url, is_sub))
        if tag == "img":
            self.images.append(a)
        if tag == "link" and "canonical" in rel:
            self.meta_urls.append(("canonical", a.get("href", "")))
        if tag == "meta" and a.get("property", a.get("name", "")) in ("og:url", "og:image", "twitter:image"):
            self.meta_urls.append((a.get("property", a.get("name", "")), a.get("content", "")))


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directory", nargs="?", default=str(here.parent))
    parser.add_argument("--site-url", default="", help="URL that replaced the __SITE_URL__ placeholder, if any")
    args = parser.parse_args()

    root = Path(args.directory).resolve()
    site_prefixes = [PLACEHOLDER] + ([args.site_url.rstrip("/")] if args.site_url else [])
    errors = []
    checked = 0
    pages = sorted(p for p in root.rglob("*.html") if "tools" not in p.relative_to(root).parts)
    if not pages:
        print(f"No HTML files under {root}", file=sys.stderr)
        return 1

    parsed = {}
    for page in pages:
        p = Page()
        p.feed(page.read_text(encoding="utf-8"))
        parsed[page] = p

    def under_site_url(url):
        for prefix in site_prefixes:
            if url == prefix or url.startswith(prefix + "/"):
                return url[len(prefix):] or "/"
        return None

    for page, p in parsed.items():
        rel_page = page.relative_to(root)

        def err(message):
            errors.append(f"{rel_page}: {message}")

        seen = set()
        for i in p.ids:
            if i in seen:
                err(f'duplicate id "{i}"')
            seen.add(i)

        for img in p.images:
            for needed in ("alt", "width", "height"):
                if needed not in img:
                    err(f'<img src="{img.get("src", "?")}"> has no {needed} attribute')

        for kind, url in p.meta_urls:
            if under_site_url(url) is None:
                err(f"{kind} must be absolute from {PLACEHOLDER}, found {url!r}")

        for tag, attr, url, is_sub in p.refs:
            checked += 1
            if not url:
                err(f'<{tag} {attr}=""> is empty')
                continue
            mapped = under_site_url(url)
            if mapped is not None:
                # Absolute URL built from the site URL: fine, and it must point at a real file.
                target_path, fragment = urlsplit(mapped).path, urlsplit(mapped).fragment
                base = root
                local = target_path.lstrip("/")
            elif url.startswith("#"):
                target_path, fragment, base, local = "", url[1:], page.parent, ""
            elif url.startswith(EXTERNAL_SCHEMES):
                if is_sub:
                    err(f"<{tag} {attr}> loads an external resource: {url}")
                continue
            elif url.startswith("/"):
                err(f'root-relative URL <{tag} {attr}="{url}"> (use a path relative to the page)')
                continue
            elif ":" in url.split("/")[0]:
                err(f"unsupported URL scheme in <{tag} {attr}=\"{url}\">")
                continue
            else:
                parts = urlsplit(url)
                target_path, fragment, base, local = parts.path, parts.fragment, page.parent, unquote(parts.path)

            if local == "" and target_path == "":
                target = page  # same-page fragment
            else:
                target = (base / local).resolve()
                if target.is_dir() or local.endswith("/") or local in ("", "."):
                    target = (base / local / "index.html").resolve()
                try:
                    target.relative_to(root)
                except ValueError:
                    err(f'<{tag} {attr}="{url}"> escapes the site folder')
                    continue
                if not target.is_file():
                    err(f'<{tag} {attr}="{url}"> points to a missing file ({target.relative_to(root)})')
                    continue
            if fragment and target.suffix == ".html":
                ids = parsed[target].ids if target in parsed else None
                if ids is not None and fragment not in ids:
                    err(f'<{tag} {attr}="{url}"> points to a missing id "{fragment}"')

    if errors:
        print(f"FAILED: {len(errors)} problem(s) in {len(pages)} page(s)", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print(f"OK: {len(pages)} page(s), {checked} href/src/srcset values checked, no problems under {root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
