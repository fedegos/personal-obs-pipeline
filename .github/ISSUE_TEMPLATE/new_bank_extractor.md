---
name: New Bank Extractor
about: Request support for a new bank or card type
title: '[EXTRACTOR] '
labels: extractor, enhancement
assignees: ''
---

## Bank Information

- **Bank Name**: [e.g., Banco Santander]
- **Country**: [e.g., Argentina]
- **Card Network**: [Visa / Mastercard / Amex / Other]
- **Statement Format**: [PDF / Excel / CSV / Other]

## Statement Structure

Describe the structure of the statement:

- How are transactions listed? (table, text blocks, etc.)
- What fields are available? (date, description, amount, installments, etc.)
- Are there multiple currencies?
- Are installments shown separately or as a single line?

## Sample File

Please attach an **anonymized** sample file, or describe what a typical row looks like:

```
15/01/2026  MERCADOLIBRE*COMPRA  $12.500,00  3/6
```

## Willingness to Contribute

- [ ] I can provide multiple sample files for testing
- [ ] I'm willing to help develop the extractor
- [ ] I just need this feature and can't contribute code

## Additional Notes

Any other information that might help implement this extractor.
