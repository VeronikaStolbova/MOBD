-- ЛАБОРАТОРНАЯ РАБОТА №4
-- Оконные функции и аналитика данных

--Задание 1. Рейтинг товаров по цене внутри каждой категории
SELECT c.name AS категория, p.title AS товар, p.price AS цена,
       ROW_NUMBER() OVER w AS row_num,
       RANK() OVER w AS rank_num,
       DENSE_RANK() OVER w AS dense_rank
FROM products p
JOIN categories c ON c.id = p.category_id
WINDOW w AS (PARTITION BY p.category_id ORDER BY p.price DESC)
LIMIT 20;

--Задание 2. Три самых дорогих товара в каждой категории
WITH ranked AS (
    SELECT c.name AS категория, p.title AS товар, p.price AS цена,
           ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rn
    FROM products p
    JOIN categories c ON c.id = p.category_id
)
SELECT категория, товар, цена
FROM ranked
WHERE rn <= 3
ORDER BY категория, цена DESC;

--Задание 3. Нарастающий итог выручки по дням
WITH daily AS (
    SELECT o.created_at::date AS день,
           SUM(oi.quantity * oi.unit_price) AS выручка_за_день
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    WHERE o.status IN ('paid', 'shipped', 'delivered')
    GROUP BY o.created_at::date
)
SELECT день, выручка_за_день,
    SUM(выручка_за_день) OVER (ORDER BY день ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS нарастающий_итог
FROM daily
ORDER BY день
LIMIT 20;

--Задание 4. Доля выручки продавца в выручке его категории
WITH seller_cat AS (
    SELECT s.store_name AS продавец, c.name AS категория,
           SUM(oi.quantity * oi.unit_price) AS выручка
    FROM sellers s
    JOIN products p ON p.seller_id = s.id
    JOIN categories c ON c.id = p.category_id
    JOIN order_items oi ON oi.product_id = p.id
    JOIN orders o ON o.id = oi.order_id
    WHERE o.status IN ('paid', 'shipped', 'delivered')
    GROUP BY s.store_name, c.name
)
SELECT продавец, категория, выручка,
       SUM(выручка) OVER (PARTITION BY категория) AS всего_по_категории,
       ROUND(выручка * 100.0 / SUM(выручка) OVER (PARTITION BY категория), 2) AS доля_проц
FROM seller_cat
ORDER BY категория, доля_проц DESC;

--Задание 5. Сравнение выручки текущего дня с предыдущим (LAG/LEAD)
SELECT o.created_at::date AS день,
       SUM(oi.quantity * oi.unit_price) AS выручка,
       LAG(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY o.created_at::date) AS пред_день,
       SUM(oi.quantity * oi.unit_price)
         - LAG(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY o.created_at::date) AS прирост
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY o.created_at::date
ORDER BY день
LIMIT 20;

--Задание 6. Сравнение оконной функции и обычной группировки
-- Способ 2: Обычная группировка
SELECT c.name AS категория, p.title AS товар, p.price AS цена
FROM products p
JOIN categories c ON c.id = p.category_id
JOIN (
    SELECT category_id, MAX(price) AS max_price 
    FROM products 
    GROUP BY category_id
) AS top ON top.category_id = p.category_id AND top.max_price = p.price
ORDER BY категория;