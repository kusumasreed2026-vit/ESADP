
CREATE SCHEMA IF NOT EXISTS warehouse;

-- 1. DATE DIMENSION
CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    day INTEGER,
    day_name VARCHAR(15),
    day_of_week INTEGER,
    week INTEGER,
    month INTEGER,
    month_name VARCHAR(15),
    quarter INTEGER,
    year INTEGER,
    is_weekend BOOLEAN
);

-- 2. CUSTOMER DIMENSION
CREATE TABLE IF NOT EXISTS warehouse.dim_customer (
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE NOT NULL,
    customer_unique_id VARCHAR(50),
    zip_code_prefix INTEGER,
    city VARCHAR(100),
    state VARCHAR(10),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7)
);

-- 3. PRODUCT DIMENSION
CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE NOT NULL,
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(12,2),
    product_length_cm NUMERIC(12,2),
    product_height_cm NUMERIC(12,2),
    product_width_cm NUMERIC(12,2)
);

-- 4. SELLER DIMENSION
CREATE TABLE IF NOT EXISTS warehouse.dim_seller (
    seller_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id VARCHAR(50) UNIQUE NOT NULL,
    zip_code_prefix INTEGER,
    city VARCHAR(100),
    state VARCHAR(10),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7)
);

-- 5. SALES FACT
CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    sales_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    order_item_id INTEGER NOT NULL,
    customer_key BIGINT REFERENCES warehouse.dim_customer(customer_key),
    product_key BIGINT REFERENCES warehouse.dim_product(product_key),
    seller_key BIGINT REFERENCES warehouse.dim_seller(seller_key),
    purchase_date_key INTEGER REFERENCES warehouse.dim_date(date_key),
    approved_date_key INTEGER REFERENCES warehouse.dim_date(date_key),
    carrier_date_key INTEGER REFERENCES warehouse.dim_date(date_key),
    delivered_date_key INTEGER REFERENCES warehouse.dim_date(date_key),
    estimated_delivery_date_key INTEGER REFERENCES warehouse.dim_date(date_key),
    order_status VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    UNIQUE (order_id, order_item_id)
);

-- 6. PAYMENT FACT
CREATE TABLE IF NOT EXISTS warehouse.fact_payment (
    payment_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(50),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2),
    UNIQUE (order_id, payment_sequential)
);

-- 7. REVIEW FACT
CREATE TABLE IF NOT EXISTS warehouse.fact_review (
    review_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    review_id VARCHAR(50),
    order_id VARCHAR(50) NOT NULL,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- 8. INVENTORY FACT
CREATE TABLE IF NOT EXISTS warehouse.fact_inventory (
    inventory_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inventory_id TEXT,
    product_id VARCHAR(50),
    category VARCHAR(100),
    store_location VARCHAR(100),
    inventory_level INTEGER,
    units_sold INTEGER,
    units_ordered INTEGER,
    demand_forecast NUMERIC(12,2),
    price NUMERIC(12,2),
    discount NUMERIC(12,2),
    weather_condition VARCHAR(50),
    holiday_promotion VARCHAR(50),
    seasonality VARCHAR(50)
);

-- 9. MARKETING LEADS FACT
CREATE TABLE IF NOT EXISTS warehouse.fact_marketing_leads (
    lead_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mql_id VARCHAR(50) UNIQUE NOT NULL,
    first_contact_date_key INTEGER
        REFERENCES warehouse.dim_date(date_key),
    landing_page_id VARCHAR(100),
    origin VARCHAR(100)
);

-- 10. CLOSED DEALS FACT
CREATE TABLE IF NOT EXISTS warehouse.fact_closed_deals (
    deal_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mql_id VARCHAR(50),
    seller_id VARCHAR(50),
    sdr_id VARCHAR(50),
    sr_id VARCHAR(50),
    won_date_key INTEGER REFERENCES warehouse.dim_date(date_key),
    business_segment VARCHAR(100),
    lead_type VARCHAR(100),
    lead_behaviour_profile VARCHAR(100),
    business_type VARCHAR(100),
    declared_product_catalog_size NUMERIC(12,2),
    declared_monthly_revenue NUMERIC(14,2)
);
