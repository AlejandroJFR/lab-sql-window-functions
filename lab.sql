
USE sakila;
-- ## Challenge 1

-- This challenge consists of three exercises that will test your ability to use the SQL RANK() function. You will use it to rank films by their length, 
-- their length within the rating category, and by the actor or actress who has acted in the greatest number of films.

-- 1. Rank films by their length and create an output table that includes the title, length, and rank columns only. Filter out any rows with null or 
-- zero values in the length column
	SELECT title, length, 
    DENSE_RANK() OVER (ORDER BY length DESC) AS 'rank'
	FROM  sakila.film
	WHERE length IS NOT NULL AND length > 0;

-- 2. Rank films by length within the rating category and create an output table that includes the title, length, rating and rank columns only. Filter 
-- out any rows with null or zero values in the length column.
	SELECT title, length, rating,
    DENSE_RANK() OVER (PARTITION BY rating ORDER BY length DESC) AS 'rank'
	FROM  sakila.film
	WHERE length IS NOT NULL AND length > 0;

-- 3. Produce a list that shows for each film in the Sakila database, the actor or actress who has acted in the greatest number of films, as well as the 
-- total number of films in which they have acted. *Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.*
	WITH actor_film_count AS (
    SELECT 
        fa.actor_id, 
        a.first_name, 
        a.last_name, 
        COUNT(fa.film_id) AS film_count
    FROM 
        film_actor fa
    JOIN 
        actor a ON fa.actor_id = a.actor_id
    GROUP BY 
        fa.actor_id, a.first_name, a.last_name
	),
	max_actor_film AS (
		SELECT 
			fa.film_id, 
			afc.actor_id, 
			afc.first_name, 
			afc.last_name, 
			afc.film_count,
			ROW_NUMBER() OVER (PARTITION BY fa.film_id ORDER BY afc.film_count DESC) AS rnk
		FROM 
			film_actor fa
		JOIN 
			actor_film_count afc ON fa.actor_id = afc.actor_id
	)
	SELECT 
		f.title,
		ma.first_name,
		ma.last_name,
		ma.film_count
	FROM 
		max_actor_film ma
	JOIN 
		film f ON ma.film_id = f.film_id
	WHERE 
		ma.rnk = 1;

-- ## Challenge 2

-- This challenge involves analyzing customer activity and retention in the Sakila database to gain insight into business performance. 
-- By analyzing customer behavior over time, businesses can identify trends and make data-driven decisions to improve customer retention and increase revenue.

-- The goal of this exercise is to perform a comprehensive analysis of customer activity and retention by conducting an analysis on the monthly percentage 
-- change in the number of active customers and the number of retained customers. Use the Sakila database and progressively build queries to achieve the desired outcome. 

-- - Step 1. Retrieve the number of monthly active customers, i.e., the number of unique customers who rented a movie in each month.
-- - Step 2. Retrieve the number of active users in the previous month.
-- - Step 3. Calculate the percentage change in the number of active customers between the current and previous month.
-- - Step 4. Calculate the number of retained customers every month, i.e., customers who rented movies in the current and previous months.

-- *Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.*
	WITH monthly_active_customers AS (
    SELECT 
        DATE_TRUNC('month', rental_date) AS month, 
        COUNT(DISTINCT customer_id) AS active_customers
    FROM 
        rental
    GROUP BY 
        DATE_TRUNC('month', rental_date)
	),
	previous_month_customers AS (
		SELECT 
			month, 
			active_customers,
			LAG(active_customers) OVER (ORDER BY month) AS previous_month_customers
		FROM 
			monthly_active_customers
	),
	current_month_rentals AS (
		SELECT 
			DATE_TRUNC('month', rental_date) AS month, 
			customer_id
		FROM 
			rental
		GROUP BY 
			DATE_TRUNC('month', rental_date), 
			customer_id
	),
	previous_month_rentals AS (
		SELECT 
			DATE_TRUNC('month', rental_date) + INTERVAL '1 month' month, 
			customer_id
		FROM 
			rental
		GROUP BY 
			DATE_TRUNC('month', rental_date), 
			customer_id
	),
	retained_customers AS (
		SELECT 
			cmr.month, 
			COUNT(DISTINCT cmr.customer_id) AS retained_customers
		FROM 
			current_month_rentals cmr
		JOIN 
			previous_month_rentals pmr ON cmr.customer_id = pmr.customer_id AND cmr.month = pmr.month
		GROUP BY 
			cmr.month
	)
	SELECT 
		pmc.month, 
		pmc.active_customers, 
		pmc.previous_month_customers, 
		ROUND(
			(pmc.active_customers - pmc.previous_month_customers) * 100.0 / NULLIF(pmc.previous_month_customers, 0), 
			2
		) AS percentage_change,
		rc.retained_customers
	FROM 
		previous_month_customers pmc
	LEFT JOIN 
		retained_customers rc ON pmc.month = rc.month;
