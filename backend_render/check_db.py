from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    res = conn.execute(text("SELECT computer_code, enrollment_no, password_hash FROM students")).fetchall()
    print("Students:", res)
