-- analysis/customer_segmentation.sql
-- RFM Customer Segmentation Analysis

USE northwestern_commerce;

-- =============================================================================
-- CREATE RFM SCORES (materialized as a temp table)
-- =============================================================================

DROP TEMPORARY TABLE IF EXISTS rfm_scores;

CREATE TEMPORARY TABLE rfm_scores AS
WITH order_items_net AS (
    SELECT 
        oi.order_id,
        o.customer_id,
        (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
),
customer_metrics AS (
    SELECT 
        c.customer_id,
        c.email,
        c.first_name,
        c.last_name,
        c.registration_date,
        DATEDIFF(CURRENT_DATE, MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        COALESCE(SUM(oin.net_revenue), 0) AS monetary_value,
        COALESCE(AVG(oin.net_revenue), 0) AS avg_order_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'Completed'
    LEFT JOIN order_items_net oin ON o.order_id = oin.order_id
    GROUP BY c.customer_id, c.email, c.first_name, c.last_name, c.registration_date
)
SELECT 
    cm.*,
    NTILE(5) OVER (ORDER BY recency_days ASC) AS recency_score,    -- more recent = higher score
    NTILE(5) OVER (ORDER BY frequency DESC) AS frequency_score,    -- higher frequency = higher score
    NTILE(5) OVER (ORDER BY monetary_value DESC) AS monetary_score -- higher monetary = higher score
FROM customer_metrics cm
WHERE monetary_value > 0;

-- =============================================================================
-- 1. Detailed Segmentation Table
-- =============================================================================

SELECT 
    *,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_segment,
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score >= 4 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'New Customers'
        WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score <= 3 THEN 'Potential Loyalists'
        WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'Cannot Lose Them'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score <= 2 THEN 'Need Attention'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Lost Customers'
        ELSE 'Others'
    END AS customer_segment
FROM rfm_scores
ORDER BY monetary_value DESC;

-- =============================================================================
-- 2. Summary Metrics by Segment
-- =============================================================================

WITH segmentation AS (
    SELECT 
        *,
        CASE 
            WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
            WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
            WHEN recency_score >= 4 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'New Customers'
            WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score <= 3 THEN 'Potential Loyalists'
            WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'At Risk'
            WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'Cannot Lose Them'
            WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score <= 2 THEN 'Need Attention'
            WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Lost Customers'
            ELSE 'Others'
        END AS customer_segment
    FROM rfm_scores
)
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    AVG(recency_days) AS avg_recency,
    AVG(frequency) AS avg_frequency,
    AVG(monetary_value) AS avg_monetary_value,
    SUM(monetary_value) AS total_revenue,
    AVG(avg_order_value) AS avg_order_value
FROM segmentation
GROUP BY customer_segment
ORDER BY total_revenue DESC;
