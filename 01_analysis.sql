USE interview;

-- =====================================================
-- SEGMENT 1: DATABASE EXPLORATION & CLEANING
-- =====================================================

-- Check row counts in each table
SELECT COUNT(*) FROM agents;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM customer;

-- Check for missing (NULL) values
SELECT * FROM agents WHERE AGENT_NAME IS NULL;
SELECT * FROM customer WHERE CUST_NAME IS NULL OR AGENT_CODE IS NULL;
SELECT * FROM orders WHERE CUST_CODE IS NULL OR AGENT_CODE IS NULL;

-- Check for duplicate customer names
SELECT CUST_NAME, COUNT(*) 
FROM customer 
GROUP BY CUST_NAME 
HAVING COUNT(*) > 1;

-- Orphan check: agent codes in orders that don't exist in agents
SELECT DISTINCT o.AGENT_CODE
FROM orders o
LEFT JOIN agents a ON o.AGENT_CODE = a.AGENT_CODE
WHERE a.AGENT_CODE IS NULL;
-- Result: A013 appears in orders (2 orders) but not in agents.



-- =====================================================
-- SEGMENT 2: BASIC SALES ANALYSIS
-- =====================================================

-- Total number of orders, total revenue, and average order value
SELECT COUNT(*) AS total_orders, 
       SUM(ORD_AMOUNT) AS total_revenue, 
       AVG(ORD_AMOUNT) AS avg_order_value
FROM orders;

-- Agent with the most high-grade customers
-- Note: Assignment specifies grade 5, but this dataset's GRADE column only 
-- goes up to 3. Using MAX(GRADE) to dynamically find the actual top grade
-- present in the data, rather than hardcoding a value that doesn't exist.
SELECT a.AGENT_NAME, COUNT(*) AS high_grade_customers
FROM customer c
JOIN agents a ON c.AGENT_CODE = a.AGENT_CODE
WHERE c.GRADE = (SELECT MAX(GRADE) FROM customer)
GROUP BY a.AGENT_NAME
ORDER BY high_grade_customers DESC;

-- Query 3: Top 3 cities by total order amount
SELECT c.CUST_CITY, SUM(o.ORD_AMOUNT) AS city_total
FROM orders o
JOIN customer c ON o.CUST_CODE = c.CUST_CODE
GROUP BY c.CUST_CITY
ORDER BY city_total DESC
LIMIT 3;

-- Extra: Monthly sales trend
SELECT MONTH(ORD_DATE) AS order_month,
       COUNT(*) AS total_orders,
       SUM(ORD_AMOUNT) AS monthly_revenue
FROM orders
GROUP BY MONTH(ORD_DATE)
ORDER BY order_month;



-- =====================================================
-- SEGMENT 3: CUSTOMER ANALYSIS
-- =====================================================

-- Total number of customers
SELECT COUNT(*) AS total_customers FROM customer;

-- Top 5 spending customers (by total order amount)
SELECT c.CUST_NAME, SUM(o.ORD_AMOUNT) AS total_spent
FROM orders o
JOIN customer c ON o.CUST_CODE = c.CUST_CODE
GROUP BY c.CUST_NAME
ORDER BY total_spent DESC
LIMIT 5;

-- Percentage of customers who placed more than one order (repeat customers)
SELECT 
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_count > 1 THEN CUST_CODE END) 
        / COUNT(DISTINCT CUST_CODE), 2) AS repeat_customer_pct
FROM (
  SELECT CUST_CODE, COUNT(*) AS order_count
  FROM orders
  GROUP BY CUST_CODE
) sub;

--  Customer with the highest outstanding amount, per country
SELECT CUST_COUNTRY, CUST_NAME, OUTSTANDING_AMT
FROM customer c1
WHERE OUTSTANDING_AMT = (
  SELECT MAX(OUTSTANDING_AMT) 
  FROM customer c2 
  WHERE c1.CUST_COUNTRY = c2.CUST_COUNTRY
)
ORDER BY CUST_COUNTRY;

-- Percentage of customers in each grade
SELECT GRADE, 
       COUNT(*) AS num_customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer), 2) AS pct_of_total
FROM customer
GROUP BY GRADE
ORDER BY GRADE;  


-- =====================================================
-- SEGMENT 4: AGENT PERFORMANCE
-- =====================================================

-- Query 1: Top 5 agents by total order amount handled
SELECT a.AGENT_NAME, SUM(o.ORD_AMOUNT) AS total_handled
FROM orders o
JOIN agents a ON o.AGENT_CODE = a.AGENT_CODE
GROUP BY a.AGENT_NAME
ORDER BY total_handled DESC
LIMIT 5;

-- Query 2: Rank agents by number of orders handled
SELECT a.AGENT_NAME, 
       COUNT(o.ORD_NUM) AS orders_handled,
       RANK() OVER (ORDER BY COUNT(o.ORD_NUM) DESC) AS agent_rank
FROM orders o
JOIN agents a ON o.AGENT_CODE = a.AGENT_CODE
GROUP BY a.AGENT_NAME;

-- Query 3: Agents whose average advance amount collected is below the overall average
-- (used here as an example rule for flagging agents who might need a commission review)
SELECT a.AGENT_NAME, AVG(o.ADVANCE_AMOUNT) AS avg_advance
FROM orders o
JOIN agents a ON o.AGENT_CODE = a.AGENT_CODE
GROUP BY a.AGENT_NAME
HAVING AVG(o.ADVANCE_AMOUNT) < (SELECT AVG(ADVANCE_AMOUNT) FROM orders)
ORDER BY avg_advance;


-- =====================================================
-- SEGMENT 5: ADVANCED SQL TASKS
-- =====================================================

-- Query 1: Calculated column - average receive amount per country
-- Each customer row gets an extra column showing the average RECEIVE_AMT
-- of all customers in the same country (needs MySQL 8.0+).
SELECT CUST_NAME,
       CUST_COUNTRY,
       RECEIVE_AMT,
       ROUND(AVG(RECEIVE_AMT) OVER (PARTITION BY CUST_COUNTRY), 2) AS avg_receive_amt_country
FROM customer;


-- Query 2: User-Defined Function (UDF)
-- Classifies a customer's risk level based on their outstanding amount.
DROP FUNCTION IF EXISTS classify_outstanding;
DELIMITER //
CREATE FUNCTION classify_outstanding(amt DECIMAL(12,2))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
  DECLARE result VARCHAR(20);
  IF amt >= 10000 THEN
    SET result = 'High Risk';
  ELSEIF amt >= 5000 THEN
    SET result = 'Medium Risk';
  ELSE
    SET result = 'Low Risk';
  END IF;
  RETURN result;
END //
DELIMITER ;

-- Use the function
SELECT CUST_NAME, OUTSTANDING_AMT, classify_outstanding(OUTSTANDING_AMT) AS risk_level
FROM customer;


-- Query 3: Stored Subroutine (stored procedure with a parameter)
-- Returns all customers of a country you pass in.
DROP PROCEDURE IF EXISTS get_customers_by_country;

CREATE PROCEDURE get_customers_by_country(IN p_country VARCHAR(20))
SELECT CUST_NAME, CUST_CITY, GRADE, OUTSTANDING_AMT
FROM customer
WHERE CUST_COUNTRY = p_country
ORDER BY OUTSTANDING_AMT DESC;

-- Run it
CALL get_customers_by_country('India');


-- Query 4: Stored Procedure using a Cursor
-- Goes through agents one by one and saves each agent's order count.
DROP PROCEDURE IF EXISTS agent_order_summary; 
DELIMITER //
CREATE PROCEDURE agent_order_summary()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_agent_name VARCHAR(40);
  DECLARE v_order_count INT;

  DECLARE cur CURSOR FOR
    SELECT a.AGENT_NAME, COUNT(o.ORD_NUM)
    FROM agents a
    LEFT JOIN orders o ON a.AGENT_CODE = o.AGENT_CODE
    GROUP BY a.AGENT_NAME;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  DROP TEMPORARY TABLE IF EXISTS agent_summary_result;
  CREATE TEMPORARY TABLE agent_summary_result (
    agent_name VARCHAR(40),
    order_count INT
  );

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_agent_name, v_order_count;
    IF done = 1 THEN
      LEAVE read_loop;
    END IF;
    INSERT INTO agent_summary_result VALUES (v_agent_name, v_order_count);
  END LOOP;
  CLOSE cur;

  SELECT * FROM agent_summary_result ORDER BY order_count DESC;
END //
DELIMITER ;

-- Run it
CALL agent_order_summary();







