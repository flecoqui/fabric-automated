-- Create Product table
IF OBJECT_ID('[dbo].[Product]', 'U') IS NOT NULL
    DROP TABLE [dbo].[Product];

CREATE TABLE [dbo].[Product](
    [ProductKey] [nvarchar](50) NOT NULL,
    [ProductName] [nvarchar](50) NULL,
    [Category] [nvarchar](50) NULL,
    [ListPrice] [nvarchar](50) NULL
)
WITH
(
    DISTRIBUTION = HASH(ProductKey),
    CLUSTERED COLUMNSTORE INDEX
);

-- Insert sample data
INSERT INTO [dbo].[Product] ([ProductKey], [ProductName], [Category], [ListPrice])
VALUES('786','Mountain-300 Black','Mountain Bikes','2294.9900');
