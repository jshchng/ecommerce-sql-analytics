-- analysis/01_exploratory_analysis.sql
-- Exploratory Data Analysis for Northwestern Commerce

USE northwestern_commerce;

-- =============================================================================
-- BASIC BUSINESS METRICS
-- =============================================================================

-- 1. Overall business summary
SELECT 
    'Total Revenue' as metric,
    CONCAT('$', FORMAT(SUM(oi.quantity * oi.unit_price - oi.discount_amount), 2)) as value
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'

UNION ALL

SELECT 
    'Total Orders',
    FORMAT(COUNT(DISTINCT o.order_id), 0)
FROM orders o
WHERE o.order_status = 'Completed'

UNION ALL

SELECT 
    'Total Customers',
    FORMAT(COUNT(DISTINCT customer_id), 0)
FROM customers

UNION ALL

SELECT 
    'Average Order Value',
    CONCAT('$', FORMAT(AVG(order_total), 2))
FROM (
    SELECT 
        o.order_id,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) as order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id
) order_totals;

-- 2. Monthly revenue trend
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') as month,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(oi.quantity * oi.unit_price - oi.discount_amount) as revenue,
    AVG(oi.quantity * oi.unit_price - oi.discount_amount) as avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
  AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 24 MONTH)
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- 3. Customer distribution by geography
SELECT 
    state,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customers), 2) as percentage,
    AVG(customer_lifetime_value) as avg_clv
FROM customers
GROUP BY state
ORDER BY customer_count DESC
LIMIT 10;

-- 4. Product category performance
SELECT 
    p.category,
    COUNT(DISTINCT oi.order_id) as orders,
    SUM(oi.quantity) as units_sold,
    SUM(oi.quantity * oi.unit_price - oi.discount_amount) as revenue,
    AVG(oi.unit_price) as avg_unit_price,
    SUM(oi.discount_amount) as total_discounts
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY p.category
ORDER BY revenue DESC;

-- =============================================================================
-- CUSTOMER ANALYSIS
-- =============================================================================

-- 5. Customer registration vs purchase timing
SELECT 
    CASE 
        WHEN DATEDIFF(first_order_date, registration_date) = 0 THEN 'Same Day'
        WHEN DATEDIFF(first_order_date, registration_date) <= 7 THEN '1 Week'
        WHEN DATEDIFF(first_order_date, registration_date) <= 30 THEN '1 Month'
        WHEN DATEDIFF(first_order_date, registration_date) <= 90 THEN '3 Months'
        ELSE 'More than 3 Months'
    END as time_to_first_purchase,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customers), 2) as percentage
FROM (
    SELECT 
        c.customer_id,
        c.registration_date,
        MIN(o.order_date) as first_order_date
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_date IS NOT NULL
    GROUP BY c.customer_id, c.registration_date
) customer_first_orders
GROUP BY time_to_first_purchase
ORDER BY 
    CASE time_to_first_purchase
        WHEN 'Same Day' THEN 1
        WHEN '1 Week' THEN 2
        WHEN '1 Month' THEN 3
        WHEN '3 Months' THEN 4
        ELSE 5
    END;

-- 6. Age group analysis
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 25 THEN '18-24'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 35 THEN '25-34'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 45 THEN '35-44'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 55 THEN '45-54'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 65 THEN '55-64'
        ELSE '65+'
    END as age_group,
    COUNT(DISTINCT c.customer_id) as customers,
    COUNT(DISTINCT o.order_id) as orders,
    SUM(oi.quantity * oi.unit_price - oi.discount_amount) as revenue,
    AVG(oi.quantity * oi.unit_price - oi.discount_amount) as avg_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'Completed'
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.birth_date IS NOT NULL
GROUP BY age_group
ORDER BY 
    CASE age_group
        WHEN '18-24' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55-64' THEN 5
        ELSE 6
    END;

-- =============================================================================
-- SEASONAL PATTERNS
-- =============================================================================

-- 7. Daily order patterns
SELECT 
    DAYNAME(order_date) as day_of_week,
    COUNT(*) as order_count,
    AVG(order_total) as avg_order_value
FROM (
    SELECT 
        o.order_date,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) as order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.order_date
) daily_orders
GROUP BY DAYOFWEEK(order_date), DAYNAME(order_date)
ORDER BY DAYOFWEEK(order_date);

-- 8. Monthly seasonal patterns
SELECT 
    MONTHNAME(order_date) as month,
    COUNT(DISTINCT order_id) as orders,
    SUM(order_total) as revenue,
    AVG(order_total) as avg_order_value
FROM (
    SELECT 
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) as order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.order_date
) monthly_orders
GROUP BY MONTH(order_date), MONTHNAME(order_date)
ORDER BY MONTH(order_date);

-- Save results to analyze trends and patterns
-- These queries provide foundation for deeper analysis in subsequent files