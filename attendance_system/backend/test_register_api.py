import requests
import sys

# Update this URL if your server is running on a different port
BASE_URL = "http://127.0.0.1:8000"

def test_register_face(enrollment_no, image_path):
    url = f"{BASE_URL}/api/student/{enrollment_no}/register_face"
    
    try:
        with open(image_path, "rb") as image_file:
            files = {"file": (image_path, image_file, "image/jpeg")}
            print(f"Uploading {image_path} for {enrollment_no}...")
            
            response = requests.post(url, files=files)
            
            if response.status_code == 200:
                print("✅ Success:", response.json())
            else:
                print(f"❌ Failed (Status {response.status_code}):", response.text)
                
    except FileNotFoundError:
        print(f"❌ Error: Image file '{image_path}' not found.")
    except Exception as e:
        print(f"❌ Error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python test_register_api.py <ENROLLMENT_NO> <IMAGE_PATH>")
        print("Example: python test_register_api.py T1A1 my_face.jpg")
    else:
        enrollment = sys.argv[1]
        img_path = sys.argv[2]
        test_register_face(enrollment, img_path)
