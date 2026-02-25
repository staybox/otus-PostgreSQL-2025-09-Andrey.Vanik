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

-- 1. Дропаем таблицу, если мы ее ранее создавали
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
-- !!! Зададим диапазоны под фактические данные в БД demo.
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

Выполняем до тестов: ```ANALYZE bookings; ANALYZE bookings_part;```

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

```Обычная таблица```

```
EEXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM bookings
WHERE book_date >= '2025-09-10 00:00:00+00'
  AND book_date <  '2025-09-11 00:00:00+00';
                                                                        QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..64421.16 rows=14829 width=21) (actual time=1.334..585.361 rows=15323.00 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   Buffers: shared hit=820 read=30460
   ->  Parallel Seq Scan on bookings  (cost=0.00..61938.26 rows=6179 width=21) (actual time=1.203..479.637 rows=5107.67 loops=3)
         Filter: ((book_date >= '2025-09-10 03:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-11 03:00:00+03'::timestamp with time zone))
         Rows Removed by Filter: 1629972
         Buffers: shared hit=820 read=30460
 Planning:
   Buffers: shared hit=25 read=1
 Planning Time: 0.515 ms
 Execution Time: 793.742 ms
(12 rows)

```

```Секционированная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM bookings_part
WHERE book_date >= '2025-09-10 00:00:00+00'
  AND book_date <  '2025-09-11 00:00:00+00';
                                                                                        QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------
 Index Scan using bookings_part_2025_09_book_date_idx on bookings_part_2025_09 bookings_part  (cost=0.42..1981.98 rows=14553 width=21) (actual time=1.076.
.124.392 rows=15323.00 loops=1)
   Index Cond: ((book_date >= '2025-09-10 03:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-11 03:00:00+03'::timestamp with time zone))
   Index Searches: 1
   Buffers: shared hit=14538 read=67
 Planning:
   Buffers: shared hit=21
 Planning Time: 0.243 ms
 Execution Time: 218.961 ms
(8 rows)
```

#### Выборка за 1 час

```Обычная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM bookings
WHERE book_date >= '2025-09-10 10:00:00+00'
  AND book_date <  '2025-09-10 11:00:00+00';
                                                                        QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..63000.06 rows=618 width=21) (actual time=7.549..475.337 rows=664.00 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   Buffers: shared hit=1102 read=30178
   ->  Parallel Seq Scan on bookings  (cost=0.00..61938.26 rows=258 width=21) (actual time=307.859..454.125 rows=221.33 loops=3)
         Filter: ((book_date >= '2025-09-10 13:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-10 14:00:00+03'::timestamp with time zone))
         Rows Removed by Filter: 1634858
         Buffers: shared hit=1102 read=30178
 Planning Time: 0.126 ms
 Execution Time: 482.328 ms
(10 rows)
```

```Секционированная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM bookings_part
WHERE book_date >= '2025-09-10 10:00:00+00'
  AND book_date <  '2025-09-10 11:00:00+00';
                                                                                    QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------
 Index Scan using bookings_part_2025_09_book_date_idx on bookings_part_2025_09 bookings_part  (cost=0.42..313.54 rows=644 width=21) (actual time=0.034..3.
610 rows=664.00 loops=1)
   Index Cond: ((book_date >= '2025-09-10 13:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-10 14:00:00+03'::timestamp with time zone))
   Index Searches: 1
   Buffers: shared hit=626
 Planning Time: 0.199 ms
 Execution Time: 6.778 ms
(6 rows)
```

#### ORDER BY book_date LIMIT

```Обычная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT book_ref, book_date, total_amount
FROM bookings
WHERE book_date >= '2025-09-10 00:00:00+00'
  AND book_date <  '2025-09-11 00:00:00+00'
ORDER BY book_date
LIMIT 100;
                                                                              QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
------------
 Limit  (cost=63327.35..63338.99 rows=100 width=21) (actual time=695.073..698.248 rows=100.00 loops=1)
   Buffers: shared hit=1460 read=29896
   ->  Gather Merge  (cost=63327.35..65054.43 rows=14829 width=21) (actual time=695.062..696.394 rows=100.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=1460 read=29896
         ->  Sort  (cost=62327.32..62342.77 rows=6179 width=21) (actual time=681.431..682.122 rows=93.67 loops=3)
               Sort Key: book_date
               Sort Method: top-N heapsort  Memory: 35kB
               Buffers: shared hit=1460 read=29896
               Worker 0:  Sort Method: top-N heapsort  Memory: 32kB
               Worker 1:  Sort Method: top-N heapsort  Memory: 32kB
               ->  Parallel Seq Scan on bookings  (cost=0.00..61938.26 rows=6179 width=21) (actual time=1.745..589.175 rows=5107.67 loops=3)
                     Filter: ((book_date >= '2025-09-10 03:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-11 03:00:00+03'::timestamp with
time zone))
                     Rows Removed by Filter: 1629972
                     Buffers: shared hit=1384 read=29896
 Planning Time: 0.175 ms
 Execution Time: 698.847 ms
(18 rows)
```

```Секционированная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT book_ref, book_date, total_amount
FROM bookings_part
WHERE book_date >= '2025-09-10 00:00:00+00'
  AND book_date <  '2025-09-11 00:00:00+00'
ORDER BY book_date
LIMIT 100;
                                                                                         QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------
 Limit  (cost=0.42..14.04 rows=100 width=21) (actual time=0.050..1.679 rows=100.00 loops=1)
   Buffers: shared hit=96
   ->  Index Scan using bookings_part_2025_09_book_date_idx on bookings_part_2025_09 bookings_part  (cost=0.42..1981.98 rows=14553 width=21) (actual time=
0.040..0.642 rows=100.00 loops=1)
         Index Cond: ((book_date >= '2025-09-10 03:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-11 03:00:00+03'::timestamp with time zon
e))
         Index Searches: 1
         Buffers: shared hit=96
 Planning Time: 0.197 ms
 Execution Time: 2.182 ms
(8 rows)
```

#### Точечный диапазон + агрегат

```Обычная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT sum(total_amount), avg(total_amount), count(*)
FROM bookings
WHERE book_date >= '2025-09-10 00:00:00+00'
  AND book_date <  '2025-09-11 00:00:00+00';
                                                                              QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
------------
 Finalize Aggregate  (cost=62969.38..62969.39 rows=1 width=72) (actual time=456.850..456.957 rows=1.00 loops=1)
   Buffers: shared hit=1666 read=29614
   ->  Gather  (cost=62969.15..62969.36 rows=2 width=72) (actual time=453.336..456.885 rows=3.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=1666 read=29614
         ->  Partial Aggregate  (cost=61969.15..61969.16 rows=1 width=72) (actual time=443.511..443.532 rows=1.00 loops=3)
               Buffers: shared hit=1666 read=29614
               ->  Parallel Seq Scan on bookings  (cost=0.00..61938.26 rows=6179 width=6) (actual time=1.257..361.977 rows=5107.67 loops=3)
                     Filter: ((book_date >= '2025-09-10 03:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-11 03:00:00+03'::timestamp with
time zone))
                     Rows Removed by Filter: 1629972
                     Buffers: shared hit=1666 read=29614
 Planning:
   Buffers: shared hit=3
 Planning Time: 0.129 ms
 Execution Time: 457.026 ms
(16 rows)
```

```Секционированная таблица```

```
demo=# EXPLAIN (ANALYZE, BUFFERS)
SELECT sum(total_amount), avg(total_amount), count(*)
FROM bookings_part
WHERE book_date >= '2025-09-10 00:00:00+00'
  AND book_date <  '2025-09-11 00:00:00+00';
                                                                                          QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------
 Aggregate  (cost=2054.75..2054.76 rows=1 width=72) (actual time=218.878..218.903 rows=1.00 loops=1)
   Buffers: shared hit=14605
   ->  Index Scan using bookings_part_2025_09_book_date_idx on bookings_part_2025_09 bookings_part  (cost=0.42..1981.98 rows=14553 width=6) (actual time=0
.043..116.255 rows=15323.00 loops=1)
         Index Cond: ((book_date >= '2025-09-10 03:00:00+03'::timestamp with time zone) AND (book_date < '2025-09-11 03:00:00+03'::timestamp with time zon
e))
         Index Searches: 1
         Buffers: shared hit=14605
 Planning Time: 0.181 ms
 Execution Time: 218.966 ms
(8 rows)
```

### Краткий отчет по ДЗ

В ходе работы была создана секционированная таблица bookings_part (секционирование по диапазону book_date) и выполнено сравнение запросов с исходной таблицей bookings с помощью EXPLAIN (ANALYZE, BUFFERS). После обновления статистики (ANALYZE) для тестовых запросов по узким диапазонам времени (1 день и 1 час) секционированная таблица показала заметное ускорение. На исходной таблице PostgreSQL использовал Parallel Seq Scan, просматривая практически всю таблицу и отбрасывая миллионы строк по фильтру, тогда как на секционированной таблице был использован Index Scan по индексу book_date только на нужной секции (bookings_part_2025_09). 

#### Наиболее заметный эффект получен для селективных запросов:

- выборка за 1 час: время выполнения уменьшилось примерно с 482 ms до 6.8 ms (ускорение примерно в 70 раз);

- выборка за 1 день: с 794 ms до 219 ms (примерно в 3.6 раза);

- запрос ORDER BY book_date LIMIT 100 за 1 день: с 699 ms до 2.2 ms (ускорение более чем в 300 раз), так как секционированная таблица смогла сразу читать данные в нужном порядке через индекс;

- агрегатный запрос (sum/avg/count) за 1 день: с 457 ms до 219 ms (примерно в 2 раза). 

Таким образом, секционирование в PostgreSQL не гарантирует ускорение всех запросов, но даёт существенный выигрыш в сочетании с индексом, когда запросы:

- фильтруют данные по ключу секционирования (book_date),

- работают с относительно узким диапазоном данных,

- используют сортировку/LIMIT или выборку небольшой части строк.

- Это подтверждает, что секционирование особенно полезно для таблиц с временными данными и типовых запросов по периодам.