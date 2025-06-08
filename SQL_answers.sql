USE maven_advanced_sql;

-- Joins
-- ASSIGNMENT 1: Basic Joins
-- Looking at the orders and products tables, which products exist in one table, but not the other?

SELECT pd.product_id, pd.product_name, od.order_id AS product_id_in_orders
FROM products AS pd 
	 LEFT JOIN orders AS od
     ON pd.product_id = od.product_id
WHERE od.order_id IS NULL;

-- ASSIGNMENT 2: Self Joins
-- Which products are within 25 cents of each other in terms of unit price?

SELECT p1.product_name, p1.unit_price,
       p2.product_name, p2.unit_price,
       p1.unit_price - p2.unit_price AS price_diff
FROM products AS p1
	 LEFT JOIN products AS p2
     ON p1.product_id <> p2.product_id
WHERE ABS(p1.unit_price - p2.unit_price) < 0.25
ORDER BY price_diff DESC;

-- Subqueries
-- ASSIGNMENT 1: Subqueries in the SELECT clause
-- Return the product id, product name, unit price, average unit price,
-- and the difference between each unit price and the average unit price

SELECT product_id, product_name, unit_price,
	   (SELECT AVG(unit_price) FROM products) AS average_unit_price,
       unit_price - (SELECT AVG(unit_price) FROM products) AS diff_price
FROM products
ORDER BY diff_price DESC;

-- ASSIGNMENT 2: Subqueries in the FROM clause

-- Return the factories, product names from the factory
-- and number of products produced by each factory

SELECT p1.factory, p1.product_name, p2.num_of_products
FROM products AS p1
	 LEFT JOIN 
     (SELECT factory,COUNT(product_id) AS num_of_products
      FROM products
      GROUP BY factory) AS p2
      ON p1.factory = p2.factory
	  ORDER BY p1.factory, p2.num_of_products;

-- ASSIGNMENT 3: Subqueries in the WHERE clause

-- Return products where the unit price is less than
-- the unit price of all products from Wicked Choccy's

SELECT *
FROM products
WHERE unit_price < (SELECT MIN(unit_price)
					FROM products
                    WHERE factory = "Wicked Choccy's");
                    

-- ASSIGNMENT 4: CTEs

-- Return the number of orders over $200

WITH tas AS (SELECT o.order_id, 
						 SUM(o.units * p.unit_price) AS total_amount_spent
						 FROM orders AS o
                         INNER JOIN products AS p
                         ON o.product_id = p.product_id
                         GROUP BY o.order_id
                         HAVING total_amount_spent > 200)
                         
SELECT COUNT(total_amount_spent)
FROM tas;

-- ASSIGNMENT 5: Multiple CTEs

-- Copy over Assignment 2 (Subqueries in the FROM clause) solution

WITH p1 AS (SELECT factory, product_name FROM products),
	 np AS (SELECT factory,COUNT(product_id) num_products
				  FROM products
                  GROUP BY factory)

SELECT p1.factory, p1.product_name, np.num_products
FROM p1 LEFT JOIN np
      ON p1.factory = np.factory
ORDER BY p1.factory, np.num_products;

-- Window function
-- ASSIGNMENT 1: Window function basics
-- For each customer, add a column for transaction number

SELECT *,
		 ROW_NUMBER() OVER(PARTITION BY customer_id 
						   ORDER BY transaction_id DESC) AS transaction_number
FROM orders
ORDER BY customer_id, transaction_id;


-- ASSIGNMENT 2: Row Number vs Rank vs Dense Rank

-- For each order, rank the products from most units to fewest units
-- If there's a tie, keep the tie and don't skip to the next number after

SELECT *,
		DENSE_RANK() OVER(PARTITION BY order_id ORDER BY units) AS ranking_prod
FROM orders
ORDER BY order_id, ranking_prod;

-- ASSIGNMENT 3: First Value vs Last Value vs Nth Value

-- Add a column that contains the 2nd most popular product
SELECT * FROM
(SELECT	order_id, product_id, units,
		NTH_VALUE(product_id,2) OVER(PARTITION BY order_id ORDER BY units) AS second_prod
FROM orders
ORDER BY order_id, second_prod) AS sp
WHERE product_id = second_prod;


-- Alternative using DENSE RANK
SELECT * FROM 
(SELECT order_id, product_id, units,
		DENSE_RANK() OVER(PARTITION BY order_id ORDER BY units) AS ranking_prod
	  FROM orders
      ORDER BY order_id, ranking_prod) AS pr
WHERE ranking_prod = 2;


-- ASSIGNMENT 4: Lead & Lag

WITH tu AS
		(SELECT customer_id, order_id, MIN(transaction_id) AS min_tid, SUM(units) AS total_units
		FROM orders
		GROUP BY customer_id, order_id
		ORDER BY customer_id, min_tid),
        
	pu AS 
		(SELECT customer_id, order_id, total_units,
			LAG(total_units) OVER(PARTITION BY customer_id ORDER BY min_tid) AS prior_units
			FROM tu)

SELECT *,
		total_units - prior_units AS diff_units
FROM pu;

-- ASSIGNMENT 5: NTILE

SELECT * 
FROM orders;

SELECT * 
FROM products;

WITH taso AS (SELECT o.order_id, 
						 SUM(o.units * p.unit_price) AS total_amount_spent_o
						 FROM orders AS o
                         INNER JOIN products AS p
                         ON o.product_id = p.product_id
                         GROUP BY o.order_id),
                         
	 ctas AS (SELECT o.customer_id, SUM(taso.total_amount_spent_o) AS total_amount_spent
			  FROM orders AS o
              INNER JOIN taso
              ON o.order_id = taso.order_id
              GROUP BY o.customer_id),

	 one_pd AS (SELECT *,
					NTILE(100) OVER(ORDER BY total_amount_spent DESC) AS one_p
				FROM ctas)

SELECT *
FROM one_pd
WHERE one_p = 1;

-- Functions
-- ASSIGNMENT 1: Numeric functions

WITH taso AS (SELECT o.order_id, 
						 SUM(o.units * p.unit_price) AS total_amount_spent_o
						 FROM orders AS o
                         INNER JOIN products AS p
                         ON o.product_id = p.product_id
                         GROUP BY o.order_id),
                         
	 ctas AS (SELECT o.customer_id, SUM(taso.total_amount_spent_o) AS total_amount_spent
			  FROM orders AS o
              INNER JOIN taso
              ON o.order_id = taso.order_id
              GROUP BY o.customer_id),
              
	ftas AS (SELECT *, FLOOR(total_amount_spent/10)*10 AS amount_bins
			FROM ctas)

SELECT amount_bins,COUNT(customer_id) AS num_customers
FROM ftas
GROUP BY amount_bins
ORDER BY amount_bins;


-- ASSIGNMENT 2: Datetime functions

SELECT order_id, order_date,
	   DATE_ADD(order_date, INTERVAL 2 DAY) AS ship_date
FROM orders
WHERE YEAR(order_date) = 2024 AND MONTH(order_date) BETWEEN 4 AND 6;

-- ASSIGNMENT 3: String functions
WITH fc AS (SELECT factory , product_id, 
			   UPPER(REPLACE(REPLACE(factory, "'", ''), ' ', '-')) AS factory_clean
			FROM products)

SELECT factory , product_id,
	   CONCAT(factory_clean, '-', product_id) AS factory_product_id
FROM fc;

-- ASSIGNMENT 4: Pattern matching

-- Only extract text after the hyphen for Wonka Bars
SELECT	 product_name,
		 REPLACE(product_name, 'Wonka Bar - ', '') AS new_product_name
FROM	 products
WHERE product_name LIKE 'Wonka Bar %';

-- Alternative using substrings
SELECT	 product_name,
		 CASE WHEN INSTR(product_name, '-') = 0 THEN product_name
			  ELSE SUBSTR(product_name, INSTR(product_name, '-') + 2) END new_product_name
FROM products;

-- ASSIGNMENT 5: Null functions

-- Replace NULL values with Other
SELECT product_name, factory, division,
	   COALESCE(division,'Other') division_other
FROM products;

-- Replace NULL values with top division for each factory
WITH np AS (SELECT factory, division, COUNT(division) AS num_products
			FROM products
			WHERE division IS NOT NULL
			GROUP BY factory, division
            ORDER BY factory, division),
            
	 np_rank AS (SELECT *,
				 ROW_NUMBER() OVER(PARTITION BY factory ORDER BY num_products) AS np_rank
                 FROM np),
                 
	 mode_div AS (SELECT factory, division
				  FROM np_rank
                  WHERE np_rank = 1)

SELECT p.product_name, md.factory, p.division,
	    COALESCE(p.division, md.division) AS top_division
FROM products AS p
				LEFT JOIN mode_div AS md
				ON p.factory = md.factory
ORDER BY p.factory, p.division;

-- Data Analysis Applications

-- ASSIGNMENT 1: Duplicate values
WITH sc AS (SELECT DISTINCT *,
				   ROW_NUMBER() OVER(PARTITION BY student_name ORDER BY id) AS row_num
			FROM students)

SELECT id, student_name, email
FROM sc 
WHERE row_num = 1;

-- ASSIGNMENT 2: Min / max value filtering

SELECT s.student_name, sg.class_name, mg.fg
FROM 
		(SELECT student_id ,MAX(final_grade) AS fg
		FROM student_grades
		GROUP BY student_id) AS mg
		LEFT JOIN student_grades AS sg
		ON mg.student_id = sg.student_id
		AND mg.fg = sg.final_grade
        LEFT JOIN students s
        ON mg.student_id = s.id
ORDER BY mg.student_id;
                    
-- ASSIGNMENT 3: Pivoting

SELECT sg.department,
	   ROUND(AVG(CASE WHEN s.grade_level = 9 THEN sg.final_grade END)) AS freshman,
       ROUND(AVG(CASE WHEN s.grade_level = 10 THEN sg.final_grade END)) AS sophomore,
       ROUND(AVG(CASE WHEN s.grade_level = 11 THEN sg.final_grade END)) AS junior,
       ROUND(AVG(CASE WHEN s.grade_level = 12 THEN sg.final_grade END)) AS senior
FROM students AS s 
	 INNER JOIN 
     student_grades AS sg
     ON s.id = sg.student_id
GROUP BY department
ORDER BY department;

-- ASSIGNMENT 4: Rolling calculations

WITH ts AS (SELECT YEAR(O.order_date) AS yr, MONTH(o.order_date) AS mnth,
			  SUM(o.units * p.unit_price) AS total_sales
		FROM orders AS o LEFT JOIN products AS p
						 ON o.product_id = p.product_id
		GROUP BY YEAR(O.order_date), MONTH(o.order_date)
		ORDER BY YEAR(O.order_date), MONTH(o.order_date))
        
SELECT *,
		SUM(total_sales) OVER(ORDER BY yr, mnth) AS cumulative_sum,
        AVG(total_sales) OVER(ORDER BY yr, mnth ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
        AS six_month_ma
FROM ts;



