-- metrics_extraction.sql
-- Extract key metrics for README (Business Impact & Key Findings)
-- Run this AFTER running all main project SQL scripts

USE northwestern_commerce;

-- =============================================================
-- 1. Top 20% Customer Revenue
-- =============================================================
WITH customer_monetary AS (
    SELECT c.customer_id,
           SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS monetary_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id
),
ranked_customers AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY monetary_value DESC) AS rn,
           COUNT(*) OVER () AS total_customers
    FROM customer_monetary
)
SELECT SUM(monetary_value) AS top_20_percent_revenue
FROM ranked_customers
WHERE rn <= CEIL(total_customers * 0.2);

-- =============================================================
-- 2. High Churn Risk Customers
-- =============================================================
SELECT COUNT(*) AS high_churn_risk_customers
FROM (
    SELECT c.customer_id
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id
    HAVING DATEDIFF(CURDATE(), MAX(o.order_date)) > 180
) AS inactive_customers;


-- =============================================================
-- 3. Potential Cross-Sell Revenue
-- =============================================================
WITH order_pairs AS (
    SELECT 
        oi1.product_id AS product_a,
        oi2.product_id AS product_b,
        COUNT(*) AS frequency
    FROM order_items oi1
    JOIN order_items oi2 
        ON oi1.order_id = oi2.order_id 
       AND oi1.product_id < oi2.product_id
    GROUP BY oi1.product_id, oi2.product_id
    HAVING COUNT(*) >= 5
)
SELECT 
    SUM(op.frequency * (p1.list_price + p2.list_price)) AS potential_cross_sell_revenue
FROM order_pairs op
JOIN products p1 ON op.product_a = p1.product_id
JOIN products p2 ON op.product_b = p2.product_id;

-- =============================================================
-- 4. Customer Segmentation Revenue Breakdown
-- =============================================================
SELECT customer_segment,
       COUNT(*) AS customer_count,
       SUM(total_revenue) AS total_revenue
FROM (
    SELECT 
        c.customer_id,
        CASE 
            WHEN COUNT(DISTINCT o.order_id) = 0 THEN 'Inactive'
            WHEN SUM(oi.quantity * oi.unit_price - oi.discount_amount) > 500 THEN 'High Value'
            ELSE 'Low/Medium Value'
        END AS customer_segment,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS total_revenue
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id
) AS customer_summary
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- =============================================================
-- 5. Quarterly Revenue for Seasonal Trends
-- =============================================================
SELECT QUARTER(o.order_date) AS quarter, SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
GROUP BY quarter
ORDER BY quarter;

-- =============================================================
-- 6. Product Category Profit Margins
-- =============================================================
SELECT p.category,
       SUM((oi.unit_price - p.cost_price) * oi.quantity - oi.discount_amount) AS profit,
       SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS revenue,
       ROUND(SUM((oi.unit_price - p.cost_price) * oi.quantity - oi.discount_amount)/SUM(oi.quantity * oi.unit_price - oi.discount_amount)*100,2) AS profit_margin
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY p.category
ORDER BY profit_margin DESC;

-- =============================================================
-- 7. Month-over-Month Growth Metrics
-- =============================================================
WITH monthly_metrics AS (
    SELECT 
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
      AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month,
       revenue,
       total_orders,
       active_customers,
       LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month))/LAG(revenue) OVER (ORDER BY month)*100,2) AS revenue_growth_pct,
       ROUND((total_orders - LAG(total_orders) OVER (ORDER BY month))/LAG(total_orders) OVER (ORDER BY month)*100,2) AS orders_growth_pct,
       ROUND((active_customers - LAG(active_customers) OVER (ORDER BY month))/LAG(active_customers) OVER (ORDER BY month)*100,2) AS customers_growth_pct
FROM monthly_metrics
ORDER BY month;
