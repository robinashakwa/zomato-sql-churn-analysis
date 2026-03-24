-- ============================================================
-- ANALYSIS 3: DELIVERY TIME vs RATING CORRELATION
-- Business Question: Does slower delivery hurt ratings?
--                    At what delivery time threshold do ratings drop?
-- Techniques: CASE binning, AVG, GROUP BY, subquery
-- ============================================================

USE zomato_analysis;

-- ─────────────────────────────────────────────
-- Bucket delivery times and see average rating per bucket
-- ─────────────────────────────────────────────
SELECT
    CASE
        WHEN delivery_time_mins <= 25 THEN '≤25 mins (Lightning Fast)'
        WHEN delivery_time_mins <= 35 THEN '26–35 mins (Fast)'
        WHEN delivery_time_mins <= 45 THEN '36–45 mins (Acceptable)'
        WHEN delivery_time_mins <= 55 THEN '46–55 mins (Slow)'
        ELSE                               '55+ mins (Very Slow)'
    END                          AS delivery_bucket,
    COUNT(*)                     AS order_count,
    ROUND(AVG(rating), 2)        AS avg_rating,
    ROUND(AVG(order_value), 2)   AS avg_order_value,
    MIN(delivery_time_mins)      AS min_delivery_time,
    MAX(delivery_time_mins)      AS max_delivery_time
FROM orders
WHERE order_status = 'Delivered'
  AND rating IS NOT NULL
GROUP BY delivery_bucket
ORDER BY MIN(delivery_time_mins);

-- ─────────────────────────────────────────────
-- Correlation: % of low ratings (< 3.5) per delivery bucket
-- ─────────────────────────────────────────────
SELECT
    CASE
        WHEN delivery_time_mins <= 25 THEN '≤25 mins'
        WHEN delivery_time_mins <= 35 THEN '26–35 mins'
        WHEN delivery_time_mins <= 45 THEN '36–45 mins'
        WHEN delivery_time_mins <= 55 THEN '46–55 mins'
        ELSE                               '55+ mins'
    END                                                               AS delivery_bucket,
    COUNT(*)                                                          AS total_orders,
    SUM(CASE WHEN rating < 3.5 THEN 1 ELSE 0 END)                    AS low_rating_orders,
    ROUND(SUM(CASE WHEN rating < 3.5 THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 1)                                              AS pct_low_ratings
FROM orders
WHERE order_status = 'Delivered' AND rating IS NOT NULL
GROUP BY delivery_bucket
ORDER BY MIN(delivery_time_mins);


-- ============================================================
-- ANALYSIS 4: RESTAURANT PERFORMANCE RANKING
-- Business Question: Which restaurants consistently deliver
--                    high value and good ratings?
-- Techniques: DENSE_RANK(), AVG, COUNT, HAVING, window functions
-- ============================================================

-- ─────────────────────────────────────────────
-- Restaurant scorecard with rankings
-- ─────────────────────────────────────────────
WITH restaurant_stats AS (
    SELECT
        restaurant_name,
        cuisine_type,
        COUNT(*)                                    AS total_orders,
        COUNT(DISTINCT customer_id)                 AS unique_customers,
        ROUND(AVG(order_value), 2)                  AS avg_order_value,
        ROUND(AVG(rating), 2)                       AS avg_rating,
        ROUND(AVG(delivery_time_mins), 1)           AS avg_delivery_time,
        SUM(order_value)                            AS total_revenue,
        SUM(CASE WHEN order_status = 'Cancelled'
                 THEN 1 ELSE 0 END)                 AS cancelled_orders,
        ROUND(SUM(CASE WHEN order_status = 'Cancelled'
                       THEN 1 ELSE 0 END) * 100.0
              / COUNT(*), 1)                        AS cancellation_rate_pct
    FROM orders
    GROUP BY restaurant_name, cuisine_type
    HAVING total_orders >= 20   -- only restaurants with enough data
)
SELECT
    restaurant_name,
    cuisine_type,
    total_orders,
    unique_customers,
    avg_order_value,
    avg_rating,
    avg_delivery_time,
    ROUND(total_revenue, 0)                                          AS total_revenue,
    cancellation_rate_pct,
    DENSE_RANK() OVER (ORDER BY avg_rating DESC)                     AS rank_by_rating,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC)                  AS rank_by_revenue,
    DENSE_RANK() OVER (ORDER BY avg_delivery_time ASC)               AS rank_by_speed,
    DENSE_RANK() OVER (ORDER BY cancellation_rate_pct ASC)          AS rank_by_reliability
FROM restaurant_stats
ORDER BY avg_rating DESC;

-- ─────────────────────────────────────────────
-- Top 5 restaurants by composite score
-- (equal weight: rating + speed + low cancellation)
-- ─────────────────────────────────────────────
WITH restaurant_stats AS (
    SELECT
        restaurant_name,
        cuisine_type,
        COUNT(*) AS total_orders,
        ROUND(AVG(order_value), 2) AS avg_order_value,
        ROUND(AVG(rating), 2) AS avg_rating,
        ROUND(AVG(delivery_time_mins), 1) AS avg_delivery_time,
        ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS cancellation_rate
    FROM orders GROUP BY restaurant_name, cuisine_type
    HAVING total_orders >= 20
),
ranked AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY avg_rating DESC)          AS r_rating,
        DENSE_RANK() OVER (ORDER BY avg_delivery_time ASC)    AS r_speed,
        DENSE_RANK() OVER (ORDER BY cancellation_rate ASC)    AS r_reliability
    FROM restaurant_stats
)
SELECT
    restaurant_name,
    cuisine_type,
    avg_rating,
    avg_delivery_time,
    cancellation_rate,
    (r_rating + r_speed + r_reliability)   AS composite_rank_score,
    DENSE_RANK() OVER (ORDER BY r_rating + r_speed + r_reliability ASC) AS overall_rank
FROM ranked
ORDER BY overall_rank
LIMIT 5;
