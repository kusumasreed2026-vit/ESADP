
WITH checks AS (

    SELECT
        'Row count: dim_date' AS check_name,
        COUNT(*)::BIGINT AS actual_value,
        3288::BIGINT AS expected_value
    FROM warehouse.dim_date

    UNION ALL
    SELECT 'Row count: dim_customer',
           COUNT(*), COUNT(DISTINCT customer_id)
    FROM warehouse.dim_customer

    UNION ALL
    SELECT 'Row count: dim_product',
           COUNT(*), COUNT(DISTINCT product_id)
    FROM warehouse.dim_product

    UNION ALL
    SELECT 'Row count: dim_seller',
           COUNT(*), COUNT(DISTINCT seller_id)
    FROM warehouse.dim_seller

    UNION ALL
    SELECT 'Row count: fact_sales',
           COUNT(*),
           COUNT(DISTINCT (order_id, order_item_id))
    FROM warehouse.fact_sales

    UNION ALL
    SELECT 'Row count: fact_payment',
           COUNT(*),
           COUNT(DISTINCT (order_id, payment_sequential))
    FROM warehouse.fact_payment

    UNION ALL
    SELECT 'Row count: fact_review',
           COUNT(*), COUNT(DISTINCT review_key)
    FROM warehouse.fact_review

    UNION ALL
    SELECT 'Row count: fact_inventory',
           COUNT(*), COUNT(DISTINCT inventory_id)
    FROM warehouse.fact_inventory

    UNION ALL
    SELECT 'Row count: fact_marketing_leads',
           COUNT(*), COUNT(DISTINCT mql_id)
    FROM warehouse.fact_marketing_leads

    UNION ALL
    SELECT 'Row count: fact_closed_deals',
           COUNT(*), COUNT(DISTINCT mql_id)
    FROM warehouse.fact_closed_deals

    UNION ALL
    SELECT 'Duplicate sales items',
           COUNT(*)::BIGINT, 0::BIGINT
    FROM (
        SELECT order_id, order_item_id
        FROM warehouse.fact_sales
        GROUP BY order_id, order_item_id
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Duplicate payments',
           COUNT(*)::BIGINT, 0::BIGINT
    FROM (
        SELECT order_id, payment_sequential
        FROM warehouse.fact_payment
        GROUP BY order_id, payment_sequential
        HAVING COUNT(*) > 1
    ) d

    UNION ALL
    SELECT 'Sales with missing customer key',
           COUNT(*) FILTER (WHERE customer_key IS NULL),
           0
    FROM warehouse.fact_sales

    UNION ALL
    SELECT 'Sales with missing product key',
           COUNT(*) FILTER (WHERE product_key IS NULL),
           0
    FROM warehouse.fact_sales

    UNION ALL
    SELECT 'Sales with missing seller key',
           COUNT(*) FILTER (WHERE seller_key IS NULL),
           0
    FROM warehouse.fact_sales

    UNION ALL
    SELECT 'Sales with missing purchase date key',
           COUNT(*) FILTER (WHERE purchase_date_key IS NULL),
           0
    FROM warehouse.fact_sales

    UNION ALL
    SELECT 'Reviews with missing order ID',
           COUNT(*) FILTER (WHERE order_id IS NULL),
           0
    FROM warehouse.fact_review

    UNION ALL
    SELECT 'Marketing leads: staging vs warehouse',
           (SELECT COUNT(*) FROM warehouse.fact_marketing_leads),
           (SELECT COUNT(*) FROM staging.stg_marketing_leads)

    UNION ALL
    SELECT 'Closed deals: staging vs warehouse',
           (SELECT COUNT(*) FROM warehouse.fact_closed_deals),
           (SELECT COUNT(*) FROM staging.stg_marketing_deals)

    UNION ALL
    SELECT 'Inventory: staging vs warehouse',
           (SELECT COUNT(*) FROM warehouse.fact_inventory),
           (SELECT COUNT(*) FROM staging.stg_inventory)
)
SELECT
    check_name,
    actual_value,
    expected_value,
    CASE
        WHEN actual_value = expected_value THEN 'PASS'
        ELSE 'CHECK'
    END AS validation_status
FROM checks
ORDER BY check_name;
