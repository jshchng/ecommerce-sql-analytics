-- analysis/product_performance.sql
-- Product Performance and Category Analysis

USE northwestern_commerce;

-- =============================================================================
-- CREATE PRODUCT METRICS (temp table)
-- =============================================================================

DROP TEMPORARY TABLE IF EXISTS product_metrics;

CREATE TEMPORARY TABLE product_metrics AS
WITH order_items_net AS (
    SELECT 
        oi.order_id,
        o.customer_id,
        oi.product_id,
        (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue,
        oi.quantity,
        oi.unit_price,
        oi.discount_amount
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
)
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    p.cost_price,
    COUNT(DISTINCT oin.order_id) AS order_count,
    COALESCE(SUM(oin.quantity),0) AS units_sold,
    COALESCE(SUM(oin.net_revenue),0) AS total_revenue,
    COALESCE(AVG(oin.unit_price),0) AS avg_selling_price,
    COALESCE(AVG(oin.net_revenue / NULLIF(oin.quantity,0)),0) AS avg_profit_per_unit,
    COALESCE(SUM((oin.unit_price - p.cost_price) * oin.quantity - oin.discount_amount),0) AS total_profit,
    COALESCE(ROUND(AVG(oin.discount_amount / NULLIF(oin.unit_price,1) * 100),2),0) AS avg_discount_percent
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status = 'Completed'
LEFT JOIN (
    SELECT 
        oi.order_id,
        o.customer_id,
        oi.product_id,
        (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue,
        oi.quantity,
        oi.unit_price,
        oi.discount_amount
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
) oin ON p.product_id = oin.product_id
GROUP BY p.product_id, p.product_name, p.category, p.subcategory, p.brand, p.cost_price;

-- =============================================================================
-- 1. Top Performing Products
-- =============================================================================

SELECT *
FROM product_metrics
ORDER BY total_revenue DESC
LIMIT 20;

-- =============================================================================
-- 2. Category Performance
-- =============================================================================

SELECT 
    category,
    COUNT(DISTINCT product_id) AS product_count,
    SUM(order_count) AS order_count,
    SUM(units_sold) AS units_sold,
    SUM(total_revenue) AS revenue,
    AVG(avg_selling_price) AS avg_price,
    AVG(cost_price) AS avg_cost,
    SUM(total_profit) AS total_profit,
    ROUND(SUM(total_profit) / NULLIF(SUM(total_revenue),0) * 100,2) AS profit_margin_percent
FROM product_metrics
GROUP BY category
ORDER BY revenue DESC;

-- =============================================================================
-- 3. Inventory Turnover / Product Velocity
-- =============================================================================

WITH product_velocity AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        DATEDIFF(CURRENT_DATE, p.created_at) AS days_since_launch,
        COALESCE(SUM(oin.quantity),0) AS total_units_sold,
        COALESCE(SUM(oin.net_revenue),0) AS total_revenue
    FROM products p
    LEFT JOIN (
        SELECT 
            oi.order_id,
            o.customer_id,
            oi.product_id,
            (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue,
            oi.quantity,
            oi.unit_price,
            oi.discount_amount
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_status = 'Completed'
    ) oin ON p.product_id = oin.product_id
    GROUP BY p.product_id, p.product_name, p.category, p.created_at
)
SELECT 
    product_id,
    product_name,
    category,
    days_since_launch,
    total_units_sold,
    total_revenue,
    ROUND(total_units_sold / GREATEST(days_since_launch,1),2) AS units_per_day,
    ROUND(total_revenue / GREATEST(days_since_launch,1),2) AS revenue_per_day,
    NTILE(5) OVER (ORDER BY total_units_sold / GREATEST(days_since_launch,1) DESC) AS velocity_quintile,
    CASE 
        WHEN total_units_sold = 0 THEN 'No Sales'
        WHEN total_units_sold / GREATEST(days_since_launch,1) >= 5 THEN 'High Velocity'
        WHEN total_units_sold / GREATEST(days_since_launch,1) >= 1 THEN 'Medium Velocity'
        ELSE 'Low Velocity'
    END AS velocity_category
FROM product_velocity
ORDER BY units_per_day DESC;

-- =============================================================================
-- 4. Cross-Sell / Frequently Bought Together Products
-- =============================================================================

WITH total_orders_per_product AS (
    SELECT product_id, COUNT(DISTINCT order_id) AS total_orders
    FROM (
        SELECT 
            oi.order_id,
            o.customer_id,
            oi.product_id
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_status = 'Completed'
    ) t
    GROUP BY product_id
),
order_pairs AS (
    SELECT 
        oi1.product_id AS product_a,
        oi2.product_id AS product_b,
        COUNT(*) AS frequency
    FROM order_items oi1
    JOIN orders o1 ON oi1.order_id = o1.order_id
    JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id < oi2.product_id
    JOIN orders o2 ON oi2.order_id = o2.order_id
    WHERE o1.order_status = 'Completed'
      AND o2.order_status = 'Completed'
    GROUP BY oi1.product_id, oi2.product_id
    HAVING COUNT(*) >= 10
)
SELECT 
    op.product_a,
    p1.product_name AS product_a_name,
    p1.category AS product_a_category,
    op.product_b,
    p2.product_name AS product_b_name,
    p2.category AS product_b_category,
    op.frequency AS times_bought_together,
    ROUND(op.frequency * 100.0 / NULLIF(t.total_orders,0),2) AS lift_percentage
FROM order_pairs op
JOIN products p1 ON op.product_a = p1.product_id
JOIN products p2 ON op.product_b = p2.product_id
JOIN total_orders_per_product t ON op.product_a = t.product_id
ORDER BY op.frequency DESC
LIMIT 20;
