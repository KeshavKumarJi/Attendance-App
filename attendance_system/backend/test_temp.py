import sqlite3
import json
import numpy as np
from deepface import DeepFace

def find_cosine_distance(source_representation, test_representation):
    a = np.matmul(np.transpose(source_representation), test_representation)
    b = np.sum(np.multiply(source_representation, source_representation))
    c = np.sum(np.multiply(test_representation, test_representation))
    return 1 - (a / (np.sqrt(b) * np.sqrt(c)))

try:
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute("SELECT enrollment_no, face_encoding FROM students WHERE enrollment_no='T1A1'")
    row = cursor.fetchone()
    if row and row[1]:
        db_encoding = json.loads(row[1])
        print("Got DB encoding for", row[0])
        
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
