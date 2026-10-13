-- Intermediate SQL Portfolio Project: Retail Sales Analytics
-- Dialect: PostgreSQL 14+
-- Run from the project root. The \copy command reads the CSV on your computer.
-- Example: psql -U postgres -d retail_analytics -f sql/retail_sales_analysis.sql

-- Drop the view first: it depends on the table, so DROP TABLE fails on a re-run otherwise.
DROP VIEW IF EXISTS cleaned_retail_orders;
DROP TABLE IF EXISTS retail_orders;
CREATE TABLE retail_orders (
    order_id        VARCHAR(10) PRIMARY KEY,
    order_date      DATE,
    customer_id     VARCHAR(10),
    customer_name   TEXT,
    city            TEXT,
    product_id      VARCHAR(10),
    product_name    TEXT,
    category        TEXT,
    quantity        INTEGER,
    unit_price      NUMERIC(12,2),
    discount_pct    NUMERIC(5,2),
    order_total     NUMERIC(12,2),
    payment_method  TEXT,
    order_status    TEXT
);

-- Load the CSV. Run this script from the project root directory.
\copy retail_orders FROM 'data/retail_orders.csv' WITH (FORMAT csv, HEADER true);

-- 1. Data quality checks
SELECT COUNT(*) AS row_count,
       COUNT(DISTINCT order_id) AS unique_orders,
       COUNT(*) FILTER (WHERE order_date IS NULL) AS missing_order_dates,
       COUNT(*) FILTER (WHERE customer_id IS NULL OR TRIM(customer_id) = '') AS missing_customer_ids,
       COUNT(*) FILTER (WHERE quantity <= 0) AS invalid_quantities,
       COUNT(*) FILTER (WHERE unit_price < 0 OR order_total < 0) AS invalid_amounts
FROM retail_orders;

-- 2. Create a cleaned view: trim text, standardize city/category/status,
--    and recalculate the expected total for comparison.
CREATE OR REPLACE VIEW cleaned_retail_orders AS
SELECT
    order_id,
    order_date,
    NULLIF(TRIM(customer_id), '') AS customer_id,
    INITCAP(TRIM(customer_name)) AS customer_name,
    INITCAP(TRIM(city)) AS city,
    product_id,
    TRIM(product_name) AS product_name,
    INITCAP(TRIM(category)) AS category,
    quantity,
    unit_price,
    COALESCE(discount_pct, 0) AS discount_pct,
    order_total,
    quantity * unit_price * (1 - COALESCE(discount_pct, 0)) AS recalculated_total,
    TRIM(payment_method) AS payment_method,
    INITCAP(TRIM(order_status)) AS order_status
FROM retail_orders
WHERE order_id IS NOT NULL;

-- 3. Monthly revenue and month-over-month growth.
-- Only completed orders count as realized sales.
WITH monthly_sales AS (
    SELECT DATE_TRUNC('month', order_date)::date AS sales_month,
           COUNT(*) AS completed_orders,
           SUM(recalculated_total) AS revenue
    FROM cleaned_retail_orders
    WHERE order_status = 'Completed'
    GROUP BY 1
),
with_previous_month AS (
    SELECT sales_month, completed_orders, revenue,
           LAG(revenue) OVER (ORDER BY sales_month) AS previous_month_revenue
    FROM monthly_sales
)
SELECT sales_month, completed_orders, ROUND(revenue, 2) AS revenue,
       ROUND(previous_month_revenue, 2) AS previous_month_revenue,
       ROUND(100.0 * (revenue - previous_month_revenue)
             / NULLIF(previous_month_revenue, 0), 2) AS mom_growth_pct
FROM with_previous_month
ORDER BY sales_month;

-- 4. Best-performing product categories by revenue.
SELECT category,
       SUM(quantity) AS units_sold,
       COUNT(*) AS order_lines,
       ROUND(SUM(recalculated_total), 2) AS revenue,
       ROUND(100.0 * SUM(recalculated_total)
             / NULLIF(SUM(SUM(recalculated_total)) OVER (), 0), 2) AS revenue_share_pct
FROM cleaned_retail_orders
WHERE order_status = 'Completed'
GROUP BY category
ORDER BY revenue DESC;

-- 5. Rank products within each category using window functions.
WITH product_performance AS (
    SELECT category, product_name,
           SUM(quantity) AS units_sold,
           SUM(recalculated_total) AS revenue
    FROM cleaned_retail_orders
    WHERE order_status = 'Completed'
    GROUP BY category, product_name
)
SELECT category, product_name, units_sold, ROUND(revenue, 2) AS revenue,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS category_rank
FROM product_performance
ORDER BY category, category_rank;

-- 6. Customer lifetime value (completed-order revenue) and order frequency.
WITH customer_metrics AS (
    SELECT customer_id, MAX(customer_name) AS customer_name,
           MAX(city) AS city,
           COUNT(*) FILTER (WHERE order_status = 'Completed') AS completed_orders,
           SUM(recalculated_total) FILTER (WHERE order_status = 'Completed') AS lifetime_revenue,
           MAX(order_date) FILTER (WHERE order_status = 'Completed') AS most_recent_order
    FROM cleaned_retail_orders
    GROUP BY customer_id
)
SELECT customer_id, customer_name, city, completed_orders,
       ROUND(COALESCE(lifetime_revenue, 0), 2) AS lifetime_revenue,
       most_recent_order,
       DENSE_RANK() OVER (ORDER BY COALESCE(lifetime_revenue, 0) DESC) AS customer_value_rank
FROM customer_metrics
ORDER BY lifetime_revenue DESC NULLS LAST;

-- 7. RFM-style segmentation.
-- Recency = days since the latest completed order in the dataset.
-- Frequency = completed orders; Monetary = completed-order revenue.
WITH last_date AS (
    SELECT MAX(order_date) AS analysis_date
    FROM cleaned_retail_orders
    WHERE order_status = 'Completed'
),
rfm AS (
    SELECT o.customer_id,
           MAX(o.customer_name) AS customer_name,
           MAX(o.order_date) FILTER (WHERE o.order_status = 'Completed') AS last_order_date,
           COUNT(*) FILTER (WHERE o.order_status = 'Completed') AS frequency,
           SUM(o.recalculated_total) FILTER (WHERE o.order_status = 'Completed') AS monetary
    FROM cleaned_retail_orders o
    GROUP BY o.customer_id
)
SELECT r.customer_id, r.customer_name,
       (d.analysis_date - r.last_order_date) AS recency_days,
       r.frequency,
       ROUND(COALESCE(r.monetary, 0), 2) AS monetary_value,
       CASE
           WHEN r.last_order_date IS NULL THEN 'No completed purchases'
           WHEN d.analysis_date - r.last_order_date <= 60
                AND r.frequency >= 3 THEN 'Loyal / Active'
           WHEN d.analysis_date - r.last_order_date > 180 THEN 'At Risk'
           WHEN r.frequency = 1 THEN 'One-time Buyer'
           ELSE 'Regular Customer'
       END AS customer_segment
FROM rfm r
CROSS JOIN last_date d
ORDER BY monetary_value DESC;

-- 8. Payment method mix: order count and revenue share.
WITH payment_summary AS (
    SELECT payment_method,
           COUNT(*) AS completed_orders,
           SUM(recalculated_total) AS revenue
    FROM cleaned_retail_orders
    WHERE order_status = 'Completed'
    GROUP BY payment_method
)
SELECT payment_method, completed_orders,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (), 0), 2) AS revenue_share_pct
FROM payment_summary
ORDER BY revenue DESC;

-- 9. Return/cancellation rate by category.
SELECT category,
       COUNT(*) AS all_orders,
       COUNT(*) FILTER (WHERE order_status = 'Returned') AS returned_orders,
       COUNT(*) FILTER (WHERE order_status = 'Cancelled') AS cancelled_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_status IN ('Returned','Cancelled'))
             / NULLIF(COUNT(*), 0), 2) AS return_cancel_rate_pct
FROM cleaned_retail_orders
GROUP BY category
ORDER BY return_cancel_rate_pct DESC;

-- 10. Reconciliation: flag rows where stored and recalculated totals differ.
SELECT order_id, order_total, ROUND(recalculated_total, 2) AS recalculated_total,
       ROUND(order_total - recalculated_total, 2) AS difference
FROM cleaned_retail_orders
WHERE ABS(order_total - recalculated_total) > 0.01
ORDER BY ABS(order_total - recalculated_total) DESC;
