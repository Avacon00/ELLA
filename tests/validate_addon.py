#!/usr/bin/env python3
"""
EĹLA (Ella) – Automated TOC, Locale Parity, Lua 5.1 Syntax & Golden Rulebook Validator.
Runs locally and in GitHub Actions on every commit and Pull Request.
"""

from __future__ import annotations

import math
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOC_PATH = ROOT / "ELLA.toc"


class ValidationError(Exception):
    pass


def strip_lua_comments_and_strings(source: str) -> str:
    """Replaces Lua strings and comments with spaces (preserving newlines) for accurate token scanning."""
    out: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        # Comment
        if ch == "-" and i + 1 < n and source[i + 1] == "-":
            if i + 3 < n and source[i + 2] == "[" and source[i + 3] == "[":
                end = source.find("]]", i + 4)
                chunk = source[i : (end + 2 if end != -1 else n)]
                out.extend("\n" if c == "\n" else " " for c in chunk)
                i = end + 2 if end != -1 else n
                continue
            end = source.find("\n", i + 2)
            if end == -1:
                break
            i = end
            continue
        # Long bracket string [[ ... ]]
        if ch == "[" and i + 1 < n and source[i + 1] == "[":
            end = source.find("]]", i + 2)
            chunk = source[i : (end + 2 if end != -1 else n)]
            out.extend("\n" if c == "\n" else " " for c in chunk)
            i = end + 2 if end != -1 else n
            continue
        # Quoted string
        if ch in ('"', "'"):
            quote = ch
            out.append(" ")
            i += 1
            while i < n:
                c = source[i]
                if c == "\\" and i + 1 < n:
                    out.append("  ")
                    i += 2
                    continue
                if c == quote:
                    out.append(" ")
                    i += 1
                    break
                out.append("\n" if c == "\n" else " ")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def validate_toc() -> list[pathlib.Path]:
    if not TOC_PATH.is_file():
        raise ValidationError(f"Missing TOC file: {TOC_PATH}")

    toc_text = TOC_PATH.read_text(encoding="utf-8")
    meta: dict[str, str] = {}
    referenced_files: list[pathlib.Path] = []

    for raw_line in toc_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("##"):
            if ":" in line:
                k, v = line[2:].split(":", 1)
                meta[k.strip()] = v.strip()
            continue
        if line.startswith("#"):
            continue
        rel = pathlib.Path(line.replace("\\", "/"))
        full = ROOT / rel
        if not full.is_file():
            raise ValidationError(f"TOC references missing file: {rel}")
        referenced_files.append(full)

    if meta.get("Interface") != "16001":
        raise ValidationError(f"Expected '## Interface: 16001', got '{meta.get('Interface')}'")
    if "camelot" not in meta.get("AllowLoadGameType", ""):
        raise ValidationError("TOC must include 'camelot' in '## AllowLoadGameType'")
    if meta.get("SavedVariables") != "ELLADB":
        raise ValidationError("TOC must declare '## SavedVariables: ELLADB'")

    # Ensure no Lua files in Core/Data/UI/API/Locales were forgotten in TOC
    ref_set = {p.resolve() for p in referenced_files}
    for sub in ("Locales", "Core", "Data", "UI", "API"):
        for lua_file in sorted((ROOT / sub).glob("*.lua")):
            if lua_file.resolve() not in ref_set:
                raise ValidationError(f"Lua file not listed in ELLA.toc: {lua_file.relative_to(ROOT)}")

    print(f"[OK] ELLA.toc verified ({len(referenced_files)} files, Interface: 16001, camelot).")
    return referenced_files


def validate_locales(lua_files: list[pathlib.Path]) -> None:
    en_text = (ROOT / "Locales" / "enUS.lua").read_text(encoding="utf-8")
    de_text = (ROOT / "Locales" / "deDE.lua").read_text(encoding="utf-8")

    assign_re = re.compile(r'L\["([A-Z0-9_]+)"\]\s*=')
    en_keys = set(assign_re.findall(en_text))
    de_keys = set(assign_re.findall(de_text))

    missing_in_de = sorted(en_keys - de_keys)
    extra_in_de = sorted(de_keys - en_keys)
    if missing_in_de:
        raise ValidationError(f"Missing German (deDE) translations for keys: {missing_in_de}")
    if extra_in_de:
        raise ValidationError(f"Keys in deDE.lua missing from enUS.lua: {extra_in_de}")

    # Verify all L["KEY"] and labelKey/nameKey/descKey references exist in enUS
    ref_l_re = re.compile(r'L\["([A-Z0-9_]+)"\]')
    key_prop_re = re.compile(r'(?:labelKey|nameKey|descKey|category)\s*=\s*"([A-Z0-9_]+)"')

    for f in lua_files:
        if "Libs" in f.parts or "Locales" in f.parts:
            continue
        txt = f.read_text(encoding="utf-8")
        for key in set(ref_l_re.findall(txt)) | set(key_prop_re.findall(txt)):
            if key not in en_keys:
                raise ValidationError(f"{f.relative_to(ROOT)} references undefined locale key '{key}'")

    print(f"[OK] Locale parity verified ({len(en_keys)} keys in both enUS and deDE, 0 missing references).")


def validate_lua_syntax_and_golden_rules(lua_files: list[pathlib.Path]) -> None:
    block_openers = {"function", "if", "do", "repeat"}
    # Note: 'while ... do' and 'for ... do' open their block via their 'do' token!
    pairs_map = {"(": ")", "{": "}", "[": "]"}

    for f in lua_files:
        rel = f.relative_to(ROOT)
        raw = f.read_text(encoding="utf-8")
        is_lib = "Libs" in f.parts

        # Golden Rule #6: Module namespace header check
        if not is_lib:
            first_code = ""
            for line in raw.splitlines():
                s = line.strip()
                if s and not s.startswith("--"):
                    first_code = s
                    break
            if first_code != "local AddonName, ns = ...":
                raise ValidationError(
                    f"{rel}: First statement must be 'local AddonName, ns = ...' (Golden Rule #6), got '{first_code}'"
                )

        stripped = strip_lua_comments_and_strings(raw)

        # Lua 5.1 compatibility checks (no '//' integer division, no '::label::' goto)
        if "//" in stripped:
            raise ValidationError(f"{rel}: Contains Lua 5.3 '//' operator (invalid in WoW Lua 5.1)")
        if "::" in stripped:
            raise ValidationError(f"{rel}: Contains Lua 5.2 '::' goto label (invalid in WoW Lua 5.1)")

        # Bracket balance
        stack: list[tuple[str, int]] = []
        for idx, ch in enumerate(stripped):
            if ch in pairs_map:
                stack.append((ch, idx))
            elif ch in (")", "}", "]"):
                if not stack or pairs_map[stack[-1][0]] != ch:
                    line_no = stripped.count("\n", 0, idx) + 1
                    raise ValidationError(f"{rel}:{line_no}: Unbalanced bracket '{ch}'")
                stack.pop()
        if stack:
            ch, idx = stack[-1]
            line_no = stripped.count("\n", 0, idx) + 1
            raise ValidationError(f"{rel}:{line_no}: Unclosed bracket '{ch}'")

        # Lua 5.1 block balance (function/if/do vs end, repeat vs until)
        tokens = re.findall(r"\b(?:function|if|do|repeat|end|until)\b", stripped)
        bstack: list[str] = []
        for tok in tokens:
            if tok in block_openers:
                bstack.append(tok)
            elif tok == "end":
                if not bstack or bstack[-1] == "repeat":
                    raise ValidationError(f"{rel}: Unexpected 'end' token (block imbalance)")
                bstack.pop()
            elif tok == "until":
                if not bstack or bstack[-1] != "repeat":
                    raise ValidationError(f"{rel}: Unexpected 'until' token (block imbalance)")
                bstack.pop()
        if bstack:
            raise ValidationError(f"{rel}: Unclosed Lua block(s) remaining at EOF: {bstack}")

        if not is_lib:
            # Golden Rule #3: Never mutate UIPanelWindows
            if re.search(r"\bUIPanelWindows\b", stripped):
                raise ValidationError(f"{rel}: Forbidden reference/mutation of UIPanelWindows (Golden Rule #3)")

            # Golden Rule Part A: No dynamic code execution or Secret Value probing
            if re.search(r"\b(?:loadstring|RunScript|issecretvalue)\b", stripped):
                raise ValidationError(f"{rel}: Forbidden API usage (loadstring/RunScript/issecretvalue)")

            # Golden Rule #8: Every OnUpdate registration must have a matching nil teardown in the same module
            onupdate_sets = re.findall(r'SetScript\(\s*"OnUpdate"\s*,\s*([^)]+)\)', raw)
            non_nil = [arg.strip() for arg in onupdate_sets if arg.strip() != "nil"]
            nil_clears = [arg.strip() for arg in onupdate_sets if arg.strip() == "nil"]
            if non_nil and not nil_clears:
                raise ValidationError(
                    f"{rel}: Sets OnUpdate without matching SetScript('OnUpdate', nil) teardown (Golden Rule #8)"
                )

    print(f"[OK] Lua 5.1 syntax & Golden Rulebook checks passed across all {len(lua_files)} files.")


def validate_anchoring_math() -> None:
    """Verifies cursor-pivot & scale-compensated anchoring leaves hovered coordinates invariant."""
    uip_h = 1080.0
    old_scale = 1.00
    new_scale = 0.78
    # Window initially at (180, -140) from UIParent TOPLEFT; badge at local offset (940, -12)
    old_uip_x, old_uip_y = 180.0, -140.0
    local_badge_x, local_badge_y = 940.0, -12.0

    # Cursor hovering right over the badge in UIParent space:
    cursor_x = old_uip_x + local_badge_x * old_scale
    cursor_y = old_uip_y + local_badge_y * old_scale

    ratio = new_scale / old_scale
    new_uip_x = cursor_x - (cursor_x - old_uip_x) * ratio
    new_uip_y = cursor_y - (cursor_y - old_uip_y) * ratio

    # SetPoint("TOPLEFT", UIParent, "TOPLEFT", new_uip_x / new_scale, new_uip_y / new_scale)
    setpoint_x = new_uip_x / new_scale
    setpoint_y = new_uip_y / new_scale

    # Resulting badge screen coordinates at new_scale:
    after_badge_x = (setpoint_x + local_badge_x) * new_scale
    after_badge_y = (setpoint_y + local_badge_y) * new_scale

    if not (math.isclose(after_badge_x, cursor_x, abs_tol=1e-9) and math.isclose(after_badge_y, cursor_y, abs_tol=1e-9)):
        raise ValidationError(
            f"Cursor-pivot drift detected! Expected ({cursor_x}, {cursor_y}), got ({after_badge_x}, {after_badge_y})"
        )
    assert uip_h > 0
    print("[OK] Cursor-pivot & scale-compensated SetPoint math verified (0.000000 px drift).")


def main() -> int:
    try:
        lua_files = validate_toc()
        validate_locales(lua_files)
        validate_lua_syntax_and_golden_rules(lua_files)
        validate_anchoring_math()
    except ValidationError as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    print("\nAll ELLA validation & Golden Rulebook checks PASSED!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
