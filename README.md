# Project Portfolio Analytics in MySQL

After finishing the Google Project Management certificate and an SQL bootcamp, I wanted a project that used both. So I made a MySQL database for a made-up IT consulting company that runs a lot of projects at once, and wrote queries to answer the kind of questions a PMO or delivery manager would ask every week. Are we over budget? Which projects are running late and why? Is anyone on the team being overworked?

## The data

The company is fictional and so is all the data. It has 42 employees, 14 clients and 60 projects. Some projects are finished, some are in progress and some haven't started yet. Altogether there are around 1,000 tasks, 8,000 timesheet entries, 300 risks, 145 change requests and 159 sprints for the Agile projects. I used 30 September 2026 as the "today" date for all the reports.

## How the database is set up

There are 12 tables, counting a small settings table that holds the report date. Projects belong to clients and are split into tasks, and tasks can depend on other tasks (task B can't start until task A is finished). Employees log their hours against tasks in the timesheets table. Each project also has its own risks, change requests and, if it's Agile, sprints. The employees table points to itself through `manager_id`, which is how the org chart is stored.

A few things I added to keep the data correct:

- `CHECK` constraints and `ENUM` columns, so you can't enter something like a risk probability of 7 or a made-up project status
- a trigger that stops anyone booking hours to a project after it's closed
- a trigger that raises the project budget when a change request gets approved
- a trigger that writes to `audit_log` whenever a project's status or budget changes

I also made views for the Earned Value numbers (planned value, earned value, actual cost, CPI and SPI). That way I only had to write those formulas once and could reuse them in the other queries.

## The queries

Each file in `queries/` answers one question:

1. Which projects are over budget or behind schedule?
2. Which phases of a project slip the most, and is Agile better than Waterfall?
3. What is the critical path for each open project?
4. Who has been working over capacity several weeks in a row?
5. How busy is each team, and how much idle time are we paying for?
6. Risk heat map (probability vs impact)
7. What is causing cost overruns?
8. How strongly is each of those causes linked to overruns (correlation)?
9. Are the Agile teams delivering what they commit to in each sprint?
10. Which projects had the most scope creep?
11. How do the project managers compare?
12. Month by month, are we spending more than planned?
13. How big is each manager's team, and what does it cost?
14. Data quality checks

The ones I learned the most from were 3, 4 and 14. The critical path query uses a recursive CTE to walk backwards through the task dependencies. Query 4 uses the "gaps and islands" trick with `ROW_NUMBER()` to find weeks in a row of overtime. The data quality query runs 10 checks, and one of them uses recursion to look for circular task dependencies. MySQL doesn't have a median function, so in query 2 I worked the median and 90th percentile out with window functions.

## What I found

- Risks mattered the most. Projects where a major risk actually happened went 20% over budget on average. Projects where none did were less than 2% over.
- Projects with no approved change requests finished about 7% under budget. Projects with change requests finished 8-10% over. My guess is the budgets were increased but the task plans never were.
- Waterfall projects went over budget by almost 10% on average. Agile projects were under 1% over.
- Delays build up as a project goes on. The worst 10% of tasks were 13 days late in the first phase but 28 days late by the last one.
- One senior engineer was over capacity in 30 different weeks, including 6 weeks in a row at about 53 hours a week. That's the kind of thing that ends with someone resigning.
- The best project manager finished every project on time with a CPI of 1.11. The weakest averaged 16 days late with a CPI of 0.86.
- The data wasn't clean. The checks found 18 bad timesheet records, including entries on weekends, duplicates, one 16-hour entry that looks like a typo and hours booked before the task had even started.

## Running it

You need MySQL 8. In MySQL Workbench, open and run the four files in `sql/` in order (01 to 04). This creates the `pmo_portfolio` database with all the data in it. After that you can open and run any file from `queries/`.

---

Shaheena Falak

My certificates: [SQL Bootcamp (Packt / Coursera)](https://coursera.org/verify/KTCO9ZLWPLKD) and [Google Project Management](https://coursera.org/verify/professional-cert/M1D03TXBMOT5)
