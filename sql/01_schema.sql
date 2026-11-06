CREATE DATABASE IF NOT EXISTS pmo_portfolio
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE pmo_portfolio;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS audit_log, change_requests, risks, sprints, timesheets,
                     task_dependencies, tasks, projects, clients, employees,
                     departments, report_params;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE report_params (
    param_key   VARCHAR(50)  PRIMARY KEY,
    param_value VARCHAR(100) NOT NULL
);

CREATE TABLE departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE employees (
    employee_id           INT PRIMARY KEY,
    full_name             VARCHAR(100)  NOT NULL,
    dept_id               INT           NOT NULL,
    job_title             VARCHAR(60)   NOT NULL,
    manager_id            INT           NULL,
    hourly_rate           DECIMAL(8,2)  NOT NULL CHECK (hourly_rate > 0),
    hire_date             DATE          NOT NULL,
    weekly_capacity_hours DECIMAL(4,1)  NOT NULL DEFAULT 40 CHECK (weekly_capacity_hours BETWEEN 0 AND 60),
    CONSTRAINT fk_emp_dept    FOREIGN KEY (dept_id)    REFERENCES departments(dept_id),
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

CREATE TABLE clients (
    client_id   INT PRIMARY KEY,
    client_name VARCHAR(100) NOT NULL UNIQUE,
    industry    VARCHAR(50)  NOT NULL,
    region      VARCHAR(50)  NOT NULL
);

CREATE TABLE projects (
    project_id         INT PRIMARY KEY,
    project_name       VARCHAR(100)   NOT NULL,
    client_id          INT            NOT NULL,
    project_manager_id INT            NOT NULL,
    methodology        ENUM('Agile','Waterfall','Hybrid')                  NOT NULL,
    priority           ENUM('Low','Medium','High','Critical')              NOT NULL,
    status             ENUM('Planned','Active','Completed','Cancelled')    NOT NULL,
    approved_budget    DECIMAL(12,2)  NOT NULL CHECK (approved_budget > 0),
    planned_start      DATE           NOT NULL,
    planned_end        DATE           NOT NULL,
    actual_start       DATE           NULL,
    actual_end         DATE           NULL,
    CONSTRAINT fk_proj_client FOREIGN KEY (client_id)          REFERENCES clients(client_id),
    CONSTRAINT fk_proj_pm     FOREIGN KEY (project_manager_id) REFERENCES employees(employee_id),
    CONSTRAINT chk_proj_planned CHECK (planned_end >= planned_start),
    CONSTRAINT chk_proj_actual  CHECK (actual_end IS NULL OR actual_end >= actual_start)
);

CREATE TABLE tasks (
    task_id          INT PRIMARY KEY,
    project_id       INT           NOT NULL,
    task_name        VARCHAR(100)  NOT NULL,
    phase            ENUM('Initiation','Planning','Design','Build','Test','Deploy','Closure') NOT NULL,
    assignee_id      INT           NOT NULL,
    estimated_hours  DECIMAL(7,1)  NOT NULL CHECK (estimated_hours > 0),
    planned_start    DATE          NOT NULL,
    planned_end      DATE          NOT NULL,
    actual_start     DATE          NULL,
    actual_end       DATE          NULL,
    status           ENUM('Not Started','In Progress','Done','Cancelled') NOT NULL,
    percent_complete TINYINT       NOT NULL DEFAULT 0 CHECK (percent_complete BETWEEN 0 AND 100),
    CONSTRAINT fk_task_project  FOREIGN KEY (project_id)  REFERENCES projects(project_id),
    CONSTRAINT fk_task_assignee FOREIGN KEY (assignee_id) REFERENCES employees(employee_id),
    CONSTRAINT chk_task_planned CHECK (planned_end >= planned_start),
    CONSTRAINT chk_task_actual  CHECK (actual_end IS NULL OR actual_end >= actual_start),
    CONSTRAINT chk_task_done    CHECK (status <> 'Done' OR (percent_complete = 100 AND actual_end IS NOT NULL))
);

CREATE TABLE task_dependencies (
    task_id            INT NOT NULL,
    depends_on_task_id INT NOT NULL,
    PRIMARY KEY (task_id, depends_on_task_id),
    CONSTRAINT fk_dep_task FOREIGN KEY (task_id)            REFERENCES tasks(task_id),
    CONSTRAINT fk_dep_pred FOREIGN KEY (depends_on_task_id) REFERENCES tasks(task_id),
    CONSTRAINT chk_dep_self CHECK (task_id <> depends_on_task_id)
);

CREATE TABLE timesheets (
    timesheet_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id  INT          NOT NULL,
    task_id      INT          NOT NULL,
    work_date    DATE         NOT NULL,
    hours        DECIMAL(4,1) NOT NULL CHECK (hours > 0 AND hours <= 24),
    CONSTRAINT fk_ts_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT fk_ts_task     FOREIGN KEY (task_id)     REFERENCES tasks(task_id)
);

CREATE TABLE sprints (
    sprint_id        INT PRIMARY KEY AUTO_INCREMENT,
    project_id       INT  NOT NULL,
    sprint_number    INT  NOT NULL,
    start_date       DATE NOT NULL,
    end_date         DATE NOT NULL,
    committed_points INT  NOT NULL CHECK (committed_points >= 0),
    completed_points INT  NOT NULL CHECK (completed_points >= 0),
    UNIQUE KEY uq_sprint (project_id, sprint_number),
    CONSTRAINT fk_sprint_project FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

CREATE TABLE risks (
    risk_id         INT PRIMARY KEY AUTO_INCREMENT,
    project_id      INT          NOT NULL,
    category        ENUM('Technical','Resource','Schedule','Budget','Vendor','Scope','Compliance') NOT NULL,
    description     VARCHAR(200) NOT NULL,
    probability     TINYINT      NOT NULL CHECK (probability BETWEEN 1 AND 5),
    impact          TINYINT      NOT NULL CHECK (impact BETWEEN 1 AND 5),
    risk_score      TINYINT      AS (probability * impact) STORED,
    status          ENUM('Open','Mitigated','Closed','Occurred') NOT NULL,
    owner_id        INT          NOT NULL,
    identified_date DATE         NOT NULL,
    closed_date     DATE         NULL,
    CONSTRAINT fk_risk_project FOREIGN KEY (project_id) REFERENCES projects(project_id),
    CONSTRAINT fk_risk_owner   FOREIGN KEY (owner_id)   REFERENCES employees(employee_id)
);

CREATE TABLE change_requests (
    cr_id                INT PRIMARY KEY AUTO_INCREMENT,
    project_id           INT           NOT NULL,
    title                VARCHAR(100)  NOT NULL,
    requested_date       DATE          NOT NULL,
    cost_impact          DECIMAL(12,2) NOT NULL,
    schedule_impact_days INT           NOT NULL,
    status               ENUM('Pending','Approved','Rejected') NOT NULL,
    CONSTRAINT fk_cr_project FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

CREATE TABLE audit_log (
    audit_id   INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(50) NOT NULL,
    record_id  INT         NOT NULL,
    field_name VARCHAR(50) NOT NULL,
    old_value  VARCHAR(100),
    new_value  VARCHAR(100),
    changed_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_timesheets_emp_date ON timesheets(employee_id, work_date);
CREATE INDEX ix_timesheets_task_date ON timesheets(task_id, work_date);
CREATE INDEX ix_tasks_project_end   ON tasks(project_id, planned_end);
CREATE INDEX ix_risks_project_status ON risks(project_id, status);
CREATE INDEX ix_cr_project_status   ON change_requests(project_id, status);
