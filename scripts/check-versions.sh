#!/usr/bin/env bash
# Version guard: app/package.json is the single version source. Cargo.toml, the
# root `cockpit` entry in Cargo.lock and tauri.conf.json ("../package.json")
# must follow it; the tauri crates must share major.minor with their JS twins.
# On a tag ref (or --tag vX) the tag must equal "v" + the package version.
# Manifests are parsed as data (json / TOML), never sourced or evaluated.
# Exit: 0 ok, 1 drift, 2 usage or missing tool.
set -euo pipefail

usage() {
  printf 'usage: %s [--root DIR] [--tag vX.Y.Z]\n' "${0##*/}" >&2
  exit 2
}

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tag=""
while (($#)); do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || usage
      root=$2
      shift 2
      ;;
    --tag)
      [[ $# -ge 2 && -n "$2" ]] || usage
      tag=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

# GitHub sets GITHUB_REF_TYPE=tag on tag pushes; a bare GITHUB_REF_NAME=vX (no
# ref type) is treated as a tag too so a local dry check can reproduce CI.
if [[ -z "$tag" ]]; then
  if [[ "${GITHUB_REF_TYPE:-}" == tag ]]; then
    tag="${GITHUB_REF_NAME:-}"
  elif [[ -z "${GITHUB_REF_TYPE:-}" && "${GITHUB_REF_NAME:-}" =~ ^v[0-9] ]]; then
    tag="$GITHUB_REF_NAME"
  fi
fi

command -v python3 >/dev/null 2>&1 || {
  echo "versions: FAIL python3 not found" >&2
  exit 2
}

PYTHONIOENCODING=utf-8 exec python3 - "$root" "$tag" <<'PY'
import json
import os
import re
import sys

root, tag = sys.argv[1], sys.argv[2]
errors = []
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")


def read(rel):
    path = os.path.join(root, rel)
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError as exc:
        errors.append(f"cannot read {rel}: {exc.strerror}")
        return None


def mini_toml(text):
    """Table-scoped reader for the string keys we need (python < 3.11)."""
    doc, current = {}, None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^\[\[([A-Za-z0-9_.-]+)\]\]$", line)
        if m:
            current = {}
            doc.setdefault(m.group(1), []).append(current)
            continue
        m = re.match(r"^\[([A-Za-z0-9_.-]+)\]$", line)
        if m:
            current = doc.setdefault(m.group(1), {})
            continue
        m = re.match(r'^([A-Za-z0-9_-]+)\s*=\s*"((?:[^"\\]|\\.)*)"\s*(?:#.*)?$', line)
        if m and isinstance(current, dict):
            current.setdefault(m.group(1), m.group(2))
    return doc


def toml(rel):
    text = read(rel)
    if text is None:
        return {}
    try:
        import tomllib
    except ModuleNotFoundError:
        return mini_toml(text)
    try:
        return tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        errors.append(f"{rel} is not valid TOML: {exc}")
        return {}


def major_minor(v):
    m = SEMVER.match(v or "")
    return (m.group(1), m.group(2)) if m else None


def lock_package(lock, name, root_only=False):
    rows = [p for p in lock.get("package", []) if p.get("name") == name]
    if root_only:
        rows = [p for p in rows if "source" not in p]
    return rows


def pnpm_resolved(lock_text, name):
    if lock_text is None:
        return None
    pat = re.compile(
        r"^\s+'?" + re.escape(name) + r"'?:\n\s+specifier: [^\n]+\n\s+version: ([^\s(]+)",
        re.M,
    )
    found = pat.findall(lock_text)
    return found[0] if found else None


pkg_text = read("app/package.json")
version = None
if pkg_text is not None:
    try:
        version = json.loads(pkg_text).get("version")
    except ValueError as exc:
        errors.append(f"app/package.json is not valid JSON: {exc}")
if not isinstance(version, str) or not SEMVER.match(version):
    errors.append(f"app/package.json version {version!r} is not semver")
    version = None

cargo = toml("app/src-tauri/Cargo.toml")
cargo_version = cargo.get("package", {}).get("version") if isinstance(cargo.get("package"), dict) else None
if version and cargo_version != version:
    errors.append(f"app/src-tauri/Cargo.toml [package] version {cargo_version!r} != {version}")

lock = toml("app/src-tauri/Cargo.lock")
roots = lock_package(lock, "cockpit", root_only=True)
if len(roots) != 1:
    errors.append(f"app/src-tauri/Cargo.lock has {len(roots)} root 'cockpit' entries (want 1)")
elif version and roots[0].get("version") != version:
    errors.append(f"app/src-tauri/Cargo.lock cockpit version {roots[0].get('version')!r} != {version}")

conf_text = read("app/src-tauri/tauri.conf.json")
if conf_text is not None:
    try:
        conf_version = json.loads(conf_text).get("version")
    except ValueError as exc:
        errors.append(f"app/src-tauri/tauri.conf.json is not valid JSON: {exc}")
    else:
        if conf_version != "../package.json":
            errors.append(
                f"app/src-tauri/tauri.conf.json version {conf_version!r} must be \"../package.json\""
            )

pnpm_text = read("app/pnpm-lock.yaml")
pairs = []
for crate, js in (("tauri", "@tauri-apps/api"), ("tauri-plugin-opener", "@tauri-apps/plugin-opener")):
    rows = lock_package(lock, crate)
    crate_v = rows[0].get("version") if len(rows) == 1 else None
    js_v = pnpm_resolved(pnpm_text, js)
    if crate_v is None:
        errors.append(f"app/src-tauri/Cargo.lock: {len(rows)} '{crate}' entries (want 1)")
    if js_v is None:
        errors.append(f"app/pnpm-lock.yaml: no resolved version for {js}")
    if crate_v and js_v:
        if major_minor(crate_v) is None or major_minor(crate_v) != major_minor(js_v):
            errors.append(f"{crate} {crate_v} and {js} {js_v} differ in major.minor")
        pairs.append(f"{crate} {crate_v} ~ {js} {js_v}")

if tag:
    if not tag.startswith("v"):
        errors.append(f"tag {tag!r} must start with 'v'")
    elif version and tag[1:] != version:
        errors.append(f"tag {tag} != v{version} (app/package.json)")

if errors:
    for e in errors:
        print(f"versions: FAIL {e}", file=sys.stderr)
    sys.exit(1)

print(
    f"versions: ok {version} (app/package.json = app/src-tauri/Cargo.toml = "
    f"app/src-tauri/Cargo.lock = tauri.conf\u2192../package.json)"
)
print("versions: " + "; ".join(pairs) + (f"; tag {tag}" if tag else ""))
PY
