-- analysis/cohort_analysis.sql
-- Customer Cohort Analysis for Retention, Revenue, and LTV

USE northwestern_commerce;

-- =============================================================================
-- Base reusable temp tables
-- =============================================================================

-- Net revenue per order item
DROP TEMPORARY TABLE IF EXISTS order_items_net;
CREATE TEMPORARY TABLE order_items_net AS
SELECT 
    oi.order_id,
    o.customer_id,
    oi.product_id,
    (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue,
    oi.quantity
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed';

-- First order per customer (cohort assignment)
DROP TEMPORARY TABLE IF EXISTS customer_first_orders;
CREATE TEMPORARY TABLE customer_first_orders AS
SELECT 
    customer_id,
    MIN(order_date) AS first_order_date,
    DATE_FORMAT(MIN(order_date), '%Y-%m') AS cohort_month
FROM orders
WHERE order_status = 'Completed'
GROUP BY customer_id;

-- =============================================================================
-- 1. RETENTION TABLE
-- =============================================================================

DROP TEMPORARY TABLE IF EXISTS customer_monthly_activity;
CREATE TEMPORARY TABLE customer_monthly_activity AS
SELECT 
    cfo.customer_id,
    cfo.cohort_month,
    cfo.first_order_date,
    DATE_FORMAT(o.order_date, '%Y-%m') AS activity_month,
    PERIOD_DIFF(DATE_FORMAT(o.order_date, '%Y%m'), DATE_FORMAT(cfo.first_order_date, '%Y%m')) AS period_number
FROM customer_first_orders cfo
JOIN orders o ON cfo.customer_id = o.customer_id
WHERE o.order_status = 'Completed';

DROP TEMPORARY TABLE IF EXISTS cohort_table;
CREATE TEMPORARY TABLE cohort_table AS
SELECT 
    cohort_month,
    period_number,
    COUNT(DISTINCT customer_id) AS customers_active
FROM customer_monthly_activity
GROUP BY cohort_month, period_number;

DROP TEMPORARY TABLE IF EXISTS cohort_sizes;
CREATE TEMPORARY TABLE cohort_sizes AS
SELECT 
    cohort_month,
    customers_active AS cohort_size
FROM cohort_table
WHERE period_number = 0;

-- Retention output
SELECT 
    ct.cohort_month,
    cs.cohort_size AS total_customers,
    ct.period_number AS months_after_first_order,
    ct.customers_active,
    ROUND(ct.customers_active * 100.0 / NULLIF(cs.cohort_size, 0), 2) AS retention_percentage
FROM cohort_table ct
JOIN cohort_sizes cs ON ct.cohort_month = cs.cohort_month
WHERE cs.cohort_size >= 100
ORDER BY ct.cohort_month, ct.period_number;

-- =============================================================================
-- 2. REVENUE TABLE
-- =============================================================================

DROP TEMPORARY TABLE IF EXISTS customer_revenue_by_month;
CREATE TEMPORARY TABLE customer_revenue_by_month AS
SELECT 
    o.customer_id,
    cfo.cohort_month,
    DATE_FORMAT(o.order_date, '%Y-%m') AS revenue_month,
    PERIOD_DIFF(DATE_FORMAT(o.order_date, '%Y%m'), DATE_FORMAT(cfo.first_order_date, '%Y%m')) AS period_number,
    SUM(oin.net_revenue) AS revenue
FROM orders o
JOIN customer_first_orders cfo ON o.customer_id = cfo.customer_id
JOIN order_items_net oin ON o.order_id = oin.order_id
WHERE o.order_status = 'Completed'
GROUP BY o.customer_id, cfo.cohort_month, revenue_month, period_number;

-- Revenue output
SELECT 
    cohort_month,
    period_number AS months_after_first_order,
    COUNT(DISTINCT customer_id) AS active_customers,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_revenue_per_customer,
    SUM(SUM(revenue)) OVER (
        PARTITION BY cohort_month 
        ORDER BY period_number 
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_revenue
FROM customer_revenue_by_month
GROUP BY cohort_month, period_number
ORDER BY cohort_month, period_number;

-- =============================================================================
-- 3. LTV SEGMENTATION TABLE
-- =============================================================================

DROP TEMPORARY TABLE IF EXISTS customer_ltv_metrics;
CREATE TEMPORARY TABLE customer_ltv_metrics AS
SELECT 
    c.customer_id,
    c.registration_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oin.net_revenue) AS total_revenue,
    AVG(oin.net_revenue) AS avg_order_value,
    DATEDIFF(MAX(o.order_date), MIN(o.order_date)) + 1 AS customer_lifespan_days,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN customer_first_orders cfo ON c.customer_id = cfo.customer_id
LEFT JOIN order_items_net oin ON o.order_id = oin.order_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.registration_date;

-- LTV output
SELECT 
    CASE 
        WHEN total_orders = 1 THEN 'One-time Customer'
        WHEN total_orders <= 3 THEN 'Low Frequency (2-3 orders)'
        WHEN total_orders <= 6 THEN 'Medium Frequency (4-6 orders)'
        ELSE 'High Frequency (7+ orders)'
    END AS customer_frequency_segment,
    COUNT(*) AS customer_count,
    AVG(total_revenue) AS avg_ltv,
    AVG(avg_order_value) AS avg_order_value,
    AVG(total_orders) AS avg_order_frequency,
    AVG(customer_lifespan_days) AS avg_lifespan_days,
    SUM(total_revenue) AS total_segment_revenue
FROM customer_ltv_metrics
GROUP BY customer_frequency_segment
ORDER BY avg_ltv DESC;
