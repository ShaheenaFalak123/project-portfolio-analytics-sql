-- Sprint velocity and predictability

USE pmo_portfolio;

WITH s AS (
    SELECT sp.*,
           1.0 * completed_points / NULLIF(committed_points, 0)                     AS say_do,
           AVG(completed_points) OVER w3                                             AS rolling_3_velocity,
           completed_points - LAG(completed_points) OVER w                           AS velocity_change,
           ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY sprint_number DESC)   AS rn_desc
    FROM sprints sp
    WINDOW w  AS (PARTITION BY project_id ORDER BY sprint_number),
           w3 AS (PARTITION BY project_id ORDER BY sprint_number ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
)
SELECT p.project_name,
       p.status,
       COUNT(*)                                                             AS sprints,
       ROUND(AVG(s.completed_points), 1)                                    AS avg_velocity,
       ROUND(MAX(CASE WHEN s.rn_desc = 1 THEN s.rolling_3_velocity END), 1) AS latest_rolling_3_velocity,
       ROUND(100 * AVG(s.say_do), 0)                                        AS say_do_pct,
       ROUND(100 * AVG(CASE WHEN s.sprint_number <= 3 THEN s.say_do END), 0) AS first_3_sprints_say_do_pct,
       ROUND(100 * AVG(CASE WHEN s.rn_desc <= 3       THEN s.say_do END), 0) AS last_3_sprints_say_do_pct,
       SUM(s.velocity_change < 0)                                           AS sprints_with_velocity_drop,
       CASE
           WHEN AVG(s.say_do) < 0.75 THEN 'Over-committing'
           WHEN AVG(CASE WHEN s.rn_desc <= 3 THEN s.say_do END)
              > AVG(CASE WHEN s.sprint_number <= 3 THEN s.say_do END) + 0.05 THEN 'Improving'
           ELSE 'Stable'
       END                                                                  AS assessment
FROM s
JOIN projects p ON p.project_id = s.project_id
GROUP BY p.project_id, p.project_name, p.status
HAVING COUNT(*) >= 4
ORDER BY say_do_pct;
