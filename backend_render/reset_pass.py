import os
from sqlalchemy import create_engine, text
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
new_hash = pwd_context.hash('password')

engine = create_engine("postgresql://postgres:kk335073@localhost:5432/attendance_db")
with engine.connect() as conn:
    conn.execute(text(f"UPDATE teachers SET password_hash = '{new_hash}'"))
    conn.commit()

print("Passwords reset successfully!")
