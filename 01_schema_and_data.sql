-- ============================================================
-- PROJECT  : Why Do Customers Churn? — Zomato Delivery Behavior Analysis
-- Author   : Robina
-- Database : MySQL 8.0+
-- Dataset  : Simulated Bengaluru food delivery data (500 customers, ~4,400 orders)
-- ============================================================

CREATE DATABASE IF NOT EXISTS zomato_analysis;
USE zomato_analysis;

-- ─────────────────────────────────────────────
-- TABLE 1: customers
-- ─────────────────────────────────────────────
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id       INT PRIMARY KEY,
    username          VARCHAR(50),
    email             VARCHAR(100),
    city_area         VARCHAR(50),
    registration_date DATE
);

-- ─────────────────────────────────────────────
-- TABLE 2: restaurants
-- ─────────────────────────────────────────────
DROP TABLE IF EXISTS restaurants;
CREATE TABLE restaurants (
    restaurant_id   INT PRIMARY KEY,
    restaurant_name VARCHAR(100),
    area            VARCHAR(50),
    cuisine_type    VARCHAR(50),
    avg_rating      DECIMAL(3,1)
);

-- ─────────────────────────────────────────────
-- TABLE 3: orders
-- ─────────────────────────────────────────────
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id            INT PRIMARY KEY,
    customer_id         INT,
    restaurant_name     VARCHAR(100),
    order_date          DATE,
    order_value         DECIMAL(8,2),
    delivery_time_mins  INT,
    rating              DECIMAL(2,1),       -- NULL if cancelled/delayed
    cuisine_type        VARCHAR(50),
    order_status        VARCHAR(20),        -- Delivered / Cancelled / Delayed
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- ─────────────────────────────────────────────
-- LOAD DATA (adjust path to your local CSV location)
-- If using MySQL Workbench, use the Table Import Wizard instead
-- ─────────────────────────────────────────────
LOAD DATA LOCAL INFILE 'customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'restaurants.csv'
INTO TABLE restaurants
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, restaurant_name, order_date, order_value,
 delivery_time_mins, @rating, cuisine_type, order_status)
SET rating = NULLIF(@rating, '');

-- ─────────────────────────────────────────────
-- QUICK SANITY CHECK
-- ─────────────────────────────────────────────
SELECT 'customers' AS tbl, COUNT(*) AS records FROM customers
UNION ALL
SELECT 'restaurants', COUNT(*) FROM restaurants
UNION ALL
SELECT 'orders', COUNT(*) FROM orders;
