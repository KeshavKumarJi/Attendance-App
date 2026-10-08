import json
import numpy as np
from deepface import DeepFace
from database import SessionLocal
import models

def find_cosine_distance(source_representation, test_representation):
    a = np.matmul(np.transpose(source_representation), test_representation)
    b = np.sum(np.multiply(source_representation, source_representation))
    c = np.sum(np.multiply(test_representation, test_representation))
    return 1 - (a / (np.sqrt(b) * np.sqrt(c)))

try:
    db = SessionLocal()
    student = db.query(models.Student).filter(models.Student.enrollment_no == "T1A1").first()
    if student and student.face_encoding:
        db_encoding = student.face_encoding
        if isinstance(db_encoding, str):
            db_encoding = json.loads(db_encoding)
            
        print("Got DB encoding for", student.enrollment_no)
        
        embedding_objs = DeepFace.represent(img_path='temp_face.jpg', model_name='Facenet', enforce_detection=False)
        img_encoding = embedding_objs[0]['embedding']
        print("Got Image encoding")
        
        distance = find_cosine_distance(db_encoding, img_encoding)
        similarity = (1 - distance) * 100
        print(f"Distance: {distance}, Similarity: {similarity}%")
    else:
        print("No student or encoding found.")
except Exception as e:
    print("Error:", e)
finally:
    db.close()
