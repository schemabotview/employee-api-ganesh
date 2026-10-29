import os
import time
from contextlib import asynccontextmanager

import psycopg2
from fastapi import FastAPI, HTTPException
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel

SCHEMA = """
CREATE TABLE IF NOT EXISTS employees (
    id     SERIAL PRIMARY KEY,
    name   TEXT           NOT NULL,
    dept   TEXT           NOT NULL,
    salary NUMERIC(12, 2) NOT NULL
)
"""

SEED = [
    ("Ada Lovelace", "Engineering", 95000.00),
    ("Grace Hopper", "Engineering", 98000.00),
    ("Alan Turing", "Research", 91000.00),
]


def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        dbname=os.getenv("DB_NAME", "appdb"),
        user=os.getenv("DB_USER", "appuser"),
        password=os.getenv("DB_PASSWORD", "localpass"),
    )


def ensure_schema(attempts: int = 30, delay: int = 2) -> None:
    """Create the table and seed it, retrying while Postgres comes up.

    The same code path serves compose and ECS, where the database is a
    sidecar container that may still be starting.
    """
    for attempt in range(1, attempts + 1):
        try:
            with get_conn() as conn, conn.cursor() as cur:
                cur.execute(SCHEMA)
                cur.execute("SELECT count(*) FROM employees")
                if cur.fetchone()[0] == 0:
                    cur.executemany(
                        "INSERT INTO employees (name, dept, salary) VALUES (%s, %s, %s)",
                        SEED,
                    )
            print("schema ready")
            return
        except psycopg2.OperationalError as exc:
            print(f"database not ready (attempt {attempt}/{attempts}): {exc}".strip())
            time.sleep(delay)

    # Keep serving so /health still answers and the logs explain why
    # /employees does not.
    print("giving up on schema setup; /employees will fail until the database is reachable")


@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_schema()
    yield


app = FastAPI(title="Employee API", lifespan=lifespan)


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
        cur.execute("INSERT INTO employees (name, dept, salary) VALUES (%s, %s, %s) RETURNING *",
                            (emp.name, emp.dept, emp.salary * 12))
        return cur.fetchone()


@app.get("/employees/{emp_id}")
def get_employee(emp_id: int):
    with get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM employees WHERE id = %s", (emp_id,))
        row = cur.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Employee not found")
    return row
