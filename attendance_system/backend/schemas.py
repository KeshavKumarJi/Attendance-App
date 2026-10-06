from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import date, time, datetime

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class TeacherResponse(BaseModel):
    id: int
    name: str
    username: str
    model_config = ConfigDict(from_attributes=True)

class SectionResponse(BaseModel):
    id: int
    name: str
    model_config = ConfigDict(from_attributes=True)

class StudentResponse(BaseModel):
    id: int
    computer_code: Optional[str] = None
    enrollment_no: str
    name: str
    batch: str
    model_config = ConfigDict(from_attributes=True)

class StudentLoginRequest(BaseModel):
    computer_code: str
    password: str

class AttendanceRecordCreate(BaseModel):
    student_id: int
    status: str

class AttendanceSessionCreate(BaseModel):
    section_id: int
    batch_type: str
    date: date
    start_time: time
    end_time: time
    records: List[AttendanceRecordCreate]

class AttendanceRecordResponse(BaseModel):
    student: StudentResponse
    status: str
    model_config = ConfigDict(from_attributes=True)

class AttendanceSessionResponse(BaseModel):
    id: int
    teacher: TeacherResponse
    section: SectionResponse
    batch_type: str
    date: date
    start_time: time
    end_time: time
    updated_at: datetime
    records: List[AttendanceRecordResponse] = []
    model_config = ConfigDict(from_attributes=True)

class ReportStudent(BaseModel):
    enrollment_no: str
    name: str
    classes_attended: int
    total_classes: int
    percentage: float

class StudentMarkRequest(BaseModel):
    enrollment_no: str
    token: str
    face_encoding: Optional[List[float]] = None

class AutoSessionCreate(BaseModel):
    section_id: int
    batch_type: str
    date: date
    start_time: time
    end_time: time
