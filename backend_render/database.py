import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))

raw_url = os.environ.get("DATABASE_URL", "postgresql+psycopg2://postgres:kk335073@localhost:5432/attendance_db")
if "://" in raw_url:
    raw_url = "postgresql+psycopg2://" + raw_url.split("://", 1)[1]
SQLALCHEMY_DATABASE_URL = raw_url

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
