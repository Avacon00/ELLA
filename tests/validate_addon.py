#!/usr/bin/env python3
"""
ELLA – Automated TOC, Bindings.xml, Locale Parity, Format Specifier, Lua 5.1 Syntax & Golden Rulebook Validator.
Runs locally and in GitHub Actions on every commit and Pull Request.
"""

from __future__ import annotations

import ast
import math
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOC_PATH = ROOT / "ELLA.toc"
BINDINGS_PATH = ROOT / "Bindings.xml"
INIT_PATH = ROOT / "Core" / "Init.lua"

FORMAT_TOKEN_STRICT_RE = re.compile(r"%(?:%|[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs])")
FORMAT_TOKEN_PLAIN_RE = re.compile(r"%(?:%|[-+#0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs])")


class ValidationError(Exception):
    pass


def match_long_bracket(source: str, idx: int) -> int | None:
    """If source[idx:] starts a Lua long bracket [=*[ ... ]=*], returns index past closing bracket (or len(source))."""
    n = len(source)
    if idx >= n or source[idx] != "[":
        return None
    j = idx + 1
    while j < n and source[j] == "=":
        j += 1
    if j >= n or source[j] != "[":
        return None
    eq_count = j - (idx + 1)
    closing = "]" + ("=" * eq_count) + "]"
    end = source.find(closing, j + 1)
    if end == -1:
        return n
    return end + len(closing)


def strip_lua_comments(source: str) -> str:
    """Strips only Lua comments (preserving string literals and line numbers) for accurate glyph scanning."""
    out: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        # Comment (-- or --[=*[ ... ]=*])
        if ch == "-" and i + 1 < n and source[i + 1] == "-":
            lb_end = match_long_bracket(source, i + 2)
            if lb_end is not None:
                chunk = source[i:lb_end]
                out.extend("\n" if c == "\n" else " " for c in chunk)
                i = lb_end
                continue
            end = source.find("\n", i + 2)
            if end == -1:
                break
            i = end
            continue
        # Long bracket string [=*[ ... ]=*] (keep intact so string contents are checked and '--' inside is ignored)
        lb_end = match_long_bracket(source, i)
        if lb_end is not None:
            out.append(source[i:lb_end])
            i = lb_end
            continue
        # Quoted string (keep intact so '--' inside strings is not mistaken for a comment)
        if ch in ('"', "'"):
            quote = ch
            out.append(ch)
            i += 1
            while i < n:
                c = source[i]
                if c == "\\" and i + 1 < n:
                    out.append(source[i : i + 2])
                    i += 2
                    continue
                out.append(c)
                i += 1
                if c == quote:
                    break
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def strip_lua_comments_and_strings(source: str) -> str:
    """Replaces Lua strings and comments with spaces (preserving newlines) for accurate token scanning."""
    out: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        # Comment (-- or --[=*[ ... ]=*])
        if ch == "-" and i + 1 < n and source[i + 1] == "-":
            lb_end = match_long_bracket(source, i + 2)
            if lb_end is not None:
                chunk = source[i:lb_end]
                out.extend("\n" if c == "\n" else " " for c in chunk)
                i = lb_end
                continue
            end = source.find("\n", i + 2)
            if end == -1:
                break
            i = end
            continue
        # Long bracket string [=*[ ... ]=*]
        lb_end = match_long_bracket(source, i)
        if lb_end is not None:
            chunk = source[i:lb_end]
            out.extend("\n" if c == "\n" else " " for c in chunk)
            i = lb_end
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


def validate_toc() -> tuple[list[pathlib.Path], str]:
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
    if meta.get("IconTexture") == r"Interface\AddOns\ELLA\Media\Icon":
        icon_tga = ROOT / "Media" / "Icon.tga"
        if not icon_tga.is_file():
            raise ValidationError(f"Custom IconTexture declared in ELLA.toc, but missing file: {icon_tga}")

    toc_version = meta.get("Version", "")
    if not toc_version:
        raise ValidationError("TOC must declare '## Version: x.y.z'")

    init_text = INIT_PATH.read_text(encoding="utf-8")
    m_ver = re.search(r'ns\.Version\s*=\s*"([^"]+)"', init_text)
    if not m_ver:
        raise ValidationError("Core/Init.lua must define ns.Version")
    if m_ver.group(1) != toc_version:
        raise ValidationError(
            f"Version mismatch: ELLA.toc has '{toc_version}', Core/Init.lua has '{m_ver.group(1)}'"
        )

    # Ensure no Lua files in Core/Data/UI/API/Locales were forgotten in TOC
    ref_set = {p.resolve() for p in referenced_files}
    for sub in ("Locales", "Core", "Data", "UI", "API"):
        for lua_file in sorted((ROOT / sub).glob("*.lua")):
            if lua_file.resolve() not in ref_set:
                raise ValidationError(f"Lua file not listed in ELLA.toc: {lua_file.relative_to(ROOT)}")

    print(
        f"[OK] ELLA.toc verified (v{toc_version}, {len(referenced_files)} files, Interface: 16001, camelot)."
    )
    return referenced_files, toc_version


def validate_bindings_xml() -> set[str]:
    if not BINDINGS_PATH.is_file():
        raise ValidationError("Missing Bindings.xml in project root")

    try:
        tree = ET.parse(BINDINGS_PATH)
    except ET.ParseError as exc:
        raise ValidationError(f"Bindings.xml is not well-formed XML: {exc}") from exc

    root = tree.getroot()
    if root.tag != "Bindings":
        raise ValidationError(f"Bindings.xml root element must be <Bindings>, got <{root.tag}>")

    required_keys: set[str] = set()
    bindings = root.findall("Binding")
    if not bindings:
        raise ValidationError("Bindings.xml contains no <Binding> definitions")

    for elem in bindings:
        name = elem.attrib.get("name", "").strip()
        header = elem.attrib.get("header", "").strip()
        category = elem.attrib.get("category", "").strip()
        if not name:
            raise ValidationError("Bindings.xml contains a <Binding> without a 'name' attribute")
        if category != "ADDONS":
            raise ValidationError(
                f"Bindings.xml <Binding name='{name}'> must set category='ADDONS' for WoW 16001 (got {category!r})"
            )
        required_keys.add(f"BINDING_NAME_{name}")
        if header:
            required_keys.add(f"BINDING_HEADER_{header}")

    print(f"[OK] Bindings.xml verified ({len(bindings)} keybindings with category='ADDONS').")
    return required_keys


def parse_locale_map(path: pathlib.Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    assign_re = re.compile(r'L\["([A-Z0-9_]+)"\]\s*=\s*("(?:\\.|[^"\\])*")')
    entries: dict[str, str] = {}
    for match in assign_re.finditer(text):
        key = match.group(1)
        raw_lit = match.group(2)
        if key in entries:
            raise ValidationError(f"{path.relative_to(ROOT)}: Duplicate locale key '{key}'")
        try:
            val = ast.literal_eval(raw_lit)
        except SyntaxError:
            val = raw_lit[1:-1]
        entries[key] = val
    return entries


def extract_format_specifiers(val: str, key: str, locale_name: str, strict_percent: bool) -> list[str]:
    specs: list[str] = []
    token_re = FORMAT_TOKEN_STRICT_RE if strict_percent else FORMAT_TOKEN_PLAIN_RE
    i = 0
    n = len(val)
    while i < n:
        if val[i] == "%":
            m = token_re.match(val, i)
            if not m:
                if strict_percent:
                    raise ValidationError(
                        f"{locale_name}: Unescaped '%' in formatted key L['{key}'] near {val[max(0, i-6):i+10]!r} (use '%%')"
                    )
                i += 1
                continue
            tok = m.group(0)
            if tok != "%%":
                specs.append(tok)
            i = m.end()
        else:
            i += 1
    return specs


def validate_locales(lua_files: list[pathlib.Path], binding_keys: set[str]) -> None:
    en_path = ROOT / "Locales" / "enUS.lua"
    de_path = ROOT / "Locales" / "deDE.lua"
    en_map = parse_locale_map(en_path)
    de_map = parse_locale_map(de_path)

    en_keys = set(en_map.keys())
    de_keys = set(de_map.keys())

    missing_in_de = sorted(en_keys - de_keys)
    extra_in_de = sorted(de_keys - en_keys)
    if missing_in_de:
        raise ValidationError(f"Missing German (deDE) translations for keys: {missing_in_de}")
    if extra_in_de:
        raise ValidationError(f"Keys in deDE.lua missing from enUS.lua: {extra_in_de}")

    # Verify all required BINDING_* keys exist and are exported to _G in both locale files
    en_raw = en_path.read_text(encoding="utf-8")
    de_raw = de_path.read_text(encoding="utf-8")
    for bkey in sorted(binding_keys):
        if bkey not in en_keys:
            raise ValidationError(f"Bindings.xml requires locale key '{bkey}', missing in enUS.lua")
        if f'_G["{bkey}"]' not in en_raw or f'_G["{bkey}"]' not in de_raw:
            raise ValidationError(f"Global binding key _G['{bkey}'] must be assigned in both enUS.lua and deDE.lua")

    # Verify all L["KEY"] and descriptor key properties exist in enUS, and track formatted keys
    ref_l_re = re.compile(r'L\["([A-Z0-9_]+)"\]')
    key_prop_re = re.compile(r'(?:labelKey|nameKey|descKey|titleKey|bodyKey|category)\s*=\s*"([A-Z0-9_]+)"')
    format_call_re = re.compile(
        r'(?:(?:ns\.)?L\["([A-Z0-9_]+)"\]\s*:\s*format|string\.format\(\s*(?:ns\.)?L\["([A-Z0-9_]+)"\])'
    )

    formatted_keys: set[str] = set()
    referenced_keys: set[str] = set(binding_keys)

    for f in lua_files:
        if "Libs" in f.parts or "Locales" in f.parts:
            continue
        txt = f.read_text(encoding="utf-8")
        refs = set(ref_l_re.findall(txt)) | set(key_prop_re.findall(txt))
        for key in refs:
            if key not in en_keys:
                raise ValidationError(f"{f.relative_to(ROOT)} references undefined locale key '{key}'")
        referenced_keys |= refs

        for m in format_call_re.finditer(txt):
            fkey = m.group(1) or m.group(2)
            if fkey:
                formatted_keys.add(fkey)

    # Validate format specifiers & parity across all keys
    for key in sorted(en_keys):
        is_formatted = key in formatted_keys
        en_specs = extract_format_specifiers(en_map[key], key, "enUS.lua", strict_percent=is_formatted)
        de_specs = extract_format_specifiers(de_map[key], key, "deDE.lua", strict_percent=is_formatted)
        if en_specs != de_specs:
            raise ValidationError(
                f"Format specifier mismatch for L['{key}']: enUS has {en_specs}, deDE has {de_specs}"
            )
        # Also catch accidental '%%' in keys that have 0 format specifiers and are never passed to :format()
        if not is_formatted and not en_specs:
            if "%%" in en_map[key] or "%%" in de_map[key]:
                raise ValidationError(
                    f"L['{key}'] contains '%%' but is never passed to :format() (would render literal '%%' in UI)"
                )

    print(
        f"[OK] Locale & format parity verified ({len(en_keys)} keys in enUS/deDE, {len(formatted_keys)} formatted strings checked)."
    )


def validate_lua_syntax_and_golden_rules(lua_files: list[pathlib.Path]) -> None:
    block_openers = {"function", "if", "do", "repeat"}
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
            # Friz Quadrata (Windows-1252) font glyph safety check on comment-stripped source
            uncommented = strip_lua_comments(raw)
            for lineno, line in enumerate(uncommented.splitlines(), 1):
                for ch in line:
                    if ord(ch) > 127:
                        try:
                            ch.encode("cp1252")
                        except UnicodeEncodeError as exc:
                            raise ValidationError(
                                f"{rel}:{lineno}: Unsupported in-game font glyph {ch!r} (U+{ord(ch):04X}) would render as '▯' in Friz Quadrata"
                            ) from exc

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

    print(f"[OK] Lua 5.1 syntax, cp1252 font safety & Golden Rulebook checks passed across all {len(lua_files)} files.")


def validate_anchoring_math() -> None:
    """Verifies cursor-pivot & scale-compensated anchoring leaves hovered coordinates invariant (including 75% cap)."""
    for old_scale, new_scale in ((1.00, 0.78), (0.75, 0.72), (0.75, 0.75)):
        old_uip_x, old_uip_y = 180.0, -140.0
        local_badge_x, local_badge_y = 940.0, -12.0

        cursor_x = old_uip_x + local_badge_x * old_scale
        cursor_y = old_uip_y + local_badge_y * old_scale

        ratio = new_scale / old_scale
        new_uip_x = cursor_x - (cursor_x - old_uip_x) * ratio
        new_uip_y = cursor_y - (cursor_y - old_uip_y) * ratio

        setpoint_x = new_uip_x / new_scale
        setpoint_y = new_uip_y / new_scale

        after_badge_x = (setpoint_x + local_badge_x) * new_scale
        after_badge_y = (setpoint_y + local_badge_y) * new_scale

        if not (
            math.isclose(after_badge_x, cursor_x, abs_tol=1e-9)
            and math.isclose(after_badge_y, cursor_y, abs_tol=1e-9)
        ):
            raise ValidationError(
                f"Cursor-pivot drift detected! Expected ({cursor_x}, {cursor_y}), got ({after_badge_x}, {after_badge_y})"
            )
    print("[OK] Cursor-pivot & scale-compensated SetPoint math verified (0.000000 px drift).")


def main() -> int:
    try:
        lua_files, _ = validate_toc()
        binding_keys = validate_bindings_xml()
        validate_locales(lua_files, binding_keys)
        validate_lua_syntax_and_golden_rules(lua_files)
        validate_anchoring_math()
    except ValidationError as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    print("\nAll ELLA validation & Golden Rulebook checks PASSED!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
