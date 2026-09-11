# ShopFlow — projekt oczyszczania danych e-commerce

## 🎯 Cel projektu

Celem projektu było dokładne oczyszczenie i przygotowanie danych sprzedażowych symulowanego sklepu internetowego **ShopFlow** do dalszej analizy.

## 📌 Opis projektu

Dane pochodzą z symulowanego sklepu internetowego **ShopFlow**, działającego na rynku polskim w branży e-commerce, obejmującej m.in.:

- modę,
- elektronikę,
- dom i wnętrza,
- urodę.

Zbiór obejmuje około **85 000 rekordów** w 5 powiązanych tabelach oraz **24 miesiące historii sprzedaży**:

- `customers` — ok. 5 000 rekordów,
- `products` — ok. 2 000 rekordów,
- `orders` — ok. 20 000 rekordów,
- `order_items` — ok. 49 000 rekordów,
- `inventory` — ok. 2 000 rekordów.

## 🧹 Czyszczenie i przygotowanie danych

Przed rozpoczęciem właściwej analizy przeprowadzono kontrolę jakości danych we wszystkich tabelach.

Zidentyfikowano m.in.:

- braki danych,
- duplikaty,
- niespójne formaty,
- błędne wartości,
- literówki,
- wartości odstające,
- problemy z integralnością danych.

Poniżej przedstawiono najważniejsze problemy oraz wybrane fragmenty kodu SQL pokazujące sposób ich rozwiązania. Wszystkie zapytania znajdują się w głównym skrypcie SQL projektu.

---

## 👤 Tabela `customers`

Tabela `customers` została sprawdzona pod kątem duplikatów `customer_id`, poprawności imion i nazwisk, pustych wartości, zbędnych spacji oraz obecności cyfr lub niepożądanych znaków.

Nie znaleziono błędów w kolumnach `customer_id`, `first_name` i `last_name`.

### 1. Niespójne formaty numerów telefonów

Numery telefonów występowały w wielu różnych formatach, m.in. z prefiksem `+48`, bez prefiksu, ze spacjami lub myślnikami.

Numery zostały ustandaryzowane do formatu `+48XXXXXXXXX`. Brakujące wartości oznaczono jako `unknown`. Dodatkowo zweryfikowano długość numerów telefonów.

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

**Przed czyszczeniem**

![Różne formaty telefonów](image/surowe_dane/telefony_rozne_formaty_customers.png)

**Po czyszczeniu**

![Telefony po czyszczeniu](image/oczyszczone_dane/telefony_po_czyszczeniu.png)

**Brakujące numery oznaczone jako `unknown`**

![Brakujące telefony oznaczone jako unknown](image/oczyszczone_dane/telefony_unknown.png)

---

### 2. Niepoprawne kody pocztowe

W kolumnie `postal_code` część kodów pocztowych klientów nie była zgodna z polskim formatem `XX-XXX`.

Rekordy, których nie można było jednoznacznie poprawić, nie zostały automatycznie zmienione na potencjalnie błędną wartość. Zostały oznaczone do dalszej weryfikacji.

```sql
UPDATE customers
SET postal_code = 'do weryf'
WHERE postal_code !~ '^\d{2}-\d{3}$';
```

**Przed czyszczeniem**

![Niepoprawne kody pocztowe](image/surowe_dane/kody_pocztowe_customers.png)

**Rekordy oznaczone do weryfikacji**

![Kody pocztowe do weryfikacji](image/oczyszczone_dane/kody_pocztowe_do_weryfikacji.png)

---

### 3. Niespójne adresy e-mail

W adresach e-mail występowały różnice w wielkości liter, zbędne spacje oraz brak jednolitego formatu.

Adresy zostały ujednolicone przez usunięcie zbędnych spacji i konwersję do małych liter.

```sql
UPDATE customers
SET email = LOWER(TRIM(email));
```

Dodatkowo znormalizowany adres e-mail wykorzystano później do identyfikacji duplikatów klientów.

**Przed czyszczeniem**

![Niespójne adresy e-mail](image/surowe_dane/Emaile_customers.png)

**Po czyszczeniu**

![E-maile po czyszczeniu](image/oczyszczone_dane/emaile_po_czyszczeniu.png)

---

### 4. Literówki i niespójne nazwy miast

W kolumnie `city` występowały różne warianty tej samej miejscowości, np. `Warsszawa` i `Warszawa`, a także problemy z wielkością liter.

Zamiast tworzyć wiele osobnych instrukcji `UPDATE`, utworzono tabelę mapującą błędne warianty na kanoniczne nazwy miast. Poniżej pokazano skrócony fragment mapowania — pełna lista znajduje się w skrypcie SQL.

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

**Przed czyszczeniem**

![Niespójne nazwy miast](image/surowe_dane/miasta_customers.png)

**Po czyszczeniu**

![Miasta po czyszczeniu](image/oczyszczone_dane/miasta_po_czyszczeniu.png)

---

### 5. Duplikaty klientów

Wykryto rekordy klientów posiadających ten sam znormalizowany adres e-mail.

Duplikaty zostały scalone na podstawie `LOWER(TRIM(email))`. Za rekord główny uznano klienta z najwcześniejszą datą rejestracji, a przy remisie — z najniższym `customer_id`.

Przed usunięciem duplikatów ich zamówienia zostały przypisane do zachowanego rekordu klienta. Dzięki temu nie utracono historii zakupowej.

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

Po przepięciu historii zamówień nadmiarowe rekordy zostały usunięte.

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

![Duplikaty klientów](image/surowe_dane/duplikaty_klient%C3%B3w_customers.png)

---

### 6. Dodatkowe duplikaty z sufiksem `_dup`

Część duplikatów posiadała zmodyfikowany adres e-mail, np.:

```text
jan.kowalski@gmail.com
jan.kowalski_dup@gmail.com
```

Takie rekordy nie zostały wykryte przez standardowe grupowanie po identycznym, znormalizowanym adresie e-mail, dlatego wymagały dodatkowej reguły identyfikacji.

Najpierw zamówienia przypisano do oryginalnego klienta, a następnie usunięto techniczne duplikaty z sufiksem `_dup`.

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

**Duplikaty z sufiksem `_dup`**

![Duplikaty z sufiksem dup](image/surowe_dane/dodatkowe_duplikaty_customers.png)

**E-maile po czyszczeniu**

![E-maile po czyszczeniu](image/oczyszczone_dane/emaile_po_czyszczeniu.png)

---

### 7. Klienci bez zamówień

Zidentyfikowano klientów, którzy założyli konto, ale nie złożyli żadnego zamówienia.

Rekordy nie zostały usunięte, ponieważ nie stanowią błędu danych. Utworzono widok `klienci_bez_zamowien`, aby umożliwić dalszą analizę tego segmentu pod kątem aktywacji, retencji i konwersji klientów.

```sql
CREATE OR REPLACE VIEW klienci_bez_zamowien AS
SELECT c.*
FROM customers c
LEFT JOIN orders o
  ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
```

---

## 📦 Tabela `products`

W tabeli produktów problemy dotyczyły przede wszystkim cen oraz niespójnych kategorii produktowych.

### 1. Produkty z ceną równą `0`

W katalogu znaleziono produkty, których `unit_price` wynosiło `0`.

Rekordy nie zostały automatycznie usunięte ani otrzymały sztucznie wyliczonej ceny. Zostały oznaczone do weryfikacji, ponieważ bez dodatkowych informacji biznesowych nie można było jednoznacznie stwierdzić, czy cena była błędem.

```sql
ALTER TABLE products
ADD COLUMN IF NOT EXISTS wymaga_weryfikacji BOOLEAN DEFAULT FALSE;

UPDATE products
SET wymaga_weryfikacji = TRUE
WHERE unit_price <= 0;
```

**Przed oznaczeniem**

![Produkty z ceną 0](image/surowe_dane/cena_0_products.png)

**Po oznaczeniu do weryfikacji**

![Produkty z ceną oznaczoną do weryfikacji](image/oczyszczone_dane/cena_oflagowana.png)

---

### 2. Niespójne kategorie produktów

Nazwy kategorii występowały w różnych wariantach: z różną wielkością liter, dodatkowymi spacjami oraz w polskiej i angielskiej wersji językowej.

Kategorie zostały sprowadzone do jednego zestawu wartości. Przykład:

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

**Przed czyszczeniem**

![Niespójne kategorie produktów](image/surowe_dane/kategorie_products.png)

**Po czyszczeniu**

![Kategorie po czyszczeniu](image/oczyszczone_dane/kategorie_po_czyszczeniu.png)

---

### 3. Wartości odstające cen produktów

W danych występowały produkty o cenach znacznie wyższych niż typowe ceny w danej kategorii.

Potencjalne wartości odstające zostały wykryte metodą statystyczną **IQR (Interquartile Range)** osobno dla każdej kategorii produktowej.

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

Rekordy nie zostały automatycznie usunięte, ponieważ wysoka cena produktu nie musi oznaczać błędu danych. W rzeczywistym projekcie wymagałyby dodatkowej weryfikacji biznesowej.

![Produkty z nietypową ceną](image/surowe_dane/produkty_z_dziwn%C4%85_cen%C4%85.png)

---

## 🧾 Tabela `orders`

W tabeli zamówień zidentyfikowano problemy związane z duplikacją rekordów, formatem dat oraz brakami w metodzie płatności.

### 1. Duplikaty zamówień

Wykryto klientów posiadających więcej niż jedno zamówienie o tej samej dacie.

Duplikaty zostały identyfikowane na podstawie `customer_id` i `order_date`. W każdej grupie zachowano rekord z najniższym `order_id`.

Ze względu na relację z `order_items` najpierw usunięto pozycje należące do nadmiarowych zamówień, a następnie same rekordy z tabeli `orders`.

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

![Duplikaty zamówień](image/surowe_dane/duplikaty_zam%C3%B3wie%C5%84_orders.png)

---

### 2. Niespójne formaty dat

Daty zamówień występowały w kilku formatach, np.:

- `08.09.2024`,
- `26/12/2024`,
- `2024-12-26`.

Najpierw ujednolicono zapis do formatu `YYYY-MM-DD`, a następnie zmieniono typ kolumny na `DATE`.

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

**Przed czyszczeniem**

![Różne formaty dat](image/surowe_dane/rozne_formaty_dat_orders.png)

**Po czyszczeniu**

![Daty po naprawie](image/oczyszczone_dane/daty_po_naprawie.png)

---

### 3. Braki w metodzie płatności

W kolumnie `payment_method` występowały puste wartości zapisane jako pusty tekst.

Puste ciągi znaków zostały przekonwertowane do `NULL`, a następnie sprawdzono ich zależność od statusu zamówienia.

```sql
UPDATE orders
SET payment_method = NULL
WHERE TRIM(payment_method) = '';

SELECT order_status, COUNT(*)
FROM orders
WHERE payment_method IS NULL
GROUP BY order_status;
```

Braki występowały przy zamówieniach anulowanych (`Cancelled`), dlatego uznano je za logicznie dopuszczalne i pozostawiono bez dalszych zmian.

![Brak płatności](image/surowe_dane/Tabela_order_payment_method.png)

---

## 🛒 Tabela `order_items`

### 1. Ujemne wartości `quantity`

W tabeli pozycji zamówień występowały rekordy z ujemną liczbą produktów.

Ujemne wartości zostały zinterpretowane jako zwroty zapisane w niewłaściwym miejscu. Informacje o nich przeniesiono do osobnej tabeli `returns`, a następnie odpowiadające im rekordy usunięto z `order_items`.

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

Takie podejście pozwoliło rozdzielić sprzedaż od zwrotów bez utraty informacji o zwróconej ilości.

**Ujemne wartości `quantity`**

![Ujemne quantity](image/surowe_dane/ujemne_quantity_order_items.png)

**Tabela `returns`**

![Tabela returns](image/oczyszczone_dane/return.png)

---

### 2. Osierocone `product_id`

W tabeli `order_items` występowały osierocone `product_id`, czyli rekordy odwołujące się do produktów, które nie istniały już w tabeli `products`.

Zamiast usuwać historyczne pozycje sprzedażowe utworzono techniczny rekord produktu z `product_id = -1`, a następnie przypisano do niego wszystkie osierocone pozycje.

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

Dzięki temu zachowano historyczne dane sprzedażowe i przywrócono spójność między tabelami.

![Produkt zarchiwizowany](image/oczyszczone_dane/Produkt_zarchiwizowany.png)

---

## 🏭 Tabela `inventory`

W danych magazynowych zidentyfikowano problemy związane ze stanami magazynowymi oraz formatem lokalizacji.

### 1. Ujemne stany magazynowe

W kolumnie `stock_quantity` występowały wartości poniżej zera.

Ujemne wartości zostały zastąpione wartością `0`, ponieważ fizyczny stan magazynowy nie może być ujemny. Rekordy te nadal wymagają weryfikacji biznesowej, aby ustalić przyczynę wystąpienia problemu.

```sql
UPDATE inventory
SET stock_quantity = 0
WHERE stock_quantity < 0;
```

![Ujemne stany magazynowe](image/surowe_dane/ujemne_stock_quantity_inventory.png)

---

### 2. Zbędne spacje w lokalizacji magazynowej

W kolumnie `warehouse_location` występowały dodatkowe spacje. Wartości zostały oczyszczone przy użyciu funkcji `TRIM()`.

```sql
UPDATE inventory
SET warehouse_location = TRIM(warehouse_location);
```

**Przed czyszczeniem**

![Spacje w lokalizacji magazynowej](image/surowe_dane/spacje_warehouse_inventory.png)

**Po czyszczeniu**

![Lokalizacje magazynowe bez zbędnych spacji](image/oczyszczone_dane/warehouse_bez_spacji.png)

---

## ✅ Podsumowanie

W ramach projektu:

- przeprowadzono kontrolę jakości danych w 5 tabelach,
- ujednolicono formaty danych tekstowych, dat, numerów telefonów i adresów e-mail,
- wykryto i obsłużono duplikaty przy zachowaniu powiązanej historii zamówień,
- zidentyfikowano wartości odstające metodą IQR oraz rekordy wymagające weryfikacji biznesowej,
- naprawiono wybrane problemy z integralnością referencyjną,
- zachowano historyczne dane tam, gdzie automatyczne usunięcie mogłoby prowadzić do utraty informacji,
- utworzono dodatkowe struktury pomocnicze, m.in. tabelę `returns`, tabelę `city_mapping` oraz widok `klienci_bez_zamowien`.

Oczyszczone dane posłużyły do właściwej analizy
