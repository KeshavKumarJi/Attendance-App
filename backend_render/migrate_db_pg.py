from database import engine, SessionLocal
from sqlalchemy import text

def upgrade_db():
    with engine.begin() as conn:
        try:
            conn.execute(text("ALTER TABLE students ADD COLUMN computer_code VARCHAR(50);"))
            print("Added computer_code column.")
        except Exception as e:
            print("computer_code might already exist:", e)
            
        try:
            conn.execute(text("ALTER TABLE students ADD COLUMN password_hash VARCHAR(255);"))
            print("Added password_hash column.")
        except Exception as e:
            print("password_hash might already exist:", e)
            
        try:
            conn.execute(text("ALTER TABLE students ADD CONSTRAINT students_computer_code_key UNIQUE (computer_code);"))
            print("Added unique constraint to computer_code.")
        except Exception as e:
            print("Unique constraint might already exist:", e)

    # Set dummy passwords for existing students so we can test login
    dummy_hash = '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW' # bcrypt hash of '123456'
    
    with engine.begin() as conn:
        conn.execute(text("UPDATE students SET password_hash = :hash WHERE password_hash IS NULL"), {"hash": dummy_hash})
        conn.execute(text("UPDATE students SET computer_code = enrollment_no WHERE computer_code IS NULL"))
        
    print("Database updated successfully.")

if __name__ == "__main__":
    upgrade_db()
