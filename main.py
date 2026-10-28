import os

import psycopg2
from fastapi import FastAPI, HTTPException
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel

app = FastAPI(title="Employee API")


def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        dbname=os.getenv("DB_NAME", "appdb"),
        user=os.getenv("DB_USER", "appuser"),
        password=os.getenv("DB_PASSWORD", "localpass"),
    )


class Employee(BaseModel):
    name: str
    dept: str
    salary: float


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/employees")
def get_employees():
    with get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM employees ORDER BY id")
        return cur.fetchall()


@app.post("/employees")
def add_employee(emp: Employee):
    with get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "INSERT INTO employees (name, dept, salary) VALUES (%s, %s, %s) RETURNING *",
            (emp.name, emp.dept, emp.salary),
        )
        return cur.fetchone()


@app.get("/employees/{emp_id}")
def get_employee(emp_id: int):
    with get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM employees WHERE id = %s", (emp_id,))
        row = cur.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Employee not found")
    return row
