-- Monthly spend vs plan

USE pmo_portfolio;

WITH RECURSIVE
months (month_start) AS (
    SELECT DATE_SUB(MIN(planned_start), INTERVAL DAYOFMONTH(MIN(planned_start)) - 1 DAY) FROM projects
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH) FROM months
    WHERE month_start < (SELECT DATE_SUB(data_date, INTERVAL DAYOFMONTH(data_date) - 1 DAY) FROM v_data_date)
),
month_ends AS (
    SELECT month_start,
           LEAST(LAST_DAY(month_start), (SELECT data_date FROM v_data_date)) AS month_end
    FROM months
),
task_budget AS (
    SELECT t.task_id, t.planned_start, t.planned_end, t.estimated_hours * e.hourly_rate AS budget
    FROM tasks t JOIN employees e ON e.employee_id = t.assignee_id
),
cumulative_plan AS (
    SELECT m.month_start,
           SUM(tb.budget *
               CASE
                   WHEN m.month_end >= tb.planned_end  THEN 1.0
                   WHEN m.month_end <  tb.planned_start THEN 0.0
                   ELSE (DATEDIFF(m.month_end, tb.planned_start) + 1.0)
                      / (DATEDIFF(tb.planned_end, tb.planned_start) + 1.0)
               END) AS cum_planned
    FROM month_ends m
    CROSS JOIN task_budget tb
    GROUP BY m.month_start
),
monthly_actual AS (
    SELECT DATE_SUB(ts.work_date, INTERVAL DAYOFMONTH(ts.work_date) - 1 DAY) AS month_start,
           SUM(ts.hours * e.hourly_rate)                                     AS actual
    FROM timesheets ts
    JOIN employees e ON e.employee_id = ts.employee_id
    GROUP BY 1
),
combined AS (
    SELECT cp.month_start,
           cp.cum_planned - COALESCE(LAG(cp.cum_planned) OVER (ORDER BY cp.month_start), 0) AS planned,
           COALESCE(ma.actual, 0)                                                           AS actual,
           cp.cum_planned,
           SUM(COALESCE(ma.actual, 0)) OVER (ORDER BY cp.month_start)                       AS cum_actual
    FROM cumulative_plan cp
    LEFT JOIN monthly_actual ma ON ma.month_start = cp.month_start
)
SELECT DATE_FORMAT(month_start, '%Y-%m')                   AS month,
       ROUND(planned, 0)                                   AS planned_spend,
       ROUND(actual, 0)                                    AS actual_spend,
       ROUND(cum_planned, 0)                               AS cumulative_planned,
       ROUND(cum_actual, 0)                                AS cumulative_actual,
       ROUND(cum_actual - cum_planned, 0)                  AS cumulative_variance,
       ROUND(100.0 * (cum_actual - cum_planned) / cum_planned, 1) AS cumulative_variance_pct,
       ROUND(100.0 * (actual - LAG(actual) OVER (ORDER BY month_start))
             / NULLIF(LAG(actual) OVER (ORDER BY month_start), 0), 1) AS actual_mom_change_pct
FROM combined
ORDER BY month_start;
