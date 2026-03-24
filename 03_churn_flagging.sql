-- ============================================================
-- ANALYSIS 2: CHURN FLAGGING USING WINDOW FUNCTIONS
-- Business Question: Which customers have gone silent?
--                    Flag churned users based on order gap > 60 days
-- Techniques: LAG(), LEAD(), DATEDIFF(), CASE
-- ============================================================

USE zomato_analysis;

-- ─────────────────────────────────────────────
-- STEP 1: For each order, get the PREVIOUS and NEXT order date
--         per customer using LAG and LEAD
-- ─────────────────────────────────────────────
WITH order_gaps AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        order_value,
        LAG(order_date)  OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date,
        LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order_date,
        ROW_NUMBER()     OVER (PARTITION BY customer_id ORDER BY order_date) AS order_seq,
        COUNT(*)         OVER (PARTITION BY customer_id)                     AS total_orders
    FROM orders
    WHERE order_status = 'Delivered'
),

-- ─────────────────────────────────────────────
-- STEP 2: Calculate gap from previous order
--         Flag the order as a churn-risk gap if > 60 days
-- ─────────────────────────────────────────────
gap_flags AS (
    SELECT
        customer_id,
        order_date,
        prev_order_date,
        next_order_date,
        DATEDIFF(order_date, prev_order_date)       AS days_since_last_order,
        DATEDIFF(next_order_date, order_date)       AS days_to_next_order,
        total_orders,
        CASE
            WHEN DATEDIFF(order_date, prev_order_date) > 60 THEN 'Long Gap — Returning User'
            WHEN prev_order_date IS NULL                    THEN 'First Order'
            ELSE 'Regular Order'
        END AS order_event_type
    FROM order_gaps
),

-- ─────────────────────────────────────────────
-- STEP 3: Classify each customer's churn status
--         based on their last order date vs. today (2025-01-01 as reference)
-- ─────────────────────────────────────────────
customer_last_order AS (
    SELECT
        customer_id,
        MAX(order_date)                                 AS last_order_date,
        COUNT(*)                                        AS total_orders,
        DATEDIFF('2025-01-01', MAX(order_date))         AS days_since_last_order
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)

-- ─────────────────────────────────────────────
-- FINAL: Customer-level churn classification
-- ─────────────────────────────────────────────
SELECT
    c.customer_id,
    c.username,
    c.city_area,
    cl.last_order_date,
    cl.total_orders,
    cl.days_since_last_order,
    CASE
        WHEN cl.days_since_last_order <= 30  THEN '🟢 Active'
        WHEN cl.days_since_last_order <= 60  THEN '🟡 At Risk'
        WHEN cl.days_since_last_order <= 120 THEN '🟠 Lapsing'
        ELSE                                      '🔴 Churned'
    END AS churn_status
FROM customer_last_order cl
JOIN customers c ON cl.customer_id = c.customer_id
ORDER BY cl.days_since_last_order DESC;

-- ─────────────────────────────────────────────
-- SUMMARY: How many customers in each churn bucket?
-- ─────────────────────────────────────────────
WITH customer_last_order AS (
    SELECT
        customer_id,
        MAX(order_date)                         AS last_order_date,
        DATEDIFF('2025-01-01', MAX(order_date)) AS days_since_last_order
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
),
churn_classified AS (
    SELECT
        CASE
            WHEN days_since_last_order <= 30  THEN 'Active'
            WHEN days_since_last_order <= 60  THEN 'At Risk'
            WHEN days_since_last_order <= 120 THEN 'Lapsing'
            ELSE                                   'Churned'
        END AS churn_status
    FROM customer_last_order
)
SELECT
    churn_status,
    COUNT(*)                               AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM churn_classified
GROUP BY churn_status
ORDER BY FIELD(churn_status, 'Active', 'At Risk', 'Lapsing', 'Churned');

-- ─────────────────────────────────────────────
-- BONUS: Customers who returned after a long gap (> 60 days)
--        These are "win-back" success stories
-- ─────────────────────────────────────────────
WITH ordered AS (
    SELECT customer_id, order_date,
           LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_date
    FROM orders WHERE order_status = 'Delivered'
)
SELECT
    customer_id,
    order_date          AS return_date,
    prev_date           AS last_order_before_gap,
    DATEDIFF(order_date, prev_date) AS gap_days
FROM ordered
WHERE DATEDIFF(order_date, prev_date) > 60
ORDER BY gap_days DESC
LIMIT 10;
