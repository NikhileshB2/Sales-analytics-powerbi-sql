-- =====================================================================
-- 05_business_analysis.sql  |  Business questions answered in SQL
-- Each query is separated by a "-- Q<n>" header so the runner can split it.
-- Skills shown: aggregation, CTEs, window functions, CASE pivots, ranking
-- =====================================================================

-- Q1: Headline KPIs
SELECT COUNT(*)                                   AS total_orders,
       SUM(quantity)                              AS units_sold,
       ROUND(SUM(net_revenue), 2)                 AS net_revenue,
       ROUND(SUM(gross_revenue), 2)               AS gross_revenue,
       ROUND(SUM(discount_amount), 2)             AS discount_given,
       ROUND(100.0 * SUM(discount_amount) / SUM(gross_revenue), 2) AS discount_rate_pct,
       ROUND(SUM(net_revenue) / COUNT(*), 2)      AS avg_order_value
FROM fact_sales;

-- Q2: Monthly revenue, MoM growth and running total
SELECT year_month, orders, revenue, mom_growth_pct,
       ROUND(SUM(revenue) OVER (ORDER BY year_month), 2) AS running_total
FROM vw_monthly_summary
ORDER BY year_month;

-- Q3: Revenue and share by product category
SELECT p.category,
       COUNT(*)                           AS orders,
       SUM(f.quantity)                    AS units,
       ROUND(SUM(f.net_revenue), 2)       AS revenue,
       ROUND(100.0 * SUM(f.net_revenue) / SUM(SUM(f.net_revenue)) OVER (), 1) AS revenue_share_pct,
       RANK() OVER (ORDER BY SUM(f.net_revenue) DESC) AS revenue_rank
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY revenue DESC;

-- Q4: Top 10 products with cumulative share (Pareto)
WITH prod AS (
    SELECT p.product_name, p.category,
           SUM(f.net_revenue) AS revenue,
           SUM(f.quantity)    AS units
    FROM fact_sales f
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY p.product_name, p.category
)
SELECT product_name, category, ROUND(revenue, 2) AS revenue, units,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 1) AS cumulative_share_pct
FROM prod
ORDER BY revenue DESC
LIMIT 10;

-- Q5: Region performance
SELECT r.region_name,
       COUNT(*)                       AS orders,
       ROUND(SUM(f.net_revenue), 2)   AS revenue,
       ROUND(AVG(f.net_revenue), 2)   AS avg_order_value,
       ROUND(100.0 * SUM(f.net_revenue) / SUM(SUM(f.net_revenue)) OVER (), 1) AS revenue_share_pct,
       ROUND(100.0 * SUM(f.discount_amount) / SUM(f.gross_revenue), 2)        AS discount_rate_pct
FROM fact_sales f
JOIN dim_region r ON r.region_key = f.region_key
GROUP BY r.region_name
ORDER BY revenue DESC;

-- Q6: Channel x customer type mix
SELECT ch.channel_name,
       ROUND(SUM(CASE WHEN f.customer_type = 'New'       THEN f.net_revenue END), 2) AS new_customer_revenue,
       ROUND(SUM(CASE WHEN f.customer_type = 'Returning' THEN f.net_revenue END), 2) AS returning_revenue,
       ROUND(SUM(f.net_revenue), 2)                                                   AS total_revenue,
       ROUND(100.0 * SUM(CASE WHEN f.customer_type = 'Returning' THEN f.net_revenue END)
             / SUM(f.net_revenue), 1)                                                 AS returning_share_pct
FROM fact_sales f
JOIN dim_channel ch ON ch.channel_key = f.channel_key
GROUP BY ch.channel_name
ORDER BY total_revenue DESC;

-- Q7: Salesperson leaderboard with rank overall and within region
SELECT sp.salesperson_name,
       r.region_name,
       COUNT(*)                     AS orders,
       ROUND(SUM(f.net_revenue), 2) AS revenue,
       ROUND(AVG(f.net_revenue), 2) AS avg_order_value,
       RANK() OVER (ORDER BY SUM(f.net_revenue) DESC)                                AS overall_rank,
       RANK() OVER (PARTITION BY r.region_name ORDER BY SUM(f.net_revenue) DESC)     AS rank_in_region
FROM fact_sales f
JOIN dim_salesperson sp ON sp.salesperson_key = f.salesperson_key
JOIN dim_region      r  ON r.region_key       = f.region_key
GROUP BY sp.salesperson_name, r.region_name
ORDER BY overall_rank;

-- Q8: Does discounting pay off? Discount band analysis
SELECT discount_band,
       COUNT(*)                          AS orders,
       ROUND(AVG(quantity), 2)           AS avg_units_per_order,
       ROUND(AVG(net_revenue), 2)        AS avg_order_value,
       ROUND(SUM(net_revenue), 2)        AS revenue,
       ROUND(SUM(discount_amount), 2)    AS discount_given
FROM fact_sales
GROUP BY discount_band, discount_band_order
ORDER BY discount_band_order;

-- Q9: Quarterly revenue by category (CASE pivot)
SELECT p.category,
       ROUND(SUM(CASE WHEN d.quarter = 1 THEN f.net_revenue ELSE 0 END), 0) AS q1,
       ROUND(SUM(CASE WHEN d.quarter = 2 THEN f.net_revenue ELSE 0 END), 0) AS q2,
       ROUND(SUM(CASE WHEN d.quarter = 3 THEN f.net_revenue ELSE 0 END), 0) AS q3,
       ROUND(SUM(CASE WHEN d.quarter = 4 THEN f.net_revenue ELSE 0 END), 0) AS q4
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
JOIN dim_date    d ON d.date_key    = f.date_key
GROUP BY p.category
ORDER BY p.category;

-- Q10: Category mix inside each region (window over partition)
SELECT r.region_name, p.category,
       ROUND(SUM(f.net_revenue), 0) AS revenue,
       ROUND(100.0 * SUM(f.net_revenue) / SUM(SUM(f.net_revenue)) OVER (PARTITION BY r.region_name), 1) AS pct_of_region
FROM fact_sales f
JOIN dim_region  r ON r.region_key  = f.region_key
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY r.region_name, p.category
ORDER BY r.region_name, revenue DESC;

-- Q11: Large orders - more than 3x the average order value
WITH avg_order AS (SELECT AVG(net_revenue) AS aov FROM fact_sales)
SELECT COUNT(*)                                                    AS large_orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_sales), 1) AS pct_of_orders,
       ROUND(100.0 * SUM(net_revenue) / (SELECT SUM(net_revenue) FROM fact_sales), 1) AS pct_of_revenue
FROM fact_sales, avg_order
WHERE net_revenue > 3 * avg_order.aov;

-- Q12: Weekday vs weekend pattern
SELECT d.day_name, d.day_of_week,
       COUNT(*) AS orders,
       ROUND(SUM(f.net_revenue), 0) AS revenue
FROM fact_sales f
JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.day_name, d.day_of_week
ORDER BY d.day_of_week;
