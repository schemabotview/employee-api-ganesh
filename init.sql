CREATE TABLE IF NOT EXISTS employees (
    id     SERIAL PRIMARY KEY,
    name   TEXT           NOT NULL,
    dept   TEXT           NOT NULL,
    salary NUMERIC(12, 2) NOT NULL
);

INSERT INTO employees (name, dept, salary) VALUES
    ('Ada Lovelace',   'Engineering', 95000.00),
    ('Grace Hopper',   'Engineering', 98000.00),
    ('Alan Turing',    'Research',    91000.00)
ON CONFLICT DO NOTHING;
