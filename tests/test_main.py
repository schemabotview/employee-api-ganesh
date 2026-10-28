import pytest
from fastapi.testclient import TestClient

import main


class FakeDatabase:
    def __init__(self):
        self.rows = [{"id": 1, "name": "Priya Sharma", "dept": "IT", "salary": 55000.0}]


class FakeCursor:
    def __init__(self, db):
        self.db = db
        self.result = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, sql, params=None):
        if sql.strip().upper().startswith("SELECT"):
            self.result = list(self.db.rows)
        elif sql.strip().upper().startswith("INSERT"):
            name, dept, salary = params
            row = {"id": len(self.db.rows) + 1, "name": name, "dept": dept, "salary": salary}
            self.db.rows.append(row)
            self.result = [row]

    def fetchall(self):
        return self.result

    def fetchone(self):
        return self.result[0] if self.result else None


class FakeConnection:
    def __init__(self, db):
        self.db = db

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def cursor(self, cursor_factory=None):
        return FakeCursor(self.db)


@pytest.fixture
def client(monkeypatch):
    db = FakeDatabase()
    monkeypatch.setattr(main, "get_conn", lambda: FakeConnection(db))
    return TestClient(main.app)

def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_get_employees(client):
    response = client.get("/employees")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Priya Sharma"


def test_add_employee(client):
    new = {"name": "Ana Lopez", "dept": "Data", "salary": 60000}
    response = client.post("/employees", json=new)
    assert response.status_code == 200
    assert response.json()["id"] == 2
    assert response.json()["salary"] == 60000

    all_rows = client.get("/employees").json()
    assert len(all_rows) == 2


def test_add_employee_missing_field(client):
    response = client.post("/employees", json={"name": "No Dept"})
    assert response.status_code == 422


def test_add_employee_bad_salary(client):
    response = client.post("/employees", json={"name": "Bad", "dept": "IT", "salary": "lots"})
    assert response.status_code == 422
