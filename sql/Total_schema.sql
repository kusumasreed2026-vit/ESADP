-- ============================================================
-- ESADP - Enterprise Sales Analytics Data Platform (UC19)
-- FINAL CONSOLIDATED DDL: source_sql + staging + warehouse + audit
-- Datasets: Olist Brazilian E-commerce, Olist Marketing Funnel,
--           Retail Store Inventory Forecasting
-- ============================================================


-- ============================================================
-- 1. SCHEMAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS source_sql;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS warehouse;
CREATE SCHEMA IF NOT EXISTS audit;


-- ============================================================
-- 2. SOURCE_SQL (simulated SQL source systems)
-- ============================================================

-- POS (from olist_order_items_dataset.csv)
CREATE TABLE IF NOT EXISTS source_sql.pos_source (
    order_id            TEXT,
    order_item_id       INTEGER,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12,2),
    freight_value       NUMERIC(12,2)
);

-- Inventory Management (from retail_store_inventory.csv)
CREATE TABLE IF NOT EXISTS source_sql.inventory_source (
    inventory_id      TEXT,
    product_id        TEXT,
    category          TEXT,
    location          TEXT,
    inventory_level   NUMERIC,
    units_sold        NUMERIC,
    units_ordered     NUMERIC,
    demand_forecast   NUMERIC,
    price             NUMERIC(12,2),
    discount          NUMERIC(12,2),
    weather_condition TEXT,
    holiday_promotion TEXT,
    seasonality       TEXT
);


-- ============================================================
-- 3. STAGING
-- ============================================================

-- Sales Order Management (CSV: olist_orders_dataset.csv)
CREATE TABLE IF NOT EXISTS staging.stg_sales_order (
    order_id                       TEXT,
    customer_id                    TEXT,
    order_status                   TEXT,
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

-- POS (SQL: source_sql.pos_source)
CREATE TABLE IF NOT EXISTS staging.stg_pos (
    order_id            TEXT,
    order_item_id       INTEGER,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12,2),
    freight_value       NUMERIC(12,2)
);

-- CRM (JSON: olist_customers_dataset)
CREATE TABLE IF NOT EXISTS staging.stg_crm (
    customer_id              TEXT,
    customer_unique_id       TEXT,
    customer_zip_code_prefix INTEGER,
    customer_city            TEXT,
    customer_state           TEXT
);

-- Geolocation reference (used for customer/seller lat-long)  [ADDED]
CREATE TABLE IF NOT EXISTS staging.stg_geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat             NUMERIC(10,7),
    geolocation_lng             NUMERIC(10,7),
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

-- E-Commerce reviews (JSON: olist_order_reviews_dataset)
CREATE TABLE IF NOT EXISTS staging.stg_order_reviews (
    review_id               TEXT,
    order_id                TEXT,
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- ERP payments (XML: olist_order_payments_dataset)
CREATE TABLE IF NOT EXISTS staging.stg_erp (
    order_id             TEXT,
    payment_sequential   INTEGER,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        NUMERIC(12,2)
);

-- Dealer Management (XML: olist_sellers_dataset)
CREATE TABLE IF NOT EXISTS staging.stg_dealer (
    seller_id              TEXT,
    seller_zip_code_prefix INTEGER,
    seller_city            TEXT,
    seller_state           TEXT
);

-- Product Catalog (Excel)
CREATE TABLE IF NOT EXISTS staging.stg_product (
    product_id                 TEXT,
    product_category_name      TEXT,
    product_name_lenght        INTEGER,   -- source typo kept in staging, fixed in warehouse
    product_description_lenght INTEGER,   -- source typo kept in staging, fixed in warehouse
    product_photos_qty         INTEGER,
    product_weight_g           NUMERIC,
    product_length_cm          NUMERIC,
    product_height_cm          NUMERIC,
    product_width_cm           NUMERIC
);

CREATE TABLE IF NOT EXISTS staging.stg_product_category_translation (
    product_category_name         TEXT,
    product_category_name_english TEXT
);

-- Pricing Management (Excel, derived from order_items)
CREATE TABLE IF NOT EXISTS staging.stg_pricing (
    order_id      TEXT,
    order_item_id INTEGER,
    product_id    TEXT,
    seller_id     TEXT,
    price         NUMERIC(12,2),
    freight_value NUMERIC(12,2)
);

-- Inventory Management (SQL)   [duplicate definition removed]
CREATE TABLE IF NOT EXISTS staging.stg_inventory (
    inventory_id      TEXT,
    product_id        TEXT,
    category          TEXT,
    location          TEXT,
    inventory_level   NUMERIC,
    units_sold        NUMERIC,
    units_ordered     NUMERIC,
    demand_forecast   NUMERIC,
    price             NUMERIC(12,2),
    discount          NUMERIC(12,2),
    weather_condition TEXT,
    holiday_promotion TEXT,
    seasonality       TEXT,
    source_system     VARCHAR(30),
    load_timestamp    TIMESTAMP
);

-- Marketing Campaign (CSV)
CREATE TABLE IF NOT EXISTS staging.stg_marketing_leads (
    mql_id             TEXT,
    first_contact_date DATE,
    landing_page_id    TEXT,
    origin             TEXT
);

CREATE TABLE IF NOT EXISTS staging.stg_marketing_deals (
    mql_id                        TEXT,
    seller_id                     TEXT,
    sdr_id                        TEXT,
    sr_id                         TEXT,
    won_date                      DATE,
    business_segment              TEXT,
    lead_type                     TEXT,
    lead_behaviour_profile        TEXT,
    business_type                 TEXT,
    declared_product_catalog_size NUMERIC,
    declared_monthly_revenue      NUMERIC
);


-- ============================================================
-- 4. AUDIT
-- ============================================================
CREATE TABLE IF NOT EXISTS audit.etl_log (
    log_id        BIGSERIAL PRIMARY KEY,
    pipeline_name TEXT NOT NULL,
    source_name   TEXT,
    source_format TEXT,
    target_table  TEXT,
    start_time    TIMESTAMP,
    end_time      TIMESTAMP,
    rows_read     INTEGER,
    rows_loaded   INTEGER,
    status        TEXT,
    error_message TEXT
);


-- ============================================================
-- 5. WAREHOUSE: DIMENSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key    INTEGER PRIMARY KEY,          -- YYYYMMDD
    full_date   DATE NOT NULL UNIQUE,
    day         INTEGER NOT NULL,
    day_name    VARCHAR(15) NOT NULL,
    day_of_week INTEGER NOT NULL,
    week        INTEGER NOT NULL,
    month       INTEGER NOT NULL,
    month_name  VARCHAR(15) NOT NULL,
    quarter     INTEGER NOT NULL,
    year        INTEGER NOT NULL,
    is_weekend  BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS warehouse.dim_customer (
    customer_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id        VARCHAR(50) NOT NULL UNIQUE,
    customer_unique_id VARCHAR(50),
    zip_code_prefix    INTEGER,
    city               VARCHAR(100),
    state              VARCHAR(10),
    latitude           NUMERIC(10,7),
    longitude          NUMERIC(10,7)
);

CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id                    VARCHAR(50) NOT NULL UNIQUE,
    product_category_name         VARCHAR(150),
    product_category_name_english VARCHAR(150),
    product_name_length           INTEGER,    -- corrected spelling
    product_description_length    INTEGER,    -- corrected spelling
    product_photos_qty            INTEGER,
    product_weight_g              NUMERIC(12,2),
    product_length_cm             NUMERIC(12,2),
    product_height_cm             NUMERIC(12,2),
    product_width_cm              NUMERIC(12,2)
);

CREATE TABLE IF NOT EXISTS warehouse.dim_seller (
    seller_key      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id       VARCHAR(50) NOT NULL UNIQUE,
    zip_code_prefix INTEGER,
    city            VARCHAR(100),
    state           VARCHAR(10),
    latitude        NUMERIC(10,7),
    longitude       NUMERIC(10,7)
);


-- ============================================================
-- 6. WAREHOUSE: FACTS
-- ============================================================

-- IMPORTANT MIGRATION:
-- These two tables may already exist with obsolete column definitions.
-- This script intentionally drops and recreates them to match the
-- definitions below. Run only if their existing data is disposable.
DROP TABLE IF EXISTS warehouse.fact_inventory;
DROP TABLE IF EXISTS warehouse.fact_closed_deals;


-- Grain: one product item within one order
CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    sales_key                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id                    VARCHAR(50) NOT NULL,
    order_item_id               INTEGER NOT NULL,
    customer_key                BIGINT,
    product_key                 BIGINT,
    seller_key                  BIGINT,
    purchase_date_key           INTEGER,
    approved_date_key           INTEGER,
    carrier_date_key            INTEGER,
    delivered_date_key          INTEGER,
    estimated_delivery_date_key INTEGER,
    order_status                VARCHAR(30),
    shipping_limit_date         TIMESTAMP,
    price                       NUMERIC(12,2),
    freight_value               NUMERIC(12,2),
    CONSTRAINT uq_fact_sales_item UNIQUE (order_id, order_item_id),
    CONSTRAINT fk_sales_customer       FOREIGN KEY (customer_key)                 REFERENCES warehouse.dim_customer(customer_key),
    CONSTRAINT fk_sales_product        FOREIGN KEY (product_key)                  REFERENCES warehouse.dim_product(product_key),
    CONSTRAINT fk_sales_seller         FOREIGN KEY (seller_key)                   REFERENCES warehouse.dim_seller(seller_key),
    CONSTRAINT fk_sales_purchase_date  FOREIGN KEY (purchase_date_key)            REFERENCES warehouse.dim_date(date_key),
    CONSTRAINT fk_sales_approved_date  FOREIGN KEY (approved_date_key)            REFERENCES warehouse.dim_date(date_key),
    CONSTRAINT fk_sales_carrier_date   FOREIGN KEY (carrier_date_key)             REFERENCES warehouse.dim_date(date_key),
    CONSTRAINT fk_sales_delivered_date FOREIGN KEY (delivered_date_key)           REFERENCES warehouse.dim_date(date_key),
    CONSTRAINT fk_sales_estimated_date FOREIGN KEY (estimated_delivery_date_key)  REFERENCES warehouse.dim_date(date_key)
);

-- Grain: one payment record for an order
CREATE TABLE IF NOT EXISTS warehouse.fact_payment (
    payment_key          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id             VARCHAR(50) NOT NULL,
    payment_sequential   INTEGER NOT NULL,
    payment_type         VARCHAR(50),
    payment_installments INTEGER,
    payment_value        NUMERIC(12,2),
    CONSTRAINT uq_fact_payment UNIQUE (order_id, payment_sequential)
);

-- Grain: one review record (review_id is not unique in source)
CREATE TABLE IF NOT EXISTS warehouse.fact_review (
    review_key              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    review_id               VARCHAR(100),
    order_id                VARCHAR(50) NOT NULL,
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Grain: one inventory snapshot row (standalone source: product_id does NOT
-- match Olist product_id, so no FK to dim_product)   [REWRITTEN]
CREATE TABLE IF NOT EXISTS warehouse.fact_inventory (
    inventory_key     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inventory_id      TEXT,
    product_id        VARCHAR(50),
    category          VARCHAR(100),
    store_location    VARCHAR(100),
    inventory_level   INTEGER,
    units_sold        INTEGER,
    units_ordered     INTEGER,
    demand_forecast   NUMERIC(12,2),
    price             NUMERIC(12,2),
    discount          NUMERIC(12,2),
    weather_condition VARCHAR(50),
    holiday_promotion VARCHAR(50),
    seasonality       VARCHAR(50)
);

-- Grain: one marketing qualified lead
CREATE TABLE IF NOT EXISTS warehouse.fact_marketing_leads (
    lead_key               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mql_id                 VARCHAR(50) NOT NULL UNIQUE,
    first_contact_date_key INTEGER,
    landing_page_id        VARCHAR(100),
    origin                 VARCHAR(100),
    CONSTRAINT fk_mql_date FOREIGN KEY (first_contact_date_key) REFERENCES warehouse.dim_date(date_key)
);

-- Grain: one closed deal
-- (has_company, has_gtin, average_stock removed: not present in stg_marketing_deals)
CREATE TABLE IF NOT EXISTS warehouse.fact_closed_deals (
    deal_key                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mql_id                        VARCHAR(50),
    seller_id                     VARCHAR(50),
    sdr_id                        VARCHAR(50),
    sr_id                         VARCHAR(50),
    won_date_key                  INTEGER,
    business_segment              VARCHAR(100),
    lead_type                     VARCHAR(100),
    lead_behaviour_profile        VARCHAR(100),
    business_type                 VARCHAR(100),
    declared_product_catalog_size NUMERIC(14,2),
    declared_monthly_revenue      NUMERIC(18,2),
    CONSTRAINT fk_deal_date FOREIGN KEY (won_date_key) REFERENCES warehouse.dim_date(date_key)
);


-- ============================================================
-- 7. INDEXES
-- ============================================================

-- Staging
CREATE INDEX IF NOT EXISTS idx_stg_sales_order_order_id  ON staging.stg_sales_order(order_id);
CREATE INDEX IF NOT EXISTS idx_stg_pos_order_id          ON staging.stg_pos(order_id);
CREATE INDEX IF NOT EXISTS idx_stg_pos_product_id        ON staging.stg_pos(product_id);
CREATE INDEX IF NOT EXISTS idx_stg_crm_customer_id       ON staging.stg_crm(customer_id);
CREATE INDEX IF NOT EXISTS idx_stg_geo_zip               ON staging.stg_geolocation(geolocation_zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_stg_reviews_order_id      ON staging.stg_order_reviews(order_id);
CREATE INDEX IF NOT EXISTS idx_stg_erp_order_id          ON staging.stg_erp(order_id);
CREATE INDEX IF NOT EXISTS idx_stg_dealer_seller_id      ON staging.stg_dealer(seller_id);
CREATE INDEX IF NOT EXISTS idx_stg_product_product_id    ON staging.stg_product(product_id);
CREATE INDEX IF NOT EXISTS idx_stg_pricing_order_id      ON staging.stg_pricing(order_id);
CREATE INDEX IF NOT EXISTS idx_stg_inventory_product_id  ON staging.stg_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_stg_mkt_leads_mql_id      ON staging.stg_marketing_leads(mql_id);
CREATE INDEX IF NOT EXISTS idx_stg_mkt_deals_mql_id      ON staging.stg_marketing_deals(mql_id);

-- Warehouse
CREATE INDEX IF NOT EXISTS idx_fact_sales_order          ON warehouse.fact_sales(order_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer       ON warehouse.fact_sales(customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product        ON warehouse.fact_sales(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_seller         ON warehouse.fact_sales(seller_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_purchase_date  ON warehouse.fact_sales(purchase_date_key);
CREATE INDEX IF NOT EXISTS idx_fact_payment_order        ON warehouse.fact_payment(order_id);
CREATE INDEX IF NOT EXISTS idx_fact_review_order         ON warehouse.fact_review(order_id);
CREATE INDEX IF NOT EXISTS idx_fact_inventory_product    ON warehouse.fact_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_deals_mql            ON warehouse.fact_closed_deals(mql_id);


-- ============================================================
-- 8. LOAD dim_date (2016-2024 covers Olist and planned inventory dates)
-- ============================================================
INSERT INTO warehouse.dim_date
SELECT to_char(d,'YYYYMMDD')::int,
       d::date,
       EXTRACT(day FROM d)::int,
       trim(to_char(d,'Day')),
       EXTRACT(isodow FROM d)::int,
       EXTRACT(week FROM d)::int,
       EXTRACT(month FROM d)::int,
       trim(to_char(d,'Month')),
       EXTRACT(quarter FROM d)::int,
       EXTRACT(year FROM d)::int,
       EXTRACT(isodow FROM d) IN (6,7)
FROM generate_series('2016-01-01'::date, '2024-12-31'::date, interval '1 day') AS dates(d)
ON CONFLICT (date_key) DO NOTHING;


-- ============================================================
-- 9. VERIFY
-- ============================================================
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('source_sql','staging','warehouse','audit')
ORDER BY table_schema, table_name;