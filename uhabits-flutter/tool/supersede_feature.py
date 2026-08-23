#!/usr/bin/env python3
"""Mark a ledger feature as superseded, with the reason recorded inline.

A superseded feature is one the port replaces by design rather than reproduces:
the Android or JVM implementation of a seam the Flutter app implements its own
way, or a feature the project explicitly decided to drop. It is neither done nor
outstanding work, and counting it as either would make the ledger lie.

Usage: supersede_feature.py "<reason>" <feature-id> [<feature-id> ...]
"""
import sys, re, pathlib

if len(sys.argv) < 3:
    sys.exit(__doc__)

reason = sys.argv[1]
ledger = pathlib.Path(__file__).resolve().parents[2] / "docs/parity/FEATURES.md"
text = ledger.read_text()

for fid in sys.argv[2:]:
    pattern = re.compile(
        r"^- \[[ x]\] `" + re.escape(fid) + r"`(.*)$", re.M)
    match = pattern.search(text)
    if not match:
        print("NOT FOUND " + fid)
        continue
    replacement = ("- [~] `" + fid + "`" + match.group(1) +
                   "\n- **Disposition:** superseded — " + reason)
    text = text[:match.start()] + replacement + text[match.end():]
    print("superseded " + fid)

ledger.write_text(text)
