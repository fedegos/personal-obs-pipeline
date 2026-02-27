# Contributing to Audit-X

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Git
- Make (optional, but recommended)

### Local Environment

```bash
# Clone the repository
git clone https://github.com/fedegos/personal-obs-pipeline.git
cd personal-obs-pipeline

# Copy environment configuration
cp .env.example .env
# Edit .env with your credentials

# Start all services
docker compose up -d

# Run tests to verify setup
make test
```

## Code Standards

### Ruby/Rails (web-enrichment-app)

- Follow [Ruby Style Guide](https://rubystyle.guide/)
- Run `make ci-rails-lint` before committing
- Write tests for new features in `test/`
- Use Service Objects for complex business logic

### Python (ingestion-engine)

- Follow PEP 8
- Run `make ci-python-lint` before committing
- Write tests in `tests/` using pytest
- Type hints are encouraged

### Commits

- Use conventional commit messages:
  - `feat: add Santander PDF extractor`
  - `fix: handle empty transactions in BBVA parser`
  - `docs: update README with new bank support`
  - `refactor: extract common PDF parsing logic`
  - `test: add coverage for installment detection`

## Adding a New Bank Extractor

This is the most common contribution. Here's how to add support for a new bank:

### 1. Gather Sample Files

Collect 3-5 sample PDF/Excel statements from different periods. Place them in:

```
ingestion-engine/samples/<bank_name>/
```

### 2. Analyze the Structure

Use `pdfplumber` to understand the PDF structure:

```python
import pdfplumber

with pdfplumber.open("sample.pdf") as pdf:
    for page in pdf.pages:
        print(page.extract_text())
        print(page.extract_tables())
```

### 3. Create the Extractor

Create a new file in `ingestion-engine/bank_extractors/`:

```python
# ingestion-engine/bank_extractors/<bank>_<network>_extractor.py

from bank_extractors.pdf.pdf_extractor_base import PdfExtractorBase

class NewBankExtractor(PdfExtractorBase):
    """Extractor for NewBank Visa PDF statements."""
    
    def extract(self, file_path: str) -> list[dict]:
        """Extract transactions from PDF.
        
        Returns:
            List of dicts with keys:
            - fecha_transaccion: date string (YYYY-MM-DD)
            - monto: float (positive for charges)
            - detalles: str (merchant/description)
            - en_cuotas: bool
            - descripcion_cuota: str or None (e.g., "2/6")
        """
        # Implementation here
        pass
```

### 4. Register the Extractor

Add to `ingestion-engine/bank_extractors/__init__.py`:

```python
from .newbank_visa_extractor import NewBankExtractor

EXTRACTORS = {
    # ... existing extractors
    "newbank_visa": NewBankExtractor,
}
```

### 5. Add UI Support

Update `web-enrichment-app/config/initializers/bank_schemas.rb`:

```ruby
BANK_SCHEMAS["newbank_visa"] = {
  label: "NewBank Visa (PDF)",
  file_types: %w[pdf],
  # ...
}
```

### 6. Write Tests

Create test file `ingestion-engine/tests/test_extractors_newbank.py`:

```python
import pytest
from bank_extractors import NewBankExtractor

class TestNewBankExtractor:
    def test_extracts_basic_transaction(self):
        extractor = NewBankExtractor()
        result = extractor.extract("samples/newbank/sample_202501.pdf")
        
        assert len(result) > 0
        assert "fecha_transaccion" in result[0]
        assert "monto" in result[0]
```

### 7. Submit PR

- Ensure all tests pass: `make test`
- Ensure linting passes: `make ci`
- Include sample output in PR description (anonymized)

## Improving Grafana Dashboards

Dashboards are defined as JSON in `grafana/dashboards/`. To contribute:

1. Make changes in the Grafana UI (localhost:3001)
2. Export the dashboard JSON
3. Place in `grafana/dashboards/`
4. Test with `docker compose restart grafana`

### Dashboard Guidelines

- Use consistent color schemes across panels
- Include meaningful titles and descriptions
- Prefer relative time ranges ($__timeFilter)
- Test with various data ranges

## Reporting Issues

When reporting bugs, please include:

- Steps to reproduce
- Expected vs actual behavior
- Sample file (anonymized) if relevant
- Docker logs if applicable: `docker compose logs <service>`

## Questions?

Open a Discussion on GitHub or reach out to the maintainers.
