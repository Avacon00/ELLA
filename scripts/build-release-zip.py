#!/usr/bin/env python3
"""Builds a clean CurseForge-ready release ZIP in .release/ELLA-v<version>-16001.zip."""

from __future__ import annotations

import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXCLUDED_TOP = {".git", ".github", ".gitignore", ".luacheckrc", ".pkgmeta", ".release", "CONTRIBUTING.md", "README.md", "scripts", "tests"}


def build_zip() -> pathlib.Path:
    toc = (ROOT / "ELLA.toc").read_text(encoding="utf-8")
    version = "1.0.0"
    for line in toc.splitlines():
        if line.startswith("## Version:"):
            version = line.split(":", 1)[1].strip()
            break

    out_dir = ROOT / ".release"
    out_dir.mkdir(exist_ok=True)
    zip_path = out_dir / f"ELLA-v{version}-16001.zip"

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(ROOT.rglob("*")):
            if path.is_dir():
                continue
            rel = path.relative_to(ROOT)
            if rel.parts[0] in EXCLUDED_TOP or "__pycache__" in rel.parts:
                continue
            arcname = pathlib.Path("ELLA") / rel
            zf.write(path, arcname.as_posix())

    print(f"[OK] Built CurseForge release archive: {zip_path}")
    return zip_path


if __name__ == "__main__":
    build_zip()
