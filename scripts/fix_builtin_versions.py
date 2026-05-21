#!/usr/bin/env python3
"""Patch a bootstrap plan JSON so builtin package versions match the actual GHC.

Bootstrap plans target a specific GHC patch release (e.g. 9.6.4) whose builtin
packages may differ from the GHC we have (e.g. 9.6.7). The bootstrap scripts
do strict version checks, so we patch the plan to match reality.

Works with both cabal-install and hadrian bootstrap plan JSON files.
"""

import json
import re
import subprocess
import sys


def get_installed_versions(ghc_pkg: str) -> dict[str, str]:
    """Query ghc-pkg for all installed package versions."""
    output = subprocess.check_output(
        [ghc_pkg, "list", "--simple-output"], text=True
    )
    versions = {}
    for entry in output.split():
        match = re.match(r"^(.+)-(\d[\d.]*)$", entry)
        if match:
            versions[match.group(1)] = match.group(2)
    return versions


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <plan.json> <ghc-pkg>")
        sys.exit(1)

    plan_path = sys.argv[1]
    ghc_pkg = sys.argv[2]

    installed = get_installed_versions(ghc_pkg)

    with open(plan_path) as f:
        plan = json.load(f)

    patched = 0
    for entry in plan.get("builtin", []):
        pkg = entry["package"]
        plan_ver = entry["version"]
        actual_ver = installed.get(pkg)
        if actual_ver and actual_ver != plan_ver:
            print(f"  Patching builtin {pkg}: {plan_ver} -> {actual_ver}")
            entry["version"] = actual_ver
            patched += 1

    if patched:
        with open(plan_path, "w") as f:
            json.dump(plan, f, indent=2)
        print(f"Patched {patched} builtin version(s)")
    else:
        print("All builtin versions match, no patching needed.")


if __name__ == "__main__":
    main()
