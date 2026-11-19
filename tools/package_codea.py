#!/usr/bin/env python3
"""Build a single Main and a tabbed archive from a canonical Codea project."""

import argparse
import plistlib
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def read_project(project):
    plist = (project / "Info.plist").read_bytes()
    tabs = plistlib.loads(plist).get("Buffer Order")
    if (not isinstance(tabs, list) or not all(isinstance(tab, str) for tab in tabs)
            or len(tabs) != len(set(tabs)) or tabs[:1] != ["Main"]):
        raise ValueError("Info.plist must list each tab once, starting with Main")
    actual = {file.stem for file in project.glob("*.lua")}
    if set(tabs) != actual:
        raise ValueError(f"Info.plist and Lua tabs differ: {', '.join(sorted(set(tabs) ^ actual))}")
    sources = {tab: (project / f"{tab}.lua").read_bytes() for tab in tabs}
    if any(not source.strip() for source in sources.values()):
        raise ValueError("The project contains an empty Lua tab")
    return plist, sources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path("PolyLax.codea"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, default=Path("releases"))
    parser.add_argument("--check-main", type=Path,
                        help="Verify an existing Main against all canonical tabs without writing files")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+(?:\.\d+)+", args.version):
        parser.error("--version must be a dotted version number")
    try:
        plist, sources = read_project(args.project)
    except (OSError, ValueError) as error:
        parser.error(str(error))

    title = f"PolyLax {args.version}"
    stem = f"PolyLax-{args.version}"
    header = (f"-- {title} | Complete single-tab edition\n"
              "-- Paste into Main in a Legacy Craft project with a single tab.\n\n")
    body = "".join(f"-- {tab}\ndo\n{source.decode('utf-8').rstrip()}\nend\n\n"
                   for tab, source in sources.items())
    footer = f"-- End of {title}\n"
    combined = (header + body + footer).encode("utf-8")
    lines = combined.count(b"\n")

    if args.check_main:
        if args.check_main.read_bytes() != combined:
            parser.error(f"{args.check_main} differs from the complete {lines}-line Main for {title}")
        print(f"Verified complete Main: {len(sources)} tabs, {lines} lines")
        return

    args.output.mkdir(parents=True, exist_ok=True)
    for suffix in ("Main.lua", "Full-Lua-Code.txt"):
        (args.output / f"{stem}-{suffix}").write_bytes(combined)
    archive = args.output / f"{stem}.codea.zip"
    bundle = f"{title}.codea/"
    with ZipFile(archive, "w", ZIP_DEFLATED) as project_zip:
        project_zip.writestr(bundle + "Info.plist", plist)
        for tab, source in sources.items():
            project_zip.writestr(bundle + f"{tab}.lua", source)
    print(f"Packaged {len(sources)} tabs and {lines} lines in the single-file Main")


if __name__ == "__main__":
    main()
