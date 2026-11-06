-- Project health: cost and schedule performance (EVM)

USE pmo_portfolio;

WITH health AS (
    SELECT e.*,
           c.client_name,
           pm.full_name AS project_manager,
           CASE
               WHEN e.status IN ('Completed', 'Cancelled')
                   THEN DATEDIFF(p.actual_end, p.planned_end)
               ELSE CAST(ROUND((e.pv - e.ev)
                         / (e.bac / (DATEDIFF(p.planned_end, p.planned_start) + 1))) AS SIGNED)
           END AS days_late
    FROM v_project_evm e
    JOIN projects  p  ON p.project_id   = e.project_id
    JOIN clients   c  ON c.client_id    = p.client_id
    JOIN employees pm ON pm.employee_id = p.project_manager_id
    WHERE e.status <> 'Planned'
)
SELECT project_name,
       client_name,
       project_manager,
       status,
       cpi,
       spi,
       days_late,
       ROUND(bac, 0)                          AS budget_at_completion,
       ROUND(eac, 0)                          AS estimate_at_completion,
       ROUND(100.0 * (eac - bac) / bac, 1)    AS forecast_overrun_pct,
       ROUND(approved_budget - eac, 0)        AS headroom_vs_approved_budget,
       CASE
           WHEN cpi < 0.85 OR days_late > 20 THEN 'RED'
           WHEN cpi < 0.95 OR days_late > 7  THEN 'AMBER'
           ELSE 'GREEN'
       END                                    AS rag_status
FROM health
ORDER BY FIELD(status, 'Active', 'Cancelled', 'Completed'),
         CASE WHEN cpi < 0.85 OR days_late > 20 THEN 0 WHEN cpi < 0.95 OR days_late > 7 THEN 1 ELSE 2 END,
         cpi;
