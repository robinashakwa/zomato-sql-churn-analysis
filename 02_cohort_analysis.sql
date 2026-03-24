-- ============================================================
-- ANALYSIS 1: COHORT ANALYSIS
-- Business Question: Of users who first ordered in Month X,
--                    how many came back in subsequent months?
-- Technique: First-order cohort + month-over-month retention
-- ============================================================

USE zomato_analysis;

-- ─────────────────────────────────────────────
-- STEP 1: Find each customer's first order month (cohort assignment)
-- ─────────────────────────────────────────────
WITH first_orders AS (
    SELECT
        customer_id,
        MIN(order_date)                              AS first_order_date,
        DATE_FORMAT(MIN(order_date), '%Y-%m')        AS cohort_month
    FROM orders
    GROUP BY customer_id
),

-- ─────────────────────────────────────────────
-- STEP 2: For every order, calculate how many months
--         after the cohort month that order was placed
-- ─────────────────────────────────────────────
order_cohort AS (
    SELECT
        o.customer_id,
        f.cohort_month,
        TIMESTAMPDIFF(MONTH, f.first_order_date, o.order_date) AS month_number
    FROM orders o
    JOIN first_orders f ON o.customer_id = f.customer_id
),

-- ─────────────────────────────────────────────
-- STEP 3: Count distinct active customers per cohort per month
-- ─────────────────────────────────────────────
cohort_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM order_cohort
    GROUP BY cohort_month, month_number
),

-- ─────────────────────────────────────────────
-- STEP 4: Get cohort size (month_number = 0 is always 100%)
-- ─────────────────────────────────────────────
cohort_size AS (
    SELECT cohort_month, active_customers AS total_customers
    FROM cohort_counts
    WHERE month_number = 0
)

-- ─────────────────────────────────────────────
-- FINAL: Retention rate by cohort x month
-- ─────────────────────────────────────────────
SELECT
    cc.cohort_month,
    cc.month_number,
    cc.active_customers,
    cs.total_customers                                                       AS cohort_size,
    ROUND(cc.active_customers * 100.0 / cs.total_customers, 1)              AS retention_pct
FROM cohort_counts cc
JOIN cohort_size cs ON cc.cohort_month = cs.cohort_month
WHERE cc.cohort_month BETWEEN '2023-01' AND '2024-06'   -- focus on cohorts with follow-up data
  AND cc.month_number <= 6                               -- track 6 months post-acquisition
ORDER BY cc.cohort_month, cc.month_number;

-- ─────────────────────────────────────────────
-- INSIGHT QUERY: Which cohort had the WORST 3-month retention?
-- ─────────────────────────────────────────────
WITH first_orders AS (
    SELECT customer_id, MIN(order_date) AS first_order_date,
           DATE_FORMAT(MIN(order_date), '%Y-%m') AS cohort_month
    FROM orders GROUP BY customer_id
),
order_cohort AS (
    SELECT o.customer_id, f.cohort_month,
           TIMESTAMPDIFF(MONTH, f.first_order_date, o.order_date) AS month_number
    FROM orders o JOIN first_orders f ON o.customer_id = f.customer_id
),
cohort_counts AS (
    SELECT cohort_month, month_number, COUNT(DISTINCT customer_id) AS active_customers
    FROM order_cohort GROUP BY cohort_month, month_number
),
cohort_size AS (
    SELECT cohort_month, active_customers AS total_customers
    FROM cohort_counts WHERE month_number = 0
)
SELECT
    cc.cohort_month,
    cs.total_customers                                          AS cohort_size,
    cc.active_customers                                         AS retained_at_month_3,
    ROUND(cc.active_customers * 100.0 / cs.total_customers, 1) AS retention_pct_month3
FROM cohort_counts cc
JOIN cohort_size cs ON cc.cohort_month = cs.cohort_month
WHERE cc.month_number = 3
ORDER BY retention_pct_month3 ASC
LIMIT 5;
