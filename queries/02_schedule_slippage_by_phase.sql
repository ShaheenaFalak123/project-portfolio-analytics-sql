-- Schedule slippage by project phase

USE pmo_portfolio;

WITH done AS (
    SELECT t.phase,
           p.methodology,
           DATEDIFF(t.actual_end, t.planned_end) AS finish_slip_days,
           (DATEDIFF(t.actual_end, t.actual_start) + 1)
             / (DATEDIFF(t.planned_end, t.planned_start) + 1) - 1 AS duration_overrun
    FROM tasks t
    JOIN projects p ON p.project_id = t.project_id
    WHERE t.status = 'Done'
),
ranked AS (
    SELECT d.*,
           ROW_NUMBER() OVER (PARTITION BY phase ORDER BY finish_slip_days) AS rn,
           COUNT(*)     OVER (PARTITION BY phase)                           AS n
    FROM done d
)
SELECT phase,
       MAX(n)                                                                  AS tasks_completed,
       ROUND(100.0 * AVG(duration_overrun), 1)                                 AS avg_duration_overrun_pct,
       AVG(CASE WHEN rn IN ((n + 1) DIV 2, (n + 2) DIV 2) THEN finish_slip_days END) AS median_finish_slip_days,
       MAX(CASE WHEN rn <= (9 * n + 9) DIV 10 THEN finish_slip_days END)       AS p90_finish_slip_days,
       ROUND(100.0 * AVG(finish_slip_days > 0), 0)                             AS pct_tasks_late,
       ROUND(AVG(CASE WHEN methodology = 'Agile'     THEN finish_slip_days END), 1) AS agile_avg_slip,
       ROUND(AVG(CASE WHEN methodology = 'Hybrid'    THEN finish_slip_days END), 1) AS hybrid_avg_slip,
       ROUND(AVG(CASE WHEN methodology = 'Waterfall' THEN finish_slip_days END), 1) AS waterfall_avg_slip
FROM ranked
GROUP BY phase
ORDER BY FIELD(phase, 'Initiation', 'Planning', 'Design', 'Build', 'Test', 'Deploy', 'Closure');
