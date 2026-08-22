#!/usr/bin/env python3
"""Tick a feature's checkbox in docs/parity/FEATURES.md."""
import sys, re, pathlib

ledger = pathlib.Path(__file__).resolve().parents[2] / "docs/parity/FEATURES.md"
text = ledger.read_text()
for fid in sys.argv[1:]:
    pattern = re.compile(r"^- \[ \] `" + re.escape(fid) + r"`", re.M)
    text, n = pattern.subn("- [x] `" + fid + "`", text)
    print(("checked " if n else "NOT FOUND ") + fid)
ledger.write_text(text)
