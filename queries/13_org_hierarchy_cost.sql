-- Team size and cost under each manager

USE pmo_portfolio;

WITH RECURSIVE
chain (manager_id, employee_id, depth) AS (
    SELECT manager_id, employee_id, 1 FROM employees WHERE manager_id IS NOT NULL
    UNION ALL
    SELECT c.manager_id, e.employee_id, c.depth + 1
    FROM chain c
    JOIN employees e ON e.manager_id = c.employee_id
),
reporting_line (employee_id, reporting_path, org_level) AS (
    SELECT employee_id, CAST(full_name AS CHAR(500)), 1 FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, CONCAT(rl.reporting_path, ' > ', e.full_name), rl.org_level + 1
    FROM reporting_line rl
    JOIN employees e ON e.manager_id = rl.employee_id
),
last_quarter_cost AS (
    SELECT ts.employee_id,
           SUM(ts.hours)                 AS hours,
           SUM(ts.hours * e.hourly_rate) AS cost
    FROM timesheets ts
    JOIN employees e ON e.employee_id = ts.employee_id
    WHERE ts.work_date > (SELECT DATE_SUB(data_date, INTERVAL 3 MONTH) FROM v_data_date)
    GROUP BY ts.employee_id
)
SELECT m.full_name                                       AS manager,
       m.job_title,
       rl.org_level,
       SUM(c.depth = 1)                                  AS direct_reports,
       COUNT(*)                                          AS total_org_size,
       MAX(c.depth)                                      AS layers_below,
       ROUND(COALESCE(SUM(q.hours), 0), 0)               AS org_hours_last_quarter,
       ROUND(COALESCE(SUM(q.cost), 0), 0)                AS org_cost_last_quarter,
       rl.reporting_path
FROM chain c
JOIN employees m       ON m.employee_id  = c.manager_id
JOIN reporting_line rl ON rl.employee_id = m.employee_id
LEFT JOIN last_quarter_cost q ON q.employee_id = c.employee_id
GROUP BY m.employee_id, m.full_name, m.job_title, rl.org_level, rl.reporting_path
ORDER BY rl.org_level, total_org_size DESC;
