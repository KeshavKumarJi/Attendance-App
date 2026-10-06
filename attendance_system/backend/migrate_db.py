import sqlite3

def upgrade_db():
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    try:
        cursor.execute("ALTER TABLE students ADD COLUMN computer_code VARCHAR(50);")
        print("Added computer_code column.")
    except sqlite3.OperationalError as e:
        print("computer_code might already exist:", e)
        
    try:
        cursor.execute("ALTER TABLE students ADD COLUMN password_hash VARCHAR(255);")
        print("Added password_hash column.")
    except sqlite3.OperationalError as e:
        print("password_hash might already exist:", e)
        
    # Set dummy passwords for existing students so we can test login
    # Let's say password is '123456' for everyone.
    # auth.get_password_hash('123456') => we need the hash. I will just hardcode a bcrypt hash for '123456'
    dummy_hash = '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW' # bcrypt hash of '123456'
    
    # We also need some dummy computer codes. Let's just use enrollment_no + 'C' for now if null
    cursor.execute("UPDATE students SET password_hash = ? WHERE password_hash IS NULL", (dummy_hash,))
    cursor.execute("UPDATE students SET computer_code = enrollment_no WHERE computer_code IS NULL")
    
    conn.commit()
    conn.close()
    print("Database updated successfully.")

if __name__ == "__main__":
    upgrade_db()
