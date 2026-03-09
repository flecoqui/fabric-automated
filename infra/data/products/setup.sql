-- Drop table if it exists
DROP TABLE IF EXISTS product;

-- Create Product table
CREATE TABLE product (
    product_key   VARCHAR(50) PRIMARY KEY,
    product_name  VARCHAR(50),
    category      VARCHAR(50),
    list_price    NUMERIC(10,4)
);

-- Insert sample data
INSERT INTO product (product_key, product_name, category, list_price)
VALUES ('786', 'Mountain-300 Black', 'Mountain Bikes', 2294.9900);
