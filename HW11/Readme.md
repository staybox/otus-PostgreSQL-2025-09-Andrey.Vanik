## Домашнее задание № 11
### Название урока: Секционирование

Цель:
- научиться выполнять секционирование таблиц в PostgreSQL;
- повысить производительность запросов и упростив управление данными;

### Описание/Пошаговая инструкция выполнения домашнего задания:
На основе готовой базы данных примените один из методов секционирования в зависимости от структуры данных.
https://postgrespro.ru/education/demodb


### Шаги выполнения домашнего задания:


#### Анализ структуры данных:

Ознакомьтесь с таблицами базы данных, особенно с таблицами bookings, tickets, ticket_flights, flights, boarding_passes, seats, airports, aircrafts.
Определите, какие данные в таблице bookings или других таблицах имеют логическую привязку к диапазонам, по которым можно провести секционирование (например, дата бронирования, рейсы).


#### Выбор таблицы для секционирования:
Основной акцент делается на секционировании таблицы bookings. Но вы можете выбрать и другие таблицы, если видите в этом смысл для оптимизации производительности (например, flights, boarding_passes).
Обоснуйте свой выбор: почему именно эта таблица требует секционирования? Какой тип данных является ключевым для секционирования?

#### Определение типа секционирования:
Определитесь с типом секционирования, которое наилучшим образом подходит для ваших данных:

По диапазону (например, по дате бронирования или дате рейса).
По списку (например, по пунктам отправления или по номерам рейсов).
По хэшированию (для равномерного распределения данных).

#### Создание секционированной таблицы:
Преобразуйте таблицу в секционированную с выбранным типом секционирования.
Например, если вы выбрали секционирование по диапазону дат бронирования, создайте секции по месяцам или годам.

#### Миграция данных:

Перенесите существующие данные из исходной таблицы в секционированную структуру.
Убедитесь, что все данные правильно распределены по секциям.

#### Оптимизация запросов:

Проверьте, как секционирование влияет на производительность запросов. Выполните несколько выборок данных до и после секционирования для оценки времени выполнения.
Оптимизируйте запросы при необходимости (например, добавьте индексы на ключевые столбцы).

#### Тестирование решения:
Протестируйте секционирование, выполняя несколько запросов к секционированной таблице.
Проверьте, что операции вставки, обновления и удаления работают корректно.

#### Документирование:

Добавьте комментарии к коду, поясняющие выбранный тип секционирования и шаги его реализации.
Опишите, как секционирование улучшает производительность запросов и как оно может быть полезно в реальных условиях.

#### Формат сдачи:

SQL-скрипты с реализованным секционированием.
Краткий отчет с описанием процесса и результатами тестирования.
Пример запросов и результаты до и после секционирования.

#### Критерии оценки:
- Корректность секционирования – таблица должна быть разделена логично и эффективно.
- Выбор типа секционирования – обоснование выбранного типа (например, секционирование по диапазону дат рейсов или по месту отправления/прибытия).
- Работоспособность решения – код должен успешно выполнять секционирование без ошибок.
- Оптимизация запросов – после секционирования, запросы к таблице должны быть оптимизированы (например, быстрее выполняться для конкретных диапазонов).
- Комментирование – код должен содержать поясняющие комментарии, объясняющие выбор секционирования и основные шаги.

### Выполнение домашнего задания

Загружаем БД demo в наш инстанс PostgreSQL: ```gunzip -c /tmp/demo-20250901-1y.sql.gz | sudo -u postgres psql```

Подключаемся к PostgreSQL: ```sudo -u postgres psql```

Подключаемся к самой БД: ```\c demo;``` и выводим структуру ```\dt```:

```
demo=# \dt
                List of tables
  Schema  |      Name       | Type  |  Owner
----------+-----------------+-------+----------
 bookings | airplanes_data  | table | postgres
 bookings | airports_data   | table | postgres
 bookings | boarding_passes | table | postgres
 bookings | bookings        | table | postgres
 bookings | flights         | table | postgres
 bookings | routes          | table | postgres
 bookings | seats           | table | postgres
 bookings | segments        | table | postgres
 bookings | tickets         | table | postgres
(9 rows)
```

**Вариант решения для данного ДЗ:** секционирование bookings по диапазону даты бронирования

#### Почему именно bookings

Таблица bookings содержит:

- book_ref

- book_date

- total_amount

#### Это хороший кандидат для секционирования, потому что:

- данные естественно привязаны ко времени (book_date);

- запросы часто фильтруют по периоду (месяц/квартал/год);

- старые данные удобно обслуживать отдельно (архивирование/удаление секций).

#### Почему не tickets / ticket_flights сразу

Можно, но:

- bookings проще для демонстрации идеи;

- секционирование по времени для bookings логично и наглядно.


### Важный нюанс

В PostgreSQL при секционировании таблицы уникальные ограничения/PK на родительской секционированной таблице должны включать ключ секционирования.

Если секционировать bookings по book_date, то:

- старый PK PRIMARY KEY (book_ref) нельзя перенести как есть на parent-table;

- для “боевого” перевода схемы нужно переработать ключи/FK (например, менять модель ключей или логику ссылок).

**Для учебного задания сделаем так:**

- создадим новую секционированную таблицу bookings_part

- перенесём данные

- сравним производительность запросов на чтение


### Анализ структуры данных

#### Ключевые таблицы demoDB

- bookings — бронирования (есть дата бронирования)

- tickets — билеты (ссылка на booking по book_ref)

- ticket_flights — сегменты билета / рейса

- flights — рейсы (есть даты/время вылета/прилёта)

- boarding_passes

- seats

- airports

- aircrafts

#### Логическая привязка для секционирования

Наиболее очевидная:

- bookings.book_date → секционирование по диапазону дат

### Выбор типа секционирования

- Выбираем RANGE partitioning по book_date (по месяцам).

#### Обоснование

- запросы по времени (месяц/период) получают partition pruning;

- удобно сопровождать данные (добавление новых месяцев, удаление старых);

- наглядно для учебной задачи.

### Выполнение практической части

```Создание секционированной таблицы и секций и другие команды (подготовка)```

```
BEGIN;

-- 1. Удаляем предыдущий учебный вариант, если запускали ранее
DROP TABLE IF EXISTS bookings_part CASCADE;

-- 2. Создаем секционированную таблицу
-- ВАЖНО: не задаем PK(book_ref), т.к. при RANGE(book_date)
-- уникальность/PK на parent должна включать ключ секционирования.
CREATE TABLE bookings_part
(
    book_ref     char(6)                     NOT NULL,
    book_date    timestamptz                 NOT NULL,
    total_amount numeric(10,2)               NOT NULL
)
PARTITION BY RANGE (book_date);

-- 3. Создаем секции (пример: по месяцам)
-- !!! Подстрой диапазоны под фактические данные в вашей demoDB.
CREATE TABLE bookings_part_2025_09 PARTITION OF bookings_part
FOR VALUES FROM ('2025-09-01 00:00:00+00') TO ('2025-10-01 00:00:00+00');

CREATE TABLE bookings_part_2025_10 PARTITION OF bookings_part
FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');

CREATE TABLE bookings_part_2025_11 PARTITION OF bookings_part
FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');

CREATE TABLE bookings_part_2025_12 PARTITION OF bookings_part
FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');

-- Рекомендуется секция DEFAULT (на случай "вылета" данных за диапазон)
CREATE TABLE bookings_part_default PARTITION OF bookings_part
DEFAULT;

-- 4. Индексы на секционированной таблице
-- PostgreSQL создаст "partitioned index" и локальные индексы на секциях.
CREATE INDEX idx_bookings_part_book_date ON bookings_part (book_date);
CREATE INDEX idx_bookings_part_book_ref  ON bookings_part (book_ref);

COMMIT;
```

#### Миграция данных

```
-- Переносим данные из исходной bookings в секционированную структуру
INSERT INTO bookings_part (book_ref, book_date, total_amount)
SELECT book_ref, book_date, total_amount
FROM bookings;

-- Проверка количества строк
SELECT 'bookings' AS table_name, count(*) AS cnt FROM bookings
UNION ALL
SELECT 'bookings_part' AS table_name, count(*) AS cnt FROM bookings_part;

-- Проверка распределения по секциям
SELECT tableoid::regclass AS partition_name, count(*) AS rows_cnt
FROM bookings_part
GROUP BY tableoid
ORDER BY partition_name;
```

#### Результат

```
demo=# SELECT 'bookings' AS table_name, count(*) AS cnt FROM bookings
UNION ALL
SELECT 'bookings_part' AS table_name, count(*) AS cnt FROM bookings_part;
  table_name   |   cnt
---------------+---------
 bookings_part | 4905238
 bookings      | 4905238
(2 rows)
```

```
SELECT tableoid::regclass AS partition_name, count(*) AS rows_cnt
FROM bookings_part
GROUP BY tableoid
ORDER BY partition_name;
    partition_name     | rows_cnt
-----------------------+----------
 bookings_part_2025_09 |   448064
 bookings_part_2025_10 |   434159
 bookings_part_2025_11 |   410670
 bookings_part_2025_12 |   410796
 bookings_part_default |  3201549
(5 rows)
```


#### Проверка, что данные попали в нужные секции

```
-- Какие данные в какой секции лежат
SELECT tableoid::regclass AS partition_name,
       min(book_date) AS min_book_date,
       max(book_date) AS max_book_date,
       count(*)       AS rows_cnt
FROM bookings_part
GROUP BY tableoid
ORDER BY partition_name;
```

#### Результат

```
SELECT tableoid::regclass AS partition_name,
       min(book_date) AS min_book_date,
       max(book_date) AS max_book_date,
       count(*)       AS rows_cnt
FROM bookings_part
GROUP BY tableoid
ORDER BY partition_name;
    partition_name     |         min_book_date         |         max_book_date         | rows_cnt
-----------------------+-------------------------------+-------------------------------+----------
 bookings_part_2025_09 | 2025-09-01 03:00:06.265219+03 | 2025-10-01 02:59:58.026243+03 |   448064
 bookings_part_2025_10 | 2025-10-01 03:00:08.899725+03 | 2025-11-01 01:59:53.263233+02 |   434159
 bookings_part_2025_11 | 2025-11-01 02:00:01.790251+02 | 2025-12-01 01:59:28.616825+02 |   410670
 bookings_part_2025_12 | 2025-12-01 02:00:00.372488+02 | 2026-01-01 01:59:40.191846+02 |   410796
 bookings_part_default | 2026-01-01 02:00:01.314353+02 | 2026-09-01 02:59:58.283465+03 |  3201549
(5 rows)
```

#### Сравнение производительности (до / после)

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM bookings
WHERE book_date >= '2025-09-01'
  AND book_date <  '2025-10-01';
```

```
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM bookings_part
WHERE book_date >= '2025-09-01'
  AND book_date <  '2025-10-01';
```

### Результат

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM bookings
WHERE book_date >= '2025-09-01'
  AND book_date <  '2025-10-01';
                                                                              QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
------------
 Finalize Aggregate  (cost=63404.20..63404.21 rows=1 width=8) (actual time=5471.644..5475.140 rows=1.00 loops=1)
   Buffers: shared read=31280
   ->  Gather  (cost=63403.98..63404.19 rows=2 width=8) (actual time=5468.097..5474.579 rows=3.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared read=31280
         ->  Partial Aggregate  (cost=62403.98..62403.99 rows=1 width=8) (actual time=5458.515..5458.542 rows=1.00 loops=3)
               Buffers: shared read=31280
               ->  Parallel Seq Scan on bookings  (cost=0.00..61937.74 rows=186498 width=0) (actual time=0.617..3060.053 rows=148773.00 loops=3)
                     Filter: ((book_date >= '2025-09-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2025-10-01 00:00:00+03'::timestamp with
time zone))
                     Rows Removed by Filter: 1486306
                     Buffers: shared read=31280
 Planning:
   Buffers: shared hit=8
 Planning Time: 0.281 ms
 Execution Time: 5475.247 ms
(16 rows)
```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM bookings_part
WHERE book_date >= '2025-09-01'
  AND book_date <  '2025-10-01';
                                                                                                     QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------
 Finalize Aggregate  (cost=9206.52..9206.53 rows=1 width=8) (actual time=9419.299..9420.782 rows=1.00 loops=1)
   Buffers: shared hit=2778 read=80
   ->  Gather  (cost=9206.31..9206.52 rows=2 width=8) (actual time=9419.242..9420.734 rows=3.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2778 read=80
         ->  Partial Aggregate  (cost=8206.31..8206.32 rows=1 width=8) (actual time=9402.888..9402.920 rows=1.00 loops=3)
               Buffers: shared hit=2778 read=80
               ->  Parallel Append  (cost=0.00..7741.52 rows=185914 width=0) (actual time=0.113..7081.458 rows=148773.00 loops=3)
                     Buffers: shared hit=2778 read=80
                     ->  Parallel Index Only Scan using bookings_part_default_book_date_idx on bookings_part_default bookings_part_2  (cost=0.43..4.45 row
s=1 width=0) (actual time=0.046..0.051 rows=0.00 loops=1)
                           Index Cond: ((book_date >= '2025-09-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2025-10-01 00:00:00+03'::times
tamp with time zone))
                           Heap Fetches: 0
                           Index Searches: 1
                           Buffers: shared hit=4
                     ->  Parallel Seq Scan on bookings_part_2025_09 bookings_part_1  (cost=0.00..6807.51 rows=262466 width=0) (actual time=0.032..2458.146
 rows=148773.00 loops=3)
                           Filter: ((book_date >= '2025-09-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2025-10-01 00:00:00+03'::timestamp
 with time zone))
                           Rows Removed by Filter: 582
                           Buffers: shared hit=2774 read=80
 Planning:
   Buffers: shared hit=20 read=10
 Planning Time: 3.570 ms
 Execution Time: 9420.954 ms
(23 rows)
```

#### Агрегация по месяцу

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', book_date) AS mon,
       count(*)                       AS cnt,
       sum(total_amount)              AS total_sum
FROM bookings
WHERE book_date >= '2025-09-01'
  AND book_date <  '2025-10-01'
GROUP BY 1
ORDER BY 1;
                                                                              QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
------------
 GroupAggregate  (cost=82919.29..145119.99 rows=447595 width=48) (actual time=14806.792..14806.981 rows=1.00 loops=1)
   Group Key: (date_trunc('month'::text, book_date))
   Buffers: shared hit=358 read=30998, temp read=1323 written=1329
   ->  Gather Merge  (cost=82919.29..135049.10 rows=447595 width=14) (actual time=5482.380..11947.669 rows=446319.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=358 read=30998, temp read=1323 written=1329
         ->  Sort  (cost=81919.26..82385.51 rows=186498 width=14) (actual time=5464.985..6500.986 rows=148773.00 loops=3)
               Sort Key: (date_trunc('month'::text, book_date))
               Sort Method: external merge  Disk: 3552kB
               Buffers: shared hit=358 read=30998, temp read=1323 written=1329
               Worker 0:  Sort Method: external merge  Disk: 3528kB
               Worker 1:  Sort Method: external merge  Disk: 3504kB
               ->  Parallel Seq Scan on bookings  (cost=0.00..62403.98 rows=186498 width=14) (actual time=0.954..3136.349 rows=148773.00 loops=3)
                     Filter: ((book_date >= '2025-09-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2025-10-01 00:00:00+03'::timestamp with
time zone))
                     Rows Removed by Filter: 1486306
                     Buffers: shared hit=282 read=30998
 Planning:
   Buffers: shared hit=11 read=4
 Planning Time: 1.754 ms
 Execution Time: 14808.198 ms
(21 rows)
```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', book_date) AS mon,
       count(*)                       AS cnt,
       sum(total_amount)              AS total_sum
FROM bookings_part
WHERE book_date >= '2025-09-01'
  AND book_date <  '2025-10-01'
GROUP BY 1
ORDER BY 1;
                                                                                                      QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------
 Finalize GroupAggregate  (cost=10806.71..10870.42 rows=200 width=48) (actual time=9792.678..9795.734 rows=1.00 loops=1)
   Group Key: (date_trunc('month'::text, bookings_part.book_date))
   Buffers: shared hit=2874
   ->  Gather Merge  (cost=10806.71..10862.62 rows=480 width=48) (actual time=9792.608..9795.672 rows=3.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2874
         ->  Sort  (cost=9806.69..9807.19 rows=200 width=48) (actual time=9776.291..9776.337 rows=1.00 loops=3)
               Sort Key: (date_trunc('month'::text, bookings_part.book_date))
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=2874
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=9796.04..9799.04 rows=200 width=48) (actual time=9776.224..9776.259 rows=1.00 loops=3)
                     Group Key: (date_trunc('month'::text, bookings_part.book_date))
                     Batches: 1  Memory Usage: 32kB
                     Buffers: shared hit=2858
                     Worker 0:  Batches: 1  Memory Usage: 32kB
                     Worker 1:  Batches: 1  Memory Usage: 32kB
                     ->  Parallel Append  (cost=0.00..8401.69 rows=185914 width=14) (actual time=0.050..7168.406 rows=148773.00 loops=3)
                           Buffers: shared hit=2858
                           ->  Parallel Index Scan using bookings_part_default_book_date_idx on bookings_part_default bookings_part_2  (cost=0.43..8.45 ro
ws=1 width=14) (actual time=0.032..0.039 rows=0.00 loops=1)
                                 Index Cond: ((book_date >= '2025-09-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2025-10-01 00:00:00+03':
:timestamp with time zone))
                                 Index Searches: 1
                                 Buffers: shared hit=4
                           ->  Parallel Seq Scan on bookings_part_2025_09 bookings_part_1  (cost=0.00..7463.67 rows=262466 width=14) (actual time=0.026..2
511.864 rows=148773.00 loops=3)
                                 Filter: ((book_date >= '2025-09-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2025-10-01 00:00:00+03'::tim
estamp with time zone))
                                 Rows Removed by Filter: 582
                                 Buffers: shared hit=2854
 Planning:
   Buffers: shared hit=24
 Planning Time: 0.493 ms
 Execution Time: 9795.876 ms
(33 rows)
```

### Краткий отчет по ДЗ
#### Цель

- Освоить секционирование таблиц в PostgreSQL для повышения производительности запросов и упрощения управления данными.

#### Выбранная таблица

- Для секционирования выбрана таблица bookings, так как она содержит поле book_date, по которому данные имеют естественную временную структуру. Это позволяет использовать диапазонное секционирование.

#### Выбранный тип секционирования

- Использовано секционирование по диапазону (RANGE) по полю book_date с разбиением по месяцам.

#### Обоснование выбора

- типичные запросы к бронированиям часто ограничиваются периодом;

- диапазонное секционирование позволяет PostgreSQL выполнять partition pruning и читать только нужные секции;

- упрощается сопровождение исторических данных (архивирование/удаление секций).

#### Особенности реализации

- В учебном варианте создана новая таблица bookings_part, секционированная по book_date.
Исходная таблица bookings сохранена без изменений.

**Причина:** при секционировании bookings по book_date невозможно сохранить PRIMARY KEY (book_ref) на родительской таблице без включения ключа секционирования в уникальный ключ (ограничение PostgreSQL для partitioned tables). Для полной миграции продакшн-схемы потребовалась бы переработка PK/FK.

#### Выполненные шаги

- Проанализирована структура таблиц demoDB.

- Выбран ключ секционирования book_date.

- Создана таблица bookings_part, секционированная по RANGE.

- Созданы секции по месяцам + DEFAULT секция.

- Добавлены индексы.

- Выполнена миграция данных из bookings.

- Проверено распределение строк по секциям.

- Выполнено сравнение запросов до/после секционирования (EXPLAIN ANALYZE).

- Протестированы операции INSERT/UPDATE/DELETE.

#### Результат

- Секционирование не всегда ускоряет всё подряд.

- Основной эффект — при фильтрации по ключу секционирования.

- По результатам тестирования секционированной таблицы bookings_part подтверждено корректное распределение данных по секциям и работа механизма partition pruning (в плане выполнения используются отдельные секции, а не вся таблица целиком).
Однако в проведённых тестах ускорения не получено: запросы к секционированной таблице выполнялись медленнее исходной таблицы. Это связано с тем, что выборка за месяц всё равно приводит к последовательному чтению крупной секции, а также с накладными расходами на Parallel Append и наличием большой DEFAULT секции.
Таким образом, секционирование само по себе не гарантирует ускорение; эффект зависит от структуры секций, распределения данных, индексов и характера запросов.

#### Практическая польза

- Подход полезен для систем с большими объемами данных, где запросы и обслуживание данных выполняются по временным периодам (месяц, квартал, год).