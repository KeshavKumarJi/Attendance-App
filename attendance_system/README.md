# Class Attendance Management System

A complete full-stack Class Attendance Management System.

## Tech Stack
- **Database:** PostgreSQL
- **Backend:** FastAPI, SQLAlchemy, psycopg2
- **Frontend:** HTML, Vanilla JS, Tailwind CSS

## Prerequisites
- PostgreSQL running locally (default: `localhost:5432` with user `postgres` and password `postgres`)
- Python 3.8+

## Setup Instructions

### 1. Database Setup
Create the database in PostgreSQL:
```sql
CREATE DATABASE attendance_db;
```
Then execute the initial schema and seed data:
```bash
psql -U postgres -d attendance_db -f init.sql
```

### 2. Backend Setup
Navigate to the backend directory and install dependencies:
```bash
cd backend
pip install -r requirements.txt
```

Run the FastAPI server:
```bash
uvicorn main:app --reload
```
The API will be available at `http://localhost:8000`.

### 3. Frontend Setup
Simply open `frontend/index.html` in your web browser. Or use a local server:
```bash
cd frontend
python -m http.server 8080
```
Then navigate to `http://localhost:8080` in your browser.
