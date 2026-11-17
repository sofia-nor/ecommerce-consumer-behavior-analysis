--PROJECT: Consumer Purchase Behavior
--DATA: Nov-2019 e-commerce events

ALTER TABLE "2019_Nov"
ALTER COLUMN price TYPE numeric USING price::numeric;
ALTER TABLE "2019_Nov"
ALTER COLUMN event_time TYPE timestamptz USING event_time::timestamptz;

-- Question 1: What brands had the most purchases of November 2019?
-- Do they also generate the most revenue?

SELECT brand,
       COUNT(*) AS total_purchased,
       COUNT(DISTINCT user_id) AS unique_buyers,
       ROUND(SUM(price), 2) AS revenue
FROM "2019_Nov"
WHERE event_type = 'purchase'
AND brand IS NOT NULL
GROUP BY brand
ORDER BY total_purchased DESC
LIMIT 20;

SELECT brand,
       COUNT(*) AS total_purchased,
       COUNT(DISTINCT user_id) AS unique_buyers,
       ROUND(AVG(price), 2) AS avg_price_per_item,
       ROUND(SUM(price), 2) AS revenue
FROM "2019_Nov"
WHERE event_type = 'purchase'
AND brand IN ('samsung' , 'apple')
GROUP BY brand
ORDER BY revenue DESC;

--Insights
--a.No,Samsung leads Apple in purchase events Samsung(200,027) v. Apple(166,064) with a lower revenue
--b.About 95% higher in average price per item for Apple(767.85) v. Samsung(274.31) explaining the heightened revenue

--Question 2: Which product categories drive the most purchases v the most revenue?

SELECT category_code,
       COUNT(event_type) AS purchase_events,
       ROUND(SUM(price),2) AS product_revenue
FROM "2019_Nov"
WHERE event_type= 'purchase'
AND category_code IS NOT NULL
GROUP BY category_code
ORDER BY product_revenue DESC
LIMIT 20;

SELECT category_code,
       COUNT(event_type) AS purchase_events,
       ROUND(SUM(price),2) AS product_revenue
FROM "2019_Nov"
WHERE event_type= 'purchase'
AND category_code IS NOT NULL
GROUP BY category_code
ORDER BY purchase_events DESC
LIMIT 20;

--Insights
--a.The lead category for both revenue and purchases is electronics specifically smartphones, volume is high with price
--being just as high.
--b.Lead categories in revenue do not coincide in the same order as lead categories in purchase events. Hinting towards
--a high purchase volume with a lower price range. However in each segment 4/5 of the top 5 categories appear in both.

--Question 3:What does the view->cart->purchase funnel look like? Where is the biggest drop off?


WITH funnel AS
(SELECT
    COUNT(DISTINCT user_session)  FILTER  (WHERE event_type= 'view') AS viewed_sessions,
    COUNT(DISTINCT user_session)  FILTER  (WHERE event_type= 'cart') AS cart_sessions,
    COUNT(DISTINCT user_session)  FILTER  (WHERE event_type= 'purchase') AS purchased_sessions
FROM "2019_Nov" )
SELECT
    viewed_sessions,
    cart_sessions,
    purchased_sessions,
    ROUND(cart_sessions * 100.0 / NULLIF(viewed_sessions, 0), 1)          AS view_to_cart_pct,
    ROUND(purchased_sessions * 100.0 / NULLIF(cart_sessions, 0), 1)       AS cart_to_purchase_pct,
    ROUND(purchased_sessions * 100.0 / NULLIF(viewed_sessions, 0), 1)     AS view_to_purchase_pct,
    ROUND(100 - purchased_sessions * 100.0 / NULLIF(cart_sessions, 0), 1) AS cart_abandonment_pct
FROM funnel;

--Insights
--a. 5.6% of viewing sessions lead to cart, 44.4% of cart sessions ended in a purchase,
--and 55.6% of cart sessions were abandoned.
--b.The biggest drop off was view to purchase sessions at 5.6%.

--Question 4: Which categories gets a lot of views but convert poorly?

WITH category_funnel AS (
    SELECT
    category_code,
    COUNT(DISTINCT user_session)  FILTER  (WHERE event_type= 'view') AS viewed_sessions,
    COUNT(DISTINCT user_session)  FILTER  (WHERE event_type= 'cart') AS cart_sessions,
    COUNT(DISTINCT user_session)  FILTER  (WHERE event_type= 'purchase') AS purchased_sessions
FROM "2019_Nov"
WHERE category_code IS NOT NULL
GROUP BY category_code)
SELECT
    category_code,
    viewed_sessions,
    cart_sessions,
    purchased_sessions,
    ROUND(purchased_sessions * 100.0 / NULLIF(cart_sessions, 0), 1)       AS cart_to_purchase_pct,
    ROUND(purchased_sessions * 100.0 / NULLIF(viewed_sessions, 0), 1)     AS view_to_purchase_pct
FROM category_funnel
ORDER BY viewed_sessions DESC
LIMIT 20;

--Insights:
--a. Cart to purchase events remain consistent among all 20 categories. The biggest gap between view to purchase
--and cart to purchase is met by the computer.desktop category at 2% and the apparel.costume category at 0.8%.
--These categories are nearly meeting a 40% in cart to purchase rate meaning the largest drop off is in viewing to
--purchase.
--b.These low conversion rates could be due to the category consisting of a longer decision process. Looking for
--desired features among desktops or viewing a variety of costumes before finalizing a choice.

--Question 5:How many buyers purchase more than once, and how much revenue do repeat buyers generate?

WITH buyer_frequency AS (
    SELECT
        user_id,
        COUNT(DISTINCT CASE
            WHEN event_type = 'purchase' THEN user_session
        END) AS purchase_sessions,

        ROUND(SUM(CASE
            WHEN event_type = 'purchase' THEN price
            ELSE 0
        END), 2) AS revenue

    FROM "2019_Nov"
    WHERE user_id IS NOT NULL
    GROUP BY user_id
),

buyer_classification AS (
    SELECT
        CASE
            WHEN purchase_sessions > 1 THEN 'Repeat buyer'
            ELSE 'One-time buyer'
        END AS buyer_type,
        revenue
    FROM buyer_frequency
    WHERE purchase_sessions > 0
)

SELECT
    buyer_type,
    COUNT(*) AS buyers,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1
    ) AS pct_of_buyers,

    ROUND(SUM(revenue), 2) AS revenue,

    ROUND(
        SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 1
    ) AS pct_of_revenue,

    ROUND(AVG(revenue), 2) AS avg_revenue_per_buyer

FROM buyer_classification
GROUP BY buyer_type
ORDER BY buyer_type DESC;

--Insights
--a.Repeat buyers make up 32% of buyers, one-time buyers make up 68%. The revenue percentage is twice as high in repeat
--buyers at 66.4%, with one-time buyer revenue at 33.6%.
--The difference in increased revenue in comparison to one-time buyers with higher purchase events can be explained by
--first purchase discounts or higher brand reliabilty for repeat buyers leading to more expensive products.
