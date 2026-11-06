USE pmo_portfolio;

DROP TRIGGER IF EXISTS trg_projects_audit;
DROP TRIGGER IF EXISTS trg_timesheets_block_closed_projects;
DROP TRIGGER IF EXISTS trg_cr_approved_updates_budget;

DELIMITER $$

CREATE TRIGGER trg_projects_audit
AFTER UPDATE ON projects
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO audit_log (table_name, record_id, field_name, old_value, new_value)
        VALUES ('projects', NEW.project_id, 'status', OLD.status, NEW.status);
    END IF;
    IF NOT (OLD.approved_budget <=> NEW.approved_budget) THEN
        INSERT INTO audit_log (table_name, record_id, field_name, old_value, new_value)
        VALUES ('projects', NEW.project_id, 'approved_budget', OLD.approved_budget, NEW.approved_budget);
    END IF;
END$$

CREATE TRIGGER trg_timesheets_block_closed_projects
BEFORE INSERT ON timesheets
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM tasks t
        JOIN projects p ON p.project_id = t.project_id
        WHERE t.task_id = NEW.task_id
          AND p.status IN ('Completed', 'Cancelled')
          AND NEW.work_date > p.actual_end
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot book time to a closed project after its end date';
    END IF;
END$$

CREATE TRIGGER trg_cr_approved_updates_budget
AFTER UPDATE ON change_requests
FOR EACH ROW
BEGIN
    IF NEW.status = 'Approved' AND OLD.status <> 'Approved' THEN
        UPDATE projects
        SET approved_budget = approved_budget + NEW.cost_impact
        WHERE project_id = NEW.project_id;
    END IF;
END$$

DELIMITER ;
