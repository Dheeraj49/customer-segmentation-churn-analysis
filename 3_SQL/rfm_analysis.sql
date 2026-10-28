CREATE DATABASE IF NOT EXISTS customer_analytics;
USE customer_analytics;

DROP TABLE IF EXISTS retail_tx;
CREATE TABLE retail_tx (
  invoice      VARCHAR(10),
  invoice_date DATETIME,
  customer_id  INT,
  revenue      DECIMAL(12,2)
);

# Load dATA

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/retail_rfm_input.csv'
INTO TABLE retail_tx
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;


SELECT COUNT(*) AS line_items, SUM(revenue) AS revenue FROM retail_tx;


SELECT MAX(invoice_date) AS last_invoice FROM retail_tx;

#One row per customer

DROP TABLE IF EXISTS customer_summary;
CREATE TABLE customer_summary AS
SELECT
  customer_id,
  TIMESTAMPDIFF(DAY, MAX(invoice_date), '2011-12-10 12:50:00') AS recency,
  COUNT(DISTINCT invoice)                                        AS frequency,
  SUM(revenue)                                                   AS monetary
FROM retail_tx
GROUP BY customer_id;


SELECT COUNT(*) AS customers FROM customer_summary;

#Scores (1-5) 
DROP TABLE IF EXISTS rfm_scores;
CREATE TABLE rfm_scores AS
SELECT
  customer_id, recency, frequency, monetary,
  CASE
    WHEN recency <= 30  THEN 5
    WHEN recency <= 90  THEN 4
    WHEN recency <= 180 THEN 3
    WHEN recency <= 365 THEN 2
    ELSE 1
  END AS r,
  CASE
    WHEN frequency = 1  THEN 1
    WHEN frequency = 2  THEN 2
    WHEN frequency <= 5 THEN 3
    WHEN frequency <= 10 THEN 4
    ELSE 5
  END AS f
FROM customer_summary;

#Segments 
DROP TABLE IF EXISTS rfm_segments;
CREATE TABLE rfm_segments AS
SELECT
  *,
  CASE
    WHEN r >= 4 AND f >= 4 THEN 'Champions'
    WHEN r >= 4 AND f = 1  THEN 'New Customers'
    WHEN r >= 4            THEN 'Potential Loyalists'
    WHEN r = 3  AND f >= 3 THEN 'Loyal Customers'
    WHEN r = 3             THEN 'Need Attention'
    WHEN f >= 3            THEN 'At Risk'
    ELSE 'Lost'
  END AS segment
FROM rfm_scores;

#Segment summary 

SELECT
  segment,
  COUNT(*)                 AS customers,
  ROUND(AVG(recency), 1)   AS avg_recency_days,
  ROUND(AVG(frequency), 1) AS avg_orders,
  ROUND(SUM(monetary), 2)  AS revenue
FROM rfm_segments
GROUP BY segment
ORDER BY revenue DESC;

#Top 10 "At Risk" customers 
SELECT customer_id, recency, frequency, ROUND(monetary, 2) AS monetary
FROM rfm_segments
WHERE segment = 'At Risk'
ORDER BY monetary DESC
LIMIT 10;

#Segment’s revenue by year
SELECT s.segment,
       ROUND(SUM(CASE WHEN YEAR(t.invoice_date) = 2010 THEN t.revenue ELSE 0 END), 2) AS revenue_2010,
       ROUND(SUM(CASE WHEN YEAR(t.invoice_date) = 2011 THEN t.revenue ELSE 0 END), 2) AS revenue_2011
FROM retail_tx t
INNER JOIN rfm_segments s
        ON t.customer_id = s.customer_id
GROUP BY s.segment
ORDER BY revenue_2011 DESC;
