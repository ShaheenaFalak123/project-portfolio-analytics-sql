-- Data quality checks

USE pmo_portfolio;

WITH RECURSIVE
reach (origin, task_id) AS (
    SELECT task_id, depends_on_task_id FROM task_dependencies
    UNION DISTINCT
    SELECT r.origin, d.depends_on_task_id
    FROM reach r
    JOIN task_dependencies d ON d.task_id = r.task_id
),
failures (check_name, record_id) AS (
    SELECT 'Timesheet on a weekend', timesheet_id
    FROM timesheets WHERE DAYOFWEEK(work_date) IN (1, 7)
    UNION ALL
    SELECT 'Single timesheet entry over 12 hours', timesheet_id
    FROM timesheets WHERE hours > 12
    UNION ALL
    SELECT 'Duplicate timesheet entry', MAX(timesheet_id)
    FROM timesheets GROUP BY employee_id, task_id, work_date HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'Time booked before task start', ts.timesheet_id
    FROM timesheets ts JOIN tasks t ON t.task_id = ts.task_id
    WHERE t.actual_start IS NULL OR ts.work_date < t.actual_start
    UNION ALL
    SELECT 'Time booked by non-assignee', ts.timesheet_id
    FROM timesheets ts JOIN tasks t ON t.task_id = ts.task_id
    WHERE ts.employee_id <> t.assignee_id
    UNION ALL
    SELECT 'Dependency violated (started before predecessor finished)', d.task_id
    FROM task_dependencies d
    JOIN tasks s ON s.task_id = d.task_id
    JOIN tasks p ON p.task_id = d.depends_on_task_id
    WHERE s.actual_start IS NOT NULL AND (p.actual_end IS NULL OR s.actual_start <= p.actual_end)
    UNION ALL
    SELECT 'Circular task dependency', origin
    FROM reach WHERE origin = task_id
    UNION ALL
    SELECT 'Done task with no timesheets', t.task_id
    FROM tasks t
    WHERE t.status = 'Done' AND NOT EXISTS (SELECT 1 FROM timesheets ts WHERE ts.task_id = t.task_id)
    UNION ALL
    SELECT 'Open risk on a closed project', r.risk_id
    FROM risks r JOIN projects p ON p.project_id = r.project_id
    WHERE r.status = 'Open' AND p.status IN ('Completed', 'Cancelled')
    UNION ALL
    SELECT 'Budget change not explained by approved CRs', p.project_id
    FROM projects p
    WHERE ABS((SELECT COALESCE(SUM(CAST(a.new_value AS DECIMAL(14,2)) - CAST(a.old_value AS DECIMAL(14,2))), 0)
               FROM audit_log a
               WHERE a.table_name = 'projects' AND a.field_name = 'approved_budget' AND a.record_id = p.project_id)
            - (SELECT COALESCE(SUM(c.cost_impact), 0)
               FROM change_requests c WHERE c.project_id = p.project_id AND c.status = 'Approved')) > 0.01
),
all_checks (check_name, severity, severity_order) AS (
    SELECT 'Timesheet on a weekend', 'Medium', 2 UNION ALL
    SELECT 'Single timesheet entry over 12 hours', 'High', 1 UNION ALL
    SELECT 'Duplicate timesheet entry', 'High', 1 UNION ALL
    SELECT 'Time booked before task start', 'High', 1 UNION ALL
    SELECT 'Time booked by non-assignee', 'Medium', 2 UNION ALL
    SELECT 'Dependency violated (started before predecessor finished)', 'High', 1 UNION ALL
    SELECT 'Circular task dependency', 'Critical', 0 UNION ALL
    SELECT 'Done task with no timesheets', 'Medium', 2 UNION ALL
    SELECT 'Open risk on a closed project', 'Low', 3 UNION ALL
    SELECT 'Budget change not explained by approved CRs', 'Critical', 0
)
SELECT ac.check_name,
       ac.severity,
       COUNT(f.record_id)                                           AS failing_records,
       CASE WHEN COUNT(f.record_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
       COALESCE(GROUP_CONCAT(f.record_id ORDER BY f.record_id SEPARATOR ', '), '') AS record_ids
FROM all_checks ac
LEFT JOIN failures f ON f.check_name = ac.check_name
GROUP BY ac.check_name, ac.severity, ac.severity_order
ORDER BY result, ac.severity_order;
