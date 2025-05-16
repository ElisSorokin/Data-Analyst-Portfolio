/* Проект «Data - доставка»
 * Цель проекта: Рассчитать ключевые метрики для продукта,
 * визуализировать их в интерактивном дашборде и на основе анализа предложить рекомендации для развития сервиса.
 * 
 * Автор: Сорокин Елисей
 */


--Задача 1. Расчёт DAU

SELECT log_date, 
        COUNT(DISTINCT(user_id)) AS DAU
FROM analytics_events
LEFT JOIN cities AS c USING (city_id)
WHERE city_name = 'Саранск'
       AND log_date >= '01-05-2021' 
       AND log_date <= '30-06-2021'
       AND event = 'order'
GROUP BY log_date
ORDER BY log_date ASC
LIMIT 10

--Задача 2. Расчёт Conversion Rate

SELECT log_date, 
        ROUND(COUNT(DISTINCT user_id) FILTER (WHERE event = 'order') / COUNT(DISTINCT user_id)::numeric,2) AS CR 
FROM analytics_events
LEFT JOIN cities AS c USING (city_id)
WHERE city_name = 'Саранск'
       AND log_date >= '01-05-2021' 
       AND log_date <= '30-06-2021'
GROUP BY log_date
ORDER BY log_date ASC
LIMIT 10

--Задача 3. Расчёт среднего чека

WITH orders AS (
    SELECT *,
            revenue * commission AS comm_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
)
SELECT DATE_TRUNC('month', log_date)::date AS "Месяц",
        COUNT(DISTINCT order_id) AS  "Количество заказов",
        ROUND(SUM(comm_revenue)::numeric,2) AS "Сумма комиссии",
        ROUND(SUM(comm_revenue)::numeric /COUNT(DISTINCT order_id)::numeric,2) AS "Средний чек"
FROM orders 
GROUP BY DATE_TRUNC('month', log_date)
ORDER BY Месяц

--Задача 4. Расчёт LTV ресторанов

WITH orders AS (
    SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue * commission AS comm_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
)
SELECT p.rest_id,
        p.chain AS "Название сети",
        p.type AS "Тип кухни",
        ROUND(SUM(comm_revenue)::numeric,2) AS LTV 
FROM partners AS p 
LEFT JOIN orders AS o ON o.rest_id = p.rest_id AND o.city_id = p.city_id
GROUP BY p.rest_id,p.chain,p.type
ORDER BY LTV DESC 
LIMIT 3

--Задача 5. Расчёт LTV ресторанов — самые популярные блюда

WITH orders AS (
    SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS comm_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
),
top_dishes AS (
    SELECT d.rest_id,
           p.chain,
           d.name AS dish_name,
           d.spicy,
           d.fish,
           d.meat,
           ROUND(SUM(o.comm_revenue)::numeric, 2) AS LTV
    FROM dishes AS d
    JOIN orders AS o ON d.rest_id = o.rest_id AND d.object_id = o.object_id
    JOIN partners AS p ON o.rest_id = p.rest_id AND o.city_id = p.city_id
    WHERE p.chain IN ('Гурманское Наслаждение', 'Гастрономический Шторм')
    GROUP BY d.rest_id, p.chain, d.name, d.spicy, d.fish, d.meat
)
SELECT chain AS "Название сети",
       dish_name AS "Название блюда",
       spicy,
       fish,
       meat,
       ROUND(LTV,2)
FROM top_dishes
ORDER BY LTV DESC
LIMIT 5

--Задача 6. Расчёт Retention Rate

WITH new_users AS (
    SELECT DISTINCT user_id, first_date
    FROM analytics_events
    JOIN cities ON analytics_events.city_id = cities.city_id
    WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
      AND city_name = 'Саранск'
),
active_users AS (
    SELECT DISTINCT user_id, log_date
    FROM analytics_events
    JOIN cities ON analytics_events.city_id = cities.city_id
    WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND city_name = 'Саранск'
),
daily_retention AS (
    SELECT 
        n.user_id,
        (a.log_date::date - n.first_date::date) AS day_since_install
    FROM new_users n
    JOIN active_users a ON n.user_id = a.user_id
    WHERE a.log_date >= n.first_date
)
SELECT 
    d.day_since_install,
    COUNT(DISTINCT d.user_id) AS retained_users,
    ROUND(
        COUNT(DISTINCT d.user_id) * 1.0 / 
        (SELECT COUNT(DISTINCT user_id) FROM new_users), 2
    ) AS retention_rate
FROM daily_retention d
WHERE d.day_since_install BETWEEN 0 AND 7 
GROUP BY d.day_since_install
ORDER BY d.day_since_install;

--Задача 7. Сравнение Retention Rate по месяцам

WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'
 ),
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'
 ),
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date
 )
SELECT DISTINCT CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",
                day_since_install,
                COUNT(DISTINCT user_id) AS retained_users,
                ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date) ORDER BY day_since_install))::numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;

