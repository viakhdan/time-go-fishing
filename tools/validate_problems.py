"""Validate the problem pools in data/problems/ (DESIGN.md §6).

For every problem this computes the real answer with sympy from the dev-only
`check` field and verifies that exactly one option equals it, at `answer_index`.
It also checks structure, pool sizes and text hygiene.

`check` format (never shown to players, like `distractor_notes`):
    {"kind": "evaluate", "expr": "2³ + 3²"}
    {"kind": "evaluate", "expr": "2a + 3a", "subs": {"a": 4}}
    {"kind": "simplify", "expr": "(2x²)³"}
    {"kind": "solve",    "expr": "3x − 4 = 11"}
    {"kind": "solve",    "expr": "3x − 5 = x + 7", "word_problem": true}
`expr` is written exactly as the player sees it and must appear verbatim in both
the uk and en question (and so must "a = 4" for `subs`), unless `word_problem`.

Usage:
    python tools/validate_problems.py [files...]   (default: data/problems/*.json)
"""
import glob
import json
import re
import sys
from collections import Counter

import sympy as sp
from sympy.parsing.sympy_parser import (
    implicit_multiplication_application,
    parse_expr,
    standard_transformations,
)

PER_TIER = 15
TIERS = (1, 2, 3)
KINDS = ("evaluate", "simplify", "solve")
LOCALES = ("uk", "en")

SUPERSCRIPTS = str.maketrans("⁰¹²³⁴⁵⁶⁷⁸⁹", "0123456789")
SUPERSCRIPT_RUN = re.compile("[⁰¹²³⁴⁵⁶⁷⁸⁹]+")
CYRILLIC = re.compile("[Ѐ-ӿ]")
# ASCII look-alikes that must be typographic in player-facing text.
FORBIDDEN_ASCII = {"-": "use − (U+2212)", "*": "use · (U+00B7)", "^": "use superscripts"}
WORD_HYPHEN = re.compile(r"(?<=[^\W\d_]{2})-(?=[^\W\d_]{2})")
ID_PATTERN = re.compile(r"^[a-z]+_t([123])_\d{3}$")
SYMBOLS = {c: sp.Symbol(c) for c in "abcmnxy"}
TRANSFORMS = standard_transformations + (implicit_multiplication_application,)
X = SYMBOLS["x"]


def to_sympy(text):
    """Parse player-facing math (2x², −3, a⁸ : a², 7/3, 1 000 000) into sympy."""
    s = text.replace("−", "-").replace("·", "*").replace(":", "/").replace("°", "").replace(" ", "")
    s = SUPERSCRIPT_RUN.sub(lambda m: "**" + m.group().translate(SUPERSCRIPTS), s)
    return parse_expr(s, local_dict=SYMBOLS, transformations=TRANSFORMS)


def fmt_number(n):
    return str(n).replace("-", "−")


def equal(a, b):
    return sp.simplify(a - b) == 0


def compute_answer(check):
    kind, expr = check["kind"], check["expr"]
    if kind == "solve":
        lhs, rhs = expr.split("=")
        solutions = sp.solve(sp.Eq(to_sympy(lhs), to_sympy(rhs)), X)
        if len(solutions) != 1:
            raise ValueError(f"equation must have exactly one solution, got {solutions}")
        return solutions[0]
    value = to_sympy(expr)
    if kind == "evaluate":
        value = value.subs({SYMBOLS[k]: v for k, v in check.get("subs", {}).items()})
        if not value.is_number:
            raise ValueError(f"evaluate did not produce a number: {value}")
    return value


def validate_problem(p, topic, errors):
    pid = p.get("id", "<no id>")

    def err(msg):
        errors.append(f"{pid}: {msg}")

    required = ("id", "topic", "tier", "question", "options", "answer_index", "solution", "distractor_notes", "check")
    missing = [k for k in required if k not in p]
    if missing:
        return err(f"missing fields {missing}")

    m = ID_PATTERN.match(pid)
    if not m:
        err("id must look like lin_t2_004")
    elif int(m.group(1)) != p["tier"]:
        err("tier in id doesn't match `tier`")
    if p["topic"] != topic:
        err(f"topic {p['topic']!r} doesn't match file topic {topic!r}")
    if p["tier"] not in TIERS:
        err(f"tier must be one of {TIERS}")

    # Localized text.
    for field in ("question", "solution"):
        for loc in LOCALES:
            text = p[field].get(loc, "")
            if not text.strip():
                err(f"{field}.{loc} is empty")
            elif loc == "en" and CYRILLIC.search(text):
                err(f"{field}.en contains Cyrillic")
        if not CYRILLIC.search(p["question"].get("uk", "")):
            err("question.uk has no Ukrainian text")

    # Options and notes.
    options, idx, notes = p["options"], p["answer_index"], p["distractor_notes"]
    if len(options) != 4:
        return err("needs exactly 4 options")
    if not (isinstance(idx, int) and 0 <= idx < 4):
        return err("answer_index must be 0–3")
    if len(notes) != 4:
        err("distractor_notes needs 4 entries")
    else:
        if notes[idx]:
            err("the note for the correct option should be empty")
        if any(not n.strip() for i, n in enumerate(notes) if i != idx):
            err("every wrong option needs a distractor note (real student mistake)")

    player_text = [*options, *p["question"].values(), *p["solution"].values()]
    for text in player_text:
        # A hyphen inside a word ("co-interior") is fine; anywhere else it's a math minus.
        math_text = WORD_HYPHEN.sub("", text)
        for ch, fix in FORBIDDEN_ASCII.items():
            if ch in math_text:
                err(f"ASCII {ch!r} in {text!r}: {fix}")

    # Math.
    check = p["check"]
    if check.get("kind") not in KINDS:
        return err(f"check.kind must be one of {KINDS}")
    if not check.get("word_problem"):
        needles = [check["expr"]]
        needles += [f"{var} = {fmt_number(val)}" for var, val in check.get("subs", {}).items()]
        for loc in LOCALES:
            for needle in needles:
                if needle not in p["question"][loc]:
                    err(f"question.{loc} doesn't contain {needle!r} verbatim")
    try:
        answer = compute_answer(check)
        parsed = [to_sympy(o) for o in options]
    except Exception as e:  # noqa: BLE001 - report any parse/solve failure
        return err(f"could not evaluate: {e}")

    matches = [i for i, o in enumerate(parsed) if equal(o, answer)]
    if matches != [idx]:
        err(f"computed answer {answer} matches options {matches}, answer_index is {idx} ({options})")
    for i in range(4):
        for j in range(i + 1, 4):
            if equal(parsed[i], parsed[j]):
                err(f"options {options[i]!r} and {options[j]!r} are equivalent")
    if check["kind"] != "simplify" and not all(o.is_number for o in parsed):
        err("options for evaluate/solve must be numbers")


def validate_file(path):
    errors = []
    topic = path.replace("\\", "/").rsplit("/", 1)[-1].removesuffix(".json")
    with open(path, encoding="utf-8") as f:
        problems = json.load(f)

    ids = Counter(p.get("id") for p in problems)
    errors += [f"duplicate id {i}" for i, n in ids.items() if n > 1]
    questions = Counter(p.get("question", {}).get("en") for p in problems)
    errors += [f"duplicate question {q!r}" for q, n in questions.items() if n > 1]
    tiers = Counter(p.get("tier") for p in problems)
    for t in TIERS:
        if tiers[t] < PER_TIER:
            errors.append(f"tier {t} has {tiers[t]} problems, needs {PER_TIER}")

    for p in problems:
        validate_problem(p, topic, errors)

    positions = Counter(p.get("answer_index") for p in problems)
    summary = ", ".join(f"t{t}: {tiers[t]}" for t in TIERS)
    print(f"{path}: {len(problems)} problems ({summary}); answer_index spread {dict(sorted(positions.items()))}")
    return errors


def main():
    files = sys.argv[1:] or sorted(glob.glob("data/problems/*.json"))
    if not files:
        sys.exit("No problem files found.")
    errors = []
    for path in files:
        errors += validate_file(path)
    for e in errors:
        print("  ✗", e)
    print("OK" if not errors else f"{len(errors)} error(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
