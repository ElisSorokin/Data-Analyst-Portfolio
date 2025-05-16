/* Проект «Property Pulse»
 * Цель проекта: Определить наиболее перспективные сегменты рынка недвижимости в Санкт-Петербурге и Ленинградской области
 *  с учетом сезонных факторов, чтобы предложить бизнес-решения для оптимизации продаж и маркетинга
 *  и визуализировать ключевые метрики на интерактивном дашборде.
 * 
 * Автор: Сорокин Елисей
*/

-- Задача 1. Провел фильтрацию данных от аномальных значений

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
)
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 2. Время активности объявлений

selection_info AS (
	SELECT *,
		CASE 
			WHEN city_id ='6X8I' 
				THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл'
		END AS region,
		CASE
			WHEN days_exposition >=181
				THEN 'больше полугода'
			WHEN days_exposition >=91
				THEN 'полгода'
			WHEN days_exposition >=31
				THEN 'квартал'
			WHEN days_exposition>=0
				THEN 'месяц'
		END AS selling_period,
		last_price/total_area AS price_per_m
	FROM real_estate.flats AS f
	LEFT JOIN real_estate.advertisement AS a USING (id)
	WHERE id IN (SELECT * FROM filtered_id)
		AND days_exposition IS NOT NULL
		AND type_id ='F8EM'
),
total_ads AS (
    SELECT COUNT(id) AS total_number_of_ads
    FROM selection_info
)
SELECT region,
       selling_period,
       COUNT(id) AS number_of_ads,
       ROUND(((COUNT(id)*1.0/(SELECT total_number_of_ads FROM total_ads)) * 100.0),2) AS ads_share_percent_total,
       ROUND((COUNT(id)*1.0/SUM(COUNT(id)) OVER (PARTITION BY region))*100.0,2) AS ads_share_in_region,
       ROUND(AVG(price_per_m)::numeric,2) AS avg_price_per_m,
       ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY living_area) AS living_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY kitchen_area) AS kitchen_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY floor) AS floor_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY floors_total) AS floor_total_mediana
FROM selection_info
GROUP BY region, selling_period
ORDER BY number_of_ads DESC;

-- Задача 3. Сезонность объявлений

publication_info AS (
    SELECT DATE_TRUNC('month', first_day_exposition)::date AS exposition_date,
        	COUNT(*) AS publication_count,
        	AVG(last_price / total_area)::numeric AS avg_price_per_m2,
        	AVG(total_area)::numeric AS avg_total_area
    FROM real_estate.advertisement AS a
    LEFT JOIN real_estate.flats AS f USING (id)
    WHERE id IN (SELECT * FROM filtered_id)
    	AND type_id ='F8EM'
    GROUP BY DATE_TRUNC('month', first_day_exposition)::date    
),
removal_info AS (
    SELECT DATE_TRUNC('month', first_day_exposition::date + days_exposition * INTERVAL '1 day') AS last_exposition_date,
       		COUNT(*) AS removal_count
    FROM real_estate.advertisement
    WHERE first_day_exposition::date + days_exposition * INTERVAL '1 day' IS NOT NULL 
    	AND id IN (SELECT * FROM filtered_id)
    GROUP BY DATE_TRUNC('month', first_day_exposition::date + days_exposition * INTERVAL '1 day')
)
SELECT pi.exposition_date,
    	pi.publication_count,
    	COALESCE(ri.removal_count, 0) AS removal_count,
    	ROUND(pi.avg_price_per_m2, 2) AS avg_price_per_m2,
    	ROUND(pi.avg_total_area, 2) AS avg_total_area,
    	ROW_NUMBER() OVER (ORDER BY pi.publication_count DESC) AS publication_rank,
    	ROW_NUMBER() OVER (ORDER BY COALESCE(ri.removal_count, 0) DESC) AS removal_rank
FROM publication_info AS pi 
LEFT JOIN removal_info AS ri ON pi.exposition_date = ri.last_exposition_date
WHERE pi.exposition_date BETWEEN '2015-01-01' AND '2018-12-31'
ORDER BY pi.exposition_date;


-- Задача 4. Анализ рынка недвижимости Ленобласти

SELECT c.city,
		COUNT(first_day_exposition) AS publication_count,
		COUNT(days_exposition) AS removal_count,
		ROUND(((COUNT(days_exposition)*1.0 / COUNT(first_day_exposition))*100.00),2) AS removal_share_perc,
		ROUND(AVG(days_exposition)::numeric,2) AS avg_day_exposition,
		ROUND(AVG(last_price/total_area)::numeric,2) AS avg_price_per_m,
       ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY living_area) AS living_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY kitchen_area) AS kitchen_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY floor) AS floor_mediana,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY floors_total) AS floor_total_mediana
FROM real_estate.flats 
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.advertisement AS a USING (id)
WHERE city_id !='6X8I'
		AND id IN (SELECT * FROM filtered_id)
GROUP  BY c.city
HAVING COUNT(id)>50
ORDER BY removal_share_perc DESC;
