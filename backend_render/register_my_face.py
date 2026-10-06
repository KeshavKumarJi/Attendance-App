import cv2
import sys
import json
from deepface import DeepFace
from database import SessionLocal
from models import Student

print("=== 🎓 College Admin Face Registration ===")

if len(sys.argv) < 2:
    print("❌ ERROR: Enrollment Number is required!")
    print("👉 Usage: python register_my_face.py T1A1")
    sys.exit(1)

enrollment_no = sys.argv[1].upper()
db = SessionLocal()

# Check if student exists
student = db.query(Student).filter(Student.enrollment_no == enrollment_no).first()
if not student:
    print(f"❌ ERROR: Student with Enrollment '{enrollment_no}' not found in database!")
    db.close()
    sys.exit(1)

print(f"✅ Found Student: {student.name} ({student.enrollment_no})")
print("\n📷 Opening Webcam...")
print("👉 Look at the camera and press 'SPACE' to capture your face.")
print("👉 Press 'ESC' to cancel.")

cap = cv2.VideoCapture(0)

while True:
    ret, frame = cap.read()
    if not ret:
        print("❌ Failed to grab frame from webcam")
        break

    cv2.imshow("Registration: Press SPACE to capture", frame)

    key = cv2.waitKey(1)
    if key % 256 == 27:
        # ESC pressed
        print("Registration Cancelled.")
        break
    elif key % 256 == 32:
        # SPACE pressed
        img_path = "temp_face.jpg"
        cv2.imwrite(img_path, frame)
        print("\n🧠 Face Captured! Processing AI Embeddings (this may take a few seconds)...")
        
        try:
            # Extract embeddings
            # We use Facenet which is lightweight and accurate
            # enforce_detection=False taaki agar lighting kam ho toh error na aaye
            embedding_objs = DeepFace.represent(img_path=img_path, model_name="Facenet", enforce_detection=False)
            
            if len(embedding_objs) == 0:
                print("❌ No face detected! Try again.")
                continue
                
            # Get the actual vector array
            embedding = embedding_objs[0]["embedding"]
            
            # Save to Database
            student.face_encoding = embedding
            student.face_registered = True
            db.commit()
            
            print(f"✅ SUCCESS! Face Registered for {student.name}.")
            print("🚀 You can now test the Attendance Proxy System!")
            break
            
        except ValueError as e:
            print("❌ Error:", e)
            print("Please ensure your face is clearly visible in the camera and try again.")
            
cap.release()
cv2.destroyAllWindows()
db.close()
