/*--------------------
Teradata Week 5 Quiz
(JDTGanding, 2020)
--------------------*/


/*----------------------Question 1-------------------------
How many skus have brand='Polo fas' and either have 
size='XXL' or color='black'
----------------------------------------------------------*/

SELECT COUNT(DISTINCT sku)
FROM skuinfo
WHERE brand = 'Polo fas' AND (size='XXL' OR color='black');
		

/*----------------------Question 2-------------------------
There was one store in the database which had only 11 days 
in one of its months (store/month/year combination only
contained 11 days of transaction data). In what city and 
state was this store located?
----------------------------------------------------------*/

SELECT 
	t.store, str.city, str.state,
	COUNT(DISTINCT t.saledate) AS NumDays,
	EXTRACT(YEAR from t.saledate) AS YearDate,
	EXTRACT(MONTH from t.saledate) AS MonthDate
FROM trnsact t INNER JOIN strinfo str
	 ON t.store = str.store
GROUP BY 
	t.store, str.city, str.state,
	EXTRACT(YEAR from t.saledate),
	EXTRACT(MONTH from t.saledate)
HAVING NumDays=11;


/*----------------------Question 3-------------------------
Which sku number had the greatest increase in total sales
revenue from November to December?
----------------------------------------------------------*/

SELECT TOP 1 T.sku,  
		SUM(CASE WHEN T.MonthDate = 11 
			THEN T.amount END) AS NovSales,
		SUM(CASE WHEN T.MonthDate = 12 
			THEN T.amount END) AS DecSales,
		(DecSales - NovSales) AS IncSales
FROM ( 	SELECT 
			trn.sku, SUM(trn.amt) AS amount, 
			COUNT(DISTINCT trn.saledate) AS NumDays,
			EXTRACT(MONTH from trn.saledate) AS MonthDate,
			EXTRACT(YEAR from trn.saledate) AS YearDate
		FROM trnsact trn 
		WHERE 
			EXTRACT(MONTH from trn.saledate) IN (11,12)
			AND trn.stype='P' AND trn.sprice <> 0 
		GROUP BY trn.sku, MonthDate, YearDate
		HAVING NumDays >= 20 ) AS T		
GROUP BY T.sku 
ORDER BY IncSales DESC;


/*----------------------Question 4-------------------------
What vendor has the greatest number of distinct skus in the
transaction table that do not exist in the skstinfo table?
----------------------------------------------------------*/

SELECT sku.vendor, COUNT(DISTINCT trn.sku) AS SkuCount
FROM trnsact trn 
	LEFT JOIN skstinfo sks ON sks.sku = trn.sku
		AND sks.store = trn.store
	INNER JOIN skuinfo sku ON trn.sku = sku.sku
WHERE sks.sku IS NULL
GROUP BY sku.vendor
ORDER BY SkuCount DESC;


/*----------------------Question 5-------------------------
What is the brand of the sku with the greatest STDDEV in 
sprice? Only examine skus which have been part of over
100 transactions.
----------------------------------------------------------*/

SELECT TOP 1
	sku.sku, sku.brand, 
	STDDEV_POP(t.sprice) AS PriceSTD, 
	COUNT(t.saledate) AS NumTrnsact
FROM trnsact t 
	INNER JOIN skuinfo sku
	ON t.sku = sku.sku
WHERE t.stype='P'
GROUP BY sku.sku, sku.brand
HAVING COUNT(t.saledate) > 100
ORDER BY PriceSTD DESC;


/*----------------------Question 6-------------------------
What is the city and state of the store that had the
greatest increase in average daily revenue from November to
December?
----------------------------------------------------------*/

SELECT TOP 1 T2.store, T2.city, T2.state,
		SUM(T2.NovSales/T2.NovDays) AS AvgNovSales,
		SUM(T2.DecSales/T2.DecDays) AS AvgDecSales,
		(AvgDecSales-AvgNovSales) AS PercentInc
FROM (	SELECT
			T.store, T.city, T.state, 
			SUM(CASE WHEN T.MonthDate = 11 
				THEN T.amount END) AS NovSales,
			SUM(CASE WHEN T.MonthDate = 12 
				THEN T.amount END) AS DecSales,
			COUNT(DISTINCT CASE WHEN T.MonthDate = 11 
				THEN T.saledate END) AS NovDays,
			COUNT(DISTINCT CASE WHEN T.MonthDate = 12 
				THEN T.saledate END) AS DecDays
		
		FROM ( 	SELECT 
					str.store, str.state, str.city, 
					SUM(trn.amt) AS amount, trn.saledate,
					EXTRACT(MONTH from trn.saledate) AS MonthDate,
					EXTRACT(YEAR from trn.saledate) AS YearDate
				FROM trnsact trn 
					INNER JOIN strinfo str ON trn.store = str.store
				WHERE 
					EXTRACT(MONTH from trn.saledate) IN (11,12)
					AND trn.stype='P' AND trn.sprice <> 0 
				GROUP BY str.store, str.state, str.city, 
						trn.saledate, MonthDate, YearDate) AS T		
	GROUP BY T.store, T.city, T.state 
	HAVING NovDays >= 20 AND DecDays >= 20 ) AS T2
GROUP BY T2.store, T2.city, T2.state
ORDER BY PercentInc DESC;


/*----------------------Question 7-------------------------
Compare the average daily revenue of the store with the
highest msa_income and the store with the lowest median 
msa_income. In what city and state were these two stores,
and which had a higher average daily revenue?
----------------------------------------------------------*/

SELECT 
	sub.store, msa.city, msa.state, 
	msa.msa_income AS MidIncome, msa.hs_ranking AS HSRank,
	SUM(sub.Revenue)/SUM(sub.NumDays) AS AvgDailyRev
FROM (
		SELECT 
			store, COUNT(DISTINCT saledate) AS NumDays, 
			SUM(amt) AS Revenue
		FROM trnsact
		WHERE 
			sprice <> 0 AND stype='P' AND NOT
			(EXTRACT(YEAR from saledate) = 2005
			AND EXTRACT(MONTH from saledate) = 8)
		GROUP BY store
		HAVING NumDays >= 20 ) AS sub
	INNER JOIN (
		SELECT store, city, state, msa_income, CASE 
			WHEN (msa_high >= 50 AND msa_high <= 60) 
				THEN 'low'
			WHEN (msa_high > 60 AND msa_high <= 70) 
				THEN 'medium'
			WHEN msa_high > 70 
				THEN 'high'
			ELSE 'very low' END AS hs_ranking 
		FROM store_msa) AS msa
	ON sub.store = msa.store 
GROUP BY 
	sub.store, msa.city, msa.state, 
	msa.msa_income, msa.hs_ranking
ORDER BY MidIncome DESC;


/*----------------------Question 8-------------------------
Divide msa_income groups so that:
		1 <= msa_income <= 20,000: low
		20,000 < msa_income <= 30,000: med_low
		30,000 < msa_income <= 40,000: med_high
		40,000 < msa_income <= 60,000: high
		
Which of these groups has the highest average daily revenue
per store?
----------------------------------------------------------*/

SELECT 
	msa.ranking, 
	SUM(sub.Revenue)/SUM(sub.NumDays) AS AvgDailyRev
FROM (
		SELECT 
			store, COUNT(DISTINCT saledate) AS NumDays, 
			SUM(amt) AS Revenue
		FROM trnsact
		WHERE 
			sprice <> 0 AND stype='P' AND NOT
			(EXTRACT(YEAR from saledate) = 2005
			AND EXTRACT(MONTH from saledate) = 8)
		GROUP BY store
		HAVING NumDays >= 20 ) AS sub
INNER JOIN (
	SELECT store, CASE 
			WHEN (msa_income >= 1 AND msa_income <= 20000) 
				THEN 'low'
      		WHEN (msa_income > 20000 AND msa_income <= 30000) 
				THEN 'med_low'
			WHEN (msa_income > 30000 AND msa_income <= 40000) 
				THEN 'med_high'
			WHEN (msa_income > 40000 AND msa_income <= 60000) 
				THEN 'high'
      		ELSE 'out_of_range' END AS ranking 
	FROM store_msa ) AS msa
ON sub.store = msa.store
GROUP BY msa.ranking
ORDER BY AvgDailyRev DESC;


/*----------------------Question 9-------------------------
Divide msa_pop groups so that:
		1 <= msa_pop <= 100,000: very_small
		100,000 < msa_pop <= 200,000: small
		200,000 < msa_pop <= 500,000: med_small
		500,000 < msa_pop <= 1,000,000: med_large
		1,000,000 < msa_pop <= 5,000,000: large
		msa_pop > 5,000,000: very_large

What is the average daily revenue for a store in a 
'very large' population?
----------------------------------------------------------*/
SELECT 
	msa.ranking, 
	SUM(sub.Revenue)/SUM(sub.NumDays) AS AvgDailyRev
FROM (
		SELECT 
			store, COUNT(DISTINCT saledate) AS NumDays, 
			SUM(amt) AS Revenue
		FROM trnsact
		WHERE 
			sprice <> 0 AND stype='P' AND NOT
			(EXTRACT(YEAR from saledate) = 2005
			AND EXTRACT(MONTH from saledate) = 8)
		GROUP BY store
		HAVING NumDays >= 20 ) AS sub
INNER JOIN (
		SELECT store, CASE 
				WHEN (msa_pop >= 1 AND msa_pop <= 100000) 
					THEN 'very_small'
				WHEN (msa_pop > 100000 AND msa_pop <= 200000) 
					THEN 'small'
				WHEN (msa_pop > 200000 AND msa_pop <= 500000) 
					THEN 'med_small'
				WHEN (msa_pop > 500000 AND msa_pop <= 1000000) 
					THEN 'med_large'
				WHEN (msa_pop > 1000000 AND msa_pop <= 5000000) 
					THEN 'large'
				WHEN (msa_pop > 5000000) THEN 'very_large'
				ELSE 'out_of_range' END AS ranking 
		FROM store_msa ) AS msa
ON sub.store = msa.store
GROUP BY msa.ranking
ORDER BY AvgDailyRev DESC;


/*---------------------Question 10-------------------------
Which department in which store had the greatest percent 
increase in average daily sales revenue from Nov to Dec, 
and what city and state that store located in? Only examine
departments whose total sales were at least $1,000 in both
Nov and Dec.
----------------------------------------------------------*/

SELECT TOP 1 T2.deptdesc, T2.store, T2.city, T2.state,
		SUM(T2.NovSales/T2.NovDays) AS AvgNovSales,
		SUM(T2.DecSales/T2.DecDays) AS AvgDecSales,
		((AvgDecSales-AvgNovSales)/AvgNovSales)*100 AS PercentInc
FROM (	SELECT
		T.deptdesc, T.store, T.city, T.state,
		SUM(CASE WHEN T.MonthDate = 11 
			THEN T.amount END) AS NovSales,
		SUM(CASE WHEN T.MonthDate = 12 
			THEN T.amount END) AS DecSales,
		COUNT(DISTINCT CASE WHEN T.MonthDate = 11 
			THEN T.saledate END) AS NovDays,
		COUNT(DISTINCT CASE WHEN T.MonthDate = 12 
			THEN T.saledate END) AS DecDays
		
	FROM ( 	SELECT 
				str.state, str.city, str.store, dep.deptdesc, 
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
			GROUP BY str.state, str.city, str.store, dep.deptdesc, 
			         trn.saledate, MonthDate, YearDate) AS T		
	GROUP BY T.deptdesc, T.store, T.city, T.state
	HAVING NovDays >= 20 AND DecDays >= 20 AND
		   (NovSales >= 1000 AND DecSales >= 1000) ) AS T2
GROUP BY T2.deptdesc, T2.store, T2.city, T2.state
ORDER BY PercentInc DESC;


/*---------------------Question 11-------------------------
Which department in which store had the greatest decrease 
in average daily sales revenu from Aug to Sep, and what 
city and state was that store located in?
----------------------------------------------------------*/

SELECT TOP 1 T2.deptdesc, T2.store, T2.city, T2.state,
		SUM(T2.AugSales/T2.AugDays) AS AvgAugSales,
		SUM(T2.SepSales/T2.SepDays) AS AvgSepSales,
		(AvgSepSales-AvgAugSales) AS PercentInc
FROM (	SELECT
		T.deptdesc, T.store, T.city, T.state,
		SUM(CASE WHEN T.MonthDate = 8 
			THEN T.amount END) AS AugSales,
		SUM(CASE WHEN T.MonthDate = 9 
			THEN T.amount END) AS SepSales,
		COUNT(DISTINCT CASE WHEN T.MonthDate = 8 
			THEN T.saledate END) AS AugDays,
		COUNT(DISTINCT CASE WHEN T.MonthDate = 9 
			THEN T.saledate END) AS SepDays
		
	FROM ( 	SELECT 
				str.state, str.city, str.store, dep.deptdesc, 
				SUM(trn.amt) AS amount, trn.saledate,
				EXTRACT(MONTH from trn.saledate) AS MonthDate,
				EXTRACT(YEAR from trn.saledate) AS YearDate
			FROM trnsact trn 
				INNER JOIN skuinfo sku ON trn.sku = sku.sku
				INNER JOIN strinfo str ON trn.store = str.store
				INNER JOIN deptinfo dep ON sku.dept = dep.dept
			WHERE 
				EXTRACT(MONTH from trn.saledate) IN (8,9)
				AND trn.stype='P' AND trn.sprice <> 0
				AND NOT (EXTRACT(YEAR from saledate) = 2005
				AND EXTRACT(MONTH from saledate) = 8)
			GROUP BY str.state, str.city, str.store, dep.deptdesc, 
			         trn.saledate, MonthDate, YearDate) AS T		
	GROUP BY T.deptdesc, T.store, T.city, T.state
	HAVING AugDays >= 20 AND SepDays >= 20 ) AS T2
GROUP BY T2.deptdesc, T2.store, T2.city, T2.state
ORDER BY PercentInc ASC;


/*---------------------Question 12-------------------------
Identify which department, in which city and state of what
store, had the greatest decrease in number of items sold
from Aug to Sep. How many fewer items did that department
sell in Sep compared to Aug?
----------------------------------------------------------*/

SELECT TOP 1 T.deptdesc, T.store, T.city, T.state,
	   SUM(CASE WHEN T.MonthDate=8 THEN T.quantity END) AS AugQua,
	   SUM(CASE WHEN T.MonthDate=9 THEN T.quantity END) AS SepQua,
	   (AugQua - SepQua) AS Diff
FROM (
		SELECT 
			str.state, str.city, str.store, dep.deptdesc, 
			SUM(trn.quantity) AS quantity, 
			COUNT(DISTINCT trn.saledate) AS NumDays,
			EXTRACT(MONTH from trn.saledate) AS MonthDate,
			EXTRACT(YEAR from trn.saledate) AS YearDate
		FROM trnsact trn 
			INNER JOIN skuinfo sku ON trn.sku = sku.sku
			INNER JOIN strinfo str ON trn.store = str.store
			INNER JOIN deptinfo dep ON sku.dept = dep.dept
		WHERE 
			EXTRACT(MONTH from trn.saledate) IN (8,9)
			AND trn.stype='P' AND trn.sprice <> 0 
			AND NOT (EXTRACT(YEAR from saledate) = 2005
			AND EXTRACT(MONTH from saledate) = 8)
		GROUP BY str.state, str.city, str.store, 
				 dep.deptdesc, MonthDate, YearDate
		HAVING NumDays >=20 ) AS T
GROUP BY T.deptdesc, T.store, T.city, T.state
ORDER BY Diff DESC;


/*---------------------Question 13-------------------------
For each store, determine the month with the minimum average
daily revenue. For each month, count how many stores'
minimum average daily revenue was in that month. During
which month/s did over 100 stores have their minimum average
daily revenue?
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
		QUALIFY AmountRank = 12
		WHERE trn.stype='P' AND NOT
			  (EXTRACT(MONTH from trn.saledate) = 8 
			  AND EXTRACT(YEAR from trn.saledate) = 2005)
		GROUP BY trn.store, MonthDate
		HAVING NumDays >= 20 ) AS T
GROUP BY BestMonth
ORDER BY NumOfStores DESC;


/*---------------------Question 14-------------------------
Determine the month in which each store had its maximum
number of sku units returned. During which month did the
greatest number of stores have their maximum number of 
sku units returned?
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
		END AS ReturnedMonth,
COUNT(T.store) AS NumOfStores
FROM (
		SELECT
			trn.store, COUNT(DISTINCT trn.saledate) AS NumDays,
			EXTRACT(MONTH from trn.saledate) AS MonthDate, 			
			SUM(trn.quantity) AS NumOfItems,
			RANK() OVER (PARTITION BY trn.store 
				ORDER BY NumOfItems DESC) AS AmountRank
		FROM trnsact trn
		QUALIFY AmountRank = 1
		WHERE trn.stype='R' AND NOT
			  (EXTRACT(MONTH from trn.saledate) = 8 
			  AND EXTRACT(YEAR from trn.saledate) = 2005)
		GROUP BY trn.store, MonthDate
		HAVING NumDays >= 20 ) AS T
GROUP BY ReturnedMonth
ORDER BY NumOfStores DESC;