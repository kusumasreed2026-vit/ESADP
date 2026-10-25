CREATE SCHEMA IF NOT EXISTS warehouse;

-- ============================================================
-- 1. DIMENSION: DATE
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    day             INTEGER NOT NULL,
    day_name        VARCHAR(15) NOT NULL,
    day_of_week     INTEGER NOT NULL,
    week            INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    month_name      VARCHAR(15) NOT NULL,
    quarter         INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    is_weekend      BOOLEAN NOT NULL
);


-- ============================================================
-- 2. DIMENSION: CUSTOMER
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.dim_customer (
    customer_key        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL UNIQUE,
    customer_unique_id  VARCHAR(50),
    zip_code_prefix     INTEGER,
    city                VARCHAR(100),
    state               VARCHAR(10),
    latitude            NUMERIC(10,7),
    longitude           NUMERIC(10,7)
);


-- ============================================================
-- 3. DIMENSION: PRODUCT
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id                     VARCHAR(50) NOT NULL UNIQUE,
    product_category_name          VARCHAR(150),
    product_category_name_english  VARCHAR(150),
    product_name_length             INTEGER,
    product_description_length      INTEGER,
    product_photos_qty              INTEGER,
    product_weight_g                NUMERIC(12,2),
    product_length_cm               NUMERIC(12,2),
    product_height_cm               NUMERIC(12,2),
    product_width_cm                NUMERIC(12,2)
);


-- ============================================================
-- 4. DIMENSION: SELLER
-- ============================================================

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
-- 5. FACT: SALES
-- Grain:
-- One row = one product item within one customer order
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    sales_key                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    order_id                     VARCHAR(50) NOT NULL,
    order_item_id                INTEGER NOT NULL,

    customer_key                 BIGINT,
    product_key                  BIGINT,
    seller_key                   BIGINT,

    purchase_date_key             INTEGER,
    approved_date_key             INTEGER,
    carrier_date_key              INTEGER,
    delivered_date_key            INTEGER,
    estimated_delivery_date_key   INTEGER,

    order_status                 VARCHAR(30),

    shipping_limit_date          TIMESTAMP,

    price                        NUMERIC(12,2),
    freight_value                NUMERIC(12,2),

    CONSTRAINT uq_fact_sales_item
        UNIQUE (order_id, order_item_id),

    CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_key)
        REFERENCES warehouse.dim_customer(customer_key),

    CONSTRAINT fk_sales_product
        FOREIGN KEY (product_key)
        REFERENCES warehouse.dim_product(product_key),

    CONSTRAINT fk_sales_seller
        FOREIGN KEY (seller_key)
        REFERENCES warehouse.dim_seller(seller_key),

    CONSTRAINT fk_sales_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES warehouse.dim_date(date_key),

    CONSTRAINT fk_sales_approved_date
        FOREIGN KEY (approved_date_key)
        REFERENCES warehouse.dim_date(date_key),

    CONSTRAINT fk_sales_carrier_date
        FOREIGN KEY (carrier_date_key)
        REFERENCES warehouse.dim_date(date_key),

    CONSTRAINT fk_sales_delivered_date
        FOREIGN KEY (delivered_date_key)
        REFERENCES warehouse.dim_date(date_key),

    CONSTRAINT fk_sales_estimated_date
        FOREIGN KEY (estimated_delivery_date_key)
        REFERENCES warehouse.dim_date(date_key)
);


-- ============================================================
-- 6. FACT: PAYMENT
-- Grain:
-- One row = one payment record for an order
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.fact_payment (
    payment_key          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    order_id             VARCHAR(50) NOT NULL,
    payment_sequential   INTEGER NOT NULL,
    payment_type         VARCHAR(50),
    payment_installments INTEGER,
    payment_value        NUMERIC(12,2),

    CONSTRAINT uq_fact_payment
        UNIQUE (order_id, payment_sequential)
);


-- ============================================================
-- 7. FACT: REVIEW
-- Grain:
-- One row = one customer review record
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.fact_review (
    review_key              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    review_id               VARCHAR(100),
    order_id                VARCHAR(50) NOT NULL,

    review_score            INTEGER,

    review_comment_title    TEXT,
    review_comment_message  TEXT,

    review_creation_date    TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);


-- ============================================================
-- 8. FACT: INVENTORY
-- Grain:
-- One row = one product inventory snapshot
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.fact_inventory (
    inventory_key      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    inventory_id       BIGINT,
    product_key        BIGINT,
    date_key           INTEGER,

    warehouse_location VARCHAR(100),

    stock_quantity     INTEGER,
    reorder_level      INTEGER,
    restock_flag       BOOLEAN,

    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_key)
        REFERENCES warehouse.dim_product(product_key),

    CONSTRAINT fk_inventory_date
        FOREIGN KEY (date_key)
        REFERENCES warehouse.dim_date(date_key)
);


-- ============================================================
-- 9. FACT: MARKETING QUALIFIED LEADS
-- Grain:
-- One row = one qualified marketing lead
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.fact_marketing_leads (
    lead_key             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    mql_id               VARCHAR(50) NOT NULL UNIQUE,
    first_contact_date_key INTEGER,

    landing_page_id      VARCHAR(100),
    origin               VARCHAR(100),

    CONSTRAINT fk_mql_date
        FOREIGN KEY (first_contact_date_key)
        REFERENCES warehouse.dim_date(date_key)
);


-- ============================================================
-- 10. FACT: CLOSED DEALS
-- Grain:
-- One row = one closed deal
-- ============================================================

CREATE TABLE IF NOT EXISTS warehouse.fact_closed_deals (
    deal_key                        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    mql_id                          VARCHAR(50),
    seller_id                       VARCHAR(50),
    sdr_id                          VARCHAR(50),
    sr_id                           VARCHAR(50),

    won_date_key                    INTEGER,

    business_segment                VARCHAR(100),
    lead_type                       VARCHAR(100),
    lead_behaviour_profile          VARCHAR(100),

    has_company                     BOOLEAN,
    has_gtin                        BOOLEAN,

    average_stock                   NUMERIC(14,2),
    business_type                   VARCHAR(100),

    declared_product_catalog_size   NUMERIC(14,2),
    declared_monthly_revenue        NUMERIC(18,2),

    CONSTRAINT fk_deal_date
        FOREIGN KEY (won_date_key)
        REFERENCES warehouse.dim_date(date_key)
);


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_fact_sales_order
    ON warehouse.fact_sales(order_id);

CREATE INDEX IF NOT EXISTS idx_fact_sales_customer
    ON warehouse.fact_sales(customer_key);

CREATE INDEX IF NOT EXISTS idx_fact_sales_product
    ON warehouse.fact_sales(product_key);

CREATE INDEX IF NOT EXISTS idx_fact_sales_seller
    ON warehouse.fact_sales(seller_key);

CREATE INDEX IF NOT EXISTS idx_fact_sales_purchase_date
    ON warehouse.fact_sales(purchase_date_key);

CREATE INDEX IF NOT EXISTS idx_fact_payment_order
    ON warehouse.fact_payment(order_id);

CREATE INDEX IF NOT EXISTS idx_fact_review_order
    ON warehouse.fact_review(order_id);

CREATE INDEX IF NOT EXISTS idx_fact_inventory_product
    ON warehouse.fact_inventory(product_key);

CREATE INDEX IF NOT EXISTS idx_fact_inventory_date
    ON warehouse.fact_inventory(date_key);

CREATE INDEX IF NOT EXISTS idx_fact_deals_mql
    ON warehouse.fact_closed_deals(mql_id);