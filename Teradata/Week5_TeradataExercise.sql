/*------------------------
Teradata Week 5 Exercises
(JDTGanding, 2020)
------------------------*/


/*----------------------Exercise 1-------------------------
How many distinct dates are there in the saledate column of 
trnsact for each month/year combination?

OUTPUT: Data from Aug 2004 to Aug 2005, with Aug 2005 having
only 27 days of transaction. Meanwhile, Dec only have 30 
days (due to Christmas), Nov only have 29 days (due to
Thanksgiving) and March only have 30 days (unknown causes)
----------------------------------------------------------*/

SELECT 
	EXTRACT(YEAR from t.saledate) AS DateYear,
	EXTRACT(MONTH from t.saledate) AS DateMonth,
	COUNT(DISTINCT t.saledate) AS CountDate
FROM trnsact t
GROUP BY 
	EXTRACT(YEAR from t.saledate),
	EXTRACT(MONTH from t.saledate)
ORDER BY DateYear, DateMonth;


/*----------------------Exercise 2-------------------------
Determine which sku had the greatest total sales during the
combined summer months of June, July and August.
----------------------------------------------------------*/

SELECT TOP 1 t.sku AS SkuItem, 
	SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=6 
		THEN t.amt END) AS JuneSales,
	SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=7
		THEN t.amt END) AS JulySales,
	SUM(CASE WHEN EXTRACT(MONTH from t.saledate)=8
		THEN t.amt END) AS AugSales,
	(JuneSales + JulySales + AugSales) AS Total
FROM trnsact t
WHERE t.stype='P' AND t.sprice <> 0
GROUP BY t.sku
ORDER BY Total DESC; 


/*----------------------Exercise 3-------------------------
How many distinct dates are in the saledate column of the
trnsact table for each month/year/store combination?
----------------------------------------------------------*/

SELECT 
	EXTRACT(YEAR from t.saledate) AS YearDate,
	EXTRACT(MONTH from t.saledate) AS MonthDate,
	t.store AS Store, 
	COUNT(DISTINCT t.saledate) AS NumDays
FROM trnsact t
GROUP BY 
	EXTRACT(YEAR from t.saledate),
	EXTRACT(MONTH from t.saledate),t.store
ORDER BY NumDays ASC;


/*----------------------Exercise 4-------------------------
Determine average daily revenue for each store/month/year
combination. We note that in some stores there is only 1
recorded transaction due to errors or deleted data. Hence,
we would get the average within a time period instead of 
using AVG() directly to avoid bias in our data.

We remove any data on Aug 2005 since it has incomplete num
of transactions (only 27 days) 
----------------------------------------------------------*/

SELECT 
	EXTRACT(YEAR from sub.saledate) || 
	EXTRACT(MONTH from sub.saledate) AS TrnsactDate,
	sub.store AS Store, 
	COUNT(DISTINCT sub.saledate) AS NumDays,
	(SUM(sub.amt)/NumDays) AS Revenue
FROM (
	SELECT t.saledate,t.store,t.amt 
    FROM trnsact t
    WHERE 
		t.sprice <> 0 AND t.stype='P'
		AND NOT (EXTRACT(YEAR from t.saledate) = 2005
		AND EXTRACT(MONTH from t.saledate) = 8)) AS sub		
GROUP BY 
	EXTRACT(YEAR from sub.saledate) || 
	EXTRACT(MONTH from sub.saledate),
	sub.store
HAVING COUNT(DISTINCT sub.saledate) >= 20
ORDER BY Revenue DESC;

/*----------------------Exercise 5-------------------------
Determine average daily revenue brought in by stores in 
areas of high, medium, or low levels of high school educ?
		low: 50-60% high school graduates
		medium: 60.01-70% high school graduates
		high: >70% high school graduates
----------------------------------------------------------*/

SELECT 
	msa.hs_ranking, 
	SUM(sub.Revenue)/SUM(sub.NumDays) AS AvgDailyRev
FROM (
		SELECT 
			store, COUNT(DISTINCT saledate) AS NumDays, 
			SUM(amt) AS Revenue
		FROM trnsact
		WHERE 
			sprice <> 0 AND stype='P' AND NOT
			(EXTRACT(YEAR from t.saledate) = 2005
			AND EXTRACT(MONTH from t.saledate) = 8)
		GROUP BY store
		HAVING NumDays >= 20 ) AS sub
INNER JOIN (
		SELECT store, CASE 
			WHEN (msa_high >= 50 AND msa_high <= 60) 
				THEN 'low'
			WHEN (msa_high > 60 AND msa_high <= 70) 
				THEN 'medium'
			WHEN msa_high > 70 
				THEN 'high'
			ELSE 'very low' END AS hs_ranking 
		FROM store_msa ) AS msa
ON sub.store = msa.store
GROUP BY msa.hs_ranking
ORDER BY AvgDailyRev DESC;


/*----------------------Exercise 6-------------------------
Compare the average daily revenues of the stores with the 
highest median msa_income and the lowest mediam msa_income.
In what city and state were these stores, and which store 
has the higher average daily revenue?
----------------------------------------------------------*/

SELECT sub.store, msa.msa_income AS MidIncome, 
	msa.hs_ranking AS HSRank,
	SUM(sub.Revenue)/SUM(sub.NumDays) AS AvgDailyRev
FROM (
		SELECT 
			store, COUNT(DISTINCT saledate) AS NumDays, 
			SUM(amt) AS Revenue
		FROM trnsact
		WHERE 
			sprice <> 0 AND stype='P' AND NOT
			(EXTRACT(YEAR from t.saledate) = 2005
			AND EXTRACT(MONTH from t.saledate) = 8)
		GROUP BY store
		HAVING NumDays >= 20 ) AS sub
INNER JOIN (
		SELECT store, msa_income, CASE 
			WHEN (msa_high >= 50 AND msa_high <= 60) 
				THEN 'low'
			WHEN (msa_high > 60 AND msa_high <= 70) 
				THEN 'medium'
			WHEN msa_high > 70 
				THEN 'high'
			ELSE 'very low' END AS hs_ranking 
		FROM store_msa) AS msa
ON sub.store = msa.store
GROUP BY sub.store, msa.msa_income, msa.hs_ranking
ORDER BY MidIncome DESC;


/*----------------------Exercise 7-------------------------
What is the brand of the sku with the greatest standard dev
in sprice? Only examine skus that have been part of over 100
transactions.
----------------------------------------------------------*/

SELECT TOP 1
	sku.sku, sku.brand, 
	STDDEV_SAMP(t.sprice) AS PriceSTD, 
	COUNT(t.saledate) AS NumTrnsact
FROM trnsact t 
	INNER JOIN skuinfo sku ON t.sku = sku.sku
WHERE t.stype='P'
GROUP BY sku.sku, sku.brand
HAVING NumTrnsact > 100
ORDER BY PriceSTD DESC;


/*----------------------Exercise 8-------------------------
Examine all the transactions for the sku with the greatest
standard deviation in sprice. Only examine skus that have 
been part of over 100 transactions.

OUTPUT: Most of the sprice are way lower than the orgprice
----------------------------------------------------------*/

SELECT *
FROM (
		SELECT TOP 1
			sku.sku, 
			STDDEV_SAMP(t.sprice) AS PriceSTD, 
			COUNT(t.saledate) AS NumTrnsact
		FROM trnsact t 
			INNER JOIN skuinfo sku ON t.sku = sku.sku
		WHERE t.stype='P'
		GROUP BY sku.sku, sku.brand
		HAVING NumTrnsact > 100
		ORDER BY PriceSTD DESC) AS T
	INNER JOIN trnsact ON T.sku = trnsact.sku;

	
/*----------------------Exercise 9-------------------------
What was the average daily revenue brought in during each
month of the year?
----------------------------------------------------------*/

SELECT 
	EXTRACT(YEAR from sub.saledate) AS YearDate,
	EXTRACT(MONTH from sub.saledate) AS MonthDate,
	COUNT(DISTINCT sub.saledate) AS NumDays,
	(SUM(sub.amt)/NumDays) AS Revenue
FROM (
	SELECT t.saledate,t.store,t.amt 
    FROM trnsact t
    WHERE t.sprice <> 0 AND t.stype='P' AND NOT
		(EXTRACT(YEAR from t.saledate) = 2005
		AND EXTRACT(MONTH from t.saledate) = 8)) AS sub		
GROUP BY YearDate, MonthDate
HAVING NumDays >= 20
ORDER BY YearDate ASC, Revenue DESC; 


/*---------------------Exercise 10-------------------------
Which department, in which city and state and what store,
had the greatest % increase in average daily sales revenue
from November to December?
----------------------------------------------------------*/

SELECT TOP 1 T2.dept, T2.store, T2.city, T2.state,
		SUM(T2.NovSales/T2.NovDays) AS AvgNovSales,
		SUM(T2.DecSales/T2.DecDays) AS AvgDecSales,
		((AvgDecSales-AvgNovSales)/AvgNovSales)*100 AS PercentInc
FROM (	SELECT
			T.dept, T.store, T.city, T.state, 
			SUM(CASE WHEN T.MonthDate = 11 
				THEN T.amount END) AS NovSales,
			SUM(CASE WHEN T.MonthDate = 12 
				THEN T.amount END) AS DecSales,
			COUNT(DISTINCT CASE WHEN T.MonthDate = 11 
				THEN T.saledate END) AS NovDays,
			COUNT(DISTINCT CASE WHEN T.MonthDate = 12 
				THEN T.saledate END) AS DecDays		
		FROM ( 	SELECT 
					str.state, str.city, str.store, dep.dept, 
					SUM(trn.amt) AS amount, trn.saledate,
					EXTRACT(MONTH from trn.saledate) AS MonthDate,
					EXTRACT(YEAR from trn.saledate) AS YearDate
				FROM trnsact trn 
					INNER JOIN skuinfo sku ON trn.sku = sku.sku
					INNER JOIN strinfo str ON trn.store = str.store
					INNER JOIN deptinfo dep ON sku.dept = dep.dept
				WHERE 
					EXTRACT(MONTH from trn.saledate) IN (11,12)
					AND trn.stype='P' AND trn.sprice <> 0 
				GROUP BY str.state, str.city, str.store, dep.dept, 
						trn.saledate, MonthDate, YearDate) AS T		
		GROUP BY T.dept, T.store, T.city, T.state 
		HAVING NovDays >= 20 AND DecDays >= 20 ) AS T2
GROUP BY T2.dept, T2.store, T2.city, T2.state
ORDER BY PercentInc DESC;


/*---------------------Exercise 11-------------------------
Which city and state of what store had the greatest decrease 
in average daily sales revenue from August to September?
----------------------------------------------------------*/

SELECT TOP 1 T2.store, T2.city, T2.state,
		SUM(T2.AugSales/T2.AugDays) AS AvgAugSales,
		SUM(T2.SepSales/T2.SepDays) AS AvgSepSales,
		(AvgSepSales-AvgAugSales) AS AvgDifference
FROM (	SELECT T.store, T.city, T.state,
		SUM(CASE WHEN T.MonthDate = 8 
			THEN T.amount END) AS AugSales,
		SUM(CASE WHEN T.MonthDate = 9 
			THEN T.amount END) AS SepSales,
		COUNT(DISTINCT CASE WHEN T.MonthDate = 8 
			THEN T.saledate END) AS AugDays,
		COUNT(DISTINCT CASE WHEN T.MonthDate = 9 
			THEN T.saledate END) AS SepDays
		
		FROM ( 	SELECT 
					str.store, str.city, str.state,
					SUM(trn.amt) AS amount, trn.saledate,
					EXTRACT(MONTH from trn.saledate) AS MonthDate,
					EXTRACT(YEAR from trn.saledate) AS YearDate
				FROM trnsact trn 				
					INNER JOIN strinfo str ON trn.store = str.store
				WHERE trn.stype='P' AND trn.sprice <> 0 
					  AND EXTRACT(MONTH from trn.saledate) IN (8,9)
					  AND NOT (EXTRACT(YEAR from trn.saledate = 2005
					  AND EXTRACT(MONTH from trn.saledate) = 8)
				GROUP BY str.store, str.city, str.state, 
						 trn.saledate, MonthDate, YearDate) AS T
		GROUP BY T.store, T.city, T.state 
		HAVING AugDays >= 20 AND SepDays >= 20 ) AS T2
GROUP BY T2.store, T2.city, T2.state
ORDER BY AvgDifference ASC;


/*---------------------Exercise 12-------------------------
For each month, determine how many stores have their
maximum average daily revenue? How do they compare?
----------------------------------------------------------*/

SELECT CASE
		WHEN T.MonthDate = 1 THEN 'Jan'
		WHEN T.MonthDate = 2 THEN 'Feb'
		WHEN T.MonthDate = 3 THEN 'Mar'
		WHEN T.MonthDate = 4 THEN 'Apr'
		WHEN T.MonthDate = 5 THEN 'May'
		WHEN T.MonthDate = 6 THEN 'Jun'
		WHEN T.MonthDate = 7 THEN 'Jul'
		WHEN T.MonthDate = 8 THEN 'Aug'
		WHEN T.MonthDate = 9 THEN 'Sep'
		WHEN T.MonthDate = 10 THEN 'Oct'
		WHEN T.MonthDate = 11 THEN 'Nov'
		WHEN T.MonthDate = 12 THEN 'Dec'
		END AS BestMonth,
COUNT(T.store) AS NumOfStores
FROM (
		SELECT
			trn.store, COUNT(DISTINCT trn.saledate) AS NumDays,
			EXTRACT(MONTH from trn.saledate) AS MonthDate, 
			SUM(trn.amt)/NumDays AS Revenue,
			RANK() OVER (PARTITION BY trn.store 
				ORDER BY Revenue DESC) AS AmountRank
		FROM trnsact trn
		QUALIFY AmountRank = 1
		WHERE trn.stype='P' AND NOT
			  (EXTRACT(MONTH from trn.saledate) = 8 
			  AND EXTRACT(YEAR from trn.saledate) = 2005)
		GROUP BY trn.store, MonthDate
		HAVING NumDays >= 20 ) AS T
GROUP BY BestMonth
ORDER BY NumOfStores DESC;
