-- =========================================================
-- CZYSZCZENIE I SPRAWDZENIE DANYCH
-- Połączony skrypt SQL
-- Kolejność: sprawdzenie danych -> wykrycie problemu -> naprawa -> kontrola
-- =========================================================


-- =========================================================
-- 1. TABELA CUSTOMERS
-- =========================================================

-- ---------------------------------------------------------
-- 1.1. Podstawowy audyt
-- ---------------------------------------------------------

SELECT *
FROM customers;

-- Duplikaty customer_id
SELECT customer_id, COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Unikalne imiona
SELECT DISTINCT first_name
FROM customers;

-- NULL w first_name
SELECT first_name
FROM customers
WHERE first_name IS NULL;

-- Unikalne nazwiska
SELECT DISTINCT last_name
FROM customers;

-- NULL w last_name
SELECT last_name
FROM customers
WHERE last_name IS NULL;

-- Spacje w imieniu / nazwisku
SELECT *
FROM customers
WHERE first_name != TRIM(first_name)
   OR last_name != TRIM(last_name);

-- Puste imię / nazwisko
SELECT *
FROM customers
WHERE TRIM(first_name) = ''
   OR TRIM(last_name) = '';

-- Cyfry w imieniu / nazwisku
SELECT *
FROM customers
WHERE first_name ~ '[0-9]'
   OR last_name ~ '[0-9]';

-- Podejrzane znaki
SELECT *
FROM customers
WHERE first_name ~ '[^A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźżÀ-ÿ'' -]'
   OR last_name ~ '[^A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźżÀ-ÿ'' -]';

-- Różne warianty imienia
SELECT
    LOWER(TRIM(first_name)) AS normalized_name,
    COUNT(DISTINCT first_name) AS variants
FROM customers
WHERE first_name IS NOT NULL
GROUP BY LOWER(TRIM(first_name))
HAVING COUNT(DISTINCT first_name) > 1;


-- ---------------------------------------------------------
-- 1.2. Email
-- ---------------------------------------------------------

-- Braki
SELECT COUNT(*)
FROM customers
WHERE email IS NULL
   OR TRIM(email) = '';

-- Format email
SELECT email
FROM customers
WHERE email IS NOT NULL
  AND email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';

-- Spacje
SELECT email
FROM customers
WHERE email != TRIM(email);

-- Wielkie litery
SELECT *
FROM customers
WHERE email != LOWER(email);

-- Różne warianty tego samego emaila
SELECT
    LOWER(TRIM(email)) AS email_normalized,
    COUNT(DISTINCT email) AS variants
FROM customers
WHERE email IS NOT NULL
GROUP BY LOWER(TRIM(email))
HAVING COUNT(DISTINCT email) > 1;

-- Duplikaty email po normalizacji
SELECT
    LOWER(TRIM(email)) AS email_normalized,
    COUNT(*) AS liczba
FROM customers
WHERE email IS NOT NULL
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1;

-- NAPRAWA: normalizacja emaili
UPDATE customers
SET email = LOWER(TRIM(email));

-- KONTROLA
SELECT email
FROM customers
WHERE email <> LOWER(TRIM(email));

SELECT email
FROM customers;


-- ---------------------------------------------------------
-- 1.3. Telefon
-- ---------------------------------------------------------

-- Wszystkie warianty
SELECT DISTINCT phone
FROM customers
ORDER BY phone;

-- Litery w numerze telefonu
SELECT *
FROM customers
WHERE phone ~ '[A-Za-z]';

-- Telefon jako same cyfry
SELECT
    phone,
    REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_digits
FROM customers
WHERE phone IS NOT NULL;

-- Podejrzana długość numeru telefonu
SELECT *
FROM customers
WHERE phone IS NOT NULL
  AND LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '', 'g')) NOT BETWEEN 9 AND 15;

-- WYKRYCIE PROBLEMU: braki w numerze telefonu
SELECT COUNT(*)
FROM customers
WHERE phone IS NULL
   OR phone = '';

-- NAPRAWA: oznaczenie braków jako unknown
UPDATE customers
SET phone = 'unknown'
WHERE phone IS NULL
   OR phone = '';

-- KONTROLA
SELECT phone
FROM customers
WHERE phone = 'unknown';

-- WYKRYCIE PROBLEMU: różne formaty telefonu
SELECT phone
FROM customers
WHERE phone <> 'unknown'
  AND phone !~ '^\+48\d{9}$';

-- NAPRAWA: 9 ostatnich cyfr + prefiks +48
UPDATE customers
SET phone = '+48' || RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 9)
WHERE phone <> 'unknown'
  AND LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '', 'g')) >= 9;

-- KONTROLA
SELECT phone
FROM customers
WHERE phone <> 'unknown'
  AND phone !~ '^\+48\d{9}$';

SELECT phone
FROM customers;


-- ---------------------------------------------------------
-- 1.4. Miasto
-- ---------------------------------------------------------

-- Braki
SELECT *
FROM customers
WHERE city IS NULL
   OR TRIM(city) = '';

-- Różne wersje miasta
SELECT DISTINCT city
FROM customers;

SELECT city, COUNT(*)
FROM customers
GROUP BY city
ORDER BY COUNT(*) DESC;

-- TABELA POMOCNICZA: mapowanie miast
CREATE TABLE IF NOT EXISTS city_mapping (
    wariant VARCHAR(50) PRIMARY KEY,
    kanoniczna VARCHAR(50)
);

INSERT INTO city_mapping (wariant, kanoniczna) VALUES
    ('warszawa', 'Warszawa'),
    ('warszaw', 'Warszawa'),
    ('wwarszawa', 'Warszawa'),
    ('warszzawa', 'Warszawa'),
    ('warszawwa', 'Warszawa'),
    ('warszaawa', 'Warszawa'),
    ('warsszawa', 'Warszawa'),
    ('waarszawa', 'Warszawa'),
    ('warrszawa', 'Warszawa'),
    ('warszawaa', 'Warszawa'),

    ('kraków', 'Kraków'),
    ('krakó', 'Kraków'),
    ('kkraków', 'Kraków'),
    ('krakków', 'Kraków'),
    ('kraaków', 'Kraków'),

    ('łódź', 'Łódź'),
    ('łód', 'Łódź'),
    ('łóódź', 'Łódź'),
    ('łłódź', 'Łódź'),
    ('łóddź', 'Łódź'),

    ('wrocła', 'Wrocław'),
    ('wrocław', 'Wrocław'),
    ('wroocław', 'Wrocław'),
    ('wrocłław', 'Wrocław'),

    ('gdańsk', 'Gdańsk'),
    ('gdańs', 'Gdańsk'),
    ('gddańsk', 'Gdańsk'),
    ('gdaańsk', 'Gdańsk'),

    ('poznań', 'Poznań'),
    ('pozna', 'Poznań'),
    ('pozznań', 'Poznań'),
    ('pooznań', 'Poznań'),

    ('olszty', 'Olsztyn'),
    ('olsztyn', 'Olsztyn'),
    ('olszttyn', 'Olsztyn'),

    ('szczzecin', 'Szczecin'),
    ('szczecin', 'Szczecin'),
    ('szczeci', 'Szczecin'),
    ('szczeecin', 'Szczecin'),
    ('szczeccin', 'Szczecin'),

    ('gdynia', 'Gdynia'),
    ('gdyni', 'Gdynia'),
    ('gddynia', 'Gdynia'),

    ('leszno', 'Leszno'),
    ('lesznoo', 'Leszno'),
    ('leszn', 'Leszno'),

    ('białystok', 'Białystok'),
    ('białysto', 'Białystok'),

    ('katowice', 'Katowice'),
    ('katowicce', 'Katowice'),
    ('katowic', 'Katowice'),
    ('katowwice', 'Katowice'),

    ('bydgoszc', 'Bydgoszcz'),
    ('bydgoszzcz', 'Bydgoszcz'),
    ('bydgooszcz', 'Bydgoszcz'),
    ('bydgoszcz', 'Bydgoszcz'),

    ('suwałk', 'Suwałki'),
    ('suwałki', 'Suwałki'),
    ('suwaałki', 'Suwałki'),

    ('opole', 'Opole'),
    ('oppole', 'Opole'),
    ('opol', 'Opole'),

    ('elbląg', 'Elbląg'),
    ('elblą', 'Elbląg'),
    ('elblląg', 'Elbląg'),
    ('elblągg', 'Elbląg'),
    ('elbląąg', 'Elbląg'),
    ('eelbląg', 'Elbląg'),

    ('częstochowa', 'Częstochowa'),
    ('częęstochowa', 'Częstochowa'),
    ('częstochow', 'Częstochowa'),

    ('lubli', 'Lublin'),
    ('lublin', 'Lublin'),
    ('lubllin', 'Lublin'),

    ('radom', 'Radom'),
    ('rado', 'Radom'),
    ('raddom', 'Radom'),

    ('konin', 'Konin'),
    ('koni', 'Konin'),
    ('konnin', 'Konin'),

    ('rzeszów', 'Rzeszów'),
    ('rzesszów', 'Rzeszów'),
    ('rzeszó', 'Rzeszów'),
    ('rzzeszów', 'Rzeszów'),

    ('kielce', 'Kielce'),
    ('kiellce', 'Kielce'),
    ('kkielce', 'Kielce'),

    ('toruńń', 'Toruń'),

    ('zielona góra', 'Zielona Góra'),
    ('zzielona góra', 'Zielona Góra'),
    ('zielona górra', 'Zielona Góra'),
    ('zielona gór', 'Zielona Góra'),

    ('gorzów wielkopolsk', 'Gorzów Wielkopolski'),
    ('gorzów wielkopolski', 'Gorzów Wielkopolski'),
    ('gorzów wieelkopolski', 'Gorzów Wielkopolski'),
    ('gorzów wielkkopolski', 'Gorzów Wielkopolski'),
    ('goorzów wielkopolski', 'Gorzów Wielkopolski'),

    ('piła', 'Piła'),
    ('pił', 'Piła'),
    ('piłła', 'Piła'),
    ('piiła', 'Piła')
ON CONFLICT (wariant) DO NOTHING;

-- NAPRAWA: podstawowe mapowanie
UPDATE customers c
SET city = m.kanoniczna
FROM city_mapping m
WHERE LOWER(c.city) = m.wariant;

-- KONTROLA
SELECT DISTINCT city
FROM customers;

SELECT city, COUNT(*)
FROM customers
GROUP BY city
ORDER BY city;

-- Diagnostyka kodowania znaków
SELECT DISTINCT city, encode(city::bytea, 'hex')
FROM customers;

-- NAPRAWA: polskie wielkie litery
UPDATE customers c
SET city = m.kanoniczna
FROM city_mapping m
WHERE LOWER(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        c.city,
        'Ą','ą'),'Ć','ć'),'Ę','ę'),'Ł','ł'),'Ń','ń'),
        'Ó','ó'),'Ś','ś'),'Ź','ź'),'Ż','ż')
) = m.wariant;

-- KONTROLA
SELECT city, COUNT(*)
FROM customers
GROUP BY city
ORDER BY city;


-- ---------------------------------------------------------
-- 1.5. Kod pocztowy
-- ---------------------------------------------------------

-- Audyt formatu
SELECT *
FROM customers
WHERE postal_code IS NOT NULL
  AND postal_code !~ '^[0-9]{2}-[0-9]{3}$';

-- Spacje
SELECT *
FROM customers
WHERE postal_code != TRIM(postal_code);

-- WYKRYCIE PROBLEMU
SELECT customer_id, postal_code
FROM customers
WHERE postal_code !~ '^\d{2}-\d{3}$';

-- NAPRAWA: oznaczenie do weryfikacji
UPDATE customers
SET postal_code = 'do weryf'
WHERE postal_code !~ '^\d{2}-\d{3}$';

-- KONTROLA
SELECT customer_id, postal_code
FROM customers
WHERE postal_code !~ '^\d{2}-\d{3}$';


-- ---------------------------------------------------------
-- 1.6. Daty i pozostałe pola klienta
-- ---------------------------------------------------------

-- registration_date: niepoprawny format
SELECT *
FROM customers
WHERE registration_date IS NOT NULL
  AND registration_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

SELECT DISTINCT registration_date
FROM customers
ORDER BY registration_date;

-- marketing_channel
SELECT DISTINCT marketing_channel
FROM customers;

-- loyalty_member
SELECT DISTINCT loyalty_member
FROM customers;

-- Podejrzanie stare birth_date
SELECT *
FROM customers
WHERE birth_date < DATE '1900-01-01';

-- Wiek klienta
SELECT
    customer_id,
    birth_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) AS age
FROM customers
WHERE birth_date IS NOT NULL
ORDER BY age DESC;

-- Maksymalna data urodzenia
SELECT MAX(birth_date)
FROM customers
WHERE birth_date IS NOT NULL;

-- Klienci poniżej 18 lat
SELECT *
FROM customers
WHERE birth_date IS NOT NULL
  AND birth_date > CURRENT_DATE - INTERVAL '18 years';

-- Loyalty member bez emaila
SELECT *
FROM customers
WHERE loyalty_member = TRUE
  AND (
      email IS NULL
      OR TRIM(email) = ''
  );

-- Data rejestracji wcześniejsza niż data urodzenia
SELECT *
FROM customers
WHERE registration_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND birth_date IS NOT NULL
  AND registration_date::date < birth_date;


-- ---------------------------------------------------------
-- 1.7. Duplikaty klientów
-- ---------------------------------------------------------

-- WYKRYCIE
SELECT LOWER(TRIM(email)) AS email_norm, COUNT(*)
FROM customers
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1;

-- NAPRAWA KROK 1: scalenie historii zamówień
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

-- NAPRAWA KROK 2: usunięcie duplikatów
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

-- KONTROLA
SELECT LOWER(TRIM(email)) AS email_norm, COUNT(*)
FROM customers
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1;

-- DODATKOWY PROBLEM: suffix _dup
SELECT customer_id, email
FROM customers
WHERE email LIKE '%\_dup@%';

-- NAPRAWA: przepięcie zamówień
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

-- NAPRAWA: usunięcie rekordów _dup
DELETE FROM customers
WHERE customer_id IN (
    SELECT dup.customer_id
    FROM customers dup
    JOIN customers orig
      ON REPLACE(dup.email, '_dup@', '@') = orig.email
    WHERE dup.email LIKE '%\_dup@%'
);

-- KONTROLA
SELECT customer_id, email
FROM customers
WHERE email LIKE '%\_dup@%';


-- =========================================================
-- 2. TABELA ORDERS
-- =========================================================

-- ---------------------------------------------------------
-- 2.1. Podstawowy audyt
-- ---------------------------------------------------------

SELECT *
FROM orders;

-- Duplikaty order_id
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Ile razy powtarza się customer_id
SELECT customer_id, COUNT(*)
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Braki customer_id
SELECT customer_id
FROM orders
WHERE customer_id IS NULL;

-- Braki order_date
SELECT order_date
FROM orders
WHERE order_date IS NULL;

-- Format daty
SELECT order_date
FROM orders
WHERE order_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

-- order_status
SELECT DISTINCT order_status
FROM orders;

-- payment_method
SELECT DISTINCT payment_method
FROM orders;

-- shipping_cost
SELECT DISTINCT shipping_cost
FROM orders;

-- total_amount
SELECT DISTINCT total_amount
FROM orders;

-- Kwoty <= 0
SELECT COUNT(total_amount)
FROM orders
WHERE total_amount <= 0;

-- marketing_channel
SELECT DISTINCT marketing_channel
FROM orders;


-- ---------------------------------------------------------
-- 2.2. Duplikaty zamówień
-- ---------------------------------------------------------

-- WYKRYCIE
SELECT customer_id, order_date, COUNT(*)
FROM orders
GROUP BY customer_id, order_date
HAVING COUNT(*) > 1;

-- NAPRAWA KROK 1: usunięcie pozycji zamówień
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

-- NAPRAWA KROK 2: usunięcie nagłówków zamówień
WITH ranked AS (
    SELECT
        order_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, order_date
            ORDER BY order_id ASC
        ) AS rn
    FROM orders
)
DELETE FROM orders
WHERE order_id IN (
    SELECT order_id
    FROM ranked
    WHERE rn > 1
);

-- KONTROLA
SELECT customer_id, order_date, COUNT(*)
FROM orders
GROUP BY customer_id, order_date
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------
-- 2.3. Payment method
-- ---------------------------------------------------------

-- WYKRYCIE
SELECT order_id, order_status, payment_method
FROM orders
WHERE payment_method IS NULL;

SELECT order_id, order_status, payment_method
FROM orders;

-- Puste teksty -> NULL
UPDATE orders
SET payment_method = NULL
WHERE TRIM(payment_method) = '';

-- Sprawdzenie powiązania z order_status
SELECT order_status, COUNT(*)
FROM orders
WHERE payment_method IS NULL
GROUP BY order_status;

-- Realne błędy danych
SELECT *
FROM orders
WHERE payment_method IS NULL
  AND order_status <> 'Cancelled';


-- ---------------------------------------------------------
-- 2.4. Daty zamówień
-- ---------------------------------------------------------

-- WYKRYCIE
SELECT order_date
FROM orders
WHERE order_date !~ '^\d{4}-\d{2}-\d{2}$'
LIMIT 20;

-- NAPRAWA: DD.MM.YYYY
UPDATE orders
SET order_date = TO_CHAR(
    TO_DATE(order_date, 'DD.MM.YYYY'),
    'YYYY-MM-DD'
)
WHERE order_date ~ '^\d{2}\.\d{2}\.\d{4}$';

-- NAPRAWA: DD/MM/YYYY
UPDATE orders
SET order_date = TO_CHAR(
    TO_DATE(order_date, 'DD/MM/YYYY'),
    'YYYY-MM-DD'
)
WHERE order_date ~ '^\d{2}/\d{2}/\d{4}$';

-- KONTROLA
SELECT order_date
FROM orders
WHERE order_date !~ '^\d{4}-\d{2}-\d{2}$'
LIMIT 20;

SELECT DISTINCT order_date
FROM orders;

-- Zmiana typu kolumny
ALTER TABLE orders
ALTER COLUMN order_date TYPE DATE
USING order_date::DATE;


-- ---------------------------------------------------------
-- 2.5. Klienci bez zamówień
-- ---------------------------------------------------------

SELECT
    c.customer_id,
    c.email,
    c.registration_date
FROM customers c
LEFT JOIN orders o
  ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

CREATE OR REPLACE VIEW klienci_bez_zamowien AS
SELECT c.*
FROM customers c
LEFT JOIN orders o
  ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;


-- =========================================================
-- 3. TABELA ORDER_ITEMS
-- =========================================================

-- ---------------------------------------------------------
-- 3.1. Podstawowy audyt
-- ---------------------------------------------------------

SELECT *
FROM order_items;

-- Duplikaty order_item_id
SELECT
    order_item_id,
    COUNT(*) AS liczba
FROM order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;

-- Braki order_id
SELECT *
FROM order_items
WHERE order_id IS NULL;

-- Liczba pozycji na zamówienie
SELECT
    order_id,
    COUNT(*) AS liczba_pozycji
FROM order_items
WHERE order_id IS NOT NULL
GROUP BY order_id
ORDER BY liczba_pozycji DESC;

-- Braki product_id
SELECT *
FROM order_items
WHERE product_id IS NULL;

-- Częstotliwość produktów
SELECT
    product_id,
    COUNT(*) AS liczba_pozycji
FROM order_items
WHERE product_id IS NOT NULL
GROUP BY product_id
ORDER BY liczba_pozycji DESC;

-- Ten sam produkt więcej niż raz w zamówieniu
SELECT
    order_id,
    product_id,
    COUNT(*) AS liczba
FROM order_items
WHERE order_id IS NOT NULL
  AND product_id IS NOT NULL
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
ORDER BY liczba DESC;


-- ---------------------------------------------------------
-- 3.2. Quantity
-- ---------------------------------------------------------

-- Braki
SELECT *
FROM order_items
WHERE quantity IS NULL;

-- Ujemna ilość lub 0
SELECT *
FROM order_items
WHERE quantity <= 0;

-- Największe quantity
SELECT *
FROM order_items
WHERE quantity IS NOT NULL
ORDER BY quantity DESC;

-- WYKRYCIE zwrotów
SELECT *
FROM order_items
WHERE quantity < 0;


-- =========================================================
-- 4. TABELA RETURNS
-- =========================================================

CREATE TABLE IF NOT EXISTS returns (
    return_id SERIAL PRIMARY KEY,
    order_item_id INTEGER,
    quantity_returned INTEGER,
    return_date DATE DEFAULT CURRENT_DATE
);

-- Przeniesienie zwrotów
INSERT INTO returns (order_item_id, quantity_returned)
SELECT order_item_id, ABS(quantity)
FROM order_items
WHERE quantity < 0;

-- Usunięcie ujemnych quantity z order_items
DELETE FROM order_items
WHERE quantity < 0;

-- KONTROLA
SELECT *
FROM returns;


-- =========================================================
-- 5. POWRÓT DO ORDER_ITEMS
-- =========================================================

-- ---------------------------------------------------------
-- 5.1. Cena w momencie zamówienia
-- ---------------------------------------------------------

SELECT *
FROM order_items
WHERE unit_price_at_order IS NULL;

SELECT *
FROM order_items
WHERE unit_price_at_order <= 0;

SELECT
    MIN(unit_price_at_order) AS minimum,
    MAX(unit_price_at_order) AS maximum,
    AVG(unit_price_at_order) AS srednia
FROM order_items;

SELECT *
FROM order_items
WHERE unit_price_at_order IS NOT NULL
ORDER BY unit_price_at_order DESC;


-- ---------------------------------------------------------
-- 5.2. Rabaty
-- ---------------------------------------------------------

SELECT DISTINCT discount_pct
FROM order_items;

SELECT
    discount_pct,
    COUNT(*) AS liczba
FROM order_items
GROUP BY discount_pct
ORDER BY discount_pct;

-- Cena 0 przy rabacie < 100%
SELECT *
FROM order_items
WHERE unit_price_at_order = 0
  AND discount_pct < 100;


-- ---------------------------------------------------------
-- 5.3. Osierocone product_id
-- ---------------------------------------------------------

SELECT oi.*
FROM order_items oi
LEFT JOIN products p
  ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- =========================================================
-- 6. TABELA PRODUCTS
-- =========================================================

-- ---------------------------------------------------------
-- 6.1. Podstawowy audyt
-- ---------------------------------------------------------

-- Duplikaty product_id
SELECT
    product_id,
    COUNT(*) AS liczba
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Braki product_name
SELECT *
FROM products
WHERE product_name IS NULL
   OR TRIM(product_name) = '';

-- Spacje
SELECT *
FROM products
WHERE product_name != TRIM(product_name);

-- Podwójne spacje
SELECT *
FROM products
WHERE product_name LIKE '%  %';

-- Różne warianty nazw
SELECT
    LOWER(TRIM(product_name)) AS product_name_normalized,
    COUNT(DISTINCT product_name) AS variants
FROM products
WHERE product_name IS NOT NULL
GROUP BY LOWER(TRIM(product_name))
HAVING COUNT(DISTINCT product_name) > 1;

-- Potencjalne duplikaty nazw
SELECT
    LOWER(TRIM(product_name)) AS product_name_normalized,
    COUNT(*) AS liczba
FROM products
WHERE product_name IS NOT NULL
GROUP BY LOWER(TRIM(product_name))
HAVING COUNT(*) > 1;

SELECT DISTINCT product_name
FROM products
ORDER BY product_name;


-- ---------------------------------------------------------
-- 6.2. Kategorie
-- ---------------------------------------------------------

SELECT *
FROM products
WHERE category IS NULL
   OR TRIM(category) = '';

SELECT
    category,
    COUNT(*) AS liczba
FROM products
GROUP BY category
ORDER BY liczba DESC;

SELECT
    LOWER(TRIM(category)) AS category_normalized,
    COUNT(DISTINCT category) AS variants
FROM products
WHERE category IS NOT NULL
GROUP BY LOWER(TRIM(category))
HAVING COUNT(DISTINCT category) > 1;

SELECT *
FROM products
WHERE category != TRIM(category);

SELECT DISTINCT category
FROM products
ORDER BY category;

-- NAPRAWA kategorii
UPDATE products
SET category = 'Elektronika'
WHERE LOWER(TRIM(category)) IN ('elektronika', 'electronics');

UPDATE products
SET category = 'Moda damska'
WHERE LOWER(TRIM(category)) IN ('moda damska', 'women fashion');

UPDATE products
SET category = 'Moda męska'
WHERE LOWER(TRIM(category)) = 'moda męska';

UPDATE products
SET category = 'Dom i wnętrza'
WHERE LOWER(TRIM(category)) = 'dom i wnętrza';

UPDATE products
SET category = 'Uroda'
WHERE LOWER(TRIM(category)) IN ('uroda', 'beauty');

UPDATE products
SET category = 'Sport'
WHERE LOWER(TRIM(category)) = 'sport';

UPDATE products
SET category = 'Dziecko'
WHERE LOWER(TRIM(category)) = 'dziecko';

UPDATE products
SET category = 'Akcesoria'
WHERE LOWER(TRIM(category)) = 'akcesoria';

-- Dodatkowa naprawa problemów z polskimi znakami
UPDATE products
SET category = 'Moda męska'
WHERE LOWER(TRIM(REPLACE(category, 'Ę', 'ę'))) = 'moda męska';

UPDATE products
SET category = 'Dom i wnętrza'
WHERE LOWER(TRIM(REPLACE(category, 'Ę', 'ę'))) = 'dom i wnętrza';

-- Diagnostyka kodowania
SELECT DISTINCT category, encode(category::bytea, 'hex')
FROM products;

-- KONTROLA
SELECT DISTINCT category
FROM products
ORDER BY category;


-- ---------------------------------------------------------
-- 6.3. Marka
-- ---------------------------------------------------------

SELECT *
FROM products
WHERE brand IS NULL
   OR TRIM(brand) = '';

SELECT
    brand,
    COUNT(*) AS liczba
FROM products
GROUP BY brand
ORDER BY liczba DESC;

SELECT
    LOWER(TRIM(brand)) AS brand_normalized,
    COUNT(DISTINCT brand) AS variants
FROM products
WHERE brand IS NOT NULL
GROUP BY LOWER(TRIM(brand))
HAVING COUNT(DISTINCT brand) > 1;

SELECT *
FROM products
WHERE brand != TRIM(brand);

SELECT DISTINCT brand
FROM products
ORDER BY brand;


-- ---------------------------------------------------------
-- 6.4. Cena produktu
-- ---------------------------------------------------------

-- Braki
SELECT *
FROM products
WHERE unit_price IS NULL;

-- WYKRYCIE: cena <= 0
SELECT product_id, product_name, unit_price
FROM products
WHERE unit_price <= 0;

-- Statystyki
SELECT
    MIN(unit_price) AS minimum,
    MAX(unit_price) AS maximum,
    AVG(unit_price) AS srednia
FROM products;

-- Najdroższe produkty
SELECT *
FROM products
WHERE unit_price IS NOT NULL
ORDER BY unit_price DESC;

-- NAPRAWA: flagowanie do weryfikacji
ALTER TABLE products
ADD COLUMN IF NOT EXISTS wymaga_weryfikacji BOOLEAN DEFAULT FALSE;

UPDATE products
SET wymaga_weryfikacji = TRUE
WHERE unit_price <= 0;

-- KONTROLA
SELECT
    product_id,
    product_name,
    unit_price,
    wymaga_weryfikacji
FROM products
WHERE unit_price <= 0;


-- ---------------------------------------------------------
-- 6.5. Koszt produktu
-- ---------------------------------------------------------

SELECT *
FROM products
WHERE unit_cost IS NULL;

SELECT *
FROM products
WHERE unit_cost <= 0;

SELECT
    MIN(unit_cost) AS minimum,
    MAX(unit_cost) AS maximum,
    AVG(unit_cost) AS srednia
FROM products;


-- ---------------------------------------------------------
-- 6.6. Data premiery i aktywność
-- ---------------------------------------------------------

SELECT *
FROM products
WHERE launch_date IS NULL;

SELECT *
FROM products
WHERE launch_date > CURRENT_DATE;

SELECT *
FROM products
WHERE launch_date < DATE '1990-01-01';

SELECT
    product_id,
    product_name,
    launch_date
FROM products
WHERE launch_date IS NOT NULL
ORDER BY launch_date;

SELECT
    product_id,
    product_name,
    launch_date
FROM products
WHERE launch_date IS NOT NULL
ORDER BY launch_date DESC;

SELECT
    is_active,
    COUNT(*) AS liczba
FROM products
GROUP BY is_active;

SELECT *
FROM products
WHERE is_active IS NULL;


-- ---------------------------------------------------------
-- 6.7. Wartości odstające cen - IQR
-- ---------------------------------------------------------

WITH kwartyle AS (
    SELECT
        category,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY unit_price) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY unit_price) AS q3
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

SELECT category, unit_price
FROM products
GROUP BY category, unit_price
ORDER BY category, unit_price;


-- ---------------------------------------------------------
-- 6.8. Produkt archiwalny dla osieroconych order_items
-- ---------------------------------------------------------

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

-- KONTROLA
SELECT oi.*
FROM order_items oi
LEFT JOIN products p
  ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT *
FROM products;


-- =========================================================
-- 7. TABELA INVENTORY
-- =========================================================

-- ---------------------------------------------------------
-- 7.1. Ujemne stany magazynowe
-- ---------------------------------------------------------

SELECT *
FROM inventory
WHERE stock_quantity < 0;

UPDATE inventory
SET stock_quantity = 0
WHERE stock_quantity < 0;

SELECT *
FROM inventory
WHERE stock_quantity < 0;


-- ---------------------------------------------------------
-- 7.2. Spacje w warehouse_location
-- ---------------------------------------------------------

SELECT *
FROM inventory
WHERE warehouse_location != TRIM(warehouse_location);

UPDATE inventory
SET warehouse_location = TRIM(warehouse_location);

SELECT *
FROM inventory
WHERE warehouse_location != TRIM(warehouse_location);

SELECT warehouse_location
FROM inventory;


-- =========================================================
-- KONIEC SKRYPTU
-- =========================================================
