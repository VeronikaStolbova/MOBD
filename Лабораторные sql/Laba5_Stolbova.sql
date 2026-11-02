-- ЛАБОРАТОРНАЯ РАБОТА №5
--Транзакции, целостность данных и серверная логика

-- 1.1 Успешная транзакция
BEGIN;
UPDATE products SET price = 9999.00 WHERE id = 1;
COMMIT;
SELECT id, title, price FROM products WHERE id = 1;

-- 1.2 Транзакция с откатом (ROLLBACK)
BEGIN;
UPDATE products SET price = 1111.00 WHERE id = 2;
ROLLBACK;
SELECT id, title, price FROM products WHERE id = 2;

--2. Функция атомарного оформления заказа
CREATE OR REPLACE FUNCTION place_order(p_user BIGINT, p_product BIGINT, p_qty INT)
RETURNS BIGINT AS $$
DECLARE
    v_order_id BIGINT;
    v_price NUMERIC(12,2);
    v_stock INT;
BEGIN
    -- 1. Получаем цену товара
    SELECT price INTO v_price FROM products WHERE id = p_product;
    IF v_price IS NULL THEN
        RAISE EXCEPTION 'Товар с id=% не найден', p_product;
    END IF;
    -- 2. Проверяем остаток на складе
    SELECT quantity INTO v_stock FROM stock WHERE product_id = p_product;
    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%), осталось % шт.', p_product, v_stock;
    END IF;
    -- 3. Создаем заказ
    INSERT INTO orders (user_id) VALUES (p_user) RETURNING id INTO v_order_id;
    -- 4. Добавляем позицию в заказ
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product, p_qty, v_price);
    -- 5. Уменьшаем остаток на складе
    UPDATE stock SET quantity = quantity - p_qty WHERE product_id = p_product;
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;
-- Проверка работы функции (успешный заказ)
SELECT place_order(1, 1, 2);
-- Проверка работы функции (ошибка: товара не хватает)
--SELECT place_order(1, 1, 99999); 

--3. Функция для расчёта сводного показателя
CREATE OR REPLACE FUNCTION get_seller_revenue(p_seller_id BIGINT, p_date_from DATE, p_date_to DATE)
RETURNS NUMERIC AS $$
DECLARE
    v_revenue NUMERIC;
BEGIN
    SELECT SUM(oi.quantity * oi.unit_price) INTO v_revenue
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    JOIN products p ON p.id = oi.product_id
    WHERE p.seller_id = p_seller_id
      AND o.created_at::DATE BETWEEN p_date_from AND p_date_to
      AND o.status IN ('paid', 'shipped', 'delivered');
    -- Если заказов не было, вернем 0 вместо NULL
    RETURN COALESCE(v_revenue, 0);
END;
$$ LANGUAGE plpgsql;

-- Проверка: выручка продавца с id=1 за последние 100 лет
SELECT get_seller_revenue(1, '2000-01-01', '2030-12-31') AS total_revenue;

--4. Триггер аудита изменения цены
-- 1. Создаем таблицу для журнала аудита
CREATE TABLE product_price_audit (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL,
    old_price NUMERIC(12,2),
    new_price NUMERIC(12,2),
    changed_at TIMESTAMPTZ DEFAULT now()
);
-- 2. Создаем триггерную функцию
CREATE OR REPLACE FUNCTION audit_product_price()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверяем, что цена действительно изменилась
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        INSERT INTO product_price_audit (product_id, old_price, new_price)
        VALUES (NEW.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- 3. Создаем сам триггер
CREATE TRIGGER trg_audit_product_price
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION audit_product_price();
-- Проверка: меняем цену и смотрим в журнал
UPDATE products SET price = 5555.00 WHERE id = 1;
SELECT * FROM product_price_audit;

--5. Триггер для поддержания денормализованного поля
-- 1. Добавляем денормализованное поле рейтинга
ALTER TABLE products ADD COLUMN rating NUMERIC(3,2) DEFAULT 0;
-- 2. Триггерная функция пересчета
CREATE OR REPLACE FUNCTION refresh_product_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET rating = (SELECT COALESCE(AVG(score), 0) FROM reviews WHERE product_id = NEW.product_id)
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- 3. Создание триггера
CREATE TRIGGER trg_refresh_rating
AFTER INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_product_rating();
-- Проверка: добавляем отзыв и смотрим, как изменился рейтинг товара
INSERT INTO reviews (user_id, product_id, score, comment) VALUES (1, 1, 5, 'Отличный товар!');
SELECT id, title, rating FROM products WHERE id = 1;