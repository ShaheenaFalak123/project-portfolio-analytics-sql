-- Correlation of each driver with cost overrun

USE pmo_portfolio;

WITH proj AS (
    SELECT e.project_id,
           100.0 * (e.ac - e.bac) / e.bac AS overrun_pct,
           (SELECT COUNT(*) FROM change_requests c WHERE c.project_id = e.project_id AND c.status = 'Approved') AS approved_crs,
           (SELECT COALESCE(SUM(c.cost_impact), 0) FROM change_requests c
             WHERE c.project_id = e.project_id AND c.status = 'Approved') * 100.0 / e.bac               AS cr_cost_pct,
           (SELECT COUNT(*) FROM risks r WHERE r.project_id = e.project_id AND r.status = 'Occurred')    AS risks_occurred,
           (SELECT AVG(r.risk_score) FROM risks r WHERE r.project_id = e.project_id)                     AS avg_risk_score,
           (SELECT COUNT(*) FROM tasks t WHERE t.project_id = e.project_id)                              AS task_count,
           CASE WHEN e.methodology = 'Waterfall' THEN 1 ELSE 0 END                                       AS is_waterfall
    FROM v_project_evm e
    WHERE e.status = 'Completed'
),
pairs (driver, x, y) AS (
    SELECT 'Approved change requests (count)',   approved_crs,   overrun_pct FROM proj UNION ALL
    SELECT 'Approved CR cost (% of budget)',     cr_cost_pct,    overrun_pct FROM proj UNION ALL
    SELECT 'Risks that occurred (count)',        risks_occurred, overrun_pct FROM proj UNION ALL
    SELECT 'Average risk score',                 avg_risk_score, overrun_pct FROM proj UNION ALL
    SELECT 'Waterfall methodology (1/0)',        is_waterfall,   overrun_pct FROM proj UNION ALL
    SELECT 'Project size (task count)',          task_count,     overrun_pct FROM proj
),
sums AS (
    SELECT driver,
           COUNT(*) AS n, SUM(x) AS sx, SUM(y) AS sy,
           SUM(x * x) AS sxx, SUM(y * y) AS syy, SUM(x * y) AS sxy
    FROM pairs
    GROUP BY driver
),
correlation AS (
    SELECT driver, n,
           (n * sxy - sx * sy) / SQRT((n * sxx - sx * sx) * (n * syy - sy * sy)) AS pearson_r
    FROM sums
)
SELECT driver,
       n                   AS projects,
       ROUND(pearson_r, 3) AS pearson_r,
       CASE
           WHEN ABS(pearson_r) >= 0.5 THEN 'Strong'
           WHEN ABS(pearson_r) >= 0.3 THEN 'Moderate'
           ELSE 'Weak'
       END                 AS strength
FROM correlation
ORDER BY ABS(pearson_r) DESC;
