-- What drives cost overruns

USE pmo_portfolio;

WITH proj AS (
    SELECT e.project_id,
           CAST(e.methodology AS CHAR) AS methodology,
           CAST(p.priority AS CHAR)    AS priority,
           e.cpi,
           100.0 * (e.ac - e.bac) / e.bac AS overrun_pct,
           (SELECT COUNT(*) FROM change_requests c
             WHERE c.project_id = e.project_id AND c.status = 'Approved')                AS approved_crs,
           (SELECT COUNT(*) FROM risks r
             WHERE r.project_id = e.project_id AND r.status = 'Occurred' AND r.risk_score >= 12) AS major_risks_hit
    FROM v_project_evm e
    JOIN projects p ON p.project_id = e.project_id
    WHERE e.status = 'Completed'
),
segments AS (
    SELECT 'Methodology' AS factor, methodology AS segment, cpi, overrun_pct FROM proj
    UNION ALL
    SELECT 'Approved change requests',
           CASE WHEN approved_crs = 0 THEN '0 CRs' WHEN approved_crs <= 2 THEN '1-2 CRs' ELSE '3+ CRs' END,
           cpi, overrun_pct
    FROM proj
    UNION ALL
    SELECT 'Major risks that materialised',
           CASE WHEN major_risks_hit = 0 THEN 'None' ELSE '1 or more' END, cpi, overrun_pct
    FROM proj
    UNION ALL
    SELECT 'Priority', priority, cpi, overrun_pct FROM proj
)
SELECT factor,
       segment,
       COUNT(*)                                                         AS projects,
       ROUND(AVG(cpi), 3)                                               AS avg_cpi,
       ROUND(AVG(overrun_pct), 1)                                       AS avg_overrun_pct,
       ROUND(AVG(overrun_pct) - (SELECT AVG(overrun_pct) FROM proj), 1) AS vs_portfolio_pp
FROM segments
GROUP BY factor, segment
ORDER BY factor, avg_overrun_pct DESC;
