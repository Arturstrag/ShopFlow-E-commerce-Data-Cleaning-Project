# ShopFlow — E-commerce Data Cleaning Project

## 🎯 Project objective

The objective of this project was to thoroughly clean and prepare sales data from the simulated **ShopFlow** online store for further analysis.

## 📌 Project description

The data comes from the simulated **ShopFlow** online store operating in the Polish e-commerce market, covering areas such as:

- fashion,
- electronics,
- home and interior,
- beauty.

The dataset contains approximately **85,000 records** across 5 related tables and **24 months of sales history**:

- `customers` — approx. 5,000 records,
- `products` — approx. 2,000 records,
- `orders` — approx. 20,000 records,
- `order_items` — approx. 49,000 records,
- `inventory` — approx. 2,000 records.

## 🧹 Data cleaning and preparation

Before starting the actual analysis, data quality was checked in all tables.

The following issues were identified, among others:

- missing data,
- duplicates,
- inconsistent formats,
- invalid values,
- typos,
- outliers,
- data integrity problems.

The most important issues and selected SQL fragments showing how they were addressed are presented below. All queries are included in the project's main SQL script.

---

## 👤 `customers` table

The `customers` table was checked for duplicate `customer_id` values, valid first and last names, empty values, unnecessary spaces, and the presence of digits or unwanted characters.

No errors were found in the `customer_id`, `first_name`, or `last_name` columns.

### 1. Inconsistent phone number formats

Phone numbers appeared in many different formats, including numbers with the `+48` prefix, without the prefix, and with spaces or hyphens.

Phone numbers were standardized to the `+48XXXXXXXXX` format. Missing values were marked as `unknown`. The length of phone numbers was also verified.

```sql
UPDATE customers
SET phone = 'unknown'
WHERE phone IS NULL
   OR phone = '';

UPDATE customers
SET phone = '+48' || RIGHT(
    REGEXP_REPLACE(phone, '[^0-9]', '', 'g'),
    9
)
WHERE phone <> 'unknown'
  AND LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '', 'g')) >= 9;
```

**Before cleaning**

![Different phone number formats](image/surowe_dane/telefony_rozne_formaty_customers.png)

**After cleaning**

![Phone numbers after cleaning](image/oczyszczone_dane/telefony_po_czyszczeniu.png)

**Missing phone numbers marked as `unknown`**

![Missing phone numbers marked as unknown](image/oczyszczone_dane/telefony_unknown.png)

---

### 2. Invalid postal codes

Some values in the `postal_code` column did not follow the Polish `XX-XXX` format.

Records that could not be corrected unambiguously were not automatically replaced with potentially incorrect values. Instead, they were marked for further review.

```sql
UPDATE customers
SET postal_code = 'do weryf'
WHERE postal_code !~ '^\d{2}-\d{3}$';
```

**Before cleaning**

![Invalid postal codes](image/surowe_dane/kody_pocztowe_customers.png)

**Records marked for review**

![Postal codes requiring review](image/oczyszczone_dane/kody_pocztowe_do_weryfikacji.png)

---

### 3. Inconsistent email addresses

Email addresses differed in letter case, contained unnecessary spaces, or lacked a consistent format.

Addresses were standardized by removing unnecessary spaces and converting them to lowercase.

```sql
UPDATE customers
SET email = LOWER(TRIM(email));
```

The normalized email address was later also used to identify duplicate customers.

**Before cleaning**

![Inconsistent email addresses](image/surowe_dane/Emaile_customers.png)

**After cleaning**

![Emails after cleaning](image/oczyszczone_dane/emaile_po_czyszczeniu.png)

---

### 4. Typos and inconsistent city names

The `city` column contained different variants of the same locality, such as `Warsszawa` and `Warszawa`, as well as inconsistent capitalization.

Instead of creating many separate `UPDATE` statements, a mapping table was created to map incorrect variants to canonical city names. The shortened mapping example is shown below; the full list is included in the SQL script.

```sql
CREATE TABLE IF NOT EXISTS city_mapping (
    wariant VARCHAR(50) PRIMARY KEY,
    kanoniczna VARCHAR(50)
);

INSERT INTO city_mapping (wariant, kanoniczna) VALUES
    ('warszawa', 'Warszawa'),
    ('warsszawa', 'Warszawa'),
    ('warszzawa', 'Warszawa'),
    ('krakó', 'Kraków'),
    ('kkraków', 'Kraków')
ON CONFLICT (wariant) DO NOTHING;

UPDATE customers c
SET city = m.kanoniczna
FROM city_mapping m
WHERE LOWER(c.city) = m.wariant;
```

**Before cleaning**

![Inconsistent city names](image/surowe_dane/miasta_customers.png)

**After cleaning**

![Cities after cleaning](image/oczyszczone_dane/miasta_po_czyszczeniu.png)

---

### 5. Duplicate customers

Records belonging to customers with the same normalized email address were detected.

Duplicates were merged based on `LOWER(TRIM(email))`. The customer with the earliest registration date was retained; in the event of a tie, the customer with the lowest `customer_id` was retained.

Before deleting duplicates, their orders were reassigned to the retained customer record. This prevented the loss of purchase history.

```sql
WITH ranked AS (
    SELECT
        customer_id,
        LOWER(TRIM(email)) AS email_norm,
        ROW_NUMBER() OVER (
            PARTITION BY LOWER(TRIM(email))
            ORDER BY registration_date ASC, customer_id ASC
        ) AS rn
    FROM customers
),
mapowanie AS (
    SELECT
        r_dup.customer_id AS stary_id,
        r_keep.customer_id AS nowy_id
    FROM ranked r_dup
    JOIN ranked r_keep
      ON r_dup.email_norm = r_keep.email_norm
     AND r_keep.rn = 1
    WHERE r_dup.rn > 1
)
UPDATE orders o
SET customer_id = m.nowy_id
FROM mapowanie m
WHERE o.customer_id = m.stary_id;
```

After the order history had been reassigned, the redundant records were deleted.

```sql
WITH ranked AS (
    SELECT
        customer_id,
        ROW_NUMBER() OVER (
            PARTITION BY LOWER(TRIM(email))
            ORDER BY registration_date ASC, customer_id ASC
        ) AS rn
    FROM customers
)
DELETE FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM ranked
    WHERE rn > 1
);
```

![Duplicate customers](image/surowe_dane/duplikaty_klient%C3%B3w_customers.png)

---

### 6. Additional duplicates with the `_dup` suffix

Some duplicates had a modified email address, for example:

```text
jan.kowalski@gmail.com
jan.kowalski_dup@gmail.com
```

These records were not detected by standard grouping based on identical normalized email addresses, so an additional identification rule was required.

First, orders were reassigned to the original customer. The technical duplicates with the `_dup` suffix were then removed.

```sql
UPDATE orders o
SET customer_id = p.nowy_id
FROM (
    SELECT
        dup.customer_id AS stary_id,
        orig.customer_id AS nowy_id
    FROM customers dup
    JOIN customers orig
      ON REPLACE(dup.email, '_dup@', '@') = orig.email
    WHERE dup.email LIKE '%\_dup@%'
) p
WHERE o.customer_id = p.stary_id;
```

**Duplicates with the `_dup` suffix**

![Duplicates with the dup suffix](image/surowe_dane/dodatkowe_duplikaty_customers.png)

**Emails after cleaning**

![Emails after cleaning](image/oczyszczone_dane/emaile_po_czyszczeniu.png)

---

### 7. Customers without orders

Customers who had created an account but had not placed any orders were identified.

These records were not deleted because they do not represent a data error. A `klienci_bez_zamowien` view was created to enable further analysis of this segment in terms of customer activation, retention, and conversion.

```sql
CREATE OR REPLACE VIEW klienci_bez_zamowien AS
SELECT c.*
FROM customers c
LEFT JOIN orders o
  ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
```

---

## 📦 `products` table

The main issues in the products table concerned prices and inconsistent product categories.

### 1. Products with a price of `0`

Products with a `unit_price` of `0` were found in the catalog.

These records were neither automatically deleted nor assigned an artificially calculated price. They were marked for review because, without additional business information, it was impossible to determine unambiguously whether the price was incorrect.

```sql
ALTER TABLE products
ADD COLUMN IF NOT EXISTS wymaga_weryfikacji BOOLEAN DEFAULT FALSE;

UPDATE products
SET wymaga_weryfikacji = TRUE
WHERE unit_price <= 0;
```

**Before being flagged**

![Products with a price of 0](image/surowe_dane/cena_0_products.png)

**After being flagged for review**

![Products with flagged prices](image/oczyszczone_dane/cena_oflagowana.png)

---

### 2. Inconsistent product categories

Category names appeared in different variants: with different capitalization, additional spaces, and Polish or English wording.

Categories were standardized to a single set of values. Example:

```sql
UPDATE products
SET category = 'Elektronika'
WHERE LOWER(TRIM(category)) IN ('elektronika', 'electronics');

UPDATE products
SET category = 'Moda damska'
WHERE LOWER(TRIM(category)) IN ('moda damska', 'women fashion');

UPDATE products
SET category = 'Uroda'
WHERE LOWER(TRIM(category)) IN ('uroda', 'beauty');
```

**Before cleaning**

![Inconsistent product categories](image/surowe_dane/kategorie_products.png)

**After cleaning**

![Categories after cleaning](image/oczyszczone_dane/kategorie_po_czyszczeniu.png)

---

### 3. Product price outliers

The data contained products with prices significantly higher than typical prices in their respective categories.

Potential outliers were detected using the **IQR (Interquartile Range)** statistical method separately for each product category.

```sql
WITH kwartyle AS (
    SELECT
        category,
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY unit_price) AS q1,
        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY unit_price) AS q3
    FROM products
    GROUP BY category
)
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price
FROM products p
JOIN kwartyle k
  ON p.category = k.category
WHERE p.unit_price > k.q3 + 1.5 * (k.q3 - k.q1)
   OR p.unit_price < k.q1 - 1.5 * (k.q3 - k.q1)
ORDER BY p.unit_price DESC;
```

The records were not deleted automatically because a high product price does not necessarily indicate a data error. In a real-world project, they would require additional business verification.

![Products with unusual prices](image/surowe_dane/produkty_z_dziwn%C4%85_cen%C4%85.png)

---

## 🧾 `orders` table

The following issues were identified in the orders table: duplicate records, inconsistent date formats, and missing payment methods.

### 1. Duplicate orders

Customers with more than one order placed on the same date were detected.

Duplicates were identified based on `customer_id` and `order_date`. Within each group, the record with the lowest `order_id` was retained.

Because of the relationship with `order_items`, items belonging to redundant orders were deleted first, followed by the redundant records in the `orders` table.

```sql
WITH ranked AS (
    SELECT
        order_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, order_date
            ORDER BY order_id ASC
        ) AS rn
    FROM orders
)
DELETE FROM order_items
WHERE order_id IN (
    SELECT order_id
    FROM ranked
    WHERE rn > 1
);
```

![Duplicate orders](image/surowe_dane/duplikaty_zam%C3%B3wie%C5%84_orders.png)

---

### 2. Inconsistent date formats

Order dates appeared in several formats, for example:

- `08.09.2024`,
- `26/12/2024`,
- `2024-12-26`.

The dates were first standardized to the `YYYY-MM-DD` format, after which the column type was changed to `DATE`.

```sql
UPDATE orders
SET order_date = TO_CHAR(
    TO_DATE(order_date, 'DD.MM.YYYY'),
    'YYYY-MM-DD'
)
WHERE order_date ~ '^\d{2}\.\d{2}\.\d{4}$';

UPDATE orders
SET order_date = TO_CHAR(
    TO_DATE(order_date, 'DD/MM/YYYY'),
    'YYYY-MM-DD'
)
WHERE order_date ~ '^\d{2}/\d{2}/\d{4}$';

ALTER TABLE orders
ALTER COLUMN order_date TYPE DATE
USING order_date::DATE;
```

**Before cleaning**

![Different date formats](image/surowe_dane/rozne_formaty_dat_orders.png)

**After cleaning**

![Dates after correction](image/oczyszczone_dane/daty_po_naprawie.png)

---

### 3. Missing payment methods

The `payment_method` column contained empty values stored as empty strings.

Empty strings were converted to `NULL`, and their relationship with order status was then checked.

```sql
UPDATE orders
SET payment_method = NULL
WHERE TRIM(payment_method) = '';

SELECT order_status, COUNT(*)
FROM orders
WHERE payment_method IS NULL
GROUP BY order_status;
```

The missing values occurred in cancelled orders (`Cancelled`), so they were considered logically acceptable and left unchanged.

![Missing payment methods](image/surowe_dane/Tabela_order_payment_method.png)

---

## 🛒 `order_items` table

### 1. Negative `quantity` values

Records with a negative number of products appeared in the order items table.

The negative values were interpreted as returns recorded in the wrong place. Their information was moved to a separate `returns` table, and the corresponding records were then deleted from `order_items`.

```sql
CREATE TABLE IF NOT EXISTS returns (
    return_id SERIAL PRIMARY KEY,
    order_item_id INTEGER,
    quantity_returned INTEGER,
    return_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO returns (order_item_id, quantity_returned)
SELECT order_item_id, ABS(quantity)
FROM order_items
WHERE quantity < 0;

DELETE FROM order_items
WHERE quantity < 0;
```

This approach separated sales from returns without losing information about the returned quantity.

**Negative `quantity` values**

![Negative quantity values](image/surowe_dane/ujemne_quantity_order_items.png)

**`returns` table**

![Returns table](image/oczyszczone_dane/return.png)

---

### 2. Orphaned `product_id` values

The `order_items` table contained orphaned `product_id` values: records referring to products that no longer existed in the `products` table.

Instead of deleting historical sales items, a technical product record with `product_id = -1` was created. All orphaned items were then assigned to it.

```sql
INSERT INTO products (
    product_id,
    product_name,
    category,
    brand,
    unit_price,
    unit_cost,
    is_active
)
VALUES (
    -1,
    'Produkt zarchiwizowany / brak danych',
    'Nieznana',
    'Nieznana',
    0,
    0,
    FALSE
)
ON CONFLICT (product_id) DO NOTHING;

UPDATE order_items oi
SET product_id = -1
WHERE NOT EXISTS (
    SELECT 1
    FROM products p
    WHERE p.product_id = oi.product_id
);
```

This preserved historical sales data and restored consistency between the tables.

![Archived product](image/oczyszczone_dane/Produkt_zarchiwizowany.png)

---

## 🏭 `inventory` table

The inventory data contained issues related to stock levels and location formatting.

### 1. Negative inventory levels

Values below zero appeared in the `stock_quantity` column.

Negative values were replaced with `0` because physical inventory cannot be negative. These records still require business verification to determine the cause of the issue.

```sql
UPDATE inventory
SET stock_quantity = 0
WHERE stock_quantity < 0;
```

![Negative inventory levels](image/surowe_dane/ujemne_stock_quantity_inventory.png)

---

### 2. Unnecessary spaces in warehouse locations

The `warehouse_location` column contained extra spaces. The values were cleaned using the `TRIM()` function.

```sql
UPDATE inventory
SET warehouse_location = TRIM(warehouse_location);
```

**Before cleaning**

![Spaces in warehouse locations](image/surowe_dane/spacje_warehouse_inventory.png)

**After cleaning**

![Warehouse locations without unnecessary spaces](image/oczyszczone_dane/warehouse_bez_spacji.png)

---

## ✅ Summary

As part of the project:

- data quality was checked across 5 tables,
- text formats, dates, phone numbers, and email addresses were standardized,
- duplicates were detected and handled while preserving related order history,
- outliers were identified using the IQR method, along with records requiring business verification,
- selected referential integrity issues were fixed,
- historical data was preserved wherever automatic deletion could have led to information loss,
- additional supporting structures were created, including the `returns` table, the `city_mapping` table, and the `klienci_bez_zamowien` view.

The cleaned data was used for the actual analysis.
