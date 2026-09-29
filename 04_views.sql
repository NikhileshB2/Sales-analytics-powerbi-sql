-- =====================================================================
-- 04_views.sql  |  Reporting views (Power BI can import these directly)
-- =====================================================================

-- Flat, denormalised view: one row per order with every label attached
CREATE VIEW vw_sales_flat AS
SELECT
    f.order_id,
    d.full_date        AS order_date,
    d.year, d.quarter_name, d.month_num, d.month_name, d.year_month, d.day_name, d.is_weekend,
    r.region_name      AS region,
    ch.channel_name    AS sales_channel,
    f.customer_type,
    p.category         AS product_category,
    p.product_name     AS product,
    p.price_tier,
    sp.salesperson_name AS salesperson,
    f.quantity, f.unit_price, f.discount_pct, f.discount_band,
    f.gross_revenue, f.discount_amount, f.net_revenue
FROM fact_sales f
JOIN dim_date        d  ON d.date_key        = f.date_key
JOIN dim_product     p  ON p.product_key     = f.product_key
JOIN dim_salesperson sp ON sp.salesperson_key = f.salesperson_key
JOIN dim_region      r  ON r.region_key      = f.region_key
JOIN dim_channel     ch ON ch.channel_key    = f.channel_key;

-- Monthly summary with month-over-month growth
CREATE VIEW vw_monthly_summary AS
WITH m AS (
    SELECT d.year_month,
           d.month_short,
           COUNT(*)                AS orders,
           SUM(f.quantity)         AS units,
           SUM(f.net_revenue)      AS revenue,
           SUM(f.discount_amount)  AS discount_given
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.year_month, d.month_short
)
SELECT year_month, month_short, orders, units,
       ROUND(revenue, 2)        AS revenue,
       ROUND(discount_given, 2) AS discount_given,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year_month))
             / LAG(revenue) OVER (ORDER BY year_month), 1) AS mom_growth_pct
FROM m;
