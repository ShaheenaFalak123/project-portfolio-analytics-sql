-- Critical path for open projects

USE pmo_portfolio;

WITH RECURSIVE
driving_pred AS (
    SELECT task_id, pred_id
    FROM (
        SELECT d.task_id,
               d.depends_on_task_id AS pred_id,
               ROW_NUMBER() OVER (PARTITION BY d.task_id
                                  ORDER BY p.planned_end DESC, p.estimated_hours DESC) AS rn
        FROM task_dependencies d
        JOIN tasks p ON p.task_id = d.depends_on_task_id
    ) x
    WHERE rn = 1
),
final_task AS (
    SELECT project_id, task_id
    FROM (
        SELECT project_id, task_id,
               ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY planned_end DESC, task_id DESC) AS rn
        FROM tasks
    ) x
    WHERE rn = 1
),
critical_path (project_id, task_id, depth) AS (
    SELECT project_id, task_id, 0 FROM final_task
    UNION ALL
    SELECT cp.project_id, dp.pred_id, cp.depth + 1
    FROM critical_path cp
    JOIN driving_pred dp ON dp.task_id = cp.task_id
)
SELECT p.project_name,
       p.status,
       COUNT(*)                                                         AS critical_tasks,
       (SELECT COUNT(*) FROM tasks x WHERE x.project_id = p.project_id) AS total_tasks,
       DATEDIFF(MAX(t.planned_end), MIN(t.planned_start)) + 1           AS path_length_days,
       GROUP_CONCAT(t.task_name ORDER BY cp.depth DESC SEPARATOR ' > ') AS critical_path,
       SUM(t.status <> 'Done' AND t.planned_end < dd.data_date)          AS overdue_critical_tasks,
       COALESCE(MAX(CASE WHEN t.status <> 'Done' AND t.planned_end < dd.data_date
                         THEN DATEDIFF(dd.data_date, t.planned_end) END), 0) AS min_project_delay_days
FROM critical_path cp
JOIN tasks    t ON t.task_id    = cp.task_id
JOIN projects p ON p.project_id = cp.project_id
CROSS JOIN v_data_date dd
WHERE p.status IN ('Active', 'Planned')
GROUP BY p.project_id, p.project_name, p.status, p.planned_start
ORDER BY min_project_delay_days DESC, p.planned_start;
