## Домашнее задание № 10
### Название урока: Виды индексов. Работа с индексами и оптимизация запросов

Цель:
- знать и уметь применять основные виды индексов PostgreSQL
- строить и анализировать план выполнения запроса
- уметь оптимизировать запросы для с использованием индексов

Создать индексы на БД, которые ускорят доступ к данным.

### В данном задании тренируются навыки:

- определения узких мест
- написания запросов для создания индекса
- оптимизации

### Описание/Пошаговая инструкция выполнения домашнего задания:
Необходимо:
1. Создать индекс к какой-либо из таблиц вашей БД
2. Прислать текстом результат команды explain,
в которой используется данный индекс
3. Реализовать индекс для полнотекстового поиска
4. Реализовать индекс на часть таблицы или индекс
на поле с функцией
5. Создать индекс на несколько полей
6. Написать комментарии к каждому из индексов
7. Описать что и как делали и с какими проблемами
столкнулись


### Выполнение домашнего задания

#### Структура таблиц 

Структура БД и наполнение таблиц взяты с прошлого домашнего задания

Подключаемся к PostgreSQL: ```sudo -u postgres psql```

Создаем БД и подключаемся к ней: ```CREATE DATABASE shop;``` и ```\c shop;```

Ниже пример небольшого интернет-магазина:

- customers — клиенты

- orders — заказы

- order_items — позиции в заказе

- products — товары

- categories — категории товаров

- payments — оплаты (не у всех заказов может быть оплата)

```
-- Таблица клиентов
CREATE TABLE customers (
    customer_id   BIGSERIAL PRIMARY KEY,
    full_name     TEXT NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    city          TEXT,
    created_at    TIMESTAMP NOT NULL DEFAULT now()
);

-- Таблица категорий товаров
CREATE TABLE categories (
    category_id    BIGSERIAL PRIMARY KEY,
    category_name  TEXT NOT NULL UNIQUE
);

-- Таблица товаров
CREATE TABLE products (
    product_id     BIGSERIAL PRIMARY KEY,
    product_name   TEXT NOT NULL,
    category_id    BIGINT REFERENCES categories(category_id),
    price          NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    is_active      BOOLEAN NOT NULL DEFAULT true
);

-- Таблица заказов
CREATE TABLE orders (
    order_id       BIGSERIAL PRIMARY KEY,
    customer_id    BIGINT NOT NULL REFERENCES customers(customer_id),
    order_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    status         TEXT NOT NULL CHECK (status IN ('new', 'paid', 'shipped', 'cancelled'))
);

-- Таблица позиций заказа (многие-ко-многим между orders и products)
CREATE TABLE order_items (
    order_item_id  BIGSERIAL PRIMARY KEY,
    order_id       BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id     BIGINT NOT NULL REFERENCES products(product_id),
    quantity       INTEGER NOT NULL CHECK (quantity > 0),
    unit_price     NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);

-- Таблица оплат (может не быть оплаты на заказ)
CREATE TABLE payments (
    payment_id      BIGSERIAL PRIMARY KEY,
    order_id        BIGINT NOT NULL REFERENCES orders(order_id),
    payment_date    TIMESTAMP NOT NULL DEFAULT now(),
    amount          NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    payment_method  TEXT NOT NULL CHECK (payment_method IN ('card', 'cash', 'sbp')),
    status          TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failed'))
);
```

Тестовые данные, чтобы запросы возвращали результат

```
INSERT INTO categories (category_name) VALUES
('Ноутбуки'),
('Мониторы'),
('Аксессуары');

INSERT INTO customers (full_name, email, city) VALUES
('Иван Петров', 'ivan@example.com', 'Москва'),
('Анна Смирнова', 'anna@example.com', 'Санкт-Петербург'),
('Олег Сидоров', 'oleg@example.com', 'Казань');

INSERT INTO products (product_name, category_id, price, is_active) VALUES
('Lenovo ThinkPad', 1, 120000, true),
('Dell UltraSharp 27', 2, 45000, true),
('Logitech Mouse', 3, 2500, true),
('Old Monitor', 2, 10000, false);

INSERT INTO orders (customer_id, order_date, status) VALUES
(1, CURRENT_DATE - 5, 'paid'),
(1, CURRENT_DATE - 1, 'new'),
(2, CURRENT_DATE - 2, 'shipped');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 120000),
(1, 3, 2, 2500),
(2, 2, 1, 45000),
(3, 3, 3, 2500);

INSERT INTO payments (order_id, payment_date, amount, payment_method, status) VALUES
(1, now() - interval '5 day', 125000, 'card', 'success'),
(3, now() - interval '2 day', 7500, 'sbp', 'success');
-- Для заказа 2 оплаты пока нет (новый заказ)
```

#### Подготовка

Перед тестами полезно обновить статистику:  ```ANALYZE;```

Если таблицы маленькие, PostgreSQL может выбирать Seq Scan (это нормально).
Чтобы наглядно увидеть эффект, иногда нужно:

- добавить больше тестовых данных,

- или проверять запросы с более селективным фильтром.

#### Выполнение:

1. Создать индекс к какой-либо из таблиц вашей БД

```
-- 1. Обычный индекс (B-tree) для поиска заказов клиента
CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON orders(customer_id);
```

#### Комментарий

- Тип по умолчанию: B-tree

Подходит для:

- =, <, >, BETWEEN

- сортировок

- многих JOIN-условий

Этот индекс полезен для запросов вида:

- “все заказы клиента”

- JOIN orders ↔ customers

#### Пример запроса

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, order_date, status
FROM orders
WHERE customer_id = 1
ORDER BY order_date DESC;
```

#### Результат

```
                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Sort  (cost=1.05..1.05 rows=1 width=52) (actual time=0.061..0.062 rows=2.00 loops=1)
   Sort Key: order_date DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=4
   ->  Seq Scan on orders  (cost=0.00..1.04 rows=1 width=52) (actual time=0.012..0.013 rows=2.00 loops=1)
         Filter: (customer_id = 1)
         Rows Removed by Filter: 1
         Buffers: shared hit=1
 Planning:
   Buffers: shared hit=58 read=1 dirtied=2
 Planning Time: 0.454 ms
 Execution Time: 0.089 ms
(12 rows)
```

Если таблица маленькая и видим Seq Scan, это не ошибка. PostgreSQL считает, что последовательное чтение дешевле. Для демонстрации можно увеличить объем данных.

1.1 Индекс для ускорения JOIN таблицы order_items

Цель: Ускорить соединение orders ↔ order_items.

```
-- Индекс для JOIN по order_id (часто очень важный)
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items(order_id);
```

#### Комментарий

- Часто один из самых полезных индексов в схемах “заказ → позиции”

Ускоряет:

- JOIN по order_id

- выборку позиций конкретного заказа

#### Пример запроса

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, oi.product_id, oi.quantity
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_id = 1;
```

#### Результат

```
 QUERY PLAN
------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.00..2.11 rows=2 width=20) (actual time=0.014..0.016 rows=2.00 loops=1)
   Buffers: shared hit=2
   ->  Seq Scan on orders o  (cost=0.00..1.04 rows=1 width=8) (actual time=0.009..0.010 rows=1.00 loops=1)
         Filter: (order_id = 1)
         Rows Removed by Filter: 2
         Buffers: shared hit=1
   ->  Seq Scan on order_items oi  (cost=0.00..1.05 rows=2 width=20) (actual time=0.003..0.003 rows=2.00 loops=1)
         Filter: (order_id = 1)
         Rows Removed by Filter: 2
         Buffers: shared hit=1
 Planning:
   Buffers: shared hit=81 read=1
 Planning Time: 0.411 ms
 Execution Time: 0.031 ms
(14 rows)
```

На маленькой таблице планировщик может не выбрать индекс.

2. Прислать текстом результат команды explain, в которой используется данный индекс (результат по п.1)

Результат указан в п.1

3. Реализовать индекс для полнотекстового поиска

Цель: Реализовать полнотекстовый поиск по названию товара (products.product_name)

```
-- 3. Индекс для полнотекстового поиска (GIN по выражению)
CREATE INDEX IF NOT EXISTS idx_products_fts_name
    ON products
    USING GIN (to_tsvector('russian', product_name));
```

#### Пример запроса:

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, product_name
FROM products
WHERE to_tsvector('russian', product_name) @@ plainto_tsquery('russian', 'монитор');
```

#### Результат:

```
QUERY PLAN
------------------------------------------------------------------------------------------------------
 Seq Scan on products  (cost=0.00..2.05 rows=1 width=40) (actual time=0.041..0.041 rows=0.00 loops=1)
   Filter: (to_tsvector('russian'::regconfig, product_name) @@ '''монитор'''::tsquery)
   Rows Removed by Filter: 4
   Buffers: shared hit=1
 Planning:
   Buffers: shared hit=38
 Planning Time: 0.498 ms
 Execution Time: 0.057 ms
(8 rows)
```

На маленькой таблице планировщик может не выбрать индекс.

4. Реализовать индекс на часть таблицы или индекс на поле с функцией

Цель: Ускорить поиск только успешных оплат, если именно они чаще всего нужны в запросах.

```
-- Partial index: индекс только для успешных оплат
CREATE INDEX IF NOT EXISTS idx_payments_success_order_id
    ON payments(order_id)
    WHERE status = 'success';
```

#### Комментарий

Это индекс на часть таблицы

- Индекс содержит только строки, где status = 'success'.

Плюсы:

- меньше размер индекса

- быстрее поддержка и чтение для целевых запросов

- Полезен, если “success” часто используется в фильтрации.

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, amount, payment_date
FROM payments
WHERE status = 'success'
  AND order_id = 1;
```

#### Результат:

```
QUERY PLAN
------------------------------------------------------------------------------------------------------
 Seq Scan on payments  (cost=0.00..1.03 rows=1 width=32) (actual time=0.015..0.016 rows=1.00 loops=1)
   Filter: ((status = 'success'::text) AND (order_id = 1))
   Rows Removed by Filter: 1
   Buffers: shared hit=1
 Planning:
   Buffers: shared hit=36 read=1
 Planning Time: 0.304 ms
 Execution Time: 0.032 ms
(8 rows)
```

На маленькой таблице планировщик может не выбрать индекс.

#### Индекс на поле с функцией

Цель: Ускорить поиск без учета регистра по email клиента.

```
-- Индекс на функцию lower(email)
CREATE INDEX IF NOT EXISTS idx_customers_lower_email
    ON customers (lower(email));
```

#### Комментарий

Это индекс на поле с функцией.

Нужен, когда в запросах используется выражение:

- WHERE lower(email) = lower('...')

- Обычный индекс на email не всегда поможет, если в условии применяется функция.


#### Результат

```
QUERY PLAN
-------------------------------------------------------------------------------------------------------
 Seq Scan on customers  (cost=0.00..1.04 rows=1 width=72) (actual time=0.012..0.014 rows=1.00 loops=1)
   Filter: (lower(email) = 'ivan@example.com'::text)
   Rows Removed by Filter: 2
   Buffers: shared hit=1
 Planning:
   Buffers: shared hit=43 read=1
 Planning Time: 0.418 ms
 Execution Time: 0.024 ms
(8 rows)
```
На маленькой таблице планировщик может не выбрать индекс.

5. Создать индекс на несколько полей

Цель: Ускорить запросы по оплатам, где одновременно используется order_id и status.

```
-- 2. Составной индекс на несколько полей
CREATE INDEX IF NOT EXISTS idx_payments_order_id_status
    ON payments(order_id, status);
```

#### Комментарий

Полезен для запросов вида:

- WHERE order_id = ... AND status = 'success'

Важен порядок полей в индексе:

- (order_id, status) хорошо для фильтрации по order_id

- и по order_id + status

- но хуже для запросов только по status (без order_id)

#### Пример запроса:

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.payment_id, p.order_id, p.amount
FROM payments p
WHERE p.order_id = 1
  AND p.status = 'success';
```

#### Результат:

```
 QUERY PLAN
--------------------------------------------------------------------------------------------------------
 Seq Scan on payments p  (cost=0.00..1.03 rows=1 width=32) (actual time=0.010..0.011 rows=1.00 loops=1)
   Filter: ((order_id = 1) AND (status = 'success'::text))
   Rows Removed by Filter: 1
   Buffers: shared hit=1
 Planning:
   Buffers: shared hit=19 read=1 dirtied=2
 Planning Time: 0.257 ms
 Execution Time: 0.025 ms
(8 rows)
```

6. Написать комментарии к каждому из индексов

Комментарии написаны под каждым пунктом отдельно

7. Описать что и как делали и с какими проблемами столкнулись

#### Проблема 1. Индекс “не используется”

Почему так бывает:

- таблица маленькая → Seq Scan дешевле;

- условие возвращает слишком много строк (низкая селективность);

- статистика устарела (ANALYZE не выполнялся);

- запрос написан так, что индекс не подходит.

Что делал:

- запускал ANALYZE;

- проверял более селективные условия;

увеличивал объем тестовых данных.

#### Проблема 2. Индекс на поле не помогает при использовании функции

Пример:

```
WHERE lower(email) = '...'
```

Обычный индекс на email может не использоваться.

Решение:

создать индекс на выражение:

```
CREATE INDEX ... ON customers (lower(email));
```

#### Проблема 3. Полнотекстовый поиск требует правильного запроса

GIN-индекс по to_tsvector(...) будет использоваться только если запрос написан совместимо:

- to_tsvector(...) @@ plainto_tsquery(...)

- Если сделать обычный LIKE '%...', этот индекс не поможет.

#### Проблема 4. Лишние индексы замедляют INSERT/UPDATE/DELETE

Индексы ускоряют чтение, но:

- увеличивают размер БД,

- замедляют операции записи,

- требуют обслуживания.

Поэтому индекс нужно создавать под реальные запросы.