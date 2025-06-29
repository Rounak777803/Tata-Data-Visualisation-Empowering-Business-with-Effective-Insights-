-- Which region is generating the highest revenue, and which region is generating the lowest?
SELECT
    Country,
    SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS TotalRevenue
FROM
    updated_retail_sales
WHERE
    COALESCE(UpdatedQuantity, Quantity) IS NOT NULL AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
GROUP BY
    Country
ORDER BY
    TotalRevenue DESC
LIMIT 1;

-- Query to find the region (Country) with the lowest revenue
SELECT
    Country,
    SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS TotalRevenue
FROM
    updated_retail_sales
WHERE
    COALESCE(UpdatedQuantity, Quantity) IS NOT NULL AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
GROUP BY
    Country
ORDER BY
    TotalRevenue ASC
LIMIT 1;


-- What is the monthly trend of revenue, which months have faced the biggest increase/decrease?
WITH MonthlyRevenue AS (
    SELECT
        DATE_FORMAT(InvoiceDateTime, '%Y-%m') AS SalesMonth, -- Extract Year and Month
        SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS MonthlyTotalRevenue
    FROM
        updated_retail_sales
    WHERE
        COALESCE(UpdatedQuantity, Quantity) IS NOT NULL
        AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
        AND COALESCE(UpdatedQuantity, Quantity) > 0 -- Exclude returns/negative quantities if not part of revenue (adjust if returns decrease revenue)
    GROUP BY
        SalesMonth
    ORDER BY
        SalesMonth
),
RevenueChange AS (
    SELECT
        SalesMonth,
        MonthlyTotalRevenue,
        LAG(MonthlyTotalRevenue, 1, 0) OVER (ORDER BY SalesMonth) AS PreviousMonthRevenue, -- Get previous month's revenue
        MonthlyTotalRevenue - LAG(MonthlyTotalRevenue, 1, 0) OVER (ORDER BY SalesMonth) AS MonthlyChange
    FROM
        MonthlyRevenue
)
-- Select all monthly trends with their changes
SELECT
    SalesMonth,
    MonthlyTotalRevenue,
    MonthlyChange,
    CASE
        WHEN MonthlyChange > 0 THEN 'Increase'
        WHEN MonthlyChange < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS Trend
FROM
    RevenueChange
ORDER BY
    SalesMonth;

-- Query to find the month with the biggest revenue INCREASE
SELECT
    SalesMonth,
    MonthlyTotalRevenue,
    MonthlyChange
FROM (
    SELECT
        DATE_FORMAT(InvoiceDateTime, '%Y-%m') AS SalesMonth,
        SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS MonthlyTotalRevenue,
        (SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice))) -
        LAG(SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)), 1, 0)
        OVER (ORDER BY DATE_FORMAT(InvoiceDateTime, '%Y-%m')) AS MonthlyChange
    FROM
        updated_retail_sales
    WHERE
        COALESCE(UpdatedQuantity, Quantity) IS NOT NULL
        AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
        AND COALESCE(UpdatedQuantity, Quantity) > 0
    GROUP BY
        SalesMonth
) AS CalculatedChanges
WHERE
    MonthlyChange > 0
ORDER BY
    MonthlyChange DESC
LIMIT 1;

-- Query to find the month with the biggest revenue DECREASE
SELECT
    SalesMonth,
    MonthlyTotalRevenue,
    MonthlyChange
FROM (
    SELECT
        DATE_FORMAT(InvoiceDateTime, '%Y-%m') AS SalesMonth,
        SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS MonthlyTotalRevenue,
        (SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice))) -
        LAG(SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)), 1, 0)
        OVER (ORDER BY DATE_FORMAT(InvoiceDateTime, '%Y-%m')) AS MonthlyChange
    FROM
        updated_retail_sales
    WHERE
        COALESCE(UpdatedQuantity, Quantity) IS NOT NULL
        AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
        AND COALESCE(UpdatedQuantity, Quantity) > 0
    GROUP BY
        SalesMonth
) AS CalculatedChanges
WHERE
    MonthlyChange < 0
ORDER BY
    MonthlyChange ASC -- For decreases, smallest (most negative) is the biggest decrease
LIMIT 1;


-- Which months generated the most revenue? Is there a seasonality in sales?
-- CTE to calculate total revenue per month, excluding negative quantities
WITH MonthlyRevenue AS (
    SELECT
        DATE_FORMAT(InvoiceDateTime, '%Y-%m') AS SalesMonth, -- Extracts Year and Month (e.g., '2010-12', '2011-01')
        SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS TotalMonthlyRevenue
    FROM
        updated_retail_sales
    WHERE
        COALESCE(UpdatedQuantity, Quantity) IS NOT NULL
        AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
        AND COALESCE(UpdatedQuantity, Quantity) > 0 -- Ensures only positive sales contribute to revenue
    GROUP BY
        SalesMonth
    ORDER BY
        SalesMonth ASC -- Order chronologically for trend observation
)
-- Query to find the months that generated the most revenue (Top 5)
SELECT
    SalesMonth,
    TotalMonthlyRevenue
FROM
    MonthlyRevenue
ORDER BY
    TotalMonthlyRevenue DESC
LIMIT 5;

-- Who are the top customers and how much do they contribute to the total revenue? Is the business dependent on these customers or is the customer base diversified?
-- Query to identify top customers and their revenue contribution

WITH CustomerRevenue AS (
    SELECT
        CustomerID,
        SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS CustomerTotalRevenue
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL -- Focus on identified customers
        AND COALESCE(UpdatedQuantity, Quantity) IS NOT NULL
        AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
        AND COALESCE(UpdatedQuantity, Quantity) > 0 -- Only positive sales for revenue
    GROUP BY
        CustomerID
),
OverallIdentifiedCustomerRevenue AS (
    SELECT
        SUM(CustomerTotalRevenue) AS GrandTotalRevenue
    FROM
        CustomerRevenue
)
-- Select Top N Customers and their percentage contribution
SELECT
    cr.CustomerID,
    cr.CustomerTotalRevenue,
    (cr.CustomerTotalRevenue / (SELECT GrandTotalRevenue FROM OverallIdentifiedCustomerRevenue)) * 100 AS ContributionPercentage
FROM
    CustomerRevenue cr
ORDER BY
    cr.CustomerTotalRevenue DESC
LIMIT 10;

-- What is the percentage of customers who are repeating their orders? Are they ordering the same products or different?
-- PART 1: Percentage of Customers Who Are Repeating Their Orders

WITH CustomerOrderCounts AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS NumberOfOrders
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL -- Only consider identified customers
    GROUP BY
        CustomerID
),
CustomerCategories AS (
    SELECT
        CustomerID,
        NumberOfOrders,
        CASE
            WHEN NumberOfOrders > 1 THEN 'Repeating'
            ELSE 'One-Time'
        END AS CustomerType
    FROM
        CustomerOrderCounts
)
SELECT
    CAST(SUM(CASE WHEN CustomerType = 'Repeating' THEN 1 ELSE 0 END) AS DECIMAL) * 100 / COUNT(CustomerID) AS PercentageRepeatingCustomers
FROM
    CustomerCategories;
 
 
-- PART 2: Are Repeating Customers Ordering the Same Products or Different?
-- This part requires analysis based on the results. The queries below help reveal the patterns.

-- Query 1: For Repeating Customers, count the number of UNIQUE products they have ordered
-- (A higher count suggests ordering different products)
WITH RepeatingCustomers AS (
    SELECT
        CustomerID
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL
    GROUP BY
        CustomerID
    HAVING
        COUNT(DISTINCT InvoiceNo) > 1 -- Identify customers with more than one order
)
SELECT
    rs.CustomerID,
    COUNT(DISTINCT rs.StockCode) AS NumberOfUniqueProductsOrdered,
    GROUP_CONCAT(DISTINCT rs.Description ORDER BY rs.Description SEPARATOR '; ') AS UniqueProductDescriptions
FROM
    updated_retail_sales rs
JOIN
    RepeatingCustomers rc ON rs.CustomerID = rc.CustomerID
WHERE
    rs.StockCode IS NOT NULL
GROUP BY
    rs.CustomerID
ORDER BY
    NumberOfUniqueProductsOrdered DESC;
    
-- Query 2: For Repeating Customers, identify their MOST FREQUENTLY ordered product(s) (if any)
-- This helps see if they repeatedly buy a specific item
WITH RepeatingCustomers AS (
    SELECT
        CustomerID
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL
    GROUP BY
        CustomerID
    HAVING
        COUNT(DISTINCT InvoiceNo) > 1
),
CustomerProductFrequency AS (
    SELECT
        rs.CustomerID,
        rs.StockCode,
        rs.Description,
        COUNT(*) AS OrderCountPerProduct,
        ROW_NUMBER() OVER(PARTITION BY rs.CustomerID ORDER BY COUNT(*) DESC, rs.StockCode) AS rn
    FROM
        updated_retail_sales rs
    JOIN
        RepeatingCustomers rc ON rs.CustomerID = rc.CustomerID
    WHERE
        rs.StockCode IS NOT NULL
    GROUP BY
        rs.CustomerID, rs.StockCode, rs.Description
)
SELECT
    cpf.CustomerID,
    cpf.Description AS MostFrequentProduct,
    cpf.OrderCountPerProduct
FROM
    CustomerProductFrequency cpf
WHERE
    cpf.rn = 1 -- Selects the top product for each repeating customer
ORDER BY
    cpf.CustomerID, cpf.OrderCountPerProduct DESC;
    
    
    
-- For the repeat customers, how long does it take for them to place the next order after being delivered the previous one?
-- Query to calculate the average time between consecutive orders for repeat customers
WITH CustomerDistinctOrders AS (
    -- Get the earliest timestamp for each unique invoice placed by an identified customer
    SELECT
        CustomerID,
        InvoiceNo,
        MIN(InvoiceDateTime) AS OrderDateTime -- Use MIN as multiple items in one invoice share the same InvoiceDateTime
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL -- Exclude transactions without an identified customer
        AND COALESCE(UpdatedQuantity, Quantity) > 0 -- Exclude returns/cancellations
    GROUP BY
        CustomerID,
        InvoiceNo
),
CustomerOrderSequence AS (
    -- For each customer, list their orders in chronological sequence
    SELECT
        cdo.CustomerID,
        cdo.InvoiceNo,
        cdo.OrderDateTime,
        LAG(cdo.OrderDateTime) OVER (PARTITION BY cdo.CustomerID ORDER BY cdo.OrderDateTime) AS PreviousOrderDateTime
    FROM
        CustomerDistinctOrders cdo
    -- Filter to include only repeat customers (those with more than one distinct order)
    WHERE
        (SELECT COUNT(*) FROM CustomerDistinctOrders WHERE CustomerID = cdo.CustomerID) > 1
)
-- Calculate the average time difference and format it for readability
SELECT
    -- Calculate the average difference in seconds
    AVG(TIMESTAMPDIFF(SECOND, PreviousOrderDateTime, OrderDateTime)) AS AverageTimeBetweenOrdersInSeconds,
    -- Format the average time into days, hours, and minutes
    CONCAT(
        FLOOR(AVG(TIMESTAMPDIFF(SECOND, PreviousOrderDateTime, OrderDateTime)) / (60 * 60 * 24)), ' days, ',
        FLOOR(MOD(AVG(TIMESTAMPDIFF(SECOND, PreviousOrderDateTime, OrderDateTime)), (60 * 60 * 24)) / (60 * 60)), ' hours, ',
        FLOOR(MOD(MOD(AVG(TIMESTAMPDIFF(SECOND, PreviousOrderDateTime, OrderDateTime)), (60 * 60 * 24)), (60 * 60)) / 60), ' minutes'
    ) AS FormattedAverageTimeBetweenOrders
FROM
    CustomerOrderSequence
WHERE
    PreviousOrderDateTime IS NOT NULL; -- Exclude the first order of each customer as it has no 'previous' order
    
    
-- What revenue is being generated from the customers who have ordered more than once?
-- Query to calculate the total revenue generated from customers who have ordered more than once

WITH RepeatCustomers AS (
    -- Step 1: Identify customers who have placed more than one distinct order
    SELECT
        CustomerID
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL -- Only consider identified customers
    GROUP BY
        CustomerID
    HAVING
        COUNT(DISTINCT InvoiceNo) > 1 -- Customers with more than one unique invoice
),
RepeatCustomerRevenue AS (
    -- Step 2: Calculate the total revenue for all orders placed by these repeat customers
    SELECT
        SUM(COALESCE(urs.UpdatedQuantity, urs.Quantity) * COALESCE(urs.UpdatedUnitPrice, urs.UnitPrice)) AS TotalRevenueFromRepeatCustomers
    FROM
        updated_retail_sales urs
    JOIN
        RepeatCustomers rc ON urs.CustomerID = rc.CustomerID
    WHERE
        COALESCE(urs.UpdatedQuantity, urs.Quantity) IS NOT NULL
        AND COALESCE(urs.UpdatedUnitPrice, urs.UnitPrice) IS NOT NULL
        AND COALESCE(urs.UpdatedQuantity, urs.Quantity) > 0 -- Exclude returns/negative quantities from revenue calculation
)
-- Final selection of the total revenue
SELECT
    TotalRevenueFromRepeatCustomers
FROM
    RepeatCustomerRevenue;
    

-- Who are the customers that have repeated the most? How much are they contributing to revenue?
-- Query to find customers with the most repeat orders and their revenue contribution

WITH CustomerOrderAndRevenue AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS NumberOfDistinctOrders,
        SUM(COALESCE(UpdatedQuantity, Quantity) * COALESCE(UpdatedUnitPrice, UnitPrice)) AS CustomerTotalRevenue
    FROM
        updated_retail_sales
    WHERE
        CustomerID IS NOT NULL -- Focus on identified customers
        AND COALESCE(UpdatedQuantity, Quantity) IS NOT NULL
        AND COALESCE(UpdatedUnitPrice, UnitPrice) IS NOT NULL
        AND COALESCE(UpdatedQuantity, Quantity) > 0 -- Only positive sales for revenue
    GROUP BY
        CustomerID
),
OverallIdentifiedCustomerRevenue AS (
    SELECT
        SUM(CustomerTotalRevenue) AS GrandTotalRevenue
    FROM
        CustomerOrderAndRevenue
)
-- Select customers who have repeated the most and their details
SELECT
    cora.CustomerID,
    cora.NumberOfDistinctOrders AS RepeatOrderCount,
    cora.CustomerTotalRevenue,
    (cora.CustomerTotalRevenue / (SELECT GrandTotalRevenue FROM OverallIdentifiedCustomerRevenue)) * 100 AS ContributionPercentage
FROM
    CustomerOrderAndRevenue cora
WHERE
    cora.NumberOfDistinctOrders > 1 -- Only consider repeat customers
ORDER BY
    RepeatOrderCount DESC, -- Order by how many times they repeated
    cora.CustomerTotalRevenue DESC -- Then by total revenue (for ties in repeat count)
LIMIT 10; -- Adjust LIMIT to see more or fewer top repeat customers (e.g., LIMIT 5, LIMIT 20)




