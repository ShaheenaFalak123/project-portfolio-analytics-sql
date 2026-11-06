-- Employees overloaded several weeks in a row

USE pmo_portfolio;

WITH weekly AS (
    SELECT employee_id,
           week_start,
           hours_logged,
           capacity,
           TO_DAYS(week_start) DIV 7 AS week_no
    FROM v_employee_weekly_load
),
overloaded AS (
    SELECT w.*,
           CAST(week_no AS SIGNED)
             - CAST(ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY week_no) AS SIGNED) AS island_id
    FROM weekly w
    WHERE hours_logged > capacity * 1.125
),
streaks AS (
    SELECT employee_id,
           island_id,
           MIN(week_start)                          AS streak_start,
           DATE_ADD(MAX(week_start), INTERVAL 6 DAY) AS streak_end,
           COUNT(*)                                 AS weeks,
           ROUND(AVG(hours_logged), 1)              AS avg_hours,
           MAX(hours_logged)                        AS peak_hours
    FROM overloaded
    GROUP BY employee_id, island_id
),
ranked AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY weeks DESC, streak_start DESC) AS rn,
           SUM(weeks)   OVER (PARTITION BY employee_id) AS total_overloaded_weeks,
           COUNT(*)     OVER (PARTITION BY employee_id) AS streak_count
    FROM streaks s
)
SELECT e.full_name,
       e.job_title,
       d.dept_name,
       e.weekly_capacity_hours           AS capacity,
       r.total_overloaded_weeks,
       r.streak_count,
       r.weeks                           AS longest_streak_weeks,
       r.streak_start,
       r.streak_end,
       r.avg_hours                       AS avg_hours_in_streak,
       r.peak_hours                      AS peak_week_hours
FROM ranked r
JOIN employees   e ON e.employee_id = r.employee_id
JOIN departments d ON d.dept_id     = e.dept_id
WHERE r.rn = 1
  AND r.weeks >= 2
ORDER BY r.weeks DESC, r.total_overloaded_weeks DESC;
