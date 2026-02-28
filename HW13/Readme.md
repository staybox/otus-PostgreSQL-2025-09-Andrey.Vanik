## Домашнее задание № 13
### Название урока: Резервное копирование и восстановление 

Цель:
- применить логический бэкап;
- восстановиться из бэкапа;

### Описание/Пошаговая инструкция выполнения домашнего задания:

- Развернуть PostgreSQL (ВМ/Docker).
- В БД test_db создать схему my_schema и две одинаковые таблицы (table1, table2).
- Заполнить ```table1``` 100 строками с помощью generate_series.
- Создать каталог ```/var/lib/postgresql/backups/``` под пользователем postgres.
- Бэкап через COPY: Выгрузить table1 в CSV командой \copy.
- Восстановление из COPY: Загрузить данные из CSV в ```table2```.
- Бэкап через pg_dump: Создать кастомный сжатый дамп (-Fc) только схемы my_schema:
- Восстановление через pg_restore: В новую БД restored_db восстановить только ```table2``` из дампа.

Важно: Предварительно создать схему my_schema в restored_db.

### Выполнение домашнего задания

1. Развернуть PostgreSQL (ВМ/Docker)

- Инстанс PostgreSQL 18 уже развернут

- Подключаемся к PostgreSQL: ```sudo -u postgres psql```

- Создаем новую БД: ```CREATE DATABASE test_db;```

- Подключаемся к самой БД: ```\c test_db;```

2. В БД test_db создать схему my_schema и две одинаковые таблицы (table1, table2).


```
CREATE SCHEMA my_schema;

CREATE TABLE my_schema.table1 (
  id   int PRIMARY KEY,
  val  text NOT NULL,
  ts   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE my_schema.table2 (LIKE my_schema.table1 INCLUDING ALL);
```

3. Заполнить ```table1``` 100 строками с помощью generate_series

```
INSERT INTO my_schema.table1 (id, val)
SELECT gs, 'row_' || gs
FROM generate_series(1, 100) AS gs;
```

4. Создать каталог ```/var/lib/postgresql/backups/``` под пользователем postgres

Каталог по пути ```/var/lib/pgsql/18/backups/``` уже есть и создавать его по пути из задания не имеет смысла.

5. Бэкап через COPY: Выгрузить table1 в CSV командой \copy

В PostgreSQL выполняем команду: ```\copy my_schema.table1 TO '/var/lib/pgsql/18/backups/table1.csv' WITH (FORMAT csv, HEADER true)```

```
ls -l /var/lib/pgsql/18/backups/
total 4
-rw-r--r-- 1 postgres postgres 3994 Feb 28 16:37 table1.csv
```

6. Восстановление из COPY: Загрузить данные из CSV в ```table2```

В PostgreSQL выполняем команду: ```\copy my_schema.table2 FROM '/var/lib/pgsql/18/backups/table1.csv' WITH (FORMAT csv, HEADER true);```

```
test_db=# SELECT count(*) FROM my_schema.table2;
 count
-------
   100
(1 row)
```

7. Бэкап через pg_dump: Создать кастомный сжатый дамп (-Fc) только схемы my_schema

Выйдем в bash из PostgreSQL и выполним: ```sudo -u postgres pg_dump -d test_db -Fc -Z 9 -n my_schema -f /var/lib/pgsql/18/backups/test_db_my_schema.dump```

Проверка выполненного дампа:

```
sudo -u postgres pg_restore -l /var/lib/pgsql/18/backups/test_db_my_schema.dump | head -n 40
;
; Archive created at 2026-02-28 16:57:37 IST
;     dbname: test_db
;     TOC Entries: 11
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 18.2
;     Dumped by pg_dump version: 18.2
;
;
; Selected TOC Entries:
;
6; 2615 16797 SCHEMA - my_schema postgres
220; 1259 16798 TABLE my_schema table1 postgres
221; 1259 16809 TABLE my_schema table2 postgres
3408; 0 16798 TABLE DATA my_schema table1 postgres
3409; 0 16809 TABLE DATA my_schema table2 postgres
3258; 2606 16808 CONSTRAINT my_schema table1 table1_pkey postgres
3260; 2606 16819 CONSTRAINT my_schema table2 table2_pkey postgres
```

8. Восстановление через pg_restore: В новую БД restored_db восстановить только ```table2``` из дампа

Подключаемся к PostgreSQL: ```sudo -u postgres psql```

Создаем новую БД: ```CREATE DATABASE restored_db;```

Подключаемся к БД: ```\c restored_db;```

Создаем схему: ```CREATE SCHEMA my_schema;```

Выходим из PostgreSQL в bash и выполняем: ```sudo -u postgres pg_restore -d restored_db -n my_schema -t table2 /var/lib/pgsql/18/backups/test_db_my_schema.dump```

Снова заходим в PostgreSQL и выполняем:

```
postgres=# \c restored_db;
You are now connected to database "restored_db" as user "postgres".
restored_db=# \dt my_schema.*
            List of tables
  Schema   |  Name  | Type  |  Owner
-----------+--------+-------+----------
 my_schema | table2 | table | postgres
(1 row)

restored_db=# SELECT count(*) FROM my_schema.table2;
 count
-------
   100
(1 row)
```