#!/usr/bin/env python3
"""Reporta fecha_vencimiento extraída por cada sample PDF."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bank_extractors import get_extractor

EXTRACTORS = [
    ("amex_pdf", "samples/amex"),
    ("bbva_pdf_visa", "samples/bbva"),
    ("bapro_pdf_visa", "samples/bapro"),
]

def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for bank_id, subdir in EXTRACTORS:
        path = os.path.join(base, subdir)
        if not os.path.isdir(path):
            continue
        files = sorted([f for f in os.listdir(path) if f.endswith(".pdf")])
        for f in files:
            fp = os.path.join(path, f)
            try:
                with open(fp, "rb") as fh:
                    kwargs = {"filename": f}
                    if bank_id == "amex_pdf":
                        kwargs["year"] = 2025
                    df = get_extractor(bank_id)(fh.read(), **kwargs)
                if "fecha_vencimiento" in df.columns and df["fecha_vencimiento"].notna().any():
                    fv = df["fecha_vencimiento"].iloc[0]
                else:
                    fv = "—"
                txs = len(df)
                print(f"{bank_id:20} | {f:50} | {txs:4} txs | vto={fv}")
            except Exception as e:
                print(f"{bank_id:20} | {f:50} | ERROR: {e}")

if __name__ == "__main__":
    main()
