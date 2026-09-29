-- =====================================================================
-- 02_data_quality_checks.sql  |  Run against stg_sales BEFORE modelling
-- severity ERROR = must be 0 to proceed; INFO = worth knowing, not blocking
-- =====================================================================
SELECT 'Row count' AS check_name, COUNT(*) AS issues_found, 'INFO' AS severity FROM stg_sales
UNION ALL
SELECT 'Duplicate order IDs', COUNT(*) - COUNT(DISTINCT order_id), 'ERROR' FROM stg_sales
UNION ALL
SELECT 'Null / blank key fields', COUNT(*), 'ERROR' FROM stg_sales
WHERE order_id IS NULL OR TRIM(order_id) = '' OR order_date IS NULL
   OR region IS NULL OR sales_channel IS NULL OR customer_type IS NULL
   OR product_category IS NULL OR product IS NULL OR salesperson IS NULL
UNION ALL
SELECT 'Quantity or unit price <= 0', COUNT(*), 'ERROR' FROM stg_sales
WHERE quantity <= 0 OR unit_price <= 0
UNION ALL
SELECT 'Discount outside 0-100%', COUNT(*), 'ERROR' FROM stg_sales
WHERE discount < 0 OR discount > 1
UNION ALL
-- Unit prices are stored to 2 decimals, so each unit can be off by up to half a cent.
-- Tolerance therefore scales with quantity: 0.5 cent per unit + 1 cent for final rounding.
SELECT 'Revenue differs from qty x price x (1 - discount) beyond rounding tolerance', COUNT(*), 'ERROR' FROM stg_sales
WHERE ABS(revenue - quantity * unit_price * (1 - discount)) > 0.005 * quantity + 0.01
UNION ALL
SELECT 'Revenue differs by a few cents (price rounding, within tolerance)', COUNT(*), 'INFO' FROM stg_sales
WHERE ABS(revenue - quantity * unit_price * (1 - discount)) > 0.005
  AND ABS(revenue - quantity * unit_price * (1 - discount)) <= 0.005 * quantity + 0.01
UNION ALL
SELECT 'Salesperson working in more than one region', COUNT(*), 'INFO' FROM (
    SELECT salesperson FROM stg_sales GROUP BY salesperson HAVING COUNT(DISTINCT region) > 1
) t
UNION ALL
SELECT 'Product mapped to more than one category', COUNT(*), 'ERROR' FROM (
    SELECT product FROM stg_sales GROUP BY product HAVING COUNT(DISTINCT product_category) > 1
) t;
