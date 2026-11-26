#!/usr/bin/env python3
"""Discover official Huangguo addresses without executing publisher JavaScript."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import html
import ipaddress
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request

RESOLVERS = (
    "https://huangguoai.com", "https://huangguoai.ai", "https://hgai16.com",
    "https://huangguoai.pages.dev", "https://huang-guo.pages.dev",
)
PATHS = ("/api/site/entries", "/api/site/go-home", "/publish.js", "/go-home/")
UA = "Mozilla/5.0 (compatible; GuomuSourceSync/1.0)"
MAX_BODY = 2 * 1024 * 1024


def normalize(value: str) -> str | None:
    value = html.unescape(value).strip().replace("\\/", "/")
    if not value or any(c in value for c in "{}<>"):
        return None
    if "://" not in value:
        value = "https://" + value.lstrip("/")
    try:
        uri = urllib.parse.urlsplit(value)
        host = (uri.hostname or "").lower().rstrip(".")
        if uri.scheme != "https" or uri.username or uri.password or uri.port not in (None, 443):
            return None
        if not re.fullmatch(r"[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?", host):
            return None
        if "." not in host or host.endswith((".local", ".internal", ".localhost", ".pages.dev")):
            return None
        if host in ("huangguoai.ai", "hgai16.com"):
            return None
        try:
            ipaddress.ip_address(host)
            return None  # Official entries are DNS names, never literal IPs.
        except ValueError:
            pass
        return "https://" + host
    except ValueError:
        return None


def _array(text: str, name: str) -> list[str]:
    match = re.search(r"\b(?:var|let|const)\s+" + re.escape(name) + r"\s*=\s*\[([\s\S]*?)\]", text)
    if not match:
        return []
    body = re.sub(r"//[^\n]*", "", match[1])
    return re.findall(r"['\"]([^'\"]+)['\"]", body)


def extract_sources(text: str) -> list[str]:
    """Only publisher responses feed this function; probes still gate inclusion."""
    text = html.unescape(text).replace("\\/", "/")
    candidates = re.findall(r"https://[a-zA-Z0-9.-]+", text)
    candidates += re.findall(r"['\"]([a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+)/*['\"]", text)
    # The official publish.js builds newestUrls from these two arrays. Use a
    # stable subset rather than Math.random(), so identical input never churns.
    subdomains = _array(text, "subdomains")[:6]
    for root in _array(text, "urls")[:12]:
        candidates.append(f"https://{root.strip('/')}")
        for subdomain in subdomains:
            if re.fullmatch(r"[a-zA-Z0-9-]+", subdomain):
                candidates.append(f"https://{subdomain}.{root.strip('/')}")
    # Keep permanent/publication entries as fallbacks. Pages.dev domains are
    # filtered by normalize(), and every surviving address still has to pass
    # the content API probe below.
    for name in ("otherUrls", "foreverUrls"):
        candidates.extend(_array(text, name))
    return list(dict.fromkeys(source for item in candidates if (source := normalize(item))))


class PublicRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlsplit(newurl)
        # Publication pages may redirect to another public DNS host.
        if parsed.scheme != "https" or not parsed.hostname or parsed.username:
            raise ValueError("untrusted redirect")
        try:
            ipaddress.ip_address(parsed.hostname)
        except ValueError:
            if parsed.hostname == "localhost" or parsed.hostname.endswith((".local", ".internal")):
                raise ValueError("local redirect")
        else:
            raise ValueError("literal IP redirect")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url: str, *, body: dict | None = None, timeout: float = 8) -> str:
    headers = {"User-Agent": UA, "Accept": "application/json,text/plain,*/*"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers.update({"Content-Type": "application/json", "Referer": url.split("/api/")[0] + "/"})
    request = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.build_opener(PublicRedirects()).open(request, timeout=timeout) as response:
        data = response.read(MAX_BODY + 1)
        if len(data) > MAX_BODY:
            raise ValueError("response too large")
        return data.decode("utf-8")


def probe(source: str) -> bool:
    try:
        # Do not probe the retired edge envelope. The current nodes expose
        # the public content API directly, which is the same path the app uses.
        value = json.loads(fetch(source + "/api/home"))
        data = value.get("data") if isinstance(value, dict) else None
        return value.get("status") == 1 and isinstance(data, dict) and any(
            isinstance(data.get(key), list)
            for key in (
                "banners",
                "featured",
                "latest",
                "recommends",
                "sections",
                "categories",
                "cate_rec",
            )
        )
    except (OSError, ValueError, AttributeError):
        return False


def merge_manifest(previous: dict, verified: list[str], now: str) -> dict:
    existing = list(dict.fromkeys(source for item in previous.get("sources", []) if isinstance(item, str) and (source := normalize(item))))
    additions = sorted(set(verified) - set(existing))
    if not additions:
        return previous
    # A CI runner's failed check cannot prove an address fails in the user's
    # network. Keep prior sources as fallbacks rather than deleting them.
    return {**previous, "version": int(previous.get("version", 1)) + 1,
            "updated_at": now, "sources": (additions + existing)[:24]}


def sync(manifest: Path, report: Path, *, dry_run: bool = False) -> int:
    previous = json.loads(manifest.read_text())
    urls = [base + path for base in RESOLVERS for path in PATHS]
    candidates: set[str] = set()
    publishers: list[str] = []

    def discover(url):
        try:
            return url, extract_sources(fetch(url))
        except (OSError, ValueError):
            return url, []

    with ThreadPoolExecutor(max_workers=6) as pool:
        for url, discovered in pool.map(discover, urls):
            if discovered:
                publishers.append(url)
                candidates.update(discovered)
        ordered = sorted(candidates)[:60]
        healthy = [source for source, valid in zip(ordered, pool.map(probe, ordered)) if valid]
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    updated = merge_manifest(previous, healthy, now)
    changed = updated != previous
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({"checked_at": now, "probe_path": "/api/home",
        "publishers": publishers, "candidate_count": len(candidates), "verified": healthy,
        "changed": changed, "retained_previous": not healthy}, ensure_ascii=False, indent=2) + "\n")
    if changed and not dry_run:
        temporary = manifest.with_suffix(".json.next")
        temporary.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n")
        temporary.replace(manifest)
    print(f"publishers={len(publishers)} candidates={len(candidates)} verified={len(healthy)} changed={changed}")
    if not healthy:
        print("No source passed the content API check; preserving the existing manifest.")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path("assets/data/source_manifest.json"))
    parser.add_argument("--report", type=Path, default=Path(".tmp/source-sync-report.json"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    raise SystemExit(sync(args.manifest, args.report, dry_run=args.dry_run))
