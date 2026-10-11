# Sales and Support Analysis using SQL (Fliipazon Retail)

A practice SQL project that analyzes sales trends, customer behavior and support agent performance for a retail business using MySQL.

## Objective
Use SQL to answer business questions about sales, customers and agents, and to check the quality of the data before analyzing it.

## Dataset
Three related tables:

| Table | Rows | What it holds |
|---|---|---|
| `agents` | 12 | Support agents, working area, commission |
| `customer` | 25 | Customers, city, country, grade, amounts received, paid and outstanding |
| `orders` | 36 | Orders with amount, advance paid, date, customer and agent |

## How to run
1. Open MySQL Workbench and run `01_setup.sql`. It creates the `interview` database, the three tables and the data.
2. Run `02_analysis.sql`. It contains all the queries.

To start again from scratch, run `DROP DATABASE IF EXISTS interview;` first, then repeat step 1. Window functions need MySQL 8.0 or newer.

## What I did
- **Segment 1, data quality:** row counts, NULL checks, duplicate check, and a check for orders that point to an unknown agent.
- **Segment 2, sales analysis:** total orders, revenue and average order value; top cities; best agent for top-grade customers; monthly sales trend.
- **Segment 3, customer analysis:** top spenders, repeat-customer percentage, highest outstanding amount per country, grade distribution.
- **Segment 4, agent performance:** top agents by order value, ranking by number of orders, agents with below-average advance payments.
- **Segment 5, advanced SQL:** window function (calculated column), user-defined function, stored procedure with a parameter, and a stored procedure using a cursor.

SQL concepts used: JOIN, GROUP BY, HAVING, subqueries (including correlated), CASE, window functions (RANK, AVG OVER), user-defined functions, stored procedures, cursors.

## Data quality notes
- No NULL values and no duplicate customer names.
- Agent code **A013** appears in 2 orders (total 6,000) but does not exist in the `agents` table. Agent-level queries use an inner join, so these two orders are left out of agent totals.
- The assignment refers to grade 5 customers, but the `GRADE` column only has values 0 to 3. I used `MAX(GRADE)` so the query finds the real top grade instead of returning an empty result.
- The `COUNTRY` column in `agents` holds no usable values, and several customer phone numbers are placeholders (for example `BBBBBBB`). These columns were not used in the analysis.

## Key insights
- **Revenue:** 36 orders worth 78,600 in total, an average order value of about 2,183.
- **Top cities:** Chennai leads with 17,000 (about 22% of revenue), followed by Mumbai (12,700) and London (12,500).
- **Seasonality:** July was the strongest month with 11 orders and 22,500 (about 29% of revenue). September (14,700) and August (12,900) came next, and January had the fewest sales.
- **Agents:** Santakumar handled the highest order value (17,000). Mukesh handled the most orders (7) and was second by value (12,700).
- **Top-grade customers:** Alford has the most grade 3 customers (2 of the 5).
- **Customers:** Ramanathan is the top spender at 10,500 across 3 orders. 8 of the 25 customers (32%) placed more than one order.
- **Grade mix:** 40% of customers are grade 2, 36% grade 1, 20% grade 3 and 4% grade 0.
- **Outstanding amounts:** In India, three customers tie for the highest outstanding amount at 12,000 (Ramesh, Rangarappa and Venkatpati).

## Tools
MySQL 8, MySQL Workbench

## Note
This is a learning project built on a small sample dataset (12, 25 and 36 rows), so the findings describe this sample only.
