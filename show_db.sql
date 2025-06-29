CREATE TABLE retail_sales (
    InvoiceNo VARCHAR(20) NOT NULL,        -- Unique identifier for each transaction/invoice. Can be alphanumeric.
    StockCode VARCHAR(20) NOT NULL,        -- Unique identifier for each product.
    Description VARCHAR(255),              -- Description of the product.
    Quantity INT NOT NULL,                 -- The quantity of the product purchased in that transaction.
    InvoiceDate DATETIME NOT NULL,         -- The date and time when the invoice was generated (e.g., DD-MM-YYYY HH:MM).
    UnitPrice DECIMAL(10, 2) NOT NULL,     -- The price per unit of the product.
    CustomerID INT,                        -- Unique identifier for each customer. Can be NULL if an order is anonymous.
    Country VARCHAR(100)                   -- The country where the transaction occurred.
);
select * from retail_sales ;


CREATE TABLE updated_retail_sales (
    InvoiceNo VARCHAR(20) NOT NULL,        -- Unique identifier for each transaction/invoice. Can be alphanumeric.
    StockCode VARCHAR(20) NOT NULL,        -- Unique identifier for each product.
    Description VARCHAR(255),              -- Description of the product.
    Quantity INT NOT NULL,                 -- The original quantity of the product purchased in that transaction.
    UpdatedQuantity INT,                   -- The updated quantity of the product, if any revision occurred.
    InvoiceDateTime DATETIME NOT NULL,     -- Combined date and time when the invoice was generated.
    UnitPrice DECIMAL(10, 2) NOT NULL,     -- The original price per unit of the product.
    UpdatedUnitPrice DECIMAL(10, 2),       -- The updated price per unit of the product, if any revision occurred.
    CustomerID INT,                        -- Unique identifier for each customer. Can be NULL if an order is anonymous.
    Country VARCHAR(100)                   -- The country where the transaction occurred.
);


select * from updated_retail_sales;

