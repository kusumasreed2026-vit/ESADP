
-- ============================================================
-- ESADP / UC19 - SPRINT 2 SQL SALES REPORTING
-- Database schema: warehouse
-- Purpose: Business analytics and sales reporting
-- All queries are read-only.
-- ============================================================


-- 1. OVERALL SALES PERFORMANCE
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS total_order_items,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(SUM(freight_value), 2) AS total_freight,
    ROUND(SUM(price + freight_value), 2) AS total_sales_with_freight,
    ROUND(
        SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0), 2
    ) AS average_order_value
FROM warehouse.fact_sales
WHERE LOWER(COALESCE(order_status, '')) <> 'canceled';


-- 2. MONTHLY REVENUE AND ORDER TRENDS
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.price), 2) AS monthly_revenue,
    ROUND(SUM(f.freight_value), 2) AS monthly_freight,
    ROUND(
        SUM(f.price) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2
    ) AS average_order_value
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d
    ON f.purchase_date_key = d.date_key
WHERE LOWER(COALESCE(f.order_status, '')) <> 'canceled'
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


-- 3. ORDER STATUS SUMMARY
SELECT
    order_status,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS total_order_items,
    ROUND(SUM(price), 2) AS item_revenue,
    ROUND(SUM(freight_value), 2) AS freight_value
FROM warehouse.fact_sales
GROUP BY order_status
ORDER BY total_orders DESC;


-- 4. TOP 10 PRODUCT CATEGORIES BY REVENUE
SELECT
    COALESCE(
        NULLIF(p.product_category_name_english, ''),
        NULLIF(p.product_category_name, ''),
        'Unknown'
    ) AS product_category,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.price), 2) AS total_revenue
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(COALESCE(f.order_status, '')) <> 'canceled'
GROUP BY
    COALESCE(
        NULLIF(p.product_category_name_english, ''),
        NULLIF(p.product_category_name, ''),
        'Unknown'
    )
ORDER BY total_revenue DESC
LIMIT 10;


-- 5. TOP 10 PRODUCTS BY REVENUE
SELECT
    p.product_id,
    COALESCE(
        NULLIF(p.product_category_name_english, ''),
        NULLIF(p.product_category_name, ''),
        'Unknown'
    ) AS product_category,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.price), 2) AS total_revenue
FROM warehouse.fact_sales f
JOIN warehouse.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(COALESCE(f.order_status, '')) <> 'canceled'
GROUP BY
    p.product_id,
    p.product_category_name_english,
    p.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;


-- 6. SALES BY CUSTOMER STATE
SELECT
    c.state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS unique_customers,
    ROUND(SUM(f.price), 2) AS total_revenue,
    ROUND(SUM(f.freight_value), 2) AS total_freight
FROM warehouse.fact_sales f
JOIN warehouse.dim_customer c
    ON f.customer_key = c.customer_key
WHERE LOWER(COALESCE(f.order_status, '')) <> 'canceled'
GROUP BY c.state
ORDER BY total_revenue DESC;


-- 7. CUSTOMER PURCHASE BEHAVIOUR
-- Repeat customers have placed more than one distinct order.
WITH customer_orders AS (
    SELECT
        customer_key,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(price) AS customer_revenue
    FROM warehouse.fact_sales
    WHERE LOWER(COALESCE(order_status, '')) <> 'canceled'
    GROUP BY customer_key
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE order_count > 1) AS repeat_customers,
    COUNT(*) FILTER (WHERE order_count = 1) AS one_order_customers,
    ROUND(AVG(order_count), 2) AS average_orders_per_customer,
    ROUND(SUM(customer_revenue), 2) AS total_revenue
FROM customer_orders;


-- 8. PAYMENT METHOD ANALYSIS
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value,
    ROUND(AVG(payment_installments), 2) AS average_installments
FROM warehouse.fact_payment
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- 9. REVIEW SCORE DISTRIBUTION
SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(
        100.0 * COUNT(*) /
        NULLIF(SUM(COUNT(*)) OVER (), 0), 2
    ) AS percentage_of_reviews
FROM warehouse.fact_review
GROUP BY review_score
ORDER BY review_score;


-- 10. AVERAGE REVIEW SCORE BY ORDER STATUS
SELECT
    f.order_status,
    COUNT(DISTINCT r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM warehouse.fact_review r
JOIN (
    SELECT DISTINCT order_id, order_status
    FROM warehouse.fact_sales
) f
    ON r.order_id = f.order_id
GROUP BY f.order_status
ORDER BY f.order_status;


-- 11. DELIVERY PERFORMANCE
SELECT
    COUNT(*) AS delivered_order_items,
    ROUND(
        AVG(delivered.full_date - purchased.full_date), 2
    ) AS average_delivery_days,
    ROUND(
        AVG(estimated.full_date - purchased.full_date), 2
    ) AS average_estimated_delivery_days,
    COUNT(*) FILTER (
        WHERE delivered.full_date > estimated.full_date
    ) AS items_delivered_late
FROM warehouse.fact_sales f
JOIN warehouse.dim_date purchased
    ON f.purchase_date_key = purchased.date_key
JOIN warehouse.dim_date delivered
    ON f.delivered_date_key = delivered.date_key
JOIN warehouse.dim_date estimated
    ON f.estimated_delivery_date_key = estimated.date_key
WHERE LOWER(COALESCE(f.order_status, '')) = 'delivered';


-- 12. SELLER PERFORMANCE
SELECT
    s.seller_id,
    s.state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(f.price), 2) AS total_revenue
FROM warehouse.fact_sales f
JOIN warehouse.dim_seller s
    ON f.seller_key = s.seller_key
WHERE LOWER(COALESCE(f.order_status, '')) <> 'canceled'
GROUP BY s.seller_id, s.state
ORDER BY total_revenue DESC
LIMIT 10;


-- 13. MARKETING LEADS BY ORIGIN
SELECT
    COALESCE(NULLIF(origin, ''), 'Unknown') AS lead_origin,
    COUNT(*) AS total_leads
FROM warehouse.fact_marketing_leads
GROUP BY COALESCE(NULLIF(origin, ''), 'Unknown')
ORDER BY total_leads DESC;


-- 14. CLOSED DEALS BY BUSINESS SEGMENT
SELECT
    COALESCE(
        NULLIF(business_segment, ''), 'Unknown'
    ) AS business_segment,
    COUNT(*) AS closed_deals,
    ROUND(SUM(declared_monthly_revenue), 2)
        AS declared_monthly_revenue
FROM warehouse.fact_closed_deals
GROUP BY COALESCE(
    NULLIF(business_segment, ''), 'Unknown'
)
ORDER BY closed_deals DESC;


-- 15. INVENTORY AND DEMAND FORECAST
SELECT
    COALESCE(NULLIF(category, ''), 'Unknown') AS category,
    COUNT(*) AS inventory_records,
    SUM(inventory_level) AS total_inventory,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(demand_forecast), 2) AS total_demand_forecast,
    SUM(inventory_level)
        - SUM(demand_forecast) AS inventory_minus_forecast
FROM warehouse.fact_inventory
GROUP BY COALESCE(NULLIF(category, ''), 'Unknown')
ORDER BY total_units_sold DESC;


-- 16. MONTHLY SALES BY CUSTOMER STATE
SELECT
    d.year,
    d.month,
    c.state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.price), 2) AS total_revenue
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d
    ON f.purchase_date_key = d.date_key
JOIN warehouse.dim_customer c
    ON f.customer_key = c.customer_key
WHERE LOWER(COALESCE(f.order_status, '')) <> 'canceled'
GROUP BY d.year, d.month, c.state
ORDER BY d.year, d.month, total_revenue DESC;
