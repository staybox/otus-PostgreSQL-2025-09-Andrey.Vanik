## Домашнее задание № 12
### Название урока: Хранимые функции и процедуры

Цель:
- научиться разрабатывать DML-триггеры и событийные триггеры
- Создать триггер для поддержки витрины в актуальном состоянии

### Описание/Пошаговая инструкция выполнения домашнего задания:

Скрипт и развернутое описание задачи – в ЛК (файл hw_triggers.sql) или по ссылке: https://disk.yandex.ru/d/l70AvknAepIJXQ


В БД создана структура, описывающая товары (таблица goods) и продажи (таблица sales).


Есть запрос для генерации отчета – сумма продаж по каждому товару.


БД была денормализована, создана таблица (витрина), структура которой повторяет структуру отчета.


Создать триггер на таблице продаж, для поддержки данных в витрине в актуальном состоянии (вычисляющий при каждой продаже сумму и записывающий её в витрину)


Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE

Задание со звездочкой*

Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
Подсказка: В реальной жизни возможны изменения цен.

### Выполнения домашнего задания

Подключаемся к PostgreSQL: ```sudo -u postgres psql```

Создаем новую БД: ```CREATE DATABASE hw_triggers;```

Подключаемся к самой БД: ```\c hw_triggers;```

```Содержимое файла hw_triggers.sql:```

```
-- ДЗ тема: триггеры, поддержка заполнения витрин

DROP SCHEMA IF EXISTS pract_functions CASCADE;
CREATE SCHEMA pract_functions;

SET search_path = pract_functions, public -- Было изначально publ, поправлено на public

-- товары:
CREATE TABLE goods
(
    goods_id    integer PRIMARY KEY,
    good_name   varchar(63) NOT NULL,
    good_price  numeric(12, 2) NOT NULL CHECK (good_price > 0.0)
);
INSERT INTO goods (goods_id, good_name, good_price)
VALUES 	(1, 'Спички хозайственные', .50),
		(2, 'Автомобиль Ferrari FXX K', 185000000.01);

-- Продажи
CREATE TABLE sales
(
    sales_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    good_id     integer REFERENCES goods (goods_id),
    sales_time  timestamp with time zone DEFAULT now(),
    sales_qty   integer CHECK (sales_qty > 0)
);

INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);

-- отчет:
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;

-- с увеличением объёма данных отчет стал создаваться медленно
-- Принято решение денормализовать БД, создать таблицу
CREATE TABLE good_sum_mart
(
	good_name   varchar(63) NOT NULL,
	sum_sale	numeric(16, 2)NOT NULL
);

-- Создать триггер (на таблице sales) для поддержки.
-- Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE

-- Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
-- Подсказка: В реальной жизни возможны изменения цен.
```

```Далее выполняем:```

```
-- ДЗ тема: триггеры, поддержка заполнения витрин

DROP SCHEMA IF EXISTS pract_functions CASCADE;
CREATE SCHEMA pract_functions;

SET search_path = pract_functions, public;

-- товары:
CREATE TABLE goods
(
    goods_id    integer PRIMARY KEY,
    good_name   varchar(63) NOT NULL,
    good_price  numeric(12, 2) NOT NULL CHECK (good_price > 0.0)
);

INSERT INTO goods (goods_id, good_name, good_price)
VALUES  (1, 'Спички хозайственные', .50),
        (2, 'Автомобиль Ferrari FXX K', 185000000.01);

-- Продажи
CREATE TABLE sales
(
    sales_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    good_id     integer REFERENCES goods (goods_id),
    sales_time  timestamp with time zone DEFAULT now(),
    sales_qty   integer CHECK (sales_qty > 0)
);

INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);

-- Витрина
CREATE TABLE good_sum_mart
(
    good_name   varchar(63) NOT NULL,
    sum_sale    numeric(16, 2) NOT NULL
);
```

```Делаем витрину обновляемой и заполняем её```:

```
ALTER TABLE good_sum_mart
  ADD CONSTRAINT good_sum_mart_good_name_uk UNIQUE (good_name); -- Это нужно, чтобы работал “upsert” (INSERT и UPDATE) в триггере

TRUNCATE good_sum_mart;

INSERT INTO good_sum_mart(good_name, sum_sale)
SELECT g.good_name, COALESCE(SUM(g.good_price * s.sales_qty),0)::numeric(16,2)
FROM goods g
LEFT JOIN sales s ON s.good_id = g.goods_id
GROUP BY g.good_name;
```

```Триггерная функция + триггер на sales (INSERT/UPDATE/DELETE)```:

```
CREATE OR REPLACE FUNCTION f_sales_to_mart()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_old_name  varchar(63);
  v_new_name  varchar(63);
  v_old_price numeric(12,2);
  v_new_price numeric(12,2);
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT good_name, good_price INTO v_new_name, v_new_price
    FROM goods WHERE goods_id = NEW.good_id;

    INSERT INTO good_sum_mart(good_name, sum_sale)
    VALUES (v_new_name, (v_new_price * NEW.sales_qty)::numeric(16,2))
    ON CONFLICT (good_name)
    DO UPDATE SET sum_sale = (good_sum_mart.sum_sale + EXCLUDED.sum_sale)::numeric(16,2);

    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    SELECT good_name, good_price INTO v_old_name, v_old_price
    FROM goods WHERE goods_id = OLD.good_id;

    UPDATE good_sum_mart
       SET sum_sale = (sum_sale - (v_old_price * OLD.sales_qty))::numeric(16,2)
     WHERE good_name = v_old_name;

    RETURN OLD;
  END IF;

  -- UPDATE
  IF TG_OP = 'UPDATE' THEN
    SELECT good_name, good_price INTO v_old_name, v_old_price
    FROM goods WHERE goods_id = OLD.good_id;

    SELECT good_name, good_price INTO v_new_name, v_new_price
    FROM goods WHERE goods_id = NEW.good_id;

    -- если товар тот же - корректируем разницу количества
    IF OLD.good_id = NEW.good_id THEN
      UPDATE good_sum_mart
         SET sum_sale = (sum_sale + v_new_price * (NEW.sales_qty - OLD.sales_qty))::numeric(16,2)
       WHERE good_name = v_new_name;

      RETURN NEW;
    END IF;

    -- если товар поменялся - вычесть старый вклад, добавить новый
    UPDATE good_sum_mart
       SET sum_sale = (sum_sale - (v_old_price * OLD.sales_qty))::numeric(16,2)
     WHERE good_name = v_old_name;

    INSERT INTO good_sum_mart(good_name, sum_sale)
    VALUES (v_new_name, (v_new_price * NEW.sales_qty)::numeric(16,2))
    ON CONFLICT (good_name)
    DO UPDATE SET sum_sale = (good_sum_mart.sum_sale + EXCLUDED.sum_sale)::numeric(16,2);

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sales_to_mart ON sales;

CREATE TRIGGER trg_sales_to_mart
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW
EXECUTE FUNCTION f_sales_to_mart();
```

```Проверка (должно менять good_sum_mart автоматически)```:

```
-- Посмотреть витрину
SELECT * FROM good_sum_mart ORDER BY good_name;

-- INSERT: добавить продажу “спички” x2
INSERT INTO sales (good_id, sales_qty) VALUES (1, 2);
SELECT * FROM good_sum_mart ORDER BY good_name;

-- UPDATE: изменить количество в одной из продаж (например sales_id=1)
UPDATE sales SET sales_qty = 20 WHERE sales_id = 1;
SELECT * FROM good_sum_mart ORDER BY good_name;

-- DELETE: удалить продажу (например sales_id=2)
DELETE FROM sales WHERE sales_id = 2;
SELECT * FROM good_sum_mart ORDER BY good_name;

-- Для контроля: “отчет по требованию”
SELECT G.good_name, sum(G.good_price * S.sales_qty)::numeric(16,2) AS sum_sale
FROM goods G
JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
ORDER BY G.good_name;
```

#### Пояснения:

- Таблица sales — это журнал/факты продаж.
Каждая строка = одна операция продажи (или один чек/позиция/событие).

- Таблица goods — это справочник товаров (каталог).
Там хранится “что за товар” и его цена.

- Таблица good_sum_mart - наша витрина (это отдельная таблица с уже посчитанным итогом)

**Триггер** — это правило: когда в таблице sales происходит INSERT/UPDATE/DELETE — автоматически запускается функция (триггерная функция), и она обновляет витрину good_sum_mart.

```
hw_triggers=# SELECT * FROM good_sum_mart ORDER BY good_name;
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 rows)

hw_triggers=# INSERT INTO sales (good_id, sales_qty) VALUES (1, 2);
SELECT * FROM good_sum_mart ORDER BY good_name;
INSERT 0 1
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        66.50
(2 rows)

hw_triggers=# UPDATE sales SET sales_qty = 20 WHERE sales_id = 1;
SELECT * FROM good_sum_mart ORDER BY good_name;
UPDATE 1
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        71.50
(2 rows)

hw_triggers=# DELETE FROM sales WHERE sales_id = 2;
SELECT * FROM good_sum_mart ORDER BY good_name;
DELETE 1
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        71.00
(2 rows)

hw_triggers=# SELECT G.good_name, sum(G.good_price * S.sales_qty)::numeric(16,2) AS sum_sale
FROM goods G
JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
ORDER BY G.good_name;
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        71.00
(2 rows)

hw_triggers=# SELECT * FROM good_sum_mart;
        good_name         |   sum_sale
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        71.00
(2 rows)
```

#### Почему “отчет по требованию” может стать неправильным при изменении цен

Если цена в goods.good_price поменялась сегодня, то отчёт, построенный завтра, пересчитает все прошлые продажи по новой цене — то есть “перепишет историю” и даст сумму, которой никогда не было в момент продаж. Т.Е. сам SELECT ничего в таблицах не меняет, но вычисляемое значение на момент выполнения запроса будет другим.

```Наш отчет по требованию```:

```-- Для контроля: “отчет по требованию”
SELECT G.good_name, sum(G.good_price * S.sales_qty)::numeric(16,2) AS sum_sale
FROM goods G
JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
ORDER BY G.good_name;

ИЛИ как он изначально был предоставлен
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
```

**Отчёт “по требованию” (как работает)**

Он умножает текущую цену из goods.good_price на количество из sales.

Вчера: цена была 1, продали 10 шт → “исторически верная” сумма = 10

Сегодня мы поменяли цену в goods на 2

Завтра запускаем отчёт: он возьмёт 2 и посчитает 2 * 10 = 20

То есть отчёт “по требованию” переписал вчерашние продажи по сегодняшней цене → стало неправильно.


**Почему витрина + триггер лучше**

Триггер обновляет витрину в момент вставки/изменения/удаления продажи, используя цену на этот момент, тем самым:

- фиксирует сумму так, как она была рассчитана тогда;

- обеспечивает одинаковый результат отчёта “сегодня и через месяц”, даже если справочник товаров (и цены) менялся.


**Витрина + триггер (как работает)**

Триггер при INSERT в sales добавляет в витрину сумму по цене на момент вставки.

Вчера при продаже: триггер взял цену 1 и записал +10 в витрину

Сегодня цена стала 2

Витрина не пересчитывается сама от смены цены (потому что триггер стоит на sales, а не на goods)
→ поэтому вчерашние 10 остаются 10 (исторически корректно)

Новые продажи сегодня будут добавляться уже по новой цене 2

Итог: витрина хранит сумму так, как она “сложилась” во времени.

### Важно!

Даже если мы используем триггер и допустим сегодня продали по 1 рублю, и если завтра цена измениться и будет 2 рубля, и мы сделаем удаление продажи, то продажа удалит 2 рубля, т.е. мы будем в минусе. Чтобы этого не случилось нужно фиксировать цену продажи отдельной колонкой в таблице sales и переписывать триггер.