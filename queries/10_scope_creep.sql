-- Scope creep from approved change requests

USE pmo_portfolio;

WITH approved AS (
    SELECT c.project_id,
           c.requested_date,
           c.cost_impact,
           SUM(c.cost_impact) OVER (PARTITION BY c.project_id
                                    ORDER BY c.requested_date, c.cr_id) AS running_cr_cost
    FROM change_requests c
    WHERE c.status = 'Approved'
),
cr_summary AS (
    SELECT project_id,
           COUNT(*)                                            AS crs_raised,
           SUM(status = 'Approved')                            AS crs_approved,
           SUM(status = 'Pending')                             AS crs_pending,
           SUM(CASE WHEN status = 'Approved' THEN cost_impact ELSE 0 END) AS approved_cr_cost
    FROM change_requests
    GROUP BY project_id
),
per_project AS (
    SELECT p.project_id,
           p.project_name,
           cl.client_name,
           p.approved_budget - cs.approved_cr_cost AS original_budget,
           cs.crs_raised,
           cs.crs_approved,
           cs.crs_pending,
           cs.approved_cr_cost
    FROM projects p
    JOIN clients    cl ON cl.client_id  = p.client_id
    JOIN cr_summary cs ON cs.project_id = p.project_id
)
SELECT pp.project_name,
       pp.client_name,
       pp.crs_raised,
       pp.crs_approved,
       pp.crs_pending,
       ROUND(pp.original_budget, 0)                                AS original_budget,
       ROUND(pp.approved_cr_cost, 0)                               AS approved_cr_cost,
       ROUND(100.0 * pp.approved_cr_cost / pp.original_budget, 1)  AS scope_growth_pct,
       (SELECT MIN(a.requested_date) FROM approved a
         WHERE a.project_id = pp.project_id
           AND a.running_cr_cost > 0.10 * pp.original_budget)      AS crossed_10pct_on,
       DENSE_RANK() OVER (ORDER BY pp.approved_cr_cost / pp.original_budget DESC) AS creep_rank
FROM per_project pp
ORDER BY creep_rank;
