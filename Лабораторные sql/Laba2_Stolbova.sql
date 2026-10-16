--ЛАБОРАТОРНАЯ РАБОТА №2
-- Наполнение данными + запросы

-- Очищаем данные (чтобы можно было запускать повторно)
TRUNCATE 
    reviews, payments, order_items, orders, 
    cart_items, carts, stock, products, 
    categories, sellers, users
RESTART IDENTITY CASCADE;

-- 1. Пользователи (20 штук)
INSERT INTO users (email, full_name, phone)
SELECT 
    'user' || g || '@mail.ru',
    'Пользователь ' || g,
    '+7900' || lpad(g::text, 7, '0')
FROM generate_series(1, 20) AS g;

-- 2. Продавцы (5 штук)
INSERT INTO sellers (user_id, store_name)
SELECT 
    id,
    'Магазин №' || id
FROM users
WHERE id <= 5;

-- 3. Категории (с иерархией)
INSERT INTO categories (name, parent_id) VALUES
('Электроника', NULL),
('Одежда', NULL),
('Косметика', NULL),
('Смартфоны', 1),
('Мужская одежда', 2),
('Женская одежда', 2),
('Уходовая косметика', 3),
('Декоративная косметика', 3);

-- 4. Товары (1000 штук)
INSERT INTO products (seller_id, category_id, title, price)
SELECT 
    (random() * 4 + 1)::int,                          
    (random() * 7 + 1)::int,                          
    'Товар №' || g,
    (random() * 9500 + 500)::numeric(12,2)      
FROM generate_series(1, 1000) AS g;

-- 5. Остатки на складе
INSERT INTO stock (product_id, quantity)
SELECT 
    id,
    (random() * 100)::int
FROM products;

-- 6. Корзины (по одной на первых 10 пользователей)
INSERT INTO carts (user_id)
SELECT id FROM users WHERE id <= 10;

-- 7. Позиции корзин
INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT 
    (random() * 9 + 1)::int,
    (random() * 999 + 1)::int,
    (random() * 3 + 1)::int
FROM generate_series(1, 50) AS g
ON CONFLICT DO NOTHING;

-- 8. Заказы (1000 штук)
INSERT INTO orders (user_id, status, created_at)
SELECT 
    (random() * 19 + 1)::int,
    (ARRAY['new', 'paid', 'shipped', 'delivered', 'cancelled'])[floor(random()*5 + 1)],
    now() - (random() * 90 || ' days')::interval
FROM generate_series(1, 1000) AS g;

-- 9. Позиции заказов
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
    o.id,
    (random() * 999 + 1)::int,
    (random() * 3 + 1)::int,
    p.price
FROM orders o
CROSS JOIN LATERAL (
    SELECT price FROM products 
    WHERE id = (random() * 999 + 1)::int
    LIMIT 1
) p
LIMIT 2000;

-- 10. Платежи (для оплаченных заказов)
INSERT INTO payments (order_id, amount, status, paid_at)
SELECT 
    id,
    (random() * 5000 + 500)::numeric(12,2),
    'success',
    created_at + interval '1 hour'
FROM orders
WHERE status IN ('paid', 'shipped', 'delivered')
LIMIT 600;

-- 11. Отзывы
INSERT INTO reviews (user_id, product_id, score, comment)
SELECT 
    (random() * 19 + 1)::int,
    (random() * 999 + 1)::int,
    (random() * 4 + 1)::int,
    'Отзыв на товар'
FROM generate_series(1, 300) AS g
ON CONFLICT DO NOTHING;

-- Задание 2: DISTINCT + псевдонимы
SELECT DISTINCT 
    title AS название_товара,
    price AS цена
FROM products
ORDER BY цена DESC
LIMIT 15;

-- Задание 3: Фильтрация AND и OR + скобки
SELECT title, price, category_id, is_active
FROM products
WHERE (price > 5000 OR category_id IN (1, 4, 5))
  AND is_active = TRUE
LIMIT 15;

-- Задание 4: BETWEEN, IN, ILIKE, IS NULL
SELECT title, price, category_id, is_active
FROM products
WHERE price BETWEEN 1000 AND 5000
  AND category_id IN (1, 2, 4, 5)
  AND title ILIKE '%товар%'
  AND is_active IS NOT NULL
LIMIT 15;

-- Задание 5: Сортировка по двум столбцам
SELECT title, price, created_at
FROM products
WHERE is_active = TRUE
ORDER BY price DESC, title ASC
LIMIT 15;

-- Задание 6: Постраничный вывод
SELECT title, price
FROM products
WHERE is_active = TRUE
ORDER BY id
LIMIT 10 OFFSET 10;
