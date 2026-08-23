#!/usr/bin/env python3
"""Clear a feature's checkbox in docs/parity/FEATURES.md."""
import sys, re, pathlib

ledger = pathlib.Path(__file__).resolve().parents[2] / "docs/parity/FEATURES.md"
text = ledger.read_text()
for fid in sys.argv[1:]:
    pattern = re.compile(r"^- \[x\] `" + re.escape(fid) + r"`", re.M)
    text, n = pattern.subn("- [ ] `" + fid + "`", text)
    print(("unchecked " if n else "NOT FOUND ") + fid)
ledger.write_text(text)
