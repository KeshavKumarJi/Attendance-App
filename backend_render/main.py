from fastapi import FastAPI, Depends, HTTPException, status, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, timedelta
import models, schemas, database, auth
from ble_engine import ble_service
# import numpy as np
from fastapi import File, UploadFile
import os
import shutil
# from deepface import DeepFace

# def find_cosine_distance(source_representation, test_representation):
#     a = np.matmul(np.transpose(source_representation), test_representation)
#     b = np.sum(np.multiply(source_representation, source_representation))
#     c = np.sum(np.multiply(test_representation, test_representation))
#     return 1 - (a / (np.sqrt(b) * np.sqrt(c)))

# Create all database tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Class Attendance Management System")

@app.on_event("startup")
def seed_database():
    db = database.SessionLocal()
    try:
        # Check if any teacher exists
        if not db.query(models.Teacher).first():
            # Create default admin teacher
            hashed_password = auth.get_password_hash("admin123")
            admin = models.Teacher(name="Admin Teacher", username="admin", password_hash=hashed_password)
            db.add(admin)
            
            # Create a default section just in case
            if not db.query(models.Section).first():
                section = models.Section(name="CSE - A")
                db.add(section)
                
            db.commit()
            print("Database seeded with default admin teacher!")
    except Exception as e:
        print("Error seeding database:", e)
    finally:
        db.close()


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/api/auth/login", response_model=schemas.Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    teacher = db.query(models.Teacher).filter(models.Teacher.username == form_data.username).first()
    if not teacher or not auth.verify_password(form_data.password, teacher.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = auth.create_access_token(data={"sub": teacher.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/api/auth/student/login")
def student_login(payload: schemas.StudentLoginRequest, db: Session = Depends(database.get_db)):
    student = db.query(models.Student).filter(models.Student.computer_code == payload.computer_code).first()
    if not student or not auth.verify_password(payload.password, student.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect computer code or password"
        )
    
    # Optional: return a JWT token or just return student data since this might be a simpler app
    # For now, we will return the student details and a success message.
    return {
        "message": "Login successful",
        "student": {
            "id": student.id,
            "computer_code": student.computer_code,
            "enrollment_no": student.enrollment_no,
            "name": student.name,
            "face_registered": student.face_registered
        }
    }

@app.get("/api/me", response_model=schemas.TeacherResponse)
def read_users_me(current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    return current_teacher

@app.get("/api/sections", response_model=list[schemas.SectionResponse])
def get_sections(db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    return db.query(models.Section).all()

@app.get("/api/sections/{section_id}/students", response_model=list[schemas.StudentResponse])
def get_students(section_id: int, batch: str = "BOTH", db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    query = db.query(models.Student).filter(models.Student.section_id == section_id)
    if batch in ["A", "B"]:
        query = query.filter(models.Student.batch == batch)
    return query.order_by(models.Student.enrollment_no).all()

@app.post("/api/attendance/session", response_model=schemas.AttendanceSessionResponse)
def submit_attendance(payload: schemas.AttendanceSessionCreate, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    overlap = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.teacher_id == current_teacher.id,
        models.AttendanceSession.date == payload.date,
        models.AttendanceSession.start_time < payload.end_time,
        models.AttendanceSession.end_time > payload.start_time
    ).first()
    
    if overlap:
        raise HTTPException(status_code=400, detail="Overlapping session exists for this teacher.")

    session = models.AttendanceSession(
        teacher_id=current_teacher.id,
        section_id=payload.section_id,
        batch_type=payload.batch_type,
        date=payload.date,
        start_time=payload.start_time,
        end_time=payload.end_time
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    
    for rec in payload.records:
        if rec.status not in ('PRESENT', 'ABSENT', 'LEAVE'):
            db.rollback()
            raise HTTPException(status_code=400, detail=f"Invalid status: {rec.status}")
        ar = models.AttendanceRecord(session_id=session.id, student_id=rec.student_id, status=rec.status)
        db.add(ar)
    db.commit()
    db.refresh(session)
    return session

@app.put("/api/attendance/session/{session_id}", response_model=schemas.AttendanceSessionResponse)
def update_attendance(session_id: int, payload: schemas.AttendanceSessionCreate, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    session = db.query(models.AttendanceSession).filter(models.AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this session")
        
    session.date = payload.date
    session.start_time = payload.start_time
    session.end_time = payload.end_time
    
    db.query(models.AttendanceRecord).filter(models.AttendanceRecord.session_id == session_id).delete()
    
    for rec in payload.records:
        ar = models.AttendanceRecord(session_id=session.id, student_id=rec.student_id, status=rec.status)
        db.add(ar)
    db.commit()
    db.refresh(session)
    return session

@app.get("/api/attendance/sessions", response_model=list[schemas.AttendanceSessionResponse])
def get_sessions(query_date: date = None, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    if not query_date:
        query_date = date.today()
    return db.query(models.AttendanceSession).filter(
        models.AttendanceSession.date == query_date,
        models.AttendanceSession.teacher_id == current_teacher.id
    ).order_by(models.AttendanceSession.start_time.desc()).all()

@app.get("/api/reports/percentages", response_model=list[schemas.ReportStudent])
def get_reports(section_id: int, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    total_sessions = db.query(func.count(models.AttendanceSession.id)).filter(models.AttendanceSession.section_id == section_id).scalar() or 0
    
    students = db.query(models.Student).filter(models.Student.section_id == section_id).all()
    results = []
    
    for s in students:
        present_count = db.query(func.count(models.AttendanceRecord.id)).join(models.AttendanceSession).filter(
            models.AttendanceRecord.student_id == s.id,
            models.AttendanceSession.section_id == section_id,
            models.AttendanceRecord.status == 'PRESENT'
        ).scalar() or 0
        
        pct = (present_count / total_sessions * 100) if total_sessions > 0 else 0
        
        results.append({
            "enrollment_no": s.enrollment_no,
            "name": s.name,
            "classes_attended": present_count,
            "total_classes": total_sessions,
            "percentage": round(pct, 2)
        })
    return sorted(results, key=lambda x: x["percentage"], reverse=True)

@app.post("/api/attendance/auto_session")
def start_auto_session(payload: schemas.AutoSessionCreate, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    overlap = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.teacher_id == current_teacher.id,
        models.AttendanceSession.date == payload.date,
        models.AttendanceSession.start_time < payload.end_time,
        models.AttendanceSession.end_time > payload.start_time
    ).first()
    
    if overlap:
        raise HTTPException(status_code=400, detail="Overlapping session exists.")

    session = models.AttendanceSession(
        teacher_id=current_teacher.id,
        section_id=payload.section_id,
        batch_type=payload.batch_type,
        date=payload.date,
        start_time=payload.start_time,
        end_time=payload.end_time
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    
    query = db.query(models.Student).filter(models.Student.section_id == payload.section_id)
    if payload.batch_type in ["A", "B"]:
        query = query.filter(models.Student.batch == payload.batch_type)
    
    students = query.all()
    for s in students:
        ar = models.AttendanceRecord(session_id=session.id, student_id=s.id, status='ABSENT')
        db.add(ar)
        
    db.commit()
    db.refresh(session)
    
    # Automatically start BLE broadcast when session starts
    try:
        ble_service.start()
    except Exception as e:
        print("BLE Start Error:", e)
        
    return {"id": session.id, "message": "Session started"}

@app.post("/api/student/mark")
async def student_mark_attendance(
    enrollment_no: str = Form(...),
    token: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(database.get_db)
):
    # 1. Validate Token (+- 4 sec window)
    if not ble_service.security_engine.validate_token(token):
        raise HTTPException(status_code=400, detail="Invalid or expired BLE token! Are you outside the class?")
        
    # 2. Get student
    student = db.query(models.Student).filter(models.Student.enrollment_no == enrollment_no).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
        
    # === FACE VERIFICATION BYPASSED FOR NOW ===
    # image processing and deepface logic is commented out temporarily.
    similarity_percentage = 100.0
    # ==========================================
        
    # 3. Find active session
    from datetime import datetime
    now_time = datetime.now().time()
    today = date.today()
    
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.date == today,
        models.AttendanceSession.section_id == student.section_id,
        models.AttendanceSession.start_time <= now_time,
        models.AttendanceSession.end_time >= now_time
    ).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="No active class going on for your section right now.")
        
    # 4. Mark Present
    record = db.query(models.AttendanceRecord).filter(
        models.AttendanceRecord.session_id == session.id,
        models.AttendanceRecord.student_id == student.id
    ).first()
    
    if not record:
        raise HTTPException(status_code=400, detail="Record not found for this session.")
        
    if record.status == 'PRESENT':
        return {"message": "Attendance already marked!"}
        
    record.status = 'PRESENT'
    db.commit()
    return {"message": f"Present marked successfully for {student.name}!"}

@app.get("/api/attendance/session/{session_id}/live")
def get_live_session(session_id: int, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    session = db.query(models.AttendanceSession).filter(models.AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    records = db.query(models.AttendanceRecord).filter(models.AttendanceRecord.session_id == session_id).all()
    student_ids = [r.student_id for r in records]
    students = db.query(models.Student).filter(models.Student.id.in_(student_ids)).all()
    
    student_map = {s.id: s for s in students}
    
    results = []
    for r in records:
        student = student_map.get(r.student_id)
        if student:
            results.append({
                "student_id": student.id,
                "enrollment_no": student.enrollment_no,
                "name": student.name,
                "status": r.status
            })
            
    return {
        "session_id": session.id,
        "date": session.date,
        "start_time": session.start_time,
        "end_time": session.end_time,
        "records": sorted(results, key=lambda x: x["enrollment_no"])
    }

@app.post("/api/attendance/session/{session_id}/end")
def end_session_early(session_id: int, db: Session = Depends(database.get_db), current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    session = db.query(models.AttendanceSession).filter(models.AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    from datetime import datetime
    session.end_time = datetime.now().time()
    db.commit()
    
    ble_service.stop()
    return {"message": "Session ended early and BLE stopped"}

# --- BLE Routes ---
@app.post("/api/student/{enrollment_no}/register_face")
async def register_face_api(enrollment_no: str, file: UploadFile = File(...), db: Session = Depends(database.get_db)):
    enrollment_no = enrollment_no.upper()
    student = db.query(models.Student).filter(models.Student.enrollment_no == enrollment_no).first()
    if not student:
        raise HTTPException(status_code=404, detail=f"Student with Enrollment '{enrollment_no}' not found.")
        
    if student.face_registered:
        raise HTTPException(status_code=400, detail=f"Student {student.name} is already registered! Registration can only be done once.")
        
    img_path = f"temp_api_face_{enrollment_no}.jpg"
    try:
        with open(img_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # Fix mobile camera rotation issues
        # try:
        #     from PIL import Image, ImageOps
        #     img = Image.open(img_path)
        #     img = ImageOps.exif_transpose(img)
        #     if img.mode != "RGB":
        #         img = img.convert("RGB")
        #     img.save(img_path)
        # except Exception:
        #     pass
            
        # embedding_objs = DeepFace.represent(img_path=img_path, model_name="Facenet", enforce_detection=True)
        # 
        # if len(embedding_objs) == 0:
        #     raise HTTPException(status_code=400, detail="No face detected in the uploaded image! Try again.")
        #     
        # embedding = embedding_objs[0]["embedding"]
        
        # Mock embedding for now since DeepFace is disabled
        embedding = [0.0] * 128
        
        student.face_encoding = embedding
        student.face_registered = True
        db.commit()
        
        return {"message": f"Face Registered successfully for {student.name}."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Face extraction error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    finally:
        if os.path.exists(img_path):
            os.remove(img_path)

@app.post("/api/ble/start")
def start_ble(current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    ble_service.start()
    return {"status": "started", "message": "BLE Broadcast is running"}

@app.post("/api/ble/stop")
def stop_ble(current_teacher: models.Teacher = Depends(auth.get_current_teacher)):
    ble_service.stop()
    return {"status": "stopped", "message": "BLE Broadcast is stopped"}
