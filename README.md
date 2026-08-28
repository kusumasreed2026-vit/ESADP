# Enterprise Sales Analytics Data Platform (ESADP)

> A unified sales performance and revenue analytics platform built on a medallion (Bronze–Silver–Gold) data architecture, integrating ten heterogeneous enterprise data sources into a governed PostgreSQL warehouse with executive Power BI reporting.

[![Status](https://img.shields.io/badge/status-in%20progress-yellow)]()
[![Sprint](https://img.shields.io/badge/sprint-1%20of%203-blue)]()
[![License](https://img.shields.io/badge/license-Academic%20Use-lightgrey)]()

---

## Overview

ABC Global Retail Ltd. (fictional client) sells through retail stores, e-commerce, distributors, dealers, and corporate channels across multiple countries. Point of Sale, Sales Order Management, CRM, ERP, Product Catalog, Pricing, Inventory, Marketing, and Dealer Management systems all operate independently today, leaving no single view of sales performance, revenue trend, inventory position, or customer behaviour across the business.

**ESADP** solves this by ingesting, cleansing, and modeling data from all ten source systems into a single governed warehouse, surfaced through executive dashboards — the same problem, and the same architectural pattern, a real enterprise data engineering team would be asked to solve.

This repository is the engineering implementation of that platform: ETL pipelines, schema definitions, transformation logic, governance artifacts, and reporting assets, built incrementally across three sprints.

## Architecture

The platform follows a **medallion architecture**.

| Zone | Purpose |
|---|---|
| **Bronze** | Ingests and stages raw data exactly as received from each of the ten source systems, in its native or converted format (CSV, Excel, JSON, XML, SQL). No transformation logic — a raw, auditable landing zone. |
| **Silver** | Cleanses, validates, and standardizes staged data — deduplication, null handling, type conformance, business-rule application. |
| **Gold** | Curated star-schema warehouse, subject-area data marts, and the analytics layer that Power BI connects to directly. |
| **Governance** | Runs parallel to all three zones — metadata repository, data lineage, data dictionary, and business glossary. |

PostgreSQL underpins both the Bronze staging layer and the Gold warehouse layer (in separate schemas within the same database), keeping ingestion and cleansing as distinct, auditable steps while still requiring genuine schema design and query-writing across the pipeline.

*Architecture diagram: see [`docs/architecture.png`](docs/architecture.png).*

## Data Sources

All ten systems named in the use case are represented using real, publicly available data — primarily the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and the [Olist Marketing Funnel dataset](https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist), Kaggle.

| # | Source System | Dataset | Format |
|---|---|---|---|
| 1 | Sales Order Management | `olist_orders_dataset.csv` | CSV (native) |
| 2 | Point of Sale (POS) | `olist_order_items_dataset.csv` | SQL (converted) |
| 3 | CRM | `olist_customers_dataset.csv` | JSON (converted) |
| 4 | E-Commerce Platform | Same transactional core as #1/#2, documented not re-ingested | JSON (converted) |
| 5 | ERP | `olist_order_payments_dataset.csv` | XML (converted) |
| 6 | Dealer Management | `olist_sellers_dataset.csv` | XML (converted) |
| 7 | Product Catalog | `olist_products_dataset.csv` + `product_category_name_translation.csv` | Excel (converted) |
| 8 | Pricing Management | Price/freight data extracted from order items | Excel (converted) |
| 9 | Inventory Management | Self-generated (`generate_inventory_data.py`, anchored to real `product_id`s) | SQL (native) |
| 10 | Marketing Campaign | `olist_marketing_qualified_leads_dataset.csv` + `olist_closed_deals_dataset.csv` | CSV (native) |

Full source-to-format rationale is documented in [`docs/BRD.md`](docs/BRD.md), Section 2.4.

## Repository Structure
```text
ESADP/
├── docs/                         # BRD, architecture, data dictionary, lineage, glossary
├── config/                       # Environment and connection configuration
├── datasets/
│   ├── bronze/
│   │   ├── ingestion/            # Raw source exports as received
│   │   └── staging/              # PostgreSQL staging table definitions
│   ├── silver/
│   │   ├── cleansing/            # Cleansing scripts and rules
│   │   ├── validation/           # Data quality checks
│   │   └── transformations/      # Business-rule transformations
│   └── gold/
│       ├── warehouse/             # Star schema DDL (fact + dimension tables)
│       ├── datamarts/             # Subject-area views
│       └── analytics/             # Analytics-ready exports
├── pentaho/
│   ├── transformations/           # .ktr transformation files
│   └── jobs/                      # .kjb orchestration jobs
├── python/                        # Profiling, cleansing, and generation scripts
├── sql/                           # DDL, reporting, and reconciliation queries
├── metadata/                      # Data dictionary and technical metadata
├── lineage/                       # Source-to-target mapping and lineage docs
├── dashboards/                    # Power BI .pbix files
├── deployment/                    # Setup and deployment scripts
├── tests/                         # Data quality and pipeline tests
└── README.md

```

## Tech Stack

| Layer | Technology |
|---|---|
| ETL | Pentaho Data Integration (Spoon) |
| Database | PostgreSQL |
| Data Profiling / Cleansing | Python (Pandas) |
| Reporting | Power BI |
| Version Control | Git & GitHub |
| Documentation | Markdown / MS Word |
| Methodology | Agile Scrum |

## Getting Started

### Prerequisites

- PostgreSQL 14+
- Pentaho Data Integration (Spoon) 9.x
- Python 3.10+ with `pandas`, `sqlalchemy`, `psycopg2-binary`
- Power BI Desktop (for dashboard development)

### Setup


# Clone the repository
git clone https://github.com/<org>/ESADP.git
cd ESADP

# Create and activate a virtual environment
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate

# Install Python dependencies
pip install -r requirements.txt

# Create the Bronze/Silver/Gold schemas
psql -U <user> -d <database> -f sql/ddl/00_create_schemas.sql
psql -U <user> -d <database> -f sql/ddl/01_bronze_staging.sql


### Running the ingestion pipeline

1. Open Pentaho Spoon and load the transformations from `pentaho/transformations/`.
2. Configure the PostgreSQL database connection under **File → Database Connections**, using the credentials in `config/`.
3. Run each transformation, or execute the orchestrating job in `pentaho/jobs/` to run the full Bronze ingestion sequence.
4. Verify row counts and rejects in the `staging.etl_log` table.

## Project Status

| Sprint | Scope | Status |
|---|---|---|
| Sprint 0 | Project initiation, BRD, architecture, backlog | ✅ Complete |
| Sprint 1 | Source ingestion, staging, data dictionary | ✅ Complete |
| Sprint 2 | Profiling, cleansing, star schema, warehouse load | ⬜ Not started |
| Sprint 3 | Governance, lineage, orchestration, dashboards, release | ⬜ Not started |

## Documentation

| Document | Description |
|---|---|
| [`docs/BRD.md`](docs/BRD.md) | Business requirements, stakeholders, scope, source inventory |
| [`docs/architecture.md`](docs/architecture.md) | Solution architecture and layer responsibilities |
| [`metadata/data_dictionary.md`](metadata/data_dictionary.md) | Field-level reference for all staged tables |
| [`lineage/source_to_target_mapping.md`](lineage/source_to_target_mapping.md) | Column-level lineage (Sprint 3) |
| [`docs/glossary.md`](docs/glossary.md) | Business term definitions |

## Contributing

This is a team academic capstone project. Team members should:

1. Create a feature branch off `main` for each task (`feature/<sprint>-<short-description>`).
2. Commit incrementally with descriptive messages — one logical change per commit, not a single end-of-sprint commit.
3. Open a pull request into `main` for review before merging.
4. Keep `docs/` in sync with any architecture or scope decisions made during development.

## Team

| Name | Registration No. |
|---|---|
| Hitashri M | 26MML1024 |
| Kusuma Sree | 26MML1021 |
| Krishnaveni M | 26MML1008 |

**Course:** Enterprise Data Engineering Capstone Project — UC19
**Methodology:** Agile Scrum (3 Sprints)

## License

This project is submitted as part of an academic capstone and is intended for educational use. Source datasets are publicly available under their respective Kaggle licenses (Olist Brazilian E-Commerce, Olist Marketing Funnel).
