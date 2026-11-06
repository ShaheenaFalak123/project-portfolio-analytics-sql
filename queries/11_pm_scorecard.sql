-- Project manager scorecard

USE pmo_portfolio;

WITH finished AS (
    SELECT p.project_manager_id,
           e.cpi,
           DATEDIFF(p.actual_end, p.planned_end) AS days_late
    FROM projects p
    JOIN v_project_evm e ON e.project_id = p.project_id
    WHERE p.status = 'Completed'
),
sprint_stats AS (
    SELECT p.project_manager_id,
           AVG(1.0 * s.completed_points / s.committed_points) AS say_do
    FROM sprints s
    JOIN projects p ON p.project_id = s.project_id
    GROUP BY p.project_manager_id
),
pm AS (
    SELECT e.employee_id,
           e.full_name,
           COUNT(f.cpi)                    AS projects_completed,
           AVG(f.cpi)                      AS avg_cpi,
           100.0 * AVG(f.days_late <= 5)   AS on_time_pct,
           AVG(f.days_late)                AS avg_days_late,
           ss.say_do
    FROM employees e
    LEFT JOIN finished     f  ON f.project_manager_id  = e.employee_id
    LEFT JOIN sprint_stats ss ON ss.project_manager_id = e.employee_id
    WHERE e.job_title = 'Project Manager'
    GROUP BY e.employee_id, e.full_name, ss.say_do
    HAVING COUNT(f.cpi) > 0
)
SELECT full_name                                AS project_manager,
       projects_completed,
       ROUND(avg_cpi, 3)                        AS avg_cpi,
       ROUND(on_time_pct, 0)                    AS on_time_pct,
       ROUND(avg_days_late, 1)                  AS avg_days_late,
       ROUND(100 * say_do, 0)                   AS sprint_say_do_pct,
       RANK() OVER (ORDER BY avg_cpi DESC)      AS cost_rank,
       RANK() OVER (ORDER BY avg_days_late)     AS schedule_rank,
       ROUND((RANK() OVER (ORDER BY avg_cpi DESC) + RANK() OVER (ORDER BY avg_days_late)) / 2.0, 1) AS composite_score
FROM pm
ORDER BY composite_score, avg_cpi DESC;
