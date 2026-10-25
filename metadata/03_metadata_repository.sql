-- ESADP Sprint 3: Metadata Repository
-- Purpose: Maintain technical metadata and business descriptions for warehouse objects.
-- Safe approach: creates/refreshes metadata only; does not alter staging or warehouse tables.
-- Run in pgAdmin Query Tool connected to the ESADP database.

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.metadata_tables (
    schema_name        VARCHAR(128) NOT NULL,
    table_name         VARCHAR(128) NOT NULL,
    table_type         VARCHAR(32)  NOT NULL DEFAULT 'BASE TABLE',
    business_description TEXT,
    business_owner     VARCHAR(128),
    metadata_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_metadata_tables PRIMARY KEY (schema_name, table_name)
);

CREATE TABLE IF NOT EXISTS audit.metadata_columns (
    schema_name          VARCHAR(128) NOT NULL,
    table_name           VARCHAR(128) NOT NULL,
    ordinal_position     INTEGER NOT NULL,
    column_name          VARCHAR(128) NOT NULL,
    data_type            VARCHAR(128) NOT NULL,
    udt_name             VARCHAR(128),
    is_nullable          VARCHAR(3) NOT NULL,
    column_default       TEXT,
    character_maximum_length INTEGER,
    numeric_precision    INTEGER,
    numeric_scale        INTEGER,
    is_primary_key       BOOLEAN NOT NULL DEFAULT FALSE,
    is_foreign_key       BOOLEAN NOT NULL DEFAULT FALSE,
    business_description TEXT,
    metadata_updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_metadata_columns PRIMARY KEY (schema_name, table_name, column_name),
    CONSTRAINT fk_metadata_columns_table FOREIGN KEY (schema_name, table_name)
        REFERENCES audit.metadata_tables(schema_name, table_name)
        ON DELETE CASCADE
);

-- Refresh table-level technical inventory for warehouse base tables.
INSERT INTO audit.metadata_tables
    (schema_name, table_name, table_type, business_description, business_owner, metadata_updated_at)
SELECT
    t.table_schema,
    t.table_name,
    t.table_type,
    NULL,
    'ESADP Data Engineering Team',
    CURRENT_TIMESTAMP
FROM information_schema.tables t
WHERE t.table_schema = 'warehouse'
  AND t.table_type = 'BASE TABLE'
ON CONFLICT (schema_name, table_name) DO UPDATE
SET table_type = EXCLUDED.table_type,
    metadata_updated_at = CURRENT_TIMESTAMP;

-- Refresh column-level technical inventory from actual PostgreSQL metadata.
INSERT INTO audit.metadata_columns
    (schema_name, table_name, ordinal_position, column_name, data_type, udt_name,
     is_nullable, column_default, character_maximum_length, numeric_precision,
     numeric_scale, is_primary_key, is_foreign_key, business_description, metadata_updated_at)
SELECT
    c.table_schema,
    c.table_name,
    c.ordinal_position,
    c.column_name,
    c.data_type,
    c.udt_name,
    c.is_nullable,
    c.column_default,
    c.character_maximum_length,
    c.numeric_precision,
    c.numeric_scale,
    EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_schema = kcu.constraint_schema
         AND tc.constraint_name = kcu.constraint_name
         AND tc.table_schema = kcu.table_schema
         AND tc.table_name = kcu.table_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = c.table_schema
          AND tc.table_name = c.table_name
          AND kcu.column_name = c.column_name
    ) AS is_primary_key,
    EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_schema = kcu.constraint_schema
         AND tc.constraint_name = kcu.constraint_name
         AND tc.table_schema = kcu.table_schema
         AND tc.table_name = kcu.table_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = c.table_schema
          AND tc.table_name = c.table_name
          AND kcu.column_name = c.column_name
    ) AS is_foreign_key,
    NULL,
    CURRENT_TIMESTAMP
FROM information_schema.columns c
WHERE c.table_schema = 'warehouse'
ON CONFLICT (schema_name, table_name, column_name) DO UPDATE
SET ordinal_position = EXCLUDED.ordinal_position,
    data_type = EXCLUDED.data_type,
    udt_name = EXCLUDED.udt_name,
    is_nullable = EXCLUDED.is_nullable,
    column_default = EXCLUDED.column_default,
    character_maximum_length = EXCLUDED.character_maximum_length,
    numeric_precision = EXCLUDED.numeric_precision,
    numeric_scale = EXCLUDED.numeric_scale,
    is_primary_key = EXCLUDED.is_primary_key,
    is_foreign_key = EXCLUDED.is_foreign_key,
    metadata_updated_at = CURRENT_TIMESTAMP;

-- Remove metadata for columns/tables no longer present in the warehouse schema.
DELETE FROM audit.metadata_columns mc
WHERE mc.schema_name = 'warehouse'
  AND NOT EXISTS (
      SELECT 1
      FROM information_schema.columns c
      WHERE c.table_schema = mc.schema_name
        AND c.table_name = mc.table_name
        AND c.column_name = mc.column_name
  );

DELETE FROM audit.metadata_tables mt
WHERE mt.schema_name = 'warehouse'
  AND NOT EXISTS (
      SELECT 1
      FROM information_schema.tables t
      WHERE t.table_schema = mt.schema_name
        AND t.table_name = mt.table_name
        AND t.table_type = 'BASE TABLE'
  );

-- Add table-level business descriptions. Update these descriptions if your terminology differs.
UPDATE audit.metadata_tables
SET business_description = CASE table_name
    WHEN 'dim_date' THEN 'Calendar dimension used to group and filter business events by date, month, quarter and year.'
    WHEN 'dim_customer' THEN 'Customer dimension containing customer identifiers and customer location attributes.'
    WHEN 'dim_product' THEN 'Product dimension containing product identifiers, category and product attributes.'
    WHEN 'dim_seller' THEN 'Seller dimension containing seller identifiers and seller location attributes.'
    WHEN 'fact_sales' THEN 'Sales order-item fact containing customer, product, seller, dates, item price and freight.'
    WHEN 'fact_payment' THEN 'Payment fact containing payment method, installments and payment amount by order payment sequence.'
    WHEN 'fact_review' THEN 'Review fact containing order review scores, comments and review timestamps.'
    WHEN 'fact_inventory' THEN 'Inventory fact containing inventory level, units sold or ordered, forecast and store conditions.'
    WHEN 'fact_marketing_leads' THEN 'Marketing leads fact containing lead identifiers, first-contact date, landing page and origin.'
    WHEN 'fact_closed_deals' THEN 'Closed-deals fact containing won date, seller and sales qualification attributes.'
    ELSE business_description
END,
metadata_updated_at = CURRENT_TIMESTAMP
WHERE schema_name = 'warehouse';

-- Add column descriptions. Technical metadata is sourced from information_schema;
-- descriptions below are business-facing definitions for key fields.
UPDATE audit.metadata_columns
SET business_description = CASE table_name || '.' || column_name
    WHEN 'dim_date.date_key' THEN 'Surrogate date key in YYYYMMDD integer format.'
    WHEN 'dim_date.full_date' THEN 'Calendar date represented by this dimension row.'
    WHEN 'dim_customer.customer_key' THEN 'Warehouse surrogate key for a customer.'
    WHEN 'dim_customer.customer_id' THEN 'Source-system customer identifier.'
    WHEN 'dim_customer.customer_unique_id' THEN 'Identifier grouping records belonging to the same unique customer.'
    WHEN 'dim_customer.city' THEN 'Customer city from the source customer record.'
    WHEN 'dim_customer.state' THEN 'Customer state abbreviation from the source customer record.'
    WHEN 'dim_product.product_key' THEN 'Warehouse surrogate key for a product.'
    WHEN 'dim_product.product_id' THEN 'Source-system product identifier.'
    WHEN 'dim_product.product_category_name' THEN 'Product category name as supplied by the source.'
    WHEN 'dim_product.product_category_name_english' THEN 'English translation of the product category when available.'
    WHEN 'dim_seller.seller_key' THEN 'Warehouse surrogate key for a seller.'
    WHEN 'dim_seller.seller_id' THEN 'Source-system seller identifier.'
    WHEN 'fact_sales.sales_key' THEN 'Warehouse surrogate key for a sales fact row.'
    WHEN 'fact_sales.order_id' THEN 'Identifier of the order associated with this item row.'
    WHEN 'fact_sales.order_item_id' THEN 'Item sequence number within the order.'
    WHEN 'fact_sales.customer_key' THEN 'Foreign key to dim_customer.'
    WHEN 'fact_sales.product_key' THEN 'Foreign key to dim_product.'
    WHEN 'fact_sales.seller_key' THEN 'Foreign key to dim_seller.'
    WHEN 'fact_sales.purchase_date_key' THEN 'Date key for when the order was purchased.'
    WHEN 'fact_sales.price' THEN 'Price of the order item, excluding freight.'
    WHEN 'fact_sales.freight_value' THEN 'Freight/shipping amount associated with the order item.'
    WHEN 'fact_payment.payment_key' THEN 'Warehouse surrogate key for a payment row.'
    WHEN 'fact_payment.order_id' THEN 'Identifier of the order associated with the payment.'
    WHEN 'fact_payment.payment_type' THEN 'Payment method recorded by the source.'
    WHEN 'fact_payment.payment_value' THEN 'Amount recorded for this payment.'
    WHEN 'fact_review.review_key' THEN 'Warehouse surrogate key for a review row.'
    WHEN 'fact_review.order_id' THEN 'Identifier of the reviewed order.'
    WHEN 'fact_review.review_score' THEN 'Numeric score submitted by the customer.'
    WHEN 'fact_inventory.inventory_key' THEN 'Warehouse surrogate key for an inventory row.'
    WHEN 'fact_inventory.product_id' THEN 'Product identifier from the separate inventory source; not assumed to match Olist product IDs.'
    WHEN 'fact_inventory.inventory_level' THEN 'Inventory quantity reported by the source.'
    WHEN 'fact_inventory.units_sold' THEN 'Units sold as reported by the inventory source.'
    WHEN 'fact_inventory.units_ordered' THEN 'Units ordered as reported by the inventory source.'
    WHEN 'fact_inventory.demand_forecast' THEN 'Forecasted demand as reported by the source.'
    WHEN 'fact_marketing_leads.lead_key' THEN 'Warehouse surrogate key for a marketing lead row.'
    WHEN 'fact_marketing_leads.mql_id' THEN 'Marketing qualified lead identifier.'
    WHEN 'fact_marketing_leads.first_contact_date_key' THEN 'Date key for the lead first-contact date.'
    WHEN 'fact_marketing_leads.origin' THEN 'Source/channel origin recorded for the lead.'
    WHEN 'fact_closed_deals.deal_key' THEN 'Warehouse surrogate key for a closed deal row.'
    WHEN 'fact_closed_deals.mql_id' THEN 'Marketing qualified lead identifier associated with the closed deal.'
    WHEN 'fact_closed_deals.won_date_key' THEN 'Date key for the date the deal was won.'
    WHEN 'fact_closed_deals.declared_monthly_revenue' THEN 'Monthly revenue declared for the closed-deal record.'
    ELSE business_description
END,
metadata_updated_at = CURRENT_TIMESTAMP
WHERE schema_name = 'warehouse';

-- Verification queries: run after the script completes.
SELECT schema_name, table_name, table_type, business_description, business_owner
FROM audit.metadata_tables
ORDER BY table_name;

SELECT schema_name, table_name, ordinal_position, column_name, data_type,
       is_nullable, is_primary_key, is_foreign_key, business_description
FROM audit.metadata_columns
ORDER BY table_name, ordinal_position;

SELECT
    (SELECT COUNT(*) FROM audit.metadata_tables WHERE schema_name = 'warehouse') AS metadata_table_count,
    (SELECT COUNT(*) FROM audit.metadata_columns WHERE schema_name = 'warehouse') AS metadata_column_count,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'warehouse' AND table_type = 'BASE TABLE') AS actual_warehouse_table_count,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'warehouse') AS actual_warehouse_column_count;
