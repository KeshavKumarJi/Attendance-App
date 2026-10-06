from database import engine
from sqlalchemy import text

with engine.begin() as conn:
    conn.execute(text("UPDATE students SET password_hash = '$2b$12$ofEl.P2WFLRwCBiDkp30B.25LrmmrKzg6Ve7KqBv2ro2CBZ91yIKe'"))
print("Hashes updated successfully")
