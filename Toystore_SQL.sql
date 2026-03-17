USE  Toystore_BDD


-- REQUÊTE 1: VUE D'ENSEMBLE DES VENTES GLOBALES

SELECT 
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_customers,
    SUM(items_purchased) AS total_items_sold,
    ROUND(SUM(price_usd), 2) AS total_revenue,
    ROUND(SUM(cogs_usd), 2) AS total_cogs,
    ROUND(SUM(price_usd - cogs_usd), 2) AS total_profit,
    ROUND(AVG(price_usd), 2) AS avg_order_value
FROM orders;


-- REQUÊTE 2: ÉVOLUTION DES VENTES PAR MOIS

SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS date,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(price_usd), 2) AS monthly_revenue,
    ROUND(AVG(price_usd), 2) AS avg_order_value,
    COUNT(DISTINCT user_id) AS unique_customers
FROM orders
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY date;



-- REQUÊTE 3: PERFORMANCE DES PRODUITS
-- Analyse des produits : chiffre d'affaires, marge, volume

SELECT 
    p.product_id,
    p.product_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price_usd) AS gross_revenue,
    SUM(oi.cogs_usd) AS total_cogs,
    COALESCE(SUM(oir.refund_amount_usd), 0) AS total_refunds,
    SUM(oi.price_usd) - COALESCE(SUM(oir.refund_amount_usd), 0) AS net_revenue,
    SUM(oi.price_usd - oi.cogs_usd) - COALESCE(SUM(oir.refund_amount_usd), 0) AS net_profit,
    ROUND((SUM(oi.price_usd - oi.cogs_usd) - COALESCE(SUM(oir.refund_amount_usd), 0)) / 
          (SUM(oi.price_usd) - COALESCE(SUM(oir.refund_amount_usd), 0)) * 100, 2) AS profit_margin_pct,
    ROUND(COALESCE(SUM(oir.refund_amount_usd), 0) / SUM(oi.price_usd) * 100, 2) AS refund_rate_pct
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
WHERE oi.created_at >= '2012-01-01'
GROUP BY p.product_id, p.product_name
ORDER BY net_revenue DESC;

================================================================================
REQUÊTE 5 : APERÇU GLOBAL DES SESSIONS ET CONVERSIONS PAR CANAL UTM
================================================================================

-- Cette requête donne une vue d'ensemble des performances par source de trafic

SELECT 
    ws.utm_source,
    ws.utm_campaign,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conversion_rate_pct,
    SUM(o.price_usd) AS total_revenue,
    ROUND(SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions1 ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
WHERE ws.created_at >= '2012-01-01' 
GROUP BY ws.utm_source, ws.utm_campaign
ORDER BY total_sessions DESC;


-- Requete 6: ANALYSE DU TUNNEL DE CONVERSION - VUE GLOBALE
================================================================================

-- Cette requête analyse les différentes étapes du parcours client
-- Du pageview initial jusqu'à la commande

WITH funnel_stages AS (
    SELECT 
        ws.website_session_id,
        ws.utm_source,
        ws.utm_campaign,
        ws.device_type,
        -- Étape 1 : Session créée
        1 AS has_session,
        -- Étape 2 : A visité une landing page
        MAX(CASE WHEN wp.pageview_url LIKE '%/lander%' OR wp.pageview_url = '/' THEN 1 ELSE 0 END) AS reached_landing,
        -- Étape 3 : A visité la page produit
        MAX(CASE WHEN wp.pageview_url LIKE '%/products%' THEN 1 ELSE 0 END) AS reached_products,
        -- Étape 4 : A ajouté au panier
        MAX(CASE WHEN wp.pageview_url LIKE '%/cart%' THEN 1 ELSE 0 END) AS reached_cart,
        -- Étape 5 : Page shipping
        MAX(CASE WHEN wp.pageview_url LIKE '%/shipping%' THEN 1 ELSE 0 END) AS reached_shipping,
        -- Étape 6 : Page billing
        MAX(CASE WHEN wp.pageview_url LIKE '%/billing%' THEN 1 ELSE 0 END) AS reached_billing,
        -- Étape 7 : Commande confirmée
        MAX(CASE WHEN wp.pageview_url LIKE '%/thank-you%' THEN 1 ELSE 0 END) AS completed_order
    FROM website_sessions1 ws
    LEFT JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY ws.website_session_id, ws.utm_source, ws.utm_campaign, ws.device_type
)
SELECT 
    COUNT(DISTINCT website_session_id) AS total_sessions,
    SUM(reached_landing) AS sessions_landing,
    SUM(reached_products) AS sessions_products,
    SUM(reached_cart) AS sessions_cart,
    SUM(reached_shipping) AS sessions_shipping,
    SUM(reached_billing) AS sessions_billing,
    SUM(completed_order) AS sessions_order,
    -- Taux de conversion par étape
    ROUND(SUM(reached_landing) / COUNT(DISTINCT website_session_id) * 100, 2) AS landing_rate,
    ROUND(SUM(reached_products) / SUM(reached_landing) * 100, 2) AS products_rate,
    ROUND(SUM(reached_cart) / SUM(reached_products) * 100, 2) AS cart_rate,
    ROUND(SUM(reached_shipping) / SUM(reached_cart) * 100, 2) AS shipping_rate,
    ROUND(SUM(reached_billing) / SUM(reached_shipping) * 100, 2) AS billing_rate,
    ROUND(SUM(completed_order) / SUM(reached_billing) * 100, 2) AS order_completion_rate
FROM funnel_stages;

-- EQUÊTE 7 : TUNNEL DE CONVERSION PAR CANAL MARKETING

WITH funnel_stages AS (
    SELECT 
        ws.website_session_id,
        ws.utm_source,
        ws.utm_campaign,
        MAX(CASE WHEN wp.pageview_url LIKE '%/lander%' OR wp.pageview_url = '/' THEN 1 ELSE 0 END) AS reached_landing,
        MAX(CASE WHEN wp.pageview_url LIKE '%/products%' THEN 1 ELSE 0 END) AS reached_products,
        MAX(CASE WHEN wp.pageview_url LIKE '%/cart%' THEN 1 ELSE 0 END) AS reached_cart,
        MAX(CASE WHEN wp.pageview_url LIKE '%/shipping%' THEN 1 ELSE 0 END) AS reached_shipping,
        MAX(CASE WHEN wp.pageview_url LIKE '%/billing%' THEN 1 ELSE 0 END) AS reached_billing,
        MAX(CASE WHEN wp.pageview_url LIKE '%/thank-you%' THEN 1 ELSE 0 END) AS completed_order
    FROM website_sessions1 ws
    LEFT JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY ws.website_session_id, ws.utm_source, ws.utm_campaign
)
SELECT 
    utm_source,
    utm_campaign,
    COUNT(DISTINCT website_session_id) AS total_sessions,
    ROUND(SUM(reached_cart) / COUNT(DISTINCT website_session_id) * 100, 2) AS cart_reach_rate,
    ROUND(SUM(reached_shipping) / SUM(reached_cart) * 100, 2) AS cart_to_shipping_rate,
    ROUND(SUM(reached_billing) / SUM(reached_shipping) * 100, 2) AS shipping_to_billing_rate,
    ROUND(SUM(completed_order) / SUM(reached_billing) * 100, 2) AS billing_to_order_rate,
    ROUND(SUM(completed_order) / COUNT(DISTINCT website_session_id) * 100, 2) AS overall_conversion_rate
FROM funnel_stages
GROUP BY utm_source, utm_campaign
HAVING total_sessions > 100  
ORDER BY overall_conversion_rate DESC;



-- REQUÊTE 10: ANALYSE DU PANIER 
-- Abandon de panier-identififaction des points de friction


WITH cart_sessions AS (
    SELECT DISTINCT 
        wp.website_session_id,
        ws.utm_source,
        ws.utm_campaign,
        ws.device_type
    FROM website_pageviews wp
    INNER JOIN website_sessions1 ws ON wp.website_session_id = ws.website_session_id
    WHERE wp.pageview_url LIKE '%/cart%'
),
checkout_progress AS (
    SELECT 
        cs.website_session_id,
        cs.utm_source,
        cs.utm_campaign,
        cs.device_type,
        MAX(CASE WHEN wp.pageview_url LIKE '%/cart%' THEN 1 ELSE 0 END) AS reached_cart,
        MAX(CASE WHEN wp.pageview_url LIKE '%/shipping%' THEN 1 ELSE 0 END) AS reached_shipping,
        MAX(CASE WHEN wp.pageview_url LIKE '%/billing%' THEN 1 ELSE 0 END) AS reached_billing,
        MAX(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) AS completed_purchase
    FROM cart_sessions cs
    LEFT JOIN website_pageviews wp ON cs.website_session_id = wp.website_session_id
    LEFT JOIN orders o ON cs.website_session_id = o.website_session_id
    GROUP BY cs.website_session_id, cs.utm_source, cs.utm_campaign, cs.device_type
)
SELECT 
    device_type,
    COUNT(DISTINCT website_session_id) AS carts_initiated,
    SUM(reached_shipping) AS reached_shipping,
    SUM(reached_billing) AS reached_billing,
    SUM(completed_purchase) AS completed_purchases,
    -- Taux de passage à chaque étape
    ROUND(SUM(reached_shipping) / COUNT(DISTINCT website_session_id) * 100, 2) AS cart_to_shipping_pct,
    ROUND(SUM(reached_billing) / SUM(reached_shipping) * 100, 2) AS shipping_to_billing_pct,
    ROUND(SUM(completed_purchase) / SUM(reached_billing) * 100, 2) AS billing_to_purchase_pct,
    -- Identification des abandons
    COUNT(DISTINCT website_session_id) - SUM(reached_shipping) AS abandoned_at_cart,
    SUM(reached_shipping) - SUM(reached_billing) AS abandoned_at_shipping,
    SUM(reached_billing) - SUM(completed_purchase) AS abandoned_at_billing
FROM checkout_progress
GROUP BY device_type;



-- EQUÊTE 11 : ANALYSE MOBILE VS DESKTOP - COMPORTEMENT UTILISATEUR
-- Comparaison des performances entre appareils

SELECT 
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conversion_rate,
    SUM(o.price_usd) AS total_revenue,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    ROUND(SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session,
    -- Analyse des pages vues
    ROUND(AVG(pv.pageviews_per_session), 2) AS avg_pageviews_per_session
FROM website_sessions1 ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
LEFT JOIN (
    SELECT 
        website_session_id,
        COUNT(website_pageview_id) AS pageviews_per_session
    FROM website_pageviews
    GROUP BY website_session_id
) pv ON ws.website_session_id = pv.website_session_id
GROUP BY ws.device_type;


-- REQUÊTE 12 : ANALYSE DES SESSIONS RÉPÉTÉES - FIDÉLISATION CLIENT
-- Cette requête analyse le comportement des clients répétés vs nouveaux clients

SELECT 
    ws.is_repeat_session,
    CASE 
        WHEN ws.is_repeat_session = 1 THEN 'Repeat Customer'
        ELSE 'New Customer'
    END AS customer_type,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conversion_rate,
    SUM(o.price_usd) AS total_revenue,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    COUNT(DISTINCT ws.user_id) AS unique_users
FROM website_sessions1 ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.is_repeat_session
ORDER BY ws.is_repeat_session;

