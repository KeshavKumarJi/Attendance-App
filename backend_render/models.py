from sqlalchemy import Column, Integer, String, Date, ForeignKey, DateTime, UniqueConstraint, func, Time, Boolean, JSON
from sqlalchemy.orm import relationship
from database import Base

class Teacher(Base):
    __tablename__ = "teachers"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    username = Column(String(50), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    sessions = relationship("AttendanceSession", back_populates="teacher")

class Section(Base):
    __tablename__ = "sections"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False)
    students = relationship("Student", back_populates="section")
    sessions = relationship("AttendanceSession", back_populates="section")

class Student(Base):
    __tablename__ = "students"
    id = Column(Integer, primary_key=True, index=True)
    computer_code = Column(String(50), unique=True, nullable=True) # Added for login
    enrollment_no = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=True) # Added for login
    name = Column(String(100), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="CASCADE"), nullable=False)
    batch = Column(String(10), nullable=False) # 'A' or 'B'
    face_registered = Column(Boolean, default=False)
    face_encoding = Column(JSON, nullable=True)
    section = relationship("Section", back_populates="students")
    attendance_records = relationship("AttendanceRecord", back_populates="student")

class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"
    id = Column(Integer, primary_key=True, index=True)
    teacher_id = Column(Integer, ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False)
    section_id = Column(Integer, ForeignKey("sections.id", ondelete="CASCADE"), nullable=False)
    batch_type = Column(String(10), nullable=False) # 'A', 'B', or 'BOTH'
    date = Column(Date, nullable=False, server_default=func.current_date())
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    teacher = relationship("Teacher", back_populates="sessions")
    section = relationship("Section", back_populates="sessions")
    records = relationship("AttendanceRecord", back_populates="session", cascade="all, delete-orphan")

class AttendanceRecord(Base):
    __tablename__ = "attendance_records"
    __table_args__ = (UniqueConstraint('session_id', 'student_id', name='_session_student_uc'),)
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("attendance_sessions.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(10), nullable=False) # 'PRESENT', 'ABSENT', 'LEAVE'
    session = relationship("AttendanceSession", back_populates="records")
    student = relationship("Student", back_populates="attendance_records")
