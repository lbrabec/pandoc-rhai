#!/usr/bin/env python3
"""Download cabal-install bootstrap dependencies from bootstrap.json."""

import argparse
import hashlib
import json
import os
import subprocess
import sys

MAX_RETRIES = 5


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def download_with_verify(
    url: str, dest: str, expected_sha256: str | None, label: str
) -> None:
    """Download a file, optionally verifying its SHA256 hash with retries."""
    for attempt in range(1, MAX_RETRIES + 1):
        result = subprocess.run(
            ["curl", "-fSL", "--progress-bar", url, "-o", dest],
            check=False,
        )
        if result.returncode != 0:
            print(
                f"  WARNING: curl failed for {label} (attempt {attempt}/{MAX_RETRIES})",
                file=sys.stderr,
            )
            if os.path.exists(dest):
                os.remove(dest)
            if attempt == MAX_RETRIES:
                raise RuntimeError(f"Failed to download {label} from {url}")
            continue

        if expected_sha256 is None:
            return

        actual = sha256_file(dest)
        if actual == expected_sha256:
            return

        print(
            f"  WARNING: hash mismatch for {label} (attempt {attempt}/{MAX_RETRIES})\n"
            f"    expected: {expected_sha256}\n"
            f"    got:      {actual}",
            file=sys.stderr,
        )
        os.remove(dest)
        if attempt == MAX_RETRIES:
            raise RuntimeError(
                f"SHA256 mismatch for {label} after {MAX_RETRIES} attempts"
            )


def download_dependencies(bootstrap_json_path: str, deps_dir: str) -> None:
    """Parse bootstrap.json and download each dependency from Hackage."""
    with open(bootstrap_json_path) as f:
        data = json.load(f)

    os.makedirs(deps_dir, exist_ok=True)

    for pkg in data.get("dependencies", []):
        name = pkg["package"]
        version = pkg["version"]
        src_sha256 = pkg.get("src_sha256")
        url = f"https://hackage.haskell.org/package/{name}-{version}/{name}-{version}.tar.gz"
        dest = os.path.join(deps_dir, f"{name}-{version}.tar.gz")

        if os.path.exists(dest):
            print(f"  Skipping {name}-{version} (already downloaded)")
        else:
            print(f"  Downloading {name}-{version}...")
            download_with_verify(url, dest, src_sha256, f"{name}-{version}.tar.gz")

        revision = pkg.get("revision")
        if revision is not None:
            cabal_sha256 = pkg.get("cabal_sha256")
            cabal_dest = os.path.join(deps_dir, f"{name}.cabal")
            if os.path.exists(cabal_dest):
                print(f"  Skipping {name}.cabal revision (already downloaded)")
                continue
            cabal_url = (
                f"https://hackage.haskell.org/package/{name}-{version}"
                f"/revision/{revision}.cabal"
            )
            print(f"  Downloading {name}.cabal (revision {revision})...")
            download_with_verify(
                cabal_url, cabal_dest, cabal_sha256, f"{name}.cabal"
            )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download cabal-install bootstrap dependencies"
    )
    parser.add_argument("bootstrap_json", help="Path to bootstrap.json file")
    parser.add_argument("deps_dir", help="Directory to store downloaded dependencies")
    args = parser.parse_args()

    if not os.path.isfile(args.bootstrap_json):
        print(f"Error: {args.bootstrap_json} not found", file=sys.stderr)
        sys.exit(1)

    download_dependencies(args.bootstrap_json, args.deps_dir)


if __name__ == "__main__":
    main()
