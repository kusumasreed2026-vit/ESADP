-- ESADP Sprint 3: Validation and Reconciliation
-- Run in pgAdmin Query Tool against the ESADP database.
-- CHECK results are diagnostic and should be explained, not hidden.

WITH checks AS (
    SELECT 'Row count: dim_date'::text AS check_name, COUNT(*)::numeric AS actual_value,
           3288::numeric AS expected_value,
           'Expected calendar coverage: 2016-01-01 through 2024-12-31.'::text AS note
    FROM warehouse.dim_date
    UNION ALL SELECT 'Row count: dim_customer', COUNT(*)::numeric,
           COUNT(DISTINCT customer_id)::numeric, 'Compares total rows with distinct customer IDs.'
    FROM warehouse.dim_customer
    UNION ALL SELECT 'Row count: dim_product', COUNT(*)::numeric,
           COUNT(DISTINCT product_id)::numeric, 'Compares total rows with distinct product IDs.'
    FROM warehouse.dim_product
    UNION ALL SELECT 'Row count: dim_seller', COUNT(*)::numeric,
           COUNT(DISTINCT seller_id)::numeric, 'Compares total rows with distinct seller IDs.'
    FROM warehouse.dim_seller
    UNION ALL SELECT 'Row count: fact_sales', COUNT(*)::numeric,
           COUNT(DISTINCT (order_id, order_item_id))::numeric, 'Expected one row per order item.'
    FROM warehouse.fact_sales
    UNION ALL SELECT 'Row count: fact_payment', COUNT(*)::numeric,
           COUNT(DISTINCT (order_id, payment_sequential))::numeric, 'Expected one row per order payment sequence.'
    FROM warehouse.fact_payment
    UNION ALL SELECT 'Row count: fact_review', COUNT(*)::numeric,
           COUNT(DISTINCT review_key)::numeric, 'Compares review rows with unique surrogate keys.'
    FROM warehouse.fact_review
    UNION ALL SELECT 'Row count: fact_inventory', COUNT(*)::numeric,
           COUNT(DISTINCT inventory_id)::numeric,
           'If inventory IDs can repeat across snapshots, interpret this comparison accordingly.'
    FROM warehouse.fact_inventory
    UNION ALL SELECT 'Row count: fact_marketing_leads', COUNT(*)::numeric,
           COUNT(DISTINCT mql_id)::numeric, 'Compares rows with unique MQL IDs.'
    FROM warehouse.fact_marketing_leads
    UNION ALL SELECT 'Row count: fact_closed_deals', COUNT(*)::numeric,
           COUNT(DISTINCT mql_id)::numeric, 'Compares rows with unique MQL IDs.'
    FROM warehouse.fact_closed_deals
    UNION ALL SELECT 'Duplicate sales items', COUNT(*)::numeric, 0::numeric,
           'Duplicate (order_id, order_item_id) groups; expected zero.'
    FROM (SELECT order_id, order_item_id FROM warehouse.fact_sales
          GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) d
    UNION ALL SELECT 'Duplicate payments', COUNT(*)::numeric, 0::numeric,
           'Duplicate (order_id, payment_sequential) groups; expected zero.'
    FROM (SELECT order_id, payment_sequential FROM warehouse.fact_payment
          GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1) d
    UNION ALL SELECT 'Sales with missing customer key',
           COUNT(*) FILTER (WHERE customer_key IS NULL)::numeric, 0::numeric,
           'Expected zero sales rows without customer dimension key.'
    FROM warehouse.fact_sales
    UNION ALL SELECT 'Sales with missing product key',
           COUNT(*) FILTER (WHERE product_key IS NULL)::numeric, 0::numeric,
           'Expected zero sales rows without product dimension key.'
    FROM warehouse.fact_sales
    UNION ALL SELECT 'Sales with missing seller key',
           COUNT(*) FILTER (WHERE seller_key IS NULL)::numeric, 0::numeric,
           'Expected zero sales rows without seller dimension key.'
    FROM warehouse.fact_sales
    UNION ALL SELECT 'Sales with missing purchase date key',
           COUNT(*) FILTER (WHERE purchase_date_key IS NULL)::numeric, 0::numeric,
           'Expected zero sales rows without purchase date key.'
    FROM warehouse.fact_sales
    UNION ALL SELECT 'Reviews with missing order ID',
           COUNT(*) FILTER (WHERE order_id IS NULL)::numeric, 0::numeric,
           'Expected zero review rows without order ID.'
    FROM warehouse.fact_review
    UNION ALL SELECT 'Marketing leads: staging vs warehouse',
           (SELECT COUNT(*) FROM warehouse.fact_marketing_leads)::numeric,
           (SELECT COUNT(*) FROM staging.stg_marketing_leads)::numeric,
           'Can differ due to source filters, duplicate exclusion, or unmatched dates.'
    UNION ALL SELECT 'Closed deals: staging vs warehouse',
           (SELECT COUNT(*) FROM warehouse.fact_closed_deals)::numeric,
           (SELECT COUNT(*) FROM staging.stg_marketing_deals)::numeric,
           'Can differ due to source filters, duplicate exclusion, or unmatched dates.'
    UNION ALL SELECT 'Inventory: staging vs warehouse',
           (SELECT COUNT(*) FROM warehouse.fact_inventory)::numeric,
           (SELECT COUNT(*) FROM staging.stg_inventory)::numeric,
           'Inventory is separate from Olist sales; product identifiers are not directly comparable.'
    UNION ALL SELECT 'Revenue: staging POS price vs warehouse sales price',
           COALESCE((SELECT SUM(price) FROM warehouse.fact_sales), 0)::numeric,
           COALESCE((SELECT SUM(price) FROM staging.stg_pos), 0)::numeric,
           'Compares item-price totals; differences may arise from joins, filters, duplicates, or incomplete loads.'
    UNION ALL SELECT 'Revenue: staging POS price plus freight vs warehouse price plus freight',
           COALESCE((SELECT SUM(price + freight_value) FROM warehouse.fact_sales), 0)::numeric,
           COALESCE((SELECT SUM(price + freight_value) FROM staging.stg_pos), 0)::numeric,
           'Compares item price plus freight at item grain.'
    UNION ALL SELECT 'Payment vs item price plus freight (absolute difference)',
           ABS(COALESCE((SELECT SUM(price + freight_value) FROM warehouse.fact_sales), 0)
             - COALESCE((SELECT SUM(payment_value) FROM warehouse.fact_payment), 0))::numeric,
           0::numeric,
           'Diagnostic only: payment rows and item rows can differ due to installments, multiple payments, vouchers, refunds, cancellations, and allocation differences.'
)
SELECT check_name, ROUND(actual_value, 2) AS actual_value,
       ROUND(expected_value, 2) AS expected_value,
       CASE WHEN ABS(actual_value - expected_value) < 0.01 THEN 'PASS' ELSE 'CHECK' END AS validation_status,
       note
FROM checks
ORDER BY check_name;

-- Diagnostic totals for the Validation Report.
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM warehouse.fact_sales) AS sales_orders,
    (SELECT COUNT(DISTINCT order_id) FROM warehouse.fact_payment) AS payment_orders,
    ROUND((SELECT COALESCE(SUM(price), 0) FROM warehouse.fact_sales), 2) AS sales_item_revenue,
    ROUND((SELECT COALESCE(SUM(freight_value), 0) FROM warehouse.fact_sales), 2) AS sales_freight,
    ROUND((SELECT COALESCE(SUM(payment_value), 0) FROM warehouse.fact_payment), 2) AS payment_total,
    ROUND((SELECT COALESCE(SUM(price + freight_value), 0) FROM warehouse.fact_sales)
        - (SELECT COALESCE(SUM(payment_value), 0) FROM warehouse.fact_payment), 2)
        AS item_plus_freight_minus_payments;

-- Inventory caveat: the inventory dataset is a separate source.
-- Do not reconcile inventory product IDs or units directly to Olist fact_sales
-- unless a documented cross-system product mapping is available.
