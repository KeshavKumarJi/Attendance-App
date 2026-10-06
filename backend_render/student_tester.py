import asyncio
import time
import requests
from bleak import BleakScanner

# Configuration
COMPANY_ID = 0x0006 # Microsoft Company ID used by Windows BLE API
API_URL = "http://127.0.0.1:8000/api/student/mark"

class StudentAttendanceTester:
    def __init__(self, enrollment_no):
        self.latest_beacon = None
        self.enrollment_no = enrollment_no

    async def scan_and_verify(self):
        print(f"\n[SYSTEM] Scanning for Teacher's BLE Beacon (Please wait up to 10 seconds)...")
        
        def match_beacon(device, advertisement_data):
            mfg = advertisement_data.manufacturer_data
            if 0xFFFF in mfg:
                data = mfg[0xFFFF]
                if data[:4] == b"ROOM":
                    # Store the matched data temporarily in the class
                    self.latest_beacon = {
                        "room": "ROOM",
                        "token": data[4:12].decode('utf-8'),
                        "rssi": advertisement_data.rssi
                    }
                    return True
            return False

        # find_device_by_filter automatically starts, waits, and stops!
        device = await BleakScanner.find_device_by_filter(match_beacon, timeout=10.0)

        if not device or not self.latest_beacon:
            print("\n[RESULT] ❌ FAILED - No Bluetooth signal found from the Teacher's phone.")
            print("Make sure Teacher has started the Live Session on their Flutter app!")
            return

        print(f"\n[BLE DATA HEARD] Room: {self.latest_beacon['room']} | Token: {self.latest_beacon['token']} | RSSI: {self.latest_beacon['rssi']} dBm")
        
        print("\n[CAMERA] Opening Webcam for Face Verification...")
        import cv2
        import json
        import os
        import sys
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        from database import SessionLocal
        from models import Student
        
        cap = cv2.VideoCapture(0)
        face_encoding = None
        
        # Test if camera is working
        if not cap.isOpened() or not cap.read()[0]:
            print("\n⚠️ [WARNING] Windows Camera is locked by another process (Glitch).")
            print("Skipping live camera feed and directly verifying face from Database for testing...")
            try:
                db = SessionLocal()
                student = db.query(Student).filter(Student.enrollment_no == self.enrollment_no).first()
                if student and student.face_encoding:
                    face_encoding = student.face_encoding
                    print("[SUCCESS] Face verified locally (Simulated), sending to server...")
                else:
                    print("[ERROR] No face registered in DB for this student!")
                db.close()
            except Exception as e:
                print(f"[DB ERROR]: {e}")
            
            cap.release()
            
        else:
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                    
                cv2.imshow("Press SPACE to verify your face", frame)
                
                key = cv2.waitKey(1)
                if key % 256 == 32: # SPACE
                    print("\n[AI] Processing Face... (Bypassing DeepFace due to TF error)")
                    
                    # Directly fetch matching face encoding from PostgreSQL DB to bypass TF crash
                    try:
                        db = SessionLocal()
                        student = db.query(Student).filter(Student.enrollment_no == self.enrollment_no).first()
                        if student and student.face_encoding:
                            face_encoding = student.face_encoding
                            print("[SUCCESS] Face verified locally (Simulated), sending to server...")
                        else:
                            print("[ERROR] No face registered in DB for this student!")
                        db.close()
                    except Exception as e:
                        print(f"[DB ERROR]: {e}")
                        
                    break
                elif key % 256 == 27: # ESC
                    print("Verification Cancelled.")
                    break
                    
            cap.release()
            cv2.destroyAllWindows()
        
        if not face_encoding:
            print("\n[ERROR] Cannot mark attendance without face verification.")
            return

        print("\n[NETWORK] Sending Attendance to Server...")
        try:
            response = requests.post(API_URL, json={
                "enrollment_no": self.enrollment_no,
                "token": self.latest_beacon['token'],
                "face_encoding": face_encoding
            })
            
            result = response.json()
            if response.status_code == 200:
                print("\n=============================================")
                print(f" [SUCCESS] {result.get('message')}")
                print("=============================================\n")
            else:
                print(f"\n[SERVER ERROR] {result.get('detail')}")
        except Exception as e:
            print(f"\n[NETWORK ERROR] Failed to connect to server: {e}")

async def main():
    print("=== Student Auto-Attendance Tester ===")
    print("This script simulates your phone's Bluetooth scanning the classroom.\n")
    
    student_id = input("📝 Enter your Enrollment No (e.g. T1A1): ").strip()
    if not student_id:
        student_id = "T1A1"
    
    print(f"Using test Enrollment No: {student_id}")
        
    tester = StudentAttendanceTester(student_id)
    await tester.scan_and_verify()

if __name__ == "__main__":
    asyncio.run(main())
