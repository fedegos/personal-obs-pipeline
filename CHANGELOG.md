# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Improved README with conceptual description, use cases, and roadmap
- CONTRIBUTING.md with guidelines for adding bank extractors
- .env.example for easier onboarding

## [0.5.0] - 2026-02-27

### Added
- **Event Repository**: Immutable event store with versioning, upcasting, and global index
- Event Store viewer in admin UI with filtering and aggregate replay
- Kafka timestamp as canonical event time source
- BBVA Mastercard PDF extractor

### Changed
- Grafana pinned to version 11.4.0 in production
- Brakeman configured to ignore version warnings

### Fixed
- Docker image deployment to Coolify with proper cache invalidation
- Database migrations run automatically on Coolify deploy

## [0.4.0] - 2026-02-23

### Added
- GitHub Actions CI/CD pipeline with Docker image registry
- Automatic deployment to Coolify via webhook
- `fecha_vencimiento` (due date) field for credit card statements
- `origen` field to distinguish partial vs definitive statements

### Changed
- Production images now built in GitHub Actions instead of Coolify

## [0.3.0] - 2026-02-13

### Added
- Test coverage reporting with SimpleCov
- System tests for transaction approval workflow

### Changed
- Improved test organization and fixtures

## [0.2.0] - 2026-02-04

### Added
- **American Express PDF extractor**
- **Banco Provincia Visa PDF extractor**
- **BBVA Visa PDF extractor**
- JSON import/export for categorization rules
- Solid Cache and Solid Queue for Rails 8

### Changed
- Categorization rules now support sentiment (Necessary/Desire)
- Transaction cards show suggestion indicators

## [0.1.0] - 2026-01-29

### Added
- Initial release
- Rails web application for transaction management
- Python ingestion engine with Kafka consumers
- PostgreSQL for transactional data
- InfluxDB + Grafana for time-series visualization
- MinIO for file storage
- Redpanda as Kafka-compatible message broker
- Basic categorization rules engine
- Transaction approval workflow

---

## Migration Notes

### Upgrading to 0.5.0

The Event Repository requires a new database migration:

```bash
docker compose exec web bin/rails db:migrate
```

### Upgrading to 0.4.0

New fields added to transactions table:

```bash
docker compose exec web bin/rails db:migrate
```
