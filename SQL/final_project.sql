create database Final_project; 

use Final_project;

CREATE TABLE customer_info (  
    Id_client INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    Total_amount INT NOT NULL,
    Gender VARCHAR(10) NOT NULL,
    Age INT NOT NULL,
    Count_city INT NOT NULL,
    Response_communication INT NOT NULL, 
    Communication_3month INT NOT NULL,
    Tenure INT NOT NULL
);

select * from customer_info;

CREATE TABLE transaction_info (
    id INT AUTO_INCREMENT PRIMARY KEY,
    date_new DATE,
    Id_check INT,
    ID_client INT,
    Count_products DECIMAL(10, 2),
    Sum_payment DECIMAL(10, 2)
);

select * from transaction_info;

-- список клиентов с покупками каждый месяц с 06.2015 по 05.2016
WITH months AS (
  SELECT DATE_FORMAT(DATE_ADD('2015-06-01', INTERVAL n MONTH), '%Y-%m') AS month_str
  FROM (
    SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
    UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11
  ) AS nums
),
client_months AS (
  SELECT DISTINCT
    ID_client,
    DATE_FORMAT(date_new, '%Y-%m') AS month_str
  FROM transaction_info
  WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
),
active_clients AS (
  SELECT ID_client
  FROM client_months
  GROUP BY ID_client
  HAVING COUNT(DISTINCT month_str) = 12
)
SELECT 
  t.ID_client,
  ROUND(AVG(t.Sum_payment), 2) AS avg_check,
  ROUND(SUM(t.Sum_payment) / 12, 2) AS avg_month_sum,
  COUNT(*) AS total_operations
FROM transaction_info t
JOIN active_clients a ON t.ID_client = a.ID_client
WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
GROUP BY t.ID_client;

-- 2 Метрики по месяцам: средний чек, число операций, число клиентов
SELECT 
  DATE_FORMAT(date_new, '%Y-%m') AS month,
  ROUND(AVG(Sum_payment), 2) AS avg_check,
  COUNT(*) AS operation_count,
  COUNT(DISTINCT ID_client) AS client_count
FROM transaction_info
WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY DATE_FORMAT(date_new, '%Y-%m')
ORDER BY month;

-- 3. Доля операций и сумм от общего годового значения

WITH total_summary AS (
  SELECT 
    COUNT(*) AS total_ops,
    SUM(Sum_payment) AS total_amount
  FROM transaction_info
  WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
),
monthly_summary AS (
  SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(*) AS ops,
    SUM(Sum_payment) AS amount
  FROM transaction_info
  WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
  GROUP BY DATE_FORMAT(date_new, '%Y-%m')
)
SELECT 
  m.month,
  m.ops,
  m.amount,
  ROUND(100 * m.ops / t.total_ops, 2) AS op_share_percent,
  ROUND(100 * m.amount / t.total_amount, 2) AS amount_share_percent
FROM monthly_summary m, total_summary t
ORDER BY m.month;


--  4. % M / F / NA по месяцам + доля затрат

WITH gender_summary AS (
  SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    COALESCE(c.Gender, 'NA') AS gender,
    COUNT(*) AS ops,
    SUM(t.Sum_payment) AS amount
  FROM transaction_info t
  LEFT JOIN customer_info c ON t.ID_client = c.Id_client
  WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
  GROUP BY month, gender
),
monthly_totals AS (
  SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(*) AS total_ops,
    SUM(Sum_payment) AS total_amount
  FROM transaction_info
  WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
  GROUP BY month
)
SELECT 
  g.month,
  g.gender,
  g.ops,
  g.amount,
  ROUND(100 * g.ops / m.total_ops, 2) AS op_share_percent,
  ROUND(100 * g.amount / m.total_amount, 2) AS amount_share_percent
FROM gender_summary g
JOIN monthly_totals m ON g.month = m.month
ORDER BY g.month, g.gender;


-- 5. Возрастные группы: за весь период и поквартально

WITH age_grouped AS (
  SELECT 
    Id_client,
    CASE
      WHEN Age IS NULL THEN 'Unknown'
      WHEN Age < 20 THEN '0-19'
      WHEN Age < 30 THEN '20-29'
      WHEN Age < 40 THEN '30-39'
      WHEN Age < 50 THEN '40-49'
      WHEN Age < 60 THEN '50-59'
      WHEN Age < 70 THEN '60-69'
      ELSE '70+'
    END AS age_group
  FROM customer_info
),
joined AS (
  SELECT 
    t.ID_client,
    DATE_FORMAT(t.date_new, '%Y-Q%q') AS quarter,
    a.age_group,
    t.Sum_payment
  FROM transaction_info t
  LEFT JOIN age_grouped a ON t.ID_client = a.Id_client
  WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
),
agg AS (
  SELECT 
    quarter,
    age_group,
    COUNT(*) AS op_count,
    ROUND(SUM(Sum_payment), 2) AS total_amount
  FROM joined
  GROUP BY quarter, age_group
),
totals AS (
  SELECT 
    quarter,
    SUM(total_amount) AS total_amt
  FROM agg
  GROUP BY quarter
)
SELECT 
  a.quarter,
  a.age_group,
  a.op_count,
  a.total_amount,
  ROUND(100 * a.total_amount / t.total_amt, 2) AS percent_of_quarter
FROM agg a
JOIN totals t ON a.quarter = t.quarter
ORDER BY a.quarter, a.age_group;

