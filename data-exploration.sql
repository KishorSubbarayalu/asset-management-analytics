
-- View Customer Data
SELECT * FROM sample_asset_management.customers;

-- View Investment Data
SELECT * FROM sample_asset_management.investment;

-- View Exchange Rate Data
SELECT * FROM sample_asset_management.exch_rate;

-- View Monthly Holdings Data
SELECT * FROM sample_asset_management.holdings;

-- 1. Get the holdings made by all customers in EUR
WITH client_holding AS (
SELECT 
	*,ROUND(AMOUNT*RATE,2) AS AMOUNT_EUR
FROM sample_asset_management.holdings H
JOIN sample_asset_management.exch_rate E
	ON H.CCY_CODE = E.FROM_CCY)
select 
	C.ID, CU.NAME, ROUND(SUM(AMOUNT_EUR),2) AS TOTAL_HOLDINGS 
FROM client_holding C
JOIN sample_asset_management.customers CU
	ON C.ID = CU.ID
GROUP BY 1
ORDER BY 3 DESC;

-- 2.Get diversified investment count made by each client

SELECT ID, COUNT( DISTINCT ISIN) AS TOTAL_INV_PRODUCTS FROM sample_asset_management.holdings
GROUP BY 1
ORDER BY 2 DESC;

-- 3. Get the total clients handled by each advisor, and the revenue made by them

WITH client_holding AS (
SELECT 
	*,ROUND(AMOUNT*RATE,2) AS AMOUNT_EUR
FROM sample_asset_management.holdings H
JOIN sample_asset_management.exch_rate E
	ON H.CCY_CODE = E.FROM_CCY)
SELECT 
	ADVISOR,
    COUNT(DISTINCT C.ID) AS CLIENTS_MANAGED,
    ROUND(SUM(AMOUNT_EUR),2) AS REVENUE_GENERATED
FROM sample_asset_management.customers C
JOIN client_holding H
	ON C.ID = H.ID
GROUP BY 1
ORDER BY 3 DESC;

-- 4. Order the best performing securities in terms of total clients, the total revenue, and the average revnue made by them
WITH client_holding AS (
SELECT 
	*,ROUND(AMOUNT*RATE,2) AS AMOUNT_EUR
FROM sample_asset_management.holdings H
JOIN sample_asset_management.exch_rate E
	ON H.CCY_CODE = E.FROM_CCY)
SELECT 
	I.ISIN,
	SECURITY_NAME,
    COUNT(DISTINCT ID) AS TOTAL_CLIENTS_INVESTED,
	ROUND(SUM(AMOUNT_EUR),2) AS REVENUE_GENERATED,
    ROUND(AVG(AMOUNT_EUR),2) AS AVG_REVENUE_GENERATED
FROM sample_asset_management.investment I
JOIN client_holding C
	ON I.ISIN = C.ISIN
GROUP BY 1
ORDER BY 4 DESC;

-- 5. In a security region, rank each asset type based on the revenue generated
WITH client_holding AS (
SELECT 
	*,ROUND(AMOUNT*RATE,2) AS AMOUNT_EUR
FROM sample_asset_management.holdings H
JOIN sample_asset_management.exch_rate E
	ON H.CCY_CODE = E.FROM_CCY),
reg_asstype_rev AS (
SELECT 
	SECURITY_REGION,
    ASSET_TYPE,
    ROUND(SUM(AMOUNT_EUR),2) AS REVENUE_GENERATED
FROM sample_asset_management.investment I
JOIN client_holding C
	ON I.ISIN = C.ISIN
GROUP BY 1,2
ORDER BY 1)
SELECT 
	*,
	RANK() OVER(PARTITION BY SECURITY_REGION ORDER BY REVENUE_GENERATED DESC) AS 'RANK'
FROM reg_asstype_rev;

-- 6. Get each client's holding distribution on each asset type

WITH client_holding AS (
SELECT 
	*,ROUND(AMOUNT*RATE,2) AS AMOUNT_EUR
FROM sample_asset_management.holdings H
JOIN sample_asset_management.exch_rate E
	ON H.CCY_CODE = E.FROM_CCY),
total_rev AS (
select 
	C.ID,
    ROUND(SUM(AMOUNT_EUR),2) AS TOTAL_HOLDINGS
FROM client_holding C
JOIN sample_asset_management.customers CU
	ON C.ID = CU.ID
GROUP BY 1)
SELECT 
	C.ID,
	I.ASSET_TYPE,
    ROUND(SUM(AMOUNT_EUR),2) AS ASSET_LEVEL_HOLDINGS,
    T.TOTAL_HOLDINGS AS TOTAL_HOLDINGS,
    CONCAT(ROUND((ROUND(SUM(AMOUNT_EUR),2)/T.TOTAL_HOLDINGS) * 100,2),'%') AS ASSET_DISTRIBUTION
FROM client_holding C
JOIN total_rev T
	ON C.ID = T.ID
JOIN sample_asset_management.investment I
	ON C.ISIN = I.ISIN
GROUP BY 1,2
ORDER BY 1;

-- 7. KPI's
/*
	7a. TOTAL CLIENTS
	7b. TOTAL INVESTMENT PRODUCTS
    7c. TOTAL REVENUE GENERATED
    7d. LOW PERFORMING CLIENT
    7e. LOW PERFORMING INVESTMENT PRODUCT
*/
WITH CLI AS (
SELECT COUNT(ID) AS TOTAL_CLIENTS FROM sample_asset_management.customers),
INV AS (
SELECT COUNT(ISIN) AS TOTAL_INVESTMENT_PRODUCTS FROM sample_asset_management.investment),
client_holding AS (
SELECT 
	*,ROUND(AMOUNT*RATE,2) AS AMOUNT_EUR
FROM sample_asset_management.holdings H
JOIN sample_asset_management.exch_rate E
	ON H.CCY_CODE = E.FROM_CCY),
TOT_REV_GEN AS (
SELECT SUM(AMOUNT_EUR) AS TOTAL_REVENUE_MADE FROM client_holding),
CLI_AN AS (
SELECT 
	H.ID,
    ROUND(SUM(AMOUNT*RATE),2) AS REVENUE_PER_CLIENT
FROM client_holding H
JOIN sample_asset_management.customers C
	ON H.ID = C.ID
GROUP BY 1
),
AVG_REV_CLI AS (
SELECT ROUND(AVG(REVENUE_PER_CLIENT),2) AS AVG_REVENUE_PER_CLIENT FROM CLI_AN
),
LOW_CLI_AN AS (
SELECT 
	NAME AS LOW_PERFORMING_CLIENT,
    ROUND(SUM(AMOUNT*RATE),2) AS FLAG
FROM client_holding H
JOIN sample_asset_management.customers C
	ON H.ID = C.ID
GROUP BY 1
ORDER BY FLAG
LIMIT 1),
LOW_CLI AS (SELECT LOW_PERFORMING_CLIENT FROM LOW_CLI_AN),
LOW_INV_AN AS (
SELECT 
	SECURITY_NAME AS LOW_PERFORMING_ASSET,
    ROUND(SUM(AMOUNT*RATE),2) AS FLAG
FROM client_holding H
JOIN sample_asset_management.investment I
	ON H.ISIN = I.ISIN
GROUP BY 1
ORDER BY FLAG
LIMIT 1),
LOW_INV AS (SELECT LOW_PERFORMING_ASSET FROM LOW_INV_AN)
SELECT 
	* 
FROM 
	CLI,
    INV,
    TOT_REV_GEN,
    AVG_REV_CLI,
    LOW_CLI,
    LOW_INV;


    




