-- ЛАБОРАТОРНАЯ РАБОТА №3
-- Многотабличные запросы и аналитические представления

--1. INNER JOIN трёх таблиц (товар — категория — продавец)
SELECT 
    p.title AS товар,
    c.name AS категория,
    s.store_name AS продавец,
    p.price AS цена
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers AS s ON s.id = p.seller_id
LIMIT 10;

--2. LEFT JOIN - товары без отзывов
SELECT 
    p.id,
    p.title AS товар,
    p.price AS цена
FROM products AS p
LEFT JOIN reviews AS r ON r.product_id = p.id
WHERE r.id IS NULL
LIMIT 10;

--3. GROUP BY - количество товаров и средняя цена по категориям
SELECT 
    c.name AS категория,
    COUNT(*) AS количество_товаров,
    ROUND(AVG(p.price), 2) AS средняя_цена
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
GROUP BY c.name
ORDER BY количество_товаров DESC;

--4. HAVING - продавцы с выручкой выше 50000
SELECT 
    s.store_name AS продавец,
    SUM(oi.quantity * oi.unit_price) AS выручка
FROM sellers AS s
JOIN products AS p ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 50000
ORDER BY выручка DESC;

--5.1. Скалярный подзапрос - товары дороже средней цены
SELECT title, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC
LIMIT 10;

--5.2. Подзапрос с IN
SELECT title, price, category_id
FROM products
WHERE category_id IN (
    SELECT id FROM categories
    WHERE name IN ('Электроника', 'Одежда')
)
LIMIT 10;

--5.3. Подзапрос с EXISTS (коррелированный)
SELECT s.id, s.store_name
FROM sellers AS s
WHERE EXISTS (
    SELECT 1 FROM products AS p
    WHERE p.seller_id = s.id
);

--6.1. CTE - выручка продавцов
WITH seller_revenue AS (
    SELECT 
        p.seller_id,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM products AS p
    JOIN order_items AS oi ON oi.product_id = p.id
    GROUP BY p.seller_id
)
SELECT 
    s.store_name AS продавец,
    r.revenue AS выручка
FROM seller_revenue AS r
JOIN sellers AS s ON s.id = r.seller_id
ORDER BY выручка DESC;

--6.2. Рекурсивный CTE - дерево категорий
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS level
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories AS c
    JOIN category_tree AS ct ON c.parent_id = ct.id
)
SELECT id, name, parent_id, level
FROM category_tree
ORDER BY level, name;

--7.1. Представление: товары с категорией и продавцом
CREATE OR REPLACE VIEW v_products_full AS
SELECT 
    p.id,
    p.title AS товар,
    c.name AS категория,
    s.store_name AS продавец,
    p.price AS цена,
    p.is_active
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers AS s ON s.id = p.seller_id;

-- Обращение к представлению
SELECT * FROM v_products_full
WHERE цена > 3000
LIMIT 10;

--7.2. Представление: статистика по категориям
CREATE OR REPLACE VIEW v_category_stats AS
SELECT 
    c.name AS категория,
    COUNT(*) AS количество_товаров,
    ROUND(AVG(p.price), 2) AS средняя_цена,
    MIN(p.price) AS мин_цена,
    MAX(p.price) AS макс_цена
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
GROUP BY c.name;

-- Обращение к представлению
SELECT * FROM v_category_stats
ORDER BY количество_товаров DESC;