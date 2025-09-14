-- analysis/business_metrics.sql
-- Key Business Metrics and KPI Dashboard Queries

USE northwestern_commerce;

-- =============================================================================
-- EXECUTIVE KPI DASHBOARD
-- =============================================================================

WITH order_items_net AS (
    SELECT 
        oi.order_id,
        o.customer_id,
        (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue,
        oi.quantity
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
),

customer_first_order AS (
    SELECT customer_id, DATE_FORMAT(MIN(order_date), '%Y-%m') AS first_order_month
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),

monthly_metrics AS (
    SELECT 
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oin.net_revenue) AS revenue,
        SUM(oin.net_revenue) / COUNT(DISTINCT o.order_id) AS aov,
        SUM(oin.quantity) AS units_sold,
        COUNT(DISTINCT CASE 
            WHEN DATE_FORMAT(o.order_date, '%Y-%m') = cfo.first_order_month 
            THEN o.customer_id 
        END) AS new_customers
    FROM orders o
    JOIN order_items_net oin ON o.order_id = oin.order_id
    LEFT JOIN customer_first_order cfo ON o.customer_id = cfo.customer_id
    WHERE o.order_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
),

monthly_growth AS (
    SELECT *,
        LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
        LAG(total_orders) OVER (ORDER BY month) AS prev_month_orders,
        LAG(active_customers) OVER (ORDER BY month) AS prev_month_customers
    FROM monthly_metrics
)

SELECT 
    month,
    active_customers,
    new_customers,
    total_orders,
    revenue,
    ROUND(aov,2) AS avg_order_value,
    units_sold,
    ROUND(
        CASE WHEN prev_month_revenue IS NOT NULL 
             THEN (revenue - prev_month_revenue) / NULLIF(prev_month_revenue,0) * 100 
        END, 2
    ) AS revenue_growth_pct,
    ROUND(
        CASE WHEN prev_month_orders IS NOT NULL 
             THEN (total_orders - prev_month_orders) / NULLIF(prev_month_orders,0) * 100 
        END, 2
    ) AS orders_growth_pct,
    ROUND(
        CASE WHEN prev_month_customers IS NOT NULL 
             THEN (active_customers - prev_month_customers) / NULLIF(prev_month_customers,0) * 100 
        END, 2
    ) AS customer_growth_pct
FROM monthly_growth
ORDER BY month;

