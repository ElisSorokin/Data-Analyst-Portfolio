/* Проект «DarkForest»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок.
 * 
 * Автор: Сорокин Елисей
*/

-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT COUNT(u.id) AS total_players,                            
           SUM(u.payer) AS paying_players,
           ROUND(AVG(u.payer)*100.0,2) AS payers_perc
FROM fantasy.users AS u

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT r.race,
    	   COUNT(u.id) AS total_players_race,                            
           SUM (u.payer) AS paying_players,
           ROUND(AVG(u.payer)*100.0,3) AS paying_perc
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING (race_id) 
GROUP BY r.race
ORDER BY paying_perc DESC

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT COUNT(transaction_id) AS transaction_count ,
		SUM(amount) AS total_amount,
		MIN(amount) AS min_amount,
		ROUND(MAX(amount)) AS max_amount,
		AVG(amount)::numeric(5,2) AS avg_amount,
		stddev(amount)::numeric(10,2) AS stand_dev,
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana
FROM fantasy.events
WHERE amount>0

-- 2.2: Аномальные нулевые покупки:

SELECT COUNT(e.amount) FILTER (WHERE amount = 0) AS zero_amount_count,
		(COUNT(e.amount) FILTER (WHERE amount = 0)*100)/COUNT(e.transaction_id)::NUMERIC AS zero_amount_perc
FROM fantasy.events AS e

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

WITH users_stats AS (
	SELECT e.id,
    		r.race,
           	COUNT(e.transaction_id) AS transaction_count,
           	SUM(e.amount) AS total_amount,
           	AVG(e.amount) AS avg_price_per_user,
           	CASE 
           		 WHEN u.payer = 0 
           		 	THEN 'non_payer'
            	WHEN u.payer = 1 
            		THEN 'payer'
    		END AS payer_type
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    LEFT JOIN fantasy.events AS e USING (id)
    WHERE e.amount > 0
    GROUP BY e.id,r.race_id,u.payer
)
SELECT us.race,
		us.payer_type,
		COUNT(DISTINCT us.id) AS user_count,
		AVG(us.transaction_count)::numeric(10,2) AS avg_transaction_count,
		AVG(us.total_amount)::numeric(10,2) AS avg_amount
FROM users_stats AS us
GROUP BY us.race, us.payer_type

-- 2.4: Популярные эпические предметы:

WITH total_counts AS (
    SELECT 
        COUNT(e.transaction_id) AS all_transaction_count,
        COUNT(DISTINCT e.id) AS total_players
    FROM fantasy.events AS e
    WHERE amount > 0
)
SELECT 
    i.game_items,
    COUNT(e.transaction_id) AS transaction_count,
    (COUNT(e.transaction_id) * 100.0)/tc.all_transaction_count AS transaction_perc,
    (COUNT(DISTINCT e.id)*100.0)/tc.total_players AS player_perc
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e ON i.item_code = e.item_code AND e.amount > 0
JOIN total_counts AS tc ON 1=1
GROUP BY i.game_items,tc.all_transaction_count,tc.total_players
ORDER BY transaction_count DESC


-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

WITH race_total_players AS (
    SELECT r.race,
      		COUNT(DISTINCT u.id) AS total_players
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    GROUP BY r.race
),
race_event_players AS (
    SELECT r.race,
           	COUNT(DISTINCT e.id) AS total_events_players
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    LEFT JOIN fantasy.events AS e USING (id)
    GROUP BY r.race
),
race_paying_event_players AS (
    SELECT r.race,
       		COUNT(DISTINCT u.id) AS total_paying_players
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    LEFT JOIN fantasy.events AS e USING (id)
    WHERE u.payer = 1 AND e.transaction_id IS NOT NULL
    GROUP BY r.race
),
race_players_stats AS (
    SELECT r.race,
           	u.id,
           	COUNT(e.transaction_id) AS transaction_count,
           	SUM(e.amount) AS total_amount
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    LEFT JOIN fantasy.events AS e USING (id)
    WHERE e.amount > 0
    GROUP BY r.race, u.id
)
SELECT r.race,
    	rtp.total_players,
   	 	rep.total_events_players,
    	((rep.total_events_players * 100.0) / rtp.total_players)::numeric(10,2) AS perc_events_players,
    	((rpp.total_paying_players * 100.0) / rep.total_events_players)::numeric(10,2) AS perc_paying_events_players,
    	AVG(ps.transaction_count)::numeric(10,2) AS avg_quantity_transaction_per_user,
    	(AVG(ps.total_amount) / AVG(ps.transaction_count))::numeric(10,2) AS  avg_price_per_user,
    	AVG(ps.total_amount)::numeric(10,2) AS avg_total_amt_per_user
FROM fantasy.race AS r
LEFT JOIN race_total_players AS rtp ON r.race = rtp.race
LEFT JOIN race_event_players AS rep ON r.race = rep.race
LEFT JOIN race_paying_event_players AS rpp ON r.race = rpp.race
LEFT JOIN race_players_stats AS ps ON r.race = ps.race
GROUP BY r.race, rtp.total_players, rep.total_events_players, rpp.total_paying_players
ORDER BY r.race
