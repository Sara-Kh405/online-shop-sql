
-- ===================== PART 0: RESET (safe to re-run) =====================
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS discount;
DROP TABLE IF EXISTS order_detail2;
DROP TABLE IF EXISTS order_detail;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS user_basket;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;

-- ===================== PART 1: USERS / ROLES =====================
CREATE TABLE users(
  id VARCHAR(40) PRIMARY KEY,
  user_name VARCHAR(100),
  password VARCHAR(255),
  first_name VARCHAR(45),
  last_name VARCHAR(45),
  birth_date DATE,
  register_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  disabled TINYINT DEFAULT 0
);

INSERT INTO users (id, user_name, password, first_name, last_name, birth_date) VALUES
('1sfdhgff', 'Sara',  'hgdjhkhkju', 'Sara',  'Taheri', '2006-05-06'),
('rtse6dg7', 'Mitra', 'gcgcg764td', 'Mitra', 'Habibi', '2000-08-03'),
('bvcs7ygf', 'Ali',   'mnbstrefg5', 'Ali',   'Sohrabi',  '1990-02-05'),
('mnwvbsdf', 'Reza',  'afdgwok461', 'Reza',  'Gholami',  '2008-03-08');

UPDATE users SET
  password = 'vsi76sv3gd'
WHERE id = '1sfdhgff';

CREATE TABLE roles(
  id INTEGER PRIMARY KEY,
  title VARCHAR(45)
);

INSERT INTO roles (id, title) VALUES
(1, 'admin'),
(2, 'seller'),
(3, 'user'),
(4, 'silver user');

CREATE TABLE user_roles(
  user_id VARCHAR(40),
  role_id INTEGER,
  PRIMARY KEY(user_id, role_id),
  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(role_id) REFERENCES roles(id)
);

INSERT INTO user_roles (user_id, role_id) VALUES
('1sfdhgff', 2),
('rtse6dg7', 3),
('bvcs7ygf', 3),
('mnwvbsdf', 3);

-- ===================== PART 2: CATEGORIES / PRODUCTS =====================
CREATE TABLE categories(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title VARCHAR(100),
  parent_id INTEGER,
  FOREIGN KEY (parent_id) REFERENCES categories(id)
);

-- parents first (ids 1,2), then children (ids 3..6)
INSERT INTO categories (title, parent_id) VALUES
('food',   NULL),   -- 1
('toys',   NULL),   -- 2
('dairy',  1),      -- 3
('milk',   3),      -- 4
('butter', 3),      -- 5
('cheese', 3);      -- 6

CREATE TABLE products(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title VARCHAR(45),
  detail TEXT,
  price INTEGER,
  category_id INTEGER,
  FOREIGN KEY (category_id) REFERENCES categories(id)
);

INSERT INTO products (title, detail, price, category_id) VALUES
('Pegah milk',   NULL,  30000, 4),   -- 1
('Pegah butter', NULL,  20000, 5),   -- 2
('Mihan milk',   NULL,  25000, 4),   -- 3
('doll',         NULL, 100000, 2),   -- 4
('Kalleh cheese',NULL,  45000, 6),   -- 5
('Lego set',     NULL, 250000, 2);   -- 6

-- test: a product with price 0 (will be removed from baskets below)
UPDATE products SET
  price = 0
WHERE title = 'Pegah butter';

-- ===================== PART 3: BASKET / ORDERS =====================
CREATE TABLE user_basket(
  user_id VARCHAR(40),
  product_id INTEGER,
  quantity INTEGER,
  PRIMARY KEY(user_id, product_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);

INSERT INTO user_basket (user_id, product_id, quantity) VALUES
('rtse6dg7', 4, 3),
('rtse6dg7', 1, 2),
('rtse6dg7', 2, 1);   -- price 0, should be deleted next

DELETE FROM user_basket
WHERE product_id IN (SELECT id FROM products WHERE price = 0);

SELECT * FROM user_basket;

CREATE TABLE orders(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id VARCHAR(40),
  order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_detail(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER,
  product_id INTEGER,
  quantity INTEGER,
  price INTEGER,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);

-- order 1: converted from Mitra's basket (create order, copy basket, empty basket)
INSERT INTO orders (user_id) VALUES ('rtse6dg7');


INSERT INTO order_detail (order_id, product_id, quantity, price)
SELECT (SELECT MAX(id) FROM orders WHERE user_id = 'rtse6dg7'),
       ub.product_id, ub.quantity, p.price
FROM user_basket AS ub
INNER JOIN products AS p ON ub.product_id = p.id
WHERE ub.user_id = 'rtse6dg7';

DELETE FROM user_basket WHERE user_id = 'rtse6dg7';

-- more orders (ids 2,3,4 because the tables were just recreated)
INSERT INTO orders (user_id) VALUES
('1sfdhgff'),   -- 2  Sara
('bvcs7ygf'),   -- 3  Ali
('rtse6dg7');   -- 4  Mitra (second order)

INSERT INTO order_detail (order_id, product_id, quantity, price) VALUES
(2, 1, 4,  30000),
(2, 3, 2,  25000),
(3, 5, 1,  45000),
(3, 6, 1, 250000),
(4, 3, 6,  25000);

-- users who have at least one order: role 3 -> 4
UPDATE user_roles SET
  role_id = 4
WHERE role_id = 3 AND user_id IN (SELECT user_id FROM orders);

SELECT DISTINCT user_id FROM orders;
SELECT * FROM orders;

-- ===================== PART 4: STEP 2 (order_detail2) =====================
CREATE TABLE order_detail2(
  order_id INTEGER,
  detail_id INTEGER,
  product_id INTEGER,
  quantity INTEGER,
  price INTEGER,
  PRIMARY KEY(order_id, detail_id),
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);

-- copy order_detail rows; detail_id = row number inside each order (1,2,3...)
INSERT INTO order_detail2 (order_id, detail_id, product_id, quantity, price)
SELECT order_id,
       ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY id),
       product_id, quantity, price
FROM order_detail;

-- ===================== PART 5: DISCOUNT =====================
CREATE TABLE discount(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title VARCHAR(255),
  discount_code VARCHAR(30),
  active_date DATETIME,
  expire_date DATETIME,
  persent INTEGER
);

-- dates MUST be YYYY-MM-DD (dashes, no spaces)
INSERT INTO discount (title, discount_code, active_date, expire_date, persent) VALUES
('d1', 'kfnksnf3',                 '2026-01-01', '2027-12-31', 10),
('d2', lower(hex(randomblob(4))),  '2026-01-01', '2027-12-31', 15);

SELECT * FROM discount;

SELECT id, persent FROM discount
WHERE discount_code = 'kfnksnf3'
  AND active_date <= date('now')
  AND expire_date >= date('now');

-- ===================== PART 6: PAYMENTS =====================
CREATE TABLE payments(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER,
  discount_id INTEGER,
  total_price INTEGER,
  discount_price INTEGER,
  total_amount INTEGER,
  payment_date DATE,
  payment_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  payment_code VARCHAR(100),
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (discount_id) REFERENCES discount(id)
);

-- order 1 with discount d1 (10%)
INSERT INTO payments
(order_id, discount_id, total_price, discount_price, total_amount, payment_date, payment_code)
SELECT
  t.order_id,
  d.id,
  t.total,
  t.total * d.persent / 100,
  t.total - (t.total * d.persent / 100),
  date('now'),
  'PAY-001'
FROM (
  SELECT order_id, SUM(price * quantity) AS total
  FROM order_detail
  WHERE order_id = 1
  GROUP BY order_id
) AS t
JOIN discount AS d
  ON d.discount_code = 'kfnksnf3'
 AND d.active_date <= date('now')
 AND d.expire_date >= date('now');

-- order 3 with discount d2 (15%), found by title
INSERT INTO payments
(order_id, discount_id, total_price, discount_price, total_amount, payment_date, payment_code)
SELECT
  t.order_id,
  d.id,
  t.total,
  t.total * d.persent / 100,
  t.total - (t.total * d.persent / 100),
  date('now'),
  'PAY-003'
FROM (
  SELECT order_id, SUM(price * quantity) AS total
  FROM order_detail
  WHERE order_id = 3
  GROUP BY order_id
) AS t
JOIN discount AS d
  ON d.title = 'd2'
 AND d.active_date <= date('now')
 AND d.expire_date >= date('now');

-- orders 2 and 4 without discount (discount_id stays NULL)


INSERT INTO payments
(order_id, discount_id, total_price, discount_price, total_amount, payment_date, payment_code)
SELECT
  order_id,
  NULL,
  SUM(price * quantity),
  0,
  SUM(price * quantity),
  date('now'),
  'PAY-00' || order_id
FROM order_detail
WHERE order_id IN (2, 4)
GROUP BY order_id;

SELECT * FROM payments;

-- ===================== PART 7: REPORTS =====================
-- (select each query alone and press Ctrl+Enter to see its result)

-- per user: sum / min / max / count of payments, only users whose biggest payment > 200000
SELECT o.user_id,
       u.user_name,
       SUM(p.total_amount) AS amount_sum,
       MIN(p.total_amount) AS amount_min,
       MAX(p.total_amount) AS amount_max,
       COUNT(*)            AS payment_count
FROM payments AS p
INNER JOIN orders AS o ON p.order_id = o.id
INNER JOIN users  AS u ON u.id = o.user_id
GROUP BY o.user_id
HAVING amount_max > 200000;

-- best-selling product (by total quantity), with its name
SELECT pr.title,
       SUM(od.quantity) AS total_sold
FROM order_detail2 AS od
INNER JOIN products AS pr ON pr.id = od.product_id
GROUP BY od.product_id
ORDER BY total_sold DESC
LIMIT 1;
