-- ============================================================
-- ESADP
-- Enterprise Sales Analytics Data Platform
-- UC19
-- PostgreSQL Database Setup
-- ============================================================


-- ============================================================
-- 1. CREATE SCHEMAS
-- ============================================================

CREATE SCHEMA IF NOT EXISTS source_sql;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE SCHEMA IF NOT EXISTS warehouse;

CREATE SCHEMA IF NOT EXISTS audit;


-- ============================================================
-- 2. POS SQL SOURCE
-- Source #2
-- Dataset: olist_order_items_dataset.csv
-- Format: SQL (converted)
--
-- This table will be populated through Pentaho:
-- CSV -> PostgreSQL source_sql.pos_source
-- ============================================================

CREATE TABLE IF NOT EXISTS source_sql.pos_source (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2)
);


-- ============================================================
-- 3. INVENTORY SQL SOURCE
-- Source #9
-- Dataset: Self-generated inventory dataset
-- Format: SQL (native)
--
-- NOTE:
-- Exact columns should eventually match the columns produced
-- by generate_inventory_data.py.
-- ============================================================

CREATE TABLE IF NOT EXISTS source_sql.inventory_source (
    inventory_id TEXT,
    product_id TEXT,
    category TEXT,
    location TEXT,
    inventory_level NUMERIC,
    units_sold NUMERIC,
    units_ordered NUMERIC,
    demand_forecast NUMERIC,
    price NUMERIC(12,2),
    discount NUMERIC(12,2),
    weather_condition TEXT,
    holiday_promotion TEXT,
    seasonality TEXT
);


-- ============================================================
-- 4. STAGING
-- Source #1
-- Sales Order Management
-- Dataset: olist_orders_dataset.csv
-- Format: CSV
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_sales_order (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);


-- ============================================================
-- 5. STAGING
-- Source #2
-- POS
-- Dataset: olist_order_items_dataset.csv
-- Format: SQL
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_pos (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2)
);


-- ============================================================
-- 6. STAGING
-- Source #3
-- CRM
-- Dataset: olist_customers_dataset.csv
-- Format: JSON
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_crm (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix INTEGER,
    customer_city TEXT,
    customer_state TEXT
);


-- ============================================================
-- 7. STAGING
-- Source #5
-- ERP
-- Dataset: olist_order_payments_dataset.csv
-- Format: XML
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_erp (
    order_id TEXT,
    payment_sequential INTEGER,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(12,2)
);


-- ============================================================
-- 8. STAGING
-- Source #6
-- Dealer Management
-- Dataset: olist_sellers_dataset.csv
-- Format: XML
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_dealer (
    seller_id TEXT,
    seller_zip_code_prefix INTEGER,
    seller_city TEXT,
    seller_state TEXT
);


-- ============================================================
-- 9. STAGING
-- Source #7
-- Product Catalog
-- Dataset:
--   olist_products_dataset.csv
--   product_category_name_translation.csv
-- Format: Excel
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_product (
    product_id TEXT,
    product_category_name TEXT,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC,
    product_length_cm NUMERIC,
    product_height_cm NUMERIC,
    product_width_cm NUMERIC
);


CREATE TABLE IF NOT EXISTS staging.stg_product_category_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);


-- ============================================================
-- 10. STAGING
-- Source #8
-- Pricing Management
-- Dataset: price/freight_value extracted from order_items
-- Format: Excel
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_pricing (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2)
);


-- ============================================================
-- 11. STAGING
-- Source #9
-- Inventory Management
-- Dataset: Self-generated inventory dataset
-- Format: SQL
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_inventory (
    inventory_id TEXT,
    product_id TEXT,
    category TEXT,
    location TEXT,
    inventory_level NUMERIC,
    units_sold NUMERIC,
    units_ordered NUMERIC,
    demand_forecast NUMERIC,
    price NUMERIC(12,2),
    discount NUMERIC(12,2),
    weather_condition TEXT,
    holiday_promotion TEXT,
    seasonality TEXT
);


-- ============================================================
-- 12. STAGING
-- Source #10
-- Marketing Campaign - Qualified Leads
-- Dataset: olist_marketing_qualified_leads_dataset.csv
-- Format: CSV
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_marketing_leads (
    mql_id TEXT,
    first_contact_date DATE,
    landing_page_id TEXT,
    origin TEXT
);


-- ============================================================
-- 13. STAGING
-- Source #10
-- Marketing Campaign - Closed Deals
-- Dataset: olist_closed_deals_dataset.csv
-- Format: CSV
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stg_marketing_deals (
    mql_id TEXT,
    seller_id TEXT,
    sdr_id TEXT,
    sr_id TEXT,
    won_date DATE,
    business_segment TEXT,
    lead_type TEXT,
    lead_behaviour_profile TEXT,
    business_type TEXT,
    declared_product_catalog_size NUMERIC,
    declared_monthly_revenue NUMERIC
);


-- ============================================================
-- 14. AUDIT / ETL LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS audit.etl_log (
    log_id BIGSERIAL PRIMARY KEY,
    pipeline_name TEXT NOT NULL,
    source_name TEXT,
    source_format TEXT,
    target_table TEXT,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    rows_read INTEGER,
    rows_loaded INTEGER,
    status TEXT,
    error_message TEXT
);


-- ============================================================
-- 15. BASIC STAGING INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_stg_sales_order_order_id
ON staging.stg_sales_order(order_id);

CREATE INDEX IF NOT EXISTS idx_stg_pos_order_id
ON staging.stg_pos(order_id);

CREATE INDEX IF NOT EXISTS idx_stg_pos_product_id
ON staging.stg_pos(product_id);

CREATE INDEX IF NOT EXISTS idx_stg_crm_customer_id
ON staging.stg_crm(customer_id);

CREATE INDEX IF NOT EXISTS idx_stg_erp_order_id
ON staging.stg_erp(order_id);

CREATE INDEX IF NOT EXISTS idx_stg_dealer_seller_id
ON staging.stg_dealer(seller_id);

CREATE INDEX IF NOT EXISTS idx_stg_product_product_id
ON staging.stg_product(product_id);

CREATE INDEX IF NOT EXISTS idx_stg_pricing_order_id
ON staging.stg_pricing(order_id);

CREATE INDEX IF NOT EXISTS idx_stg_inventory_product_id
ON staging.stg_inventory(product_id);

CREATE INDEX IF NOT EXISTS idx_stg_marketing_leads_mql_id
ON staging.stg_marketing_leads(mql_id);

CREATE INDEX IF NOT EXISTS idx_stg_marketing_deals_mql_id
ON staging.stg_marketing_deals(mql_id);


-- ============================================================
-- 16. VERIFY SCHEMAS
-- ============================================================

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN (
    'source_sql',
    'staging',
    'warehouse',
    'audit'
)
ORDER BY schema_name;


-- ============================================================
-- 17. VERIFY ALL PROJECT TABLES
-- ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema IN (
    'source_sql',
    'staging',
    'warehouse',
    'audit'
)
ORDER BY
    table_schema,
    table_name;