-- Inspecting Data
SELECT * FROM dbo.sales_data_sample

-- Checking unique values
SELECT DISTINCT STATUS FROM dbo.sales_data_sample -- Nice one to plot
SELECT DISTINCT YEAR_ID FROM dbo.sales_data_sample
SELECT DISTINCT PRODUCTLINE FROM dbo.sales_data_sample -- Nice one to plot
SELECT DISTINCT COUNTRY FROM dbo.sales_data_sample -- Nice one to plot
SELECT DISTINCT DEALSIZE FROM dbo.sales_data_sample -- Nice one to plot
SELECT DISTINCT TERRITORY FROM dbo.sales_data_sample -- Nice one to plot



/* SALES ANALYSIS */ 

-- Grouping sales by productline
SELECT
	PRODUCTLINE,
	SUM(SALES) AS REVENUE
FROM dbo.sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

-- Grouping sales by year
SELECT
	YEAR_ID,
	SUM(SALES) AS REVENUE
FROM dbo.sales_data_sample
GROUP BY YEAR_ID
ORDER BY 2 DESC
	-- Calculate how many Months have they operated in 2005
	-- to explain why Revenue in 2005 is much smaller than in 2004
	SELECT DISTINCT MONTH_ID
	FROM dbo.sales_data_sample
	WHERE YEAR_ID = 2005 --> change the year to see the rest
	--> They have operated 5 months in 2005 and full year in 2003 and 2004


-- Grouping sales by DealSize
SELECT
	DEALSIZE,
	SUM(SALES) AS REVENUE
FROM dbo.sales_data_sample
GROUP BY DEALSIZE
ORDER BY 2 DESC

-- What was the best month for sales in a specific year?
-- How much was earned in that month?
SELECT
	MONTH_ID,
	COUNT(ORDERNUMBER) AS FREQUENCY,
	SUM(SALES) AS REVENUE
FROM dbo.sales_data_sample
WHERE YEAR_ID = 2004 --> change the year to see the rest
GROUP BY MONTH_ID
ORDER BY 3 DESC --> November seems to be the best month for sales

-- Which product was sell the most the in best month (November)?
SELECT
	MONTH_ID,
	PRODUCTLINE,
	COUNT(ORDERNUMBER) AS FREQUENCY,
	SUM(SALES) AS REVENUE
FROM dbo.sales_data_sample
WHERE YEAR_ID = 2004 AND MONTH_ID = 11 --> change the year to see the rest
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 4 DESC



/* RFM Analysis */

-- Who is the best customer?
DROP TABLE IF EXISTS #rfm;
WITH rfm AS
(
	SELECT
		CUSTOMERNAME,
		SUM(SALES) AS Monetary_value,
		AVG(SALES) AS AVG_Monetary_value,
		COUNT(ORDERNUMBER) AS FREQUENCY,
		MAX(ORDERDATE) AS Last_order_date,
		(SELECT MAX(ORDERDATE) FROM dbo.sales_data_sample) Max_order_date,
		DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM dbo.sales_data_sample)) AS RECENCY
	FROM dbo.sales_data_sample
	GROUP BY CUSTOMERNAME
),

rfm_calc AS 
(
	SELECT
		*,
		NTILE(3) OVER (ORDER BY rfm.RECENCY DESC) recency_rank,
		NTILE(3) OVER (ORDER BY rfm.FREQUENCY) frequency_rank,
		NTILE(3) OVER (ORDER BY rfm.AVG_Monetary_value) monetary_rank
		--> 3 is the highest rfm point and 1 is the lowest one
	FROM rfm 
)

SELECT
	*,
	(rfm_calc.recency_rank + rfm_calc.frequency_rank + rfm_calc.monetary_rank) AS rfm_score,
	CONCAT(rfm_calc.recency_rank, rfm_calc.frequency_rank, rfm_calc.monetary_rank) AS rfm_rank
INTO #rfm
FROM rfm_calc

SELECT *
FROM #rfm

SELECT *
FROM #rfm
WHERE recency_rank >= 2 AND frequency_rank >= 2 AND monetary_rank >= 2
ORDER BY rfm_score DESC
--> There are 30/92 customers who have rfm_score >= 6 (9 is the maximum point) and rencecy_rank, frequency_rank and monetary_rank >= 2 (3 is max)


-- Who are the top 10% of our customers based on their overall RFM score (sum of recency, frequency and monetary)?
SELECT TOP 10 PERCENT
	CUSTOMERNAME,
	RECENCY,
	FREQUENCY,
	ROUND(Monetary_value,1) AS MONETARY_VAL,
	recency_rank,
	frequency_rank,
	monetary_rank,
	rfm_score
FROM #rfm
ORDER BY rfm_score DESC
--> here is the result:
/*
CUSTOMERNAME			RECENCY	FREQUENCY	MONETARY_VAL	recency_rank	frequency_rank	monetary_rank	rfm_score
Salzburg Collectables		14	40		149798.6	3		3		3		9
Tokyo Collectables, Ltd		39	32		120562.7	3		3		3		9
Diecast Classics Inc.		1	31		122138.1	3		3		3		9
The Sharp Gifts Warehouse	39	40		160010.3	3		3		3		9
Dragon Souveniers, Ltd.		90	43		172989.7	3		3		3		9
Danish Wholesale Imports	46	36		145041.6	3		3		3		9
UK Collectables, Ltd.		53	29		118008.3	3		2		3		8
Gift Depot Inc.			26	25		101894.8	3		2		3		8
Muscle Machine Inc		181	48		197736.9	2		3		3		8
Online Diecast Creations Co.	208	34		131685.3	2		3		3		8
*/
--> We can see that there are 7/10 customers who bought our goods less than 90 days ago (recency <90), 
-- so that the other 3 customers may are wholesale customer (with monetary_rank = 3)


-- Classify customers into RFM segmentation
SELECT 
	CUSTOMERNAME,
	recency_rank,
	frequency_rank,
	monetary_rank,
	CASE
		WHEN rfm_rank IN (333, 332, 323) THEN 'VIP'
		WHEN rfm_rank IN (313) THEN 'VIP, Wholesale customer'
		WHEN rfm_rank IN (331, 322, 321, 312) THEN 'Normal'
		WHEN rfm_rank IN (233, 223, 213, 133, 123, 113) THEN 'VIP but churning/churned'
		WHEN rfm_rank IN (232, 231, 222, 221, 212, 211) THEN 'Potential churners'
		ELSE 'Lost custommer'
		END AS rfm_segment
FROM #rfm


-- What is the distribution of RFM segmentation across our customer base?
SELECT
	rfm_segment,
	COUNT(rfm_segment) AS count_customers
FROM (
	SELECT 
		CUSTOMERNAME,
		recency_rank,
		frequency_rank,
		monetary_rank,
		CASE
			WHEN rfm_rank IN (333, 332, 323) THEN 'VIP'
			WHEN rfm_rank IN (313) THEN 'VIP, Wholesale customer'
			WHEN rfm_rank IN (331, 322, 321, 312) THEN 'Normal'
			WHEN rfm_rank IN (233, 223, 213, 133, 123, 113) THEN 'VIP but churning/churned'
			WHEN rfm_rank IN (232, 231, 222, 221, 212, 211) THEN 'Potential churners'
			ELSE 'Lost custommer'
			END AS rfm_segment
	FROM #rfm
) AS rfm_rank
GROUP BY rfm_segment
ORDER BY 2 DESC
-- Here is the result:
/*
rfm_segment			count_customers
Lost custommer			22
Potential churners		22
VIP but churning/churned	18
VIP				15
Normal				12
VIP, Wholesale customer		3
*/
--> We can see that customers are classified as 'Lost customer' or 'Potential churners' that account for the largest percentage.
-- That means we have problem in customer retention policies and advertising/marketing programs or something else.
-- One thing that positive in the analytic is the percentage of customers who are classifed as 'VIP' or 'VIP, Wholesale customer' is nearly 20%
-- but we have to change policies or plan new marketing programs to make it better.

