# ShopFlow — projekt oczyszczania danych e-commerce

## 🎯 Cel projektu

Celem projektu było dokładne oczyszczenie i przygotowanie danych sprzedażowych symulowanego sklepu internetowego **ShopFlow**.

## 📌 Opis projektu

Dane pochodzą z symulowanego sklepu internetowego **ShopFlow**, działającego na rynku polskim w branży e-commerce, obejmującej m.in.:

- modę,
- elektronikę,
- dom i wnętrza,
- urodę.
- 
## 🗂️ Dane
Zbiór obejmuje około **85 000 rekordów** w 5 powiązanych tabelach oraz **24 miesiące historii sprzedaży**:

- `customers` — ok. 5 000 rekordów,
- `products` — ok. 2 000 rekordów,
- `orders` — ok. 20 000 rekordów,
- `order_items` — ok. 49 000 rekordów,
- `inventory` — ok. 2 000 rekordów.
-
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

Problemy zostały przeanalizowane i naprawione przy użyciu **SQL** oraz **PostgreSQL**.

---

## 👤 Tabela `customers`

Tabela `customers` została sprawdzona pod kątem duplikatów `customer_id`, poprawności imion i nazwisk, pustych wartości, zbędnych spacji oraz obecności cyfr lub niepożądanych znaków.

Nie znaleziono błędów w kolumnach `customer_id`, `first_name` i `last_name`.

### 1. Niespójne formaty numerów telefonów

Numery telefonów występowały w wielu różnych formatach, m.in. z prefiksem `+48`, bez prefiksu, ze spacjami lub myślnikami.

Numery zostały ustandaryzowane do formatu `+48XXXXXXXXX`. Brakujące wartości oznaczono jako `unknown`. Dodatkowo zweryfikowano długość numerów telefonów.

<details>
<summary>📷 Zobacz przykłady przed i po czyszczeniu</summary>

**Przed czyszczeniem**

![Różne formaty telefonów](image/surowe_dane/telefony_rozne_formaty_customers.png)

**Po czyszczeniu**

![Telefony po czyszczeniu](image/oczyszczone_dane/telefony_po_czyszczeniu.png)

**Brakujące numery oznaczone jako `unknown`**

![Brakujące telefony oznaczone jako unknown](image/oczyszczone_dane/telefony_unknown.png)

</details>

---

### 2. Niepoprawne kody pocztowe

W kolumnie `postalcode` część kodów pocztowych klientów nie była zgodna z polskim formatem `XX-XXX`.

Rekordy, których nie można było jednoznacznie poprawić, zostały oznaczone do dalszej weryfikacji.

<details>
<summary>📷 Zobacz przykłady kodów pocztowych</summary>

**Przed czyszczeniem**

![Niepoprawne kody pocztowe](image/surowe_dane/kody_pocztowe_customers.png)

**Rekordy oznaczone do weryfikacji**

![Kody pocztowe do weryfikacji](image/oczyszczone_dane/kody_pocztowe_do_weryfikacji.png)

</details>

---

### 3. Niespójne adresy e-mail

W adresach e-mail występowały:

- różnice w wielkości liter,
- zbędne spacje,
- brak jednolitego formatu.

Adresy zostały ujednolicone do jednego standardu.

<details>
<summary>📷 Zobacz przykłady adresów e-mail</summary>

**Przed czyszczeniem**

![Niespójne adresy e-mail](image/surowe_dane/Emaile_customers.png)

**Po czyszczeniu**

![E-maile po czyszczeniu](image/oczyszczone_dane/emaile_po_czyszczeniu.png)

</details>

---

### 4. Literówki i niespójne nazwy miast

W kolumnie `city` występowały różne warianty tej samej miejscowości, np. `Warsszawa` i `Warszawa`, a także problemy z wielkością liter.

Utworzono tabelę mapującą, która pozwoliła przypisać błędne warianty do poprawnych nazw miast.

<details>
<summary>📷 Zobacz przykłady nazw miast</summary>

**Przed czyszczeniem**

![Niespójne nazwy miast](image/surowe_dane/miasta_customers.png)

**Po czyszczeniu**

![Miasta po czyszczeniu](image/oczyszczone_dane/miasta_po_czyszczeniu.png)

</details>

---

### 5. Duplikaty klientów

Wykryto rekordy klientów posiadających ten sam znormalizowany adres e-mail.

Duplikaty zostały scalone na podstawie znormalizowanego adresu e-mail. Zachowano rekord z najwcześniejszą datą rejestracji, przypisano do niego historię zamówień, a pozostałe duplikaty usunięto.

<details>
<summary>📷 Zobacz wykryte duplikaty klientów</summary>

![Duplikaty klientów](image/surowe_dane/duplikaty_klientów_customers.png)

</details>

---

### 6. Dodatkowe duplikaty z sufiksem `_dup`

Część duplikatów posiadała zmodyfikowany adres e-mail, np.:

```text
jan.kowalski@gmail.com
jan.kowalski_dup@gmail.com
```

Takie rekordy wymagały osobnej reguły identyfikacji i scalania. Adresy e-mail zostały następnie oczyszczone i ujednolicone.

<details>
<summary>📷 Zobacz dodatkowe duplikaty</summary>

**Duplikaty z sufiksem `_dup`**

![Duplikaty z sufiksem dup](image/surowe_dane/dodatkowe_duplikaty_customers.png)

**E-maile po czyszczeniu**

![E-maile po czyszczeniu](image/oczyszczone_dane/emaile_po_czyszczeniu.png)

</details>

---

### 7. Klienci bez zamówień

Zidentyfikowano klientów, którzy założyli konto, ale nie złożyli żadnego zamówienia.

Rekordy nie zostały usunięte, ponieważ nie stanowią błędu danych. Utworzono widok `klienci_bez_zamowien`, aby umożliwić dalszą analizę tego segmentu pod kątem aktywacji, retencji i konwersji klientów.

---

## 📦 Tabela `products`

W tabeli produktów problemy dotyczyły przede wszystkim cen oraz niespójnych kategorii produktowych.

### 1. Produkty z ceną równą `0`

W katalogu znaleziono produkty, których `unit_price` wynosiło `0`.

Rekordy nie zostały automatycznie usunięte. Zostały oznaczone do weryfikacji, ponieważ bez dodatkowych informacji nie można było jednoznacznie stwierdzić, czy cena była błędem.

<details>
<summary>📷 Zobacz produkty z ceną równą 0</summary>

**Przed oznaczeniem**

![Produkty z ceną 0](image/surowe_dane/cena_0_products.png)

**Po oznaczeniu do weryfikacji**

![Produkty z ceną oznaczoną do weryfikacji](image/oczyszczone_dane/cena_oflagowana.png)

</details>

---

### 2. Niespójne kategorie produktów

Nazwy kategorii występowały w różnych wariantach, m.in.:

- różna wielkość liter,
- polskie i angielskie nazwy,
- dodatkowe spacje,
- różne warianty tej samej kategorii.

Kategorie zostały ujednolicone do jednego zestawu wartości.

<details>
<summary>📷 Zobacz przykłady kategorii produktów</summary>

**Przed czyszczeniem**

![Niespójne kategorie produktów](image/surowe_dane/kategorie_products.png)

**Po czyszczeniu**

![Kategorie po czyszczeniu](image/oczyszczone_dane/kategorie_po_czyszczeniu.png)

</details>

---

### 3. Wartości odstające cen produktów

W danych występowały produkty o cenach znacznie wyższych niż typowe ceny w danej kategorii.

Potencjalne wartości odstające zostały wykryte metodą statystyczną **IQR**. Rekordy nie zostały usunięte, ponieważ wysoka cena produktu nie musi oznaczać błędu danych. W rzeczywistym projekcie wymagałyby dodatkowej weryfikacji biznesowej.

<details>
<summary>📷 Zobacz przykłady wartości odstających</summary>

![Produkty z nietypową ceną](image/surowe_dane/produkty_z_dziwną_ceną.png)

</details>

---

## 🧾 Tabela `orders`

W tabeli zamówień zidentyfikowano problemy związane z duplikacją rekordów oraz formatem dat.

### 1. Duplikaty zamówień

Wykryto klientów posiadających więcej niż jedno zamówienie o tej samej dacie.

Duplikaty zostały zidentyfikowane na podstawie `customer_id` i `order_date`. W każdej grupie zachowano rekord z najniższym `order_id`. Najpierw usunięto powiązane pozycje z tabeli `order_items`, a następnie nadmiarowe rekordy z tabeli `orders`.

<details>
<summary>📷 Zobacz wykryte duplikaty zamówień</summary>

![Duplikaty zamówień](image/surowe_dane/duplikaty_zamówień_orders.png)

</details>

---

### 2. Niespójne formaty dat

Daty zamówień występowały w kilku formatach, np.:

- `08.09.2024`,
- `26/12/2024`,
- `2024-12-26`.

Wszystkie daty zostały ujednolicone do formatu `YYYY-MM-DD`, a następnie kolumnę przekonwertowano na typ `DATE`.

<details>
<summary>📷 Zobacz przykłady dat przed i po czyszczeniu</summary>

**Przed czyszczeniem**

![Różne formaty dat](image/surowe_dane/rozne_formaty_dat_orders.png)

**Po czyszczeniu**

![Daty po naprawie](image/oczyszczone_dane/daty_po_naprawie.png)

</details>

---

### 3. Braki w metodzie płatności

W kolumnie `payment_method` występowały puste wartości zapisane jako pusty tekst.

Puste wartości zostały przekonwertowane do `NULL`, a następnie zweryfikowano ich zgodność ze statusem zamówienia. Braki występowały przy zamówieniach anulowanych (`Cancelled`), dlatego uznano je za poprawne i pozostawiono bez dalszych zmian.

<details>
<summary>📷 Zobacz brakujące metody płatności</summary>

![Brak płatności](image/surowe_dane/Tabela_order_payment_method.png)

</details>

---

## 🛒 Tabela `order_items`

### 1. Ujemne wartości `quantity`

W tabeli pozycji zamówień występowały rekordy z ujemną liczbą produktów.

Ujemne wartości zostały zinterpretowane jako zwroty zapisane w niewłaściwym miejscu. Nie zmieniono ich bezpośrednio. Utworzono osobną tabelę `returns`, do której przeniesiono informacje o zwrotach.

<details>
<summary>📷 Zobacz przykłady zwrotów</summary>

**Ujemne wartości `quantity`**

![Ujemne quantity](image/surowe_dane/ujemne_quantity_order_items.png)

**Tabela `returns`**

![Tabela returns](image/oczyszczone_dane/return.png)

</details>

---

### 2. Osierocone `product_id`

W tabeli `order_items` występowały osierocone `product_id`, czyli rekordy odwołujące się do produktów, które nie istniały już w tabeli `products`.

Utworzono techniczny rekord `Produkt zarchiwizowany / brak danych` z `product_id = -1`, a następnie przypisano do niego wszystkie osierocone pozycje zamówień. Dzięki temu zachowano historyczne dane sprzedażowe i przywrócono spójność między tabelami.

<details>
<summary>📷 Zobacz rekord produktu zarchiwizowanego</summary>

![Produkt zarchiwizowany](images/Produkt_zarchiwizowany.png)

</details>

---

## 🏭 Tabela `inventory`

W danych magazynowych zidentyfikowano problemy związane ze stanami magazynowymi oraz formatem lokalizacji.

### 1. Ujemne stany magazynowe

W kolumnie `stock_quantity` występowały wartości poniżej zera.

Ujemne wartości zostały zastąpione wartością `0`, ponieważ fizyczny stan magazynowy nie może być ujemny. Rekordy te nadal wymagają weryfikacji biznesowej, aby ustalić przyczynę wystąpienia ujemnych stanów.

<details>
<summary>📷 Zobacz ujemne stany magazynowe</summary>

![Ujemne stany magazynowe](image/surowe_dane/ujemne_stock_quantity_inventory.png)

</details>

---

### 2. Zbędne spacje w lokalizacji magazynowej

W kolumnie `warehouse_location` występowały dodatkowe spacje.

Spacje zostały usunięte i wartości ujednolicono.

<details>
<summary>📷 Zobacz lokalizacje przed i po czyszczeniu</summary>

**Przed czyszczeniem**

![Spacje w lokalizacji magazynowej](image/surowe_dane/spacje_warehouse_inventory.png)

**Po czyszczeniu**

![Lokalizacje magazynowe bez zbędnych spacji](image/oczyszczone_dane/warehouse_bez_spacji.png)

</details>

---

## ✅ Podsumowanie

