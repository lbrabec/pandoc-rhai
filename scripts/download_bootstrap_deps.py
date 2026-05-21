#!/usr/bin/env python3
"""Download cabal-install bootstrap dependencies from bootstrap.json."""

import argparse
import json
import os
import subprocess
import sys


def download_dependencies(bootstrap_json_path: str, deps_dir: str) -> None:
    """Parse bootstrap.json and download each dependency from Hackage."""
    with open(bootstrap_json_path) as f:
        data = json.load(f)

    os.makedirs(deps_dir, exist_ok=True)

    for pkg in data.get("dependencies", []):
        name = pkg["package"]
        version = pkg["version"]
        url = f"https://hackage.haskell.org/package/{name}-{version}/{name}-{version}.tar.gz"
        dest = os.path.join(deps_dir, f"{name}-{version}.tar.gz")

        if os.path.exists(dest):
            print(f"  Skipping {name}-{version} (already downloaded)")
        else:
            print(f"  Downloading {name}-{version}...")
            result = subprocess.run(
                ["curl", "-L", "--progress-bar", url, "-o", dest],
                check=False
            )
            if result.returncode != 0:
                print(f"  WARNING: Failed to download {name}-{version}", file=sys.stderr)

        revision = pkg.get("revision")
        if revision is not None:
            cabal_dest = os.path.join(deps_dir, f"{name}.cabal")
            if os.path.exists(cabal_dest):
                print(f"  Skipping {name}.cabal revision (already downloaded)")
                continue
            cabal_url = (
                f"https://hackage.haskell.org/package/{name}-{version}"
                f"/revision/{revision}.cabal"
            )
            print(f"  Downloading {name}.cabal (revision {revision})...")
            subprocess.run(
                ["curl", "-sL", cabal_url, "-o", cabal_dest],
                check=False,
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
