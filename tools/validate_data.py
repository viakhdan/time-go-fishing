"""Cross-check data/*.json and i18n/strings.csv (DESIGN.md §5, §7, §8, §11).

Checks references between fish, zones and upgrades, that every text key exists
in both languages, and prints an economy summary to compare with §5.

Usage:
    python tools/validate_data.py
"""
import csv
import json
import os
import re
import sys

DATA = "data"
STRINGS = "i18n/strings.csv"
LOCALES = ("uk", "en")
FISH_TEXT_KEYS = ("name_key", "flavor_key", "fact_key", "try_q_key", "try_a_key", "deep_fact_key")
PLACEHOLDER = re.compile(r"\{(\w+)\}")


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


def main():
    errors = []
    err = errors.append

    fish_data, zones, upgrades = load("fish.json"), load("zones.json"), load("upgrades.json")
    rarities, fish = fish_data["rarities"], fish_data["fish"]

    with open(STRINGS, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    if rows[0] != ["keys", *LOCALES]:
        err(f"{STRINGS}: header must be keys,{','.join(LOCALES)}")
    strings = {}
    for row in rows[1:]:
        if len(row) != 3:
            err(f"{STRINGS}: row {row[:1]} has {len(row)} columns")
            continue
        if row[0] in strings:
            err(f"{STRINGS}: duplicate key {row[0]}")
        strings[row[0]] = dict(zip(LOCALES, row[1:]))
        if PLACEHOLDER.findall(row[1]) != PLACEHOLDER.findall(row[2]):
            err(f"{STRINGS}: {row[0]} has different {{placeholders}} in uk and en")

    def need_key(key, where):
        if key not in strings:
            err(f"{where}: key {key} missing from {STRINGS}")
        elif not all(strings[key][loc].strip() for loc in LOCALES):
            err(f"{where}: key {key} is empty in some language")

    # Rarities.
    for rid, r in rarities.items():
        need_key(r["name_key"], f"rarity {rid}")
        if r["tier"] not in (1, 2, 3):
            err(f"rarity {rid}: tier must be 1–3")

    # Fish.
    fish_by_id = {}
    for f_ in fish:
        fid = f_["id"]
        if fid in fish_by_id:
            err(f"duplicate fish {fid}")
        fish_by_id[fid] = f_
        if f_["rarity"] not in rarities:
            err(f"fish {fid}: unknown rarity {f_['rarity']}")
        for k in FISH_TEXT_KEYS:
            need_key(f_[k], f"fish {fid}")
        if f_["avg_size_cm"] <= 0 or f_["deep_fact_unlock"] < 1:
            err(f"fish {fid}: bad avg_size_cm or deep_fact_unlock")

    # Upgrades.
    upg_by_id = {}
    for u in upgrades:
        upg_by_id[u["id"]] = u
        need_key(u["name_key"], f"upgrade {u['id']}")
        need_key(u["desc_key"], f"upgrade {u['id']}")
        if not os.path.exists(u["icon"].replace("res://", "")):
            err(f"upgrade {u['id']}: icon {u['icon']} not found")
        costs = [lv["cost"] for lv in u["levels"]]
        if not costs or costs != sorted(costs) or len(set(costs)) != len(costs):
            err(f"upgrade {u['id']}: costs must be strictly increasing, got {costs}")
        for i, lv in enumerate(u["levels"], 1):
            if set(lv) - {"cost"} != set(u["base"]):
                err(f"upgrade {u['id']} L{i}: effect fields {sorted(set(lv) - {'cost'})} don't match base {sorted(u['base'])}")

    # Zones.
    zone_ids = set()
    for z in zones:
        zid = z["id"]
        zone_ids.add(zid)
        need_key(z["name_key"], f"zone {zid}")
        for fid in z["fish"]:
            if fid not in fish_by_id:
                err(f"zone {zid}: unknown fish {fid}")
            elif fish_by_id[fid]["zone"] != zid:
                err(f"zone {zid}: fish {fid} says its zone is {fish_by_id[fid]['zone']}")
        if not z["enabled"]:
            continue
        if not z["fish"]:
            err(f"zone {zid}: enabled but has no fish")
        if not os.path.exists(os.path.join(DATA, "problems", z["topic"] + ".json")):
            err(f"zone {zid}: enabled but problem pool {z['topic']}.json is missing")
        unlock = z["unlock"]
        if unlock:
            u = upg_by_id.get(unlock["upgrade"])
            if not u:
                err(f"zone {zid}: unlock upgrade {unlock['upgrade']} doesn't exist")
            elif not u["enabled"]:
                err(f"zone {zid}: enabled, but its unlock upgrade {u['id']} is disabled")
            elif not 1 <= unlock["level"] <= len(u["levels"]):
                err(f"zone {zid}: unlock level {unlock['level']} out of range")
    for fid, f_ in fish_by_id.items():
        if f_["zone"] not in zone_ids:
            err(f"fish {fid}: unknown zone {f_['zone']}")
        elif fid not in next(z for z in zones if z["id"] == f_["zone"])["fish"]:
            err(f"fish {fid}: not listed in zone {f_['zone']}")

    print_economy(fish_data, zones, upgrades)
    for e in errors:
        print("  ✗", e)
    print("OK" if not errors else f"{len(errors)} error(s)")
    sys.exit(1 if errors else 0)


def print_economy(fish_data, zones, upgrades):
    """Expected coins per catch at average size (§5.1) and total upgrade cost (§5.2)."""
    rarities = fish_data["rarities"]
    by_id = {f["id"]: f for f in fish_data["fish"]}
    print("Economy (no bait, average size):")
    for z in zones:
        if not z["enabled"]:
            continue
        present = {by_id[fid]["rarity"] for fid in z["fish"]}
        total_w = sum(rarities[r]["weight"] for r in present)
        ev = sum(rarities[r]["weight"] * rarities[r]["base_price"] for r in present) / total_w
        print(f"  {z['id']:6} ≈ {ev:.1f} coins per catch")
    enabled = [u for u in upgrades if u["enabled"]]
    total = sum(lv["cost"] for u in enabled for lv in u["levels"])
    print(f"  all enabled upgrades: {total} coins ({', '.join(u['id'] for u in enabled)})")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
