# Cosmic Rings Designs — E-Commerce SQL & BI Analysis

SQL data cleaning, inventory modeling, and customer cohort analysis in Google BigQuery for **Cosmic Rings Designs**, my custom handmade jewelry shop on Etsy (1,638 orders, 1,790 line items, and $304K+ in net revenue from Aug 2020 to present).

* **Interactive Tableau Public Dashboard:** [Cosmic Rings Designs Executive KPI Suite](https://public.tableau.com/views/CosmicRingsDesignsSalesDashboards/ExecutiveSalesOverview?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

## Project Overview & Data Challenges
Raw order and item exports from Etsy Shop Manager have a few quirks that make direct analysis tricky:
1. **Listing Title Changes Over Time:** Editing an Etsy listing's SEO title changes the `item_name` on future orders, splitting a single ring design across multiple text strings. To fix this, I built a master SKU lookup table (`v_skus`) and joined order items by immutable `listing_id`.
2. **Unstructured Size & Width Variations:** Ring size and band width are exported inside a single free-text `variations` column (e.g., `Ring size: 10.5 US, Width: 8mm`). I used `REGEXP_EXTRACT` in BigQuery to parse clean ring sizes and widths for raw blank inventory ordering.
3. **Mixed Dates & Currency Formatting:** Standardized 2-digit and 4-digit year strings (`SAFE.PARSE_DATE`) and stripped currency characters into clean numeric types via staging views (`v_orders`, `v_order_items`, `v_skus`).

*(Note: Raw order CSVs are excluded from this repository to protect customer PII.)*

## Key Business Findings
* **Pareto Revenue Concentration (80/20 Rule):** The top 5 product lines drive **81% of total store revenue**, led by our flagship *Sapphire Storm* design (**$102,605**).
* **Customer Lifetime Value (LTV) & Repeat Buyers:** Repeat and VIP customers generated **$83K+ in revenue**, with Average Order Value (AOV) climbing from **$207 to $252** across peak demand periods.
* **Blank Inventory Planning Matrix:** By extracting ring size and band width via Regex and partitioning volume by material (Tungsten Carbide vs. Black Ceramic), I built a core blank ordering matrix that prevents stockouts on high-velocity sizes (US 9–11) while reducing dead-stock inventory on rare half-sizes.
