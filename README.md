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
