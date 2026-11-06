-- Risk heat map (probability x impact)

USE pmo_portfolio;

WITH probability_levels (probability, label) AS (
    SELECT 5, '5 - Almost certain' UNION ALL
    SELECT 4, '4 - Likely'         UNION ALL
    SELECT 3, '3 - Possible'       UNION ALL
    SELECT 2, '2 - Unlikely'       UNION ALL
    SELECT 1, '1 - Rare'
)
SELECT pl.label                                            AS probability,
       SUM(CASE WHEN r.impact = 1 THEN 1 ELSE 0 END)       AS impact_1_minimal,
       SUM(CASE WHEN r.impact = 2 THEN 1 ELSE 0 END)       AS impact_2_minor,
       SUM(CASE WHEN r.impact = 3 THEN 1 ELSE 0 END)       AS impact_3_moderate,
       SUM(CASE WHEN r.impact = 4 THEN 1 ELSE 0 END)       AS impact_4_major,
       SUM(CASE WHEN r.impact = 5 THEN 1 ELSE 0 END)       AS impact_5_severe,
       COUNT(r.risk_id)                                    AS total_risks,
       SUM(CASE WHEN r.risk_score >= 15 THEN 1 ELSE 0 END) AS red_zone,
       SUM(CASE WHEN r.status = 'Occurred' THEN 1 ELSE 0 END) AS materialised
FROM probability_levels pl
LEFT JOIN risks r ON r.probability = pl.probability
GROUP BY pl.probability, pl.label
ORDER BY pl.probability DESC;
