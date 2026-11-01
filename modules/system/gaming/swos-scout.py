"""swos-scout: read-only scouting report for an OpenSWOS career save.

Purpose:
    Rate every player in your squad and in the world database by how well
    their skills suit their position, next to their market value, so you can
    see who is worth keeping and who is worth buying. The save is only read.

    Rating (0-100): the player's seven skills (0-7) weighted by how much each
    one counts at his position (WEIGHTS below, a judgement call, not a game
    table). Goalkeepers have no skills in SWOS. Their quality is their price
    index, so their rating is that index scaled to 0-100.

    Value: what the game shows as the player's price. It is the price index
    plus a form adjustment, looked up in the game's value table
    (GetDisplayedPlayerValue / FormatPlayerValueOrStatusText).

Dependencies:
    Python 3 standard library only. Reads ~/.swos/save/*.CAR (OpenSWOS JSON
    careers) and ~/.swos/assets/data_json/teams/*.json (the team database).

Author:
    AI (Claude), for Michal's nixos-config.
"""

import argparse
import glob
import json
import os
import sys

POS = ["GK", "RB", "LB", "D", "RW", "LW", "M", "A"]
POS_LONG = {
    "GK": "Goalkeepers", "RB": "Right backs", "LB": "Left backs",
    "D": "Centre backs", "RW": "Right wingers", "LW": "Left wingers",
    "M": "Midfielders", "A": "Attackers",
}
# Order the game shows skills in, and the save's field names.
SKILLS = ["passing", "velocity", "heading", "tackling",
          "control", "speed", "finishing"]
SKILL_LETTERS = ["P", "V", "H", "T", "C", "S", "F"]

# How much each skill (P V H T C S F) counts at each outfield position.
# Hand-set from how the match engine uses them: speed everywhere; tackling
# and heading at the back; passing and control in midfield; finishing,
# control, shot power (V) and heading up front. (The game's own
# position-value tables, docs/TACTICS_POSITION_VALUE.md, set the price and
# barely weigh finishing for attackers, so they are not a scouting guide.)
WEIGHTS = {
    1: dict(passing=2, velocity=0, heading=1, tackling=4, control=1, speed=3, finishing=0),  # RB
    2: dict(passing=2, velocity=0, heading=1, tackling=4, control=1, speed=3, finishing=0),  # LB
    3: dict(passing=1, velocity=0, heading=3, tackling=4, control=1, speed=2, finishing=0),  # D
    4: dict(passing=2, velocity=1, heading=0, tackling=1, control=3, speed=4, finishing=1),  # RW
    5: dict(passing=2, velocity=1, heading=0, tackling=1, control=3, speed=4, finishing=1),  # LW
    6: dict(passing=4, velocity=1, heading=1, tackling=2, control=3, speed=2, finishing=1),  # M
    7: dict(passing=1, velocity=2, heading=2, tackling=0, control=3, speed=3, finishing=4),  # A
}

# _avgTeamValues (price index + form -> value step) and _avgTeamValueBases
# (value step -> value in thousands of pounds).
AVG_TEAM_VALUES = [
    5, 5, 6, 8, 10, 13, 15, 17, 20, 21, 23, 25, 26, 28, 30, 32, 34, 35, 37,
    38, 39, 40, 41, 42, 43, 44, 45, 47, 48, 49, 51, 53, 54, 56, 57, 58, 59,
    61, 62, 63, 65, 66, 67, 68, 69, 70, 71, 73, 76, 76,
]
VALUE_BASES = [
    0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85,
    90, 95, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 225, 250,
    275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900,
    950, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000,
    2250, 2500, 2750, 3000, 3500, 4000, 4500, 5000, 6000, 7000, 8000, 9000,
    10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000,
    20000, 21000, 22000, 23000, 24000, 25000, 26000, 27000, 28000, 29000,
    30000,
]
# kPlayerAgeToFormDivisorTable (indexed by price index).
FORM_DIVISOR = [
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 9, 9, 9, 10, 10, 12, 12, 12, 15, 15, 15,
    15, 15, 15, 15,
]
FORM_TRIALIST = -101   # 0x9B as a signed byte
FORM_RESERVE = -102    # 0x9A
PF_INFORM, PF_LOAN = 0x01, 0x02


def skill(p, name):
    """The 0-7 skill the match engine uses (the high bit of the nibble is ignored)."""
    return p[name] & 7


def rating(p):
    """0-100 position-weighted rating (GK: price index scaled)."""
    if p["position"] == 0:
        return round(min(p["price"], 49) / 49 * 100)
    w = WEIGHTS[p["position"]]
    return round(sum(w[s] * skill(p, s) for s in SKILLS) / (7 * sum(w.values())) * 100)


def value_k(p):
    """Displayed market value in thousands of pounds."""
    price = max(0, min(p["price"], 49))
    form = p["form"]
    if form in (FORM_TRIALIST, FORM_RESERVE):
        form = 0
    elif p["flags"] & PF_INFORM:
        form *= 2
    step = AVG_TEAM_VALUES[price] + int(form / FORM_DIVISOR[price])
    return VALUE_BASES[max(1, min(step, 80))]


def money(k):
    """Format thousands of pounds the way the game does (750K, 1.5M)."""
    if k < 1000:
        return f"{k}K"
    m = k / 1000
    return f"{m:.2f}".rstrip("0").rstrip(".") + "M"


def status(p):
    """Short status column: injury, cards, loan, trialist/reserve, form."""
    out = []
    if p["form"] == FORM_TRIALIST:
        out.append("TRIAL")
    elif p["form"] == FORM_RESERVE:
        out.append("RES")
    elif p["form"]:
        out.append(f"form{p['form']:+d}")
    if p["flags"] & PF_LOAN:
        out.append("LOAN")
    if p["injury"]:
        out.append(f"INJ{p['injury']}")
    if p["cards"]:
        out.append(f"cards{p['cards']}")
    return " ".join(out)


def latest_save(save_dir):
    """Most recently written career save."""
    saves = glob.glob(os.path.join(save_dir, "*.CAR"))
    if not saves:
        sys.exit(f"swos-scout: no career saves (*.CAR) in {save_dir}")
    return max(saves, key=os.path.getmtime)


def world_players(save, db_dir, own_gtn):
    """Every player you could bid for: teams in the save (current skills and
    form) first, then the rest of the database (as the season started)."""
    seen_teams, players = set(), []

    def add(team, plist, source):
        gtn = team["global_team_number"]
        if gtn == own_gtn or gtn in seen_teams:
            return
        seen_teams.add(gtn)
        for p in plist:
            if p.get("player_name"):
                players.append((team["team_name"], source, p))

    for t in (save.get("selected_teams") or []) + (save.get("tmd_teams") or []):
        add(t["team"], t["players"], "save")
    for path in sorted(glob.glob(os.path.join(db_dir, "*.json"))):
        try:
            with open(path, encoding="utf-8") as f:
                doc = json.load(f)
        except (OSError, ValueError):
            continue
        if doc.get("type") != "team":
            continue
        for t in doc.get("teams", []):
            add(t["team"], t["players"], "db")
    return players


def row(p, team=None):
    """One table row: position, rating, skills, value, status."""
    skills = " ".join(
        "-" if p["position"] == 0 else str(skill(p, s)) for s in SKILLS)
    name = p["player_name"].title()
    club = f"{team.title()[:18]:<18} " if team is not None else ""
    return (f"{POS[p['position']]:<3}{rating(p):>4}  {name[:22]:<22} {club}"
            f"{skills}  {money(value_k(p)):>6}  {status(p)}")


def header(with_club):
    """Column header matching row()."""
    club = f"{'Club':<18} " if with_club else ""
    return (f"Pos Rtg  {'Name':<22} {club}{' '.join(SKILL_LETTERS)}  "
            f"{'Value':>6}  Status")


def main():
    """Print the squad report, then the best buys per position."""
    ap = argparse.ArgumentParser(
        description="Read-only OpenSWOS career scouting report.")
    ap.add_argument("save", nargs="?", help="career save (default: newest ~/.swos/save/*.CAR)")
    ap.add_argument("--pos", help="only this position (GK RB LB D RW LW M A)")
    ap.add_argument("--top", type=int, default=5, help="buys listed per position (default 5)")
    ap.add_argument("--budget", type=float,
                    help="max price in £M (default: your bank balance)")
    ap.add_argument("--squad", action="store_true", help="squad only, no market")
    ap.add_argument("--market", action="store_true", help="market only, no squad")
    args = ap.parse_args()

    home = os.path.expanduser("~/.swos")
    path = args.save or latest_save(os.path.join(home, "save"))
    with open(path, encoding="utf-8") as f:
        save = json.load(f)

    sc = save["career_scalars"]
    team = save["career_team"]["team"]
    squad = save["career_team"]["players"] + (save.get("career_team_reserves") or [])
    squad = [p for p in squad if p.get("player_name")]
    balance = sc.get("new_balance", 0)
    budget_k = (args.budget * 1000 if args.budget is not None
                else max(balance, 0) / 1000)
    only = args.pos.upper() if args.pos else None
    if only and only not in POS:
        sys.exit(f"swos-scout: unknown position {args.pos} (one of {' '.join(POS)})")

    print(f"{team['team_name'].title()} - {os.path.basename(path)} - "
          f"balance £{balance:,} - squad value "
          f"{money(sum(value_k(p) for p in squad))}")
    print("Rating: skills weighted for the position (GK: price index), 0-100. "
          "Skills shown 0-7.\n")

    market = []
    if not args.squad:
        db_dir = os.path.join(home, "assets", "data_json", "teams")
        market = world_players(save, db_dir, team["global_team_number"])

    def upgrades(pos, floor, cap_k):
        """Market players at `pos` rated above `floor` and costing <= cap_k."""
        return sorted(
            (m for m in market
             if m[2]["position"] == pos and rating(m[2]) > floor
             and value_k(m[2]) <= cap_k),
            key=lambda m: (-rating(m[2]), value_k(m[2])))

    if not args.market:
        print("YOUR SQUAD (by position, best first)")
        print(header(False) + "  Verdict")
        for pos in range(8):
            if only and POS[pos] != only:
                continue
            group = sorted((p for p in squad if p["position"] == pos),
                           key=rating, reverse=True)
            for i, p in enumerate(group):
                verdict = "keep"
                if market:
                    # Could you replace him with someone clearly better using
                    # your balance plus his own sale price?
                    better = upgrades(pos, rating(p) + 10, budget_k + value_k(p))
                    if better:
                        b = better[0][2]
                        verdict = (f"upgrade: {b['player_name'].title()} "
                                   f"({rating(b)}, {money(value_k(b))})")
                if i >= 2 and verdict == "keep" and pos != 0:
                    verdict = "depth"
                print(f"{row(p)}  {verdict}")
        print()

    if market and not args.squad:
        print(f"BEST BUYS within {money(int(budget_k))} "
              f"(rated above your best at the position)")
        for pos in range(8):
            if only and POS[pos] != only:
                continue
            mine = max((rating(p) for p in squad if p["position"] == pos), default=0)
            best = upgrades(pos, mine, budget_k)[: args.top]
            print(f"\n{POS_LONG[POS[pos]]} (your best: {mine})")
            if not best:
                print("  nobody better within budget")
                continue
            print("  " + header(True))
            for club, src, p in best:
                print("  " + row(p, club) + ("" if src == "save" else "  *"))
        print("\n* not in your save: skills and value as the season started.")


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
