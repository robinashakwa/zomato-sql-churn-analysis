-- ============================================================
-- ANALYSIS 5: RFM SEGMENTATION
-- Business Question: Who are our best customers?
--                    Who is about to leave? Who do we win back?
-- Technique: Recency + Frequency + Monetary scoring via CTEs
-- RFM Score: Each dimension scored 1–5, combined into segment label
-- ============================================================

USE zomato_analysis;

-- ─────────────────────────────────────────────
-- STEP 1: Compute raw RFM values per customer
-- Reference date: 2025-01-01
-- ─────────────────────────────────────────────
WITH rfm_base AS (
    SELECT
        customer_id,
        DATEDIFF('2025-01-01', MAX(order_date))     AS recency_days,    -- lower = better
        COUNT(*)                                     AS frequency,       -- higher = better
        ROUND(SUM(order_value), 2)                   AS monetary         -- higher = better
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),

-- ─────────────────────────────────────────────
-- STEP 2: Score each dimension 1–5 using NTILE
--         NTILE splits into 5 equal buckets
--         Recency: reversed (lower days = higher score)
-- ─────────────────────────────────────────────
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,   -- DESC so recent = 5
        NTILE(5) OVER (ORDER BY frequency ASC)       AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)        AS m_score
    FROM rfm_base
),

-- ─────────────────────────────────────────────
-- STEP 3: Combine into RFM string and total score
-- ─────────────────────────────────────────────
rfm_combined AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CONCAT(r_score, f_score, m_score)            AS rfm_code,
        (r_score + f_score + m_score)                AS rfm_total
    FROM rfm_scores
),

-- ─────────────────────────────────────────────
-- STEP 4: Map RFM score to business segment labels
-- ─────────────────────────────────────────────
rfm_segmented AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        rfm_code,
        rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score <= 2 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Cannot Lose Them'
            WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost / Churned'
            WHEN r_score = 3  AND f_score <= 2                  THEN 'Promising'
            ELSE                                                     'Need Attention'
        END AS rfm_segment
    FROM rfm_combined
)

-- ─────────────────────────────────────────────
-- FINAL OUTPUT 1: Full customer RFM table
-- ─────────────────────────────────────────────
SELECT
    s.customer_id,
    c.username,
    c.city_area,
    s.recency_days,
    s.frequency,
    ROUND(s.monetary, 0)   AS monetary,
    s.r_score,
    s.f_score,
    s.m_score,
    s.rfm_code,
    s.rfm_total,
    s.rfm_segment
FROM rfm_segmented s
JOIN customers c ON s.customer_id = c.customer_id
ORDER BY s.rfm_total DESC;

-- ─────────────────────────────────────────────
-- FINAL OUTPUT 2: Segment summary — how many in each bucket?
-- ─────────────────────────────────────────────
WITH rfm_base AS (
    SELECT customer_id,
           DATEDIFF('2025-01-01', MAX(order_date)) AS recency_days,
           COUNT(*) AS frequency,
           SUM(order_value) AS monetary
    FROM orders WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT customer_id, recency_days, frequency, monetary,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
           NTILE(5) OVER (ORDER BY monetary ASC)        AS m_score
    FROM rfm_base
),
rfm_segmented AS (
    SELECT customer_id, recency_days, frequency, monetary,
           r_score, f_score, m_score,
           (r_score + f_score + m_score) AS rfm_total,
           CASE
               WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
               WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
               WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
               WHEN r_score >= 3 AND f_score >= 3 AND m_score <= 2 THEN 'Potential Loyalists'
               WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
               WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Cannot Lose Them'
               WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost / Churned'
               WHEN r_score = 3  AND f_score <= 2                  THEN 'Promising'
               ELSE                                                     'Need Attention'
           END AS rfm_segment
    FROM rfm_scores
)
SELECT
    rfm_segment,
    COUNT(*)                                                           AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)                AS pct_of_customers,
    ROUND(AVG(monetary), 0)                                            AS avg_revenue,
    ROUND(AVG(frequency), 1)                                           AS avg_orders,
    ROUND(AVG(recency_days), 0)                                        AS avg_days_since_last_order
FROM rfm_segmented
GROUP BY rfm_segment
ORDER BY avg_revenue DESC;

-- ─────────────────────────────────────────────
-- BONUS: Which city area has the most churned customers?
-- ─────────────────────────────────────────────
WITH rfm_base AS (
    SELECT customer_id,
           DATEDIFF('2025-01-01', MAX(order_date)) AS recency_days,
           COUNT(*) AS frequency,
           SUM(order_value) AS monetary
    FROM orders WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT customer_id,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
           NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM rfm_base
)
SELECT
    c.city_area,
    COUNT(*)                                                         AS total_customers,
    SUM(CASE WHEN r_score <= 2 AND f_score <= 2 THEN 1 ELSE 0 END)  AS churned_count,
    ROUND(SUM(CASE WHEN r_score <= 2 AND f_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS churn_pct
FROM rfm_scores rs
JOIN customers c ON rs.customer_id = c.customer_id
GROUP BY c.city_area
ORDER BY churn_pct DESC;
