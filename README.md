# 🍽️ Why Do Customers Churn? — Zomato Delivery Behavior Analysis

**Tools:** MySQL 8.0 | CTEs | Window Functions | RFM Segmentation  
**Domain:** Food Delivery / Customer Analytics  
**Dataset:** Simulated Bengaluru food delivery data — 500 customers, ~4,400 orders, 20 restaurants (Jan 2023 – Dec 2024)

---

## 📌 Business Problem

Most food delivery analytics stops at "how many orders did we get?"  
This project goes deeper — it answers the question every product and growth team actually cares about:

> **Who is churning, when did they start slipping, and why?**

---

## 📂 Project Structure

```
zomato_sql_project/
│
├── data/
│   ├── customers.csv          # 500 customers with area and registration date
│   ├── restaurants.csv        # 20 Bengaluru restaurants with cuisine and rating
│   └── orders.csv             # ~4,400 orders with delivery time, rating, status
│
├── 01_schema_and_data.sql     # Table creation + data load
├── 02_cohort_analysis.sql     # Monthly retention cohort grid
├── 03_churn_flagging.sql      # LAG/LEAD-based churn classification
├── 04_delivery_rating_and_restaurant_ranking.sql
├── 05_rfm_segmentation.sql    # Full RFM scoring + segment labels
└── README.md
```

---

## 🔍 Analyses Performed

### 1. Cohort Retention Analysis
Grouped customers by their **first order month** and tracked how many returned in months 1–6.  
Identified cohorts with <30% retention at month 3 — flagged for campaign targeting.

**Key SQL:** `MIN(order_date)`, `TIMESTAMPDIFF`, `DATE_FORMAT`, multi-step CTEs

---

### 2. Churn Flagging with Window Functions
Used `LAG()` to calculate gaps between consecutive orders per customer.  
Classified every customer into: **Active / At Risk / Lapsing / Churned** based on days since last order.

**Key SQL:** `LAG()`, `LEAD()`, `DATEDIFF()`, `PARTITION BY`, `CASE WHEN`

---

### 3. Delivery Time vs. Rating Correlation
Bucketed delivery times (≤25 / 26–35 / 36–45 / 46–55 / 55+ mins) and calculated average rating per bucket.  
Found that orders taking **55+ minutes** have **~35% more low ratings** than orders under 35 minutes.

**Key SQL:** `CASE` binning, `AVG`, `GROUP BY`, percentage calculation

---

### 4. Restaurant Performance Ranking
Built a full restaurant scorecard using `DENSE_RANK()` across four dimensions:  
rating, revenue, delivery speed, and cancellation rate.  
Combined into a **composite rank score** to identify the overall best-performing restaurant.

**Key SQL:** `DENSE_RANK()`, `HAVING`, multiple window functions, composite scoring

---

### 5. RFM Segmentation
Scored every customer on **Recency, Frequency, Monetary** value using `NTILE(5)`.  
Mapped combined scores to 8 business segments: Champions, Loyal, At Risk, Cannot Lose Them, Lost/Churned, etc.

**Key SQL:** `NTILE()`, `CONCAT()`, multi-CTE pipeline, segment CASE logic

---

## 💡 Key Insights

| Insight | Finding |
|---|---|
| Churn rate | ~38% of customers classified as Lapsing or Churned |
| Worst retention cohort | Cohorts from mid-2023 showed <28% month-3 retention |
| Delivery time impact | Ratings drop by avg 0.6 stars for deliveries over 55 mins |
| Top restaurant | Vidyarthi Bhavan ranked #1 on composite score (rating + speed + reliability) |
| Highest churn area | Electronic City had the highest % of churned customers |

---

## ▶️ How to Run

1. Install MySQL 8.0+
2. Open MySQL Workbench or any SQL client
3. Run `01_schema_and_data.sql` to create tables and load data
4. Run analysis files `02` through `05` in order

> **Tip:** If `LOAD DATA LOCAL INFILE` is blocked, use MySQL Workbench's Table Data Import Wizard to load the CSVs directly.

---

## 🛠️ Skills Demonstrated

- Multi-step CTEs for complex aggregations
- Window functions: `LAG`, `LEAD`, `DENSE_RANK`, `NTILE`, `ROW_NUMBER`
- Cohort analysis from scratch (no external libraries)
- RFM customer segmentation framework
- Business-framed SQL — every query answers a real question

---

*Built as part of a data analyst portfolio. Dataset is simulated but designed to reflect real Bengaluru food delivery patterns.*
