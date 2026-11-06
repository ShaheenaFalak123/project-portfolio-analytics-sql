-- Team utilisation: last 13 weeks vs previous 13 weeks

USE pmo_portfolio;

WITH RECURSIVE
calendar (d) AS (
    SELECT DATE_SUB(data_date, INTERVAL 181 DAY) FROM v_data_date
    UNION ALL
    SELECT DATE_ADD(d, INTERVAL 1 DAY) FROM calendar WHERE d < (SELECT data_date FROM v_data_date)
),
periods AS (
    SELECT CASE WHEN c.d > DATE_SUB(dd.data_date, INTERVAL 91 DAY) THEN 'recent' ELSE 'prior' END AS period,
           MIN(c.d) AS start_d,
           MAX(c.d) AS end_d,
           SUM(DAYOFWEEK(c.d) NOT IN (1, 7)) AS work_days
    FROM calendar c CROSS JOIN v_data_date dd
    GROUP BY 1
),
delivery_staff AS (
    SELECT e.*
    FROM employees e
    WHERE EXISTS (SELECT 1 FROM tasks t WHERE t.assignee_id = e.employee_id)
),
emp_period AS (
    SELECT s.employee_id,
           s.dept_id,
           s.hourly_rate,
           pr.period,
           pr.work_days * s.weekly_capacity_hours / 5.0 AS capacity_hours,
           COALESCE(SUM(ts.hours), 0)                   AS logged_hours
    FROM delivery_staff s
    CROSS JOIN periods pr
    LEFT JOIN timesheets ts
           ON ts.employee_id = s.employee_id
          AND ts.work_date BETWEEN pr.start_d AND pr.end_d
    GROUP BY s.employee_id, s.dept_id, s.hourly_rate, pr.period, pr.work_days, s.weekly_capacity_hours
),
dept AS (
    SELECT dept_id,
           COUNT(DISTINCT employee_id)                                                            AS headcount,
           100.0 * SUM(CASE WHEN period = 'recent' THEN logged_hours END)
                 / SUM(CASE WHEN period = 'recent' THEN capacity_hours END)                       AS recent_util,
           100.0 * SUM(CASE WHEN period = 'prior' THEN logged_hours END)
                 / SUM(CASE WHEN period = 'prior' THEN capacity_hours END)                        AS prior_util,
           SUM(CASE WHEN period = 'recent' THEN GREATEST(capacity_hours - logged_hours, 0) * hourly_rate END) AS bench_cost,
           SUM(CASE WHEN period = 'recent' THEN GREATEST(logged_hours - capacity_hours, 0) END)   AS overtime_hours
    FROM emp_period
    GROUP BY dept_id
)
SELECT d.dept_name,
       x.headcount,
       ROUND(x.prior_util, 1)                    AS prior_13w_util_pct,
       ROUND(x.recent_util, 1)                   AS last_13w_util_pct,
       ROUND(x.recent_util - x.prior_util, 1)    AS change_pp,
       ROUND(x.overtime_hours, 0)                AS overtime_hours_13w,
       ROUND(x.bench_cost, 0)                    AS idle_capacity_cost_13w,
       RANK() OVER (ORDER BY x.recent_util DESC) AS busiest_rank
FROM dept x
JOIN departments d ON d.dept_id = x.dept_id
ORDER BY busiest_rank;
