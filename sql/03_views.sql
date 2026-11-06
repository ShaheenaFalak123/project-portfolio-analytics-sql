USE pmo_portfolio;

CREATE OR REPLACE VIEW v_data_date AS
SELECT CAST(param_value AS DATE) AS data_date
FROM report_params
WHERE param_key = 'data_date';

CREATE OR REPLACE VIEW v_task_evm AS
WITH actual_cost AS (
    SELECT ts.task_id,
           SUM(ts.hours)                 AS actual_hours,
           SUM(ts.hours * e.hourly_rate) AS actual_cost
    FROM timesheets ts
    JOIN employees e ON e.employee_id = ts.employee_id
    WHERE ts.work_date <= (SELECT data_date FROM v_data_date)
    GROUP BY ts.task_id
)
SELECT t.task_id,
       t.project_id,
       t.phase,
       t.status,
       t.estimated_hours,
       t.estimated_hours * e.hourly_rate AS task_budget,
       t.estimated_hours * e.hourly_rate *
           CASE
               WHEN d.data_date >= t.planned_end   THEN 1.0
               WHEN d.data_date <  t.planned_start THEN 0.0
               ELSE (DATEDIFF(d.data_date, t.planned_start) + 1.0)
                  / (DATEDIFF(t.planned_end, t.planned_start) + 1.0)
           END                                                    AS planned_value,
       t.estimated_hours * e.hourly_rate * t.percent_complete / 100.0 AS earned_value,
       COALESCE(ac.actual_hours, 0)                               AS actual_hours,
       COALESCE(ac.actual_cost, 0)                                AS actual_cost
FROM tasks t
JOIN employees e        ON e.employee_id = t.assignee_id
CROSS JOIN v_data_date d
LEFT JOIN actual_cost ac ON ac.task_id = t.task_id;

CREATE OR REPLACE VIEW v_project_evm AS
WITH agg AS (
    SELECT project_id,
           SUM(task_budget)   AS bac,
           SUM(planned_value) AS pv,
           SUM(earned_value)  AS ev,
           SUM(actual_cost)   AS ac
    FROM v_task_evm
    GROUP BY project_id
)
SELECT p.project_id,
       p.project_name,
       p.status,
       p.methodology,
       p.approved_budget,
       ROUND(a.bac, 2)                                       AS bac,
       ROUND(a.pv, 2)                                        AS pv,
       ROUND(a.ev, 2)                                        AS ev,
       ROUND(a.ac, 2)                                        AS ac,
       ROUND(a.ev / NULLIF(a.ac, 0), 3)                      AS cpi,
       ROUND(a.ev / NULLIF(a.pv, 0), 3)                      AS spi,
       ROUND(a.bac / NULLIF(a.ev / NULLIF(a.ac, 0), 0), 2)   AS eac,
       ROUND(a.bac - a.bac / NULLIF(a.ev / NULLIF(a.ac, 0), 0), 2) AS vac
FROM projects p
JOIN agg a ON a.project_id = p.project_id;

CREATE OR REPLACE VIEW v_employee_weekly_load AS
SELECT ts.employee_id,
       DATE_SUB(ts.work_date, INTERVAL WEEKDAY(ts.work_date) DAY) AS week_start,
       SUM(ts.hours)                                              AS hours_logged,
       MAX(e.weekly_capacity_hours)                               AS capacity
FROM timesheets ts
JOIN employees e ON e.employee_id = ts.employee_id
GROUP BY ts.employee_id, DATE_SUB(ts.work_date, INTERVAL WEEKDAY(ts.work_date) DAY);
