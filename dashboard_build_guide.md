# Power BI Build Guide (about 60-90 minutes)

You need **Power BI Desktop** (free, Windows). Everything below uses the files already in this repo.

## 1. Load the data
1. `Home > Get data > Text/CSV`, then load these six files from `data/processed/`:
   `fact_sales.csv`, `dim_date.csv`, `dim_product.csv`, `dim_salesperson.csv`, `dim_region.csv`, `dim_channel.csv`
   (choose **Transform Data** so you can set types).
2. In Power Query set data types:
   - `dim_date[full_date]` -> **Date**
   - all `*_key`, `quantity`, `year`, `month_num` -> **Whole number**
   - `net_revenue`, `gross_revenue`, `discount_amount`, `unit_price` -> **Fixed decimal number**
   - `discount_pct` -> **Decimal number**
3. **Close & Apply.**

> Using a real database instead? Run `sql/01_schema.sql`, `03_build_star_schema.sql`, `04_views.sql` on SQL Server / PostgreSQL / MySQL (see dialect notes in the README) and use `Get data > SQL Server` (or PostgreSQL/MySQL) on the tables. Everything after this step is identical.

## 2. Build the data model (Model view)
Create these **many-to-one, single-direction** relationships (dimension -> fact):

| From (dimension, "one") | To (fact, "many") |
|---|---|
| dim_date[date_key] | fact_sales[date_key] |
| dim_product[product_key] | fact_sales[product_key] |
| dim_salesperson[salesperson_key] | fact_sales[salesperson_key] |
| dim_region[region_key] | fact_sales[region_key] |
| dim_channel[channel_key] | fact_sales[channel_key] |

Then:
- `dim_date` > **Mark as date table** > choose `full_date`.
- **Sort by column** (Column tools): `month_short` by `month_num`, `month_name` by `month_num`, `day_name` by `day_of_week`, `fact_sales[discount_band]` by `discount_band_order`.
- Hide the key columns and the raw numeric columns in the fact table so report users only see measures.

## 3. Add measures
`Home > Enter data` > create an empty table named `_Measures`, then add every measure from [`dax_measures.dax`](dax_measures.dax) (`Table tools > New measure`). Format: revenue measures as currency (0 decimals), percentages as `0.0%`.

## 4. Apply the theme
`View > Themes > Browse for themes` > select [`theme.json`](theme.json). Set the canvas to **16:9 (1280 x 720)** under `Format page > Page size`.
(If Power BI rejects the theme, open the file and delete the `visualStyles` block; the colours will still load.)

## 5. Pages and visuals
Positions are for a 1280 x 720 canvas: X, Y, width x height.

### Page 1 - Executive Overview
| Visual | Fields | Position |
|---|---|---|
| Header text box | "Sales Performance Dashboard" (navy #0B1F3A fill, white text) | 0,0 1280x56 |
| Slicers (tile/dropdown) | dim_date[quarter_name], dim_region[region_name], dim_channel[channel_name], fact_sales[customer_type] | 20,64 (4 x 300x40) |
| 5 x Card | [Total Revenue], [Total Orders], [Avg Order Value], [Units Sold], [Discount Rate %] | y=116, 240x88, x = 20/270/520/770/1020 |
| Line chart (area optional) | X: dim_date[month_short]; Y: [Total Revenue]; tooltip: [MoM Growth %] | 20,216 620x240 |
| Bar chart | Y: dim_product[category]; X: [Total Revenue] (sort desc) | 650,216 300x240 |
| Donut | Legend: dim_channel[channel_name]; Values: [Total Revenue] | 960,216 300x240 |
| Column chart | X: dim_region[region_name]; Y: [Total Revenue]; title = [Region Title] | 20,466 400x240 |
| 100% stacked bar | Y: dim_channel[channel_name]; X: [Total Revenue]; Legend: fact_sales[customer_type] | 430,466 420x240 |
| Table | dim_product[product_name], [Total Revenue], [Revenue Share %]; Top N filter = 5 by [Total Revenue] | 860,466 400x240 |

Card tip: under Callout value set colour navy; add [MoM Indicator] as a second small card below Total Revenue, coloured with [MoM Color].

### Page 2 - Product Performance
| Visual | Fields |
|---|---|
| Line and clustered column (Pareto) | X: product_name (Top 10 by revenue); Column: [Total Revenue]; Line: [Product Cumulative Revenue %] |
| Treemap | Group: category; Details: product_name; Values: [Total Revenue] |
| Scatter | X: dim_product[avg_price]; Y: [Units Sold]; Size: [Total Revenue]; Legend: category |
| Matrix | Rows: category; Columns: quarter_name; Values: [Total Revenue]; Conditional formatting > Background colour scale (white to #1F6FEB) |
| Slicer | dim_product[price_tier] |

### Page 3 - Sales Team & Discounts
| Visual | Fields |
|---|---|
| Bar chart (leaderboard) | Y: salesperson_name (sorted desc); X: [Total Revenue]; Legend: dim_region[region_name] |
| Matrix | Rows: salesperson_name; Values: [Total Revenue], [Total Orders], [Avg Order Value], [Salesperson Rank]; data bars on revenue |
| Column + line | X: fact_sales[discount_band]; Column: [Total Orders]; Line: [Avg Order Value] |
| Cards | [Top Region], [Top Product], [Large Order Revenue %] |

### Finishing touches
- Turn on **Sync slicers** (View > Sync slicers) so region/channel selections carry across pages.
- Add a **page navigator** (Insert > Buttons > Navigator > Page navigator).
- Add alt text to each visual and check **View > Mobile layout** for page 1.
- Save as `powerbi/Sales_Performance_Dashboard.pbix`, then take screenshots of each page into `docs/` and reference them in the README.

## 6. Reconciliation check (do this before publishing)
With no filters applied, your cards should match the SQL results exactly:

| Measure | Expected |
|---|---|
| Total Revenue | 3,462,605.32 |
| Gross Revenue | 3,743,568.68 |
| Total Discount | 280,963.36 |
| Discount Rate % | 7.51% |
| Total Orders | 2,000 |
| Units Sold | 7,552 |
| Avg Order Value | 1,731.30 |
| Revenue by region | Central ~802.6K, North ~787.1K, East ~658.3K, South ~627.7K, West ~586.9K |

Mismatch? Most likely causes are a wrong relationship direction or a column left as text instead of number.
