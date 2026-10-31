-- =================================================================================
-- COSMIC RINGS DESIGNS: E-COMMERCE SQL ANALYSIS (GOOGLE BIGQUERY)
-- Dataset: CosmicRingsData (1,638 Orders | 1,790 Order Line Items | 2020–2026)
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- STEP 0: DATA CLEANING VIEWS (Handling mixed date formats & currency strings)
-- ---------------------------------------------------------------------------------

CREATE OR REPLACE VIEW `CosmicRingsData.v_orders` AS
SELECT
    CAST(Order_ID AS STRING) AS Order_ID,
    COALESCE(
        SAFE.PARSE_DATE('%m/%d/%y', CAST(Sale_Date AS STRING)),
        SAFE.PARSE_DATE('%m/%d/%Y', CAST(Sale_Date AS STRING)),
        SAFE_CAST(Sale_Date AS DATE)
    ) AS Sale_Date,
    SAFE_CAST(REGEXP_REPLACE(CAST(Number_of_Items AS STRING), r'[^0-9.-]', '') AS INT64) AS Number_of_Items,
    SAFE_CAST(REGEXP_REPLACE(CAST(order_value AS STRING), r'[^0-9.-]', '') AS FLOAT64) AS order_value,
    SAFE_CAST(REGEXP_REPLACE(CAST(order_net AS STRING), r'[^0-9.-]', '') AS FLOAT64) AS order_net,
    SAFE_CAST(REGEXP_REPLACE(CAST(card_processing_fees AS STRING), r'[^0-9.-]', '') AS FLOAT64) AS card_processing_fees,
    SAFE_CAST(REGEXP_REPLACE(CAST(discount_amount AS STRING), r'[^0-9.-]', '') AS FLOAT64) AS discount_amount,
    CAST(ship_state AS STRING) AS ship_state,
    CAST(ship_country AS STRING) AS ship_country,
    CAST(coupon_code AS STRING) AS coupon_code
FROM `CosmicRingsData.cleanetsysoldorderstotal`;

CREATE OR REPLACE VIEW `CosmicRingsData.v_order_items` AS
SELECT
    CAST(transaction_id AS STRING) AS transaction_id,
    CAST(order_id AS STRING) AS order_id,
    SAFE_CAST(REGEXP_REPLACE(CAST(listing_id AS STRING), r'[^0-9]', '') AS INT64) AS listing_id,
    CAST(item_name AS STRING) AS item_name,
    CAST(buyer AS STRING) AS buyer,
    CAST(variations AS STRING) AS variations,
    SAFE_CAST(REGEXP_REPLACE(CAST(quantity AS STRING), r'[^0-9.-]', '') AS INT64) AS quantity,
    SAFE_CAST(REGEXP_REPLACE(CAST(price AS STRING), r'[^0-9.-]', '') AS FLOAT64) AS price,
    SAFE_CAST(REGEXP_REPLACE(CAST(item_total AS STRING), r'[^0-9.-]', '') AS FLOAT64) AS item_total,
    COALESCE(
        SAFE.PARSE_DATE('%m/%d/%y', CAST(sale_date AS STRING)),
        SAFE.PARSE_DATE('%m/%d/%Y', CAST(sale_date AS STRING)),
        SAFE_CAST(sale_date AS DATE)
    ) AS sale_date,
    COALESCE(
        SAFE.PARSE_DATE('%m/%d/%y', CAST(date_shipped AS STRING)),
        SAFE.PARSE_DATE('%m/%d/%Y', CAST(date_shipped AS STRING)),
        SAFE_CAST(date_shipped AS DATE)
    ) AS date_shipped
FROM `CosmicRingsData.cleanetsysoldorderitemstotal`;

CREATE OR REPLACE VIEW `CosmicRingsData.v_skus` AS
SELECT
    CAST(product_name AS STRING) AS product_name,
    CAST(band AS STRING) AS band,
    SAFE_CAST(REGEXP_REPLACE(CAST(sku AS STRING), r'[^0-9]', '') AS INT64) AS sku,
    SAFE_CAST(REGEXP_REPLACE(CAST(listing_id AS STRING), r'[^0-9]', '') AS INT64) AS listing_id
FROM `CosmicRingsData.cosmicringsskus`;


-- ---------------------------------------------------------------------------------
-- PART 1: CORE REVENUE, AOV & GEOGRAPHIC PERFORMANCE
-- ---------------------------------------------------------------------------------

-- 1. Overall store summary (Orders, Units, Gross vs. Net Revenue, Processing Fees)
SELECT 
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Number_of_Items) AS Total_Items_Sold,
    ROUND(SUM(order_value), 2) AS Gross_Revenue,
    ROUND(SUM(order_net), 2) AS Net_Revenue,
    ROUND(SUM(card_processing_fees), 2) AS Total_Fees_Paid
FROM `CosmicRingsData.v_orders`;

-- 2. Average Order Value (AOV) and items per order
SELECT 
    ROUND(AVG(order_value), 2) AS Average_Order_Value,
    ROUND(AVG(order_net), 2) AS Average_Net_Per_Order,
    ROUND(AVG(Number_of_Items), 2) AS Average_Items_Per_Order
FROM `CosmicRingsData.v_orders`;

-- 3. Top 10 US states by net revenue and state AOV
SELECT 
    ship_state,
    COUNT(Order_ID) AS Order_Count,
    ROUND(SUM(order_net), 2) AS Total_Net_Revenue,
    ROUND(AVG(order_value), 2) AS State_AOV
FROM `CosmicRingsData.v_orders`
WHERE ship_country IN ('United States', 'US')
GROUP BY ship_state
ORDER BY Total_Net_Revenue DESC
LIMIT 10;

-- 4. Domestic (US) vs. International sales split
SELECT 
    CASE 
        WHEN ship_country IN ('United States', 'US') THEN 'Domestic (US)'
        ELSE 'International'
    END AS Region,
    COUNT(Order_ID) AS Order_Count,
    ROUND(SUM(order_net), 2) AS Net_Revenue
FROM `CosmicRingsData.v_orders`
GROUP BY Region
ORDER BY Net_Revenue DESC;

-- 5. Promo code performance and discount impact on order size
SELECT 
    CASE 
        WHEN discount_amount > 0 THEN 'Used Discount'
        ELSE 'No Discount'
    END AS Discount_Status,
    COUNT(Order_ID) AS Total_Orders,
    ROUND(AVG(Number_of_Items), 2) AS Avg_Items_Per_Order,
    ROUND(AVG(order_net), 2) AS Avg_Net_Revenue
FROM `CosmicRingsData.v_orders`
GROUP BY Discount_Status;


-- ---------------------------------------------------------------------------------
-- PART 2: PRODUCT CATALOG, REGEX VARIATION PARSING & INVENTORY PLANNING
-- ---------------------------------------------------------------------------------

-- 6. Top selling ring designs (joined on listing_id to handle historical Etsy title edits)
SELECT 
    s.product_name,
    COUNT(i.transaction_id) AS Total_Orders,
    SUM(i.quantity) AS Total_Units_Sold,
    ROUND(SUM(i.item_total), 2) AS Total_Revenue_Generated
FROM `CosmicRingsData.v_order_items` i
JOIN (
    SELECT DISTINCT listing_id, product_name 
    FROM `CosmicRingsData.v_skus`
    WHERE listing_id IS NOT NULL
) s ON i.listing_id = s.listing_id
WHERE s.product_name NOT LIKE '%Upgrade%'
  AND s.product_name NOT LIKE '%Exchange%'
  AND s.product_name NOT LIKE '%Repair%'
GROUP BY s.product_name
ORDER BY Total_Revenue_Generated DESC
LIMIT 15;

-- 7. Band material breakdown (Tungsten Carbide vs. Black Ceramic, etc.)
SELECT 
    s.band AS Material_Type,
    COUNT(i.transaction_id) AS Total_Orders,
    SUM(i.quantity) AS Total_Quantity,
    ROUND(SUM(i.item_total), 2) AS Revenue_Generated
FROM `CosmicRingsData.v_order_items` i
JOIN `CosmicRingsData.v_skus` s 
    ON i.listing_id = s.listing_id
GROUP BY s.band
ORDER BY Total_Quantity DESC;

-- 8. Universal ring size distribution (extracted from raw Etsy variations text via Regex)
SELECT 
    TRIM(REGEXP_EXTRACT(variations, r'Ring size:\s*([^U,]+?)\s*US')) AS Universal_Ring_Size,
    SUM(quantity) AS Total_Units_Sold
FROM `CosmicRingsData.v_order_items`
WHERE variations LIKE '%Ring size:%'
GROUP BY Universal_Ring_Size
ORDER BY Total_Units_Sold DESC
LIMIT 15;

-- 9. Blank inventory ordering matrix (Band Material x Width x Ring Size)
WITH Extracted_Specs AS (
    SELECT 
        COALESCE(s.band, 'Unmapped/Custom') AS Band_Material,
        TRIM(REGEXP_EXTRACT(i.variations, r'Width:\s*([0-9]+\s*mm)')) AS Band_Width,
        TRIM(REGEXP_EXTRACT(i.variations, r'Ring size:\s*([^U,]+?)\s*US')) AS Ring_Size,
        i.quantity,
        i.item_total
    FROM `CosmicRingsData.v_order_items` i
    LEFT JOIN (
        SELECT DISTINCT listing_id, band 
        FROM `CosmicRingsData.v_skus`
        WHERE listing_id IS NOT NULL
    ) s ON i.listing_id = s.listing_id
    WHERE i.variations LIKE '%Ring size:%'
)
SELECT 
    Band_Material,
    COALESCE(Band_Width, 'Standard/Unspecified') AS Band_Width,
    Ring_Size,
    SUM(quantity) AS Total_Blanks_Needed,
    ROUND(SUM(item_total), 2) AS Total_Revenue,
    ROUND(100.0 * SUM(quantity) / SUM(SUM(quantity)) OVER (PARTITION BY Band_Material), 2) AS Pct_Of_Material_Volume
FROM Extracted_Specs
WHERE Ring_Size IS NOT NULL
GROUP BY Band_Material, Band_Width, Ring_Size
ORDER BY Total_Blanks_Needed DESC
LIMIT 25;


-- ---------------------------------------------------------------------------------
-- PART 3: TIME-SERIES TRENDS, PARETO CONCENTRATION & CUSTOMER LTV COHORTS
-- ---------------------------------------------------------------------------------

-- 10. Monthly unit comparison across flagship lines (Sapphire Storm, Fordite, Steampunk)
SELECT 
    FORMAT_DATE('%Y-%m', i.sale_date) AS Sales_Month,
    SUM(CASE WHEN s.product_name = 'Sapphire Storm' THEN i.quantity ELSE 0 END) AS Sapphire_Storm_Units,
    SUM(CASE WHEN s.product_name = 'Fordite' THEN i.quantity ELSE 0 END) AS Fordite_Units,
    SUM(CASE WHEN s.product_name = 'Steampunk' THEN i.quantity ELSE 0 END) AS Steampunk_Units
FROM `CosmicRingsData.v_order_items` i
JOIN (
    SELECT DISTINCT listing_id, product_name 
    FROM `CosmicRingsData.v_skus`
    WHERE listing_id IS NOT NULL
) s ON i.listing_id = s.listing_id
WHERE s.product_name IN ('Sapphire Storm', 'Fordite', 'Steampunk')
GROUP BY Sales_Month
ORDER BY Sales_Month DESC;

-- 11. Month-over-Month (MoM) revenue growth and 3-month rolling average
WITH Monthly_Metrics AS (
    SELECT 
        FORMAT_DATE('%Y-%m', Sale_Date) AS Sales_Month,
        COUNT(DISTINCT Order_ID) AS Total_Orders,
        ROUND(SUM(order_net), 2) AS Net_Revenue
    FROM `CosmicRingsData.v_orders`
    GROUP BY Sales_Month
)
SELECT 
    Sales_Month,
    Total_Orders,
    Net_Revenue,
    LAG(Net_Revenue) OVER (ORDER BY Sales_Month) AS Prev_Month_Revenue,
    ROUND(
        100.0 * (Net_Revenue - LAG(Net_Revenue) OVER (ORDER BY Sales_Month)) 
        / NULLIF(LAG(Net_Revenue) OVER (ORDER BY Sales_Month), 0), 2
    ) AS MoM_Growth_Pct,
    ROUND(
        AVG(Net_Revenue) OVER (ORDER BY Sales_Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2
    ) AS Rolling_3Mo_Avg_Revenue
FROM Monthly_Metrics
ORDER BY Sales_Month DESC;

-- 12. Pareto (80/20) product revenue concentration
WITH Product_Sales AS (
    SELECT 
        s.product_name,
        SUM(i.quantity) AS Units_Sold,
        ROUND(SUM(i.item_total), 2) AS Product_Revenue
    FROM `CosmicRingsData.v_order_items` i
    JOIN (
        SELECT DISTINCT listing_id, product_name 
        FROM `CosmicRingsData.v_skus`
        WHERE listing_id IS NOT NULL
    ) s ON i.listing_id = s.listing_id
    GROUP BY s.product_name
)
SELECT 
    product_name,
    Units_Sold,
    Product_Revenue,
    ROUND(100.0 * Product_Revenue / SUM(Product_Revenue) OVER (), 2) AS Pct_Of_Total_Revenue,
    ROUND(
        100.0 * SUM(Product_Revenue) OVER (ORDER BY Product_Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) 
        / SUM(Product_Revenue) OVER (), 2
    ) AS Cumulative_Revenue_Pct
FROM Product_Sales
ORDER BY Product_Revenue DESC;

-- 13. Fulfillment lead time by product (days from order date to ship date)
SELECT 
    s.product_name,
    COUNT(i.transaction_id) AS Completed_Orders,
    ROUND(AVG(DATE_DIFF(i.date_shipped, i.sale_date, DAY)), 1) AS Avg_Days_To_Ship,
    MIN(DATE_DIFF(i.date_shipped, i.sale_date, DAY)) AS Fastest_Ship_Days,
    MAX(DATE_DIFF(i.date_shipped, i.sale_date, DAY)) AS Slowest_Ship_Days
FROM `CosmicRingsData.v_order_items` i
JOIN (
    SELECT DISTINCT listing_id, product_name 
    FROM `CosmicRingsData.v_skus`
    WHERE listing_id IS NOT NULL
) s ON i.listing_id = s.listing_id
WHERE i.date_shipped IS NOT NULL 
  AND i.sale_date IS NOT NULL
  AND DATE_DIFF(i.date_shipped, i.sale_date, DAY) >= 0
GROUP BY s.product_name
HAVING Completed_Orders >= 5
ORDER BY Avg_Days_To_Ship DESC;

-- 14. Customer Lifetime Value (LTV) & repeat buyer cohorts
WITH Customer_History AS (
    SELECT 
        buyer,
        COUNT(DISTINCT order_id) AS Total_Orders,
        SUM(quantity) AS Total_Items_Bought,
        ROUND(SUM(item_total), 2) AS Lifetime_Spend,
        MIN(sale_date) AS First_Order_Date,
        MAX(sale_date) AS Last_Order_Date,
        DATE_DIFF(MAX(sale_date), MIN(sale_date), DAY) AS Customer_Lifespan_Days
    FROM `CosmicRingsData.v_order_items`
    WHERE buyer IS NOT NULL AND buyer != ''
    GROUP BY buyer
)
SELECT 
    CASE 
        WHEN Total_Orders = 1 THEN '1. One-Time Buyer'
        WHEN Total_Orders = 2 THEN '2. Two-Time Repeat Buyer'
        ELSE '3. VIP Loyal (3+ Orders)'
    END AS Customer_Tier,
    COUNT(buyer) AS Customer_Count,
    ROUND(100.0 * COUNT(buyer) / SUM(COUNT(buyer)) OVER (), 2) AS Pct_Of_Customer_Base,
    ROUND(SUM(Lifetime_Spend), 2) AS Total_Tier_Revenue,
    ROUND(AVG(Lifetime_Spend), 2) AS Avg_Customer_LTV,
    ROUND(AVG(NULLIF(Customer_Lifespan_Days, 0)), 1) AS Avg_Days_Between_First_And_Last_Order
FROM Customer_History
GROUP BY Customer_Tier
ORDER BY Customer_Tier;

-- 15. Market Basket Analysis (Products frequently purchased together in the same order)
WITH Order_Products AS (
    SELECT 
        i.order_id,
        i.transaction_id,
        COALESCE(s.product_name, i.item_name) AS Clean_Product_Name
    FROM `CosmicRingsData.v_order_items` i
    LEFT JOIN (
        SELECT DISTINCT listing_id, product_name 
        FROM `CosmicRingsData.v_skus`
        WHERE listing_id IS NOT NULL
    ) s ON i.listing_id = s.listing_id
)
SELECT 
    a.Clean_Product_Name AS Primary_Item,
    b.Clean_Product_Name AS Paired_Item,
    COUNT(DISTINCT a.order_id) AS Times_Bought_Together
FROM Order_Products a
JOIN Order_Products b 
    ON a.order_id = b.order_id 
    AND a.transaction_id < b.transaction_id
GROUP BY Primary_Item, Paired_Item
ORDER BY Times_Bought_Together DESC
LIMIT 15;
