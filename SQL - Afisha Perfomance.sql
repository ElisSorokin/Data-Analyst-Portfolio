/* Проект «Afisha Perfomance»
 * Цель проекта: Построить дашборд для отслеживания бизнес-показателей
 *  и провести исследовательский анализ пользовательского поведения в сервисе «Афиша».
 * 
 * Автор: Сорокин Елисей
 */

--Задача 1. - Получение общих данных

SELECT 
    currency_code,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    COUNT(DISTINCT user_id) AS total_users
FROM afisha.purchases
GROUP BY currency_code
ORDER BY total_revenue DESC

--Задача 2. - Изучение распределения выручки в разрезе устройств

WITH set_config_precode AS (
  SELECT set_config('synchronize_seqscans', 'off', true)
),
revenue_info AS (
        SELECT 
            SUM(revenue) AS all_revenue
        FROM afisha.purchases
        WHERE currency_code = 'rub'
)
SELECT 
    device_type_canonical,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    ROUND((SUM(revenue) / all_revenue)::numeric,3) AS revenue_share
FROM afisha.purchases,revenue_info 
WHERE currency_code = 'rub'
GROUP BY device_type_canonical,all_revenue
ORDER BY revenue_share DESC,total_revenue DESC

--Задача 3. - Изучение распределения выручки в разрезе типа мероприятий

SELECT 
    event_type_main,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    COUNT(DISTINCT event_name_code) AS total_event_name,
    AVG(tickets_count) AS avg_tickets,
    SUM(revenue) / SUM(tickets_count) AS avg_tickets_revenue,
    ROUND(SUM(revenue)::numeric / (SELECT SUM(revenue) FROM afisha.purchases WHERE currency_code = 'rub')::numeric,3) AS revenue_share
FROM afisha.purchases
LEFT JOIN afisha.events USING(event_id)
WHERE currency_code = 'rub'
GROUP BY event_type_main
ORDER BY total_orders DESC  

--Задача 4. - Динамика изменения значений

SELECT 
    DATE_TRUNC('week',created_dt_msk)::date AS week,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    SUM(revenue) / COUNT(order_id) AS revenue_per_order 
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY DATE_TRUNC('week',created_dt_msk)
ORDER BY week ASC 

--Задача 5. - Выделение топ-сегментов

SELECT 
    region_name,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    SUM(tickets_count) AS total_tickets,
    SUM(revenue) / SUM(tickets_count) AS one_ticket_cost 
FROM afisha.purchases 
LEFT JOIN afisha.events USING (event_id)
LEFT JOIN afisha.city USING (city_id)
LEFT JOIN afisha.regions USING (region_id)
WHERE currency_code = 'rub'
GROUP BY region_name
ORDER BY total_revenue DESC 
LIMIT 7 
