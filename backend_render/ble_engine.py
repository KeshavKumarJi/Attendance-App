import sys
import time
import hmac
import hashlib
import struct
import asyncio

CLASSROOM_ID = "ROOM_101"
CLASSROOM_SECRET_KEY = b"Indore_Secure_Classroom_Salt_2026"
CYCLE_INTERVAL_SEC = 4
CALIBRATED_TX_POWER = -12

class RollingSecurityEngine:
    def __init__(self, room_id: str, secret_key: bytes, interval: int = 4):
        self.room_id = room_id
        self.secret_key = secret_key
        self.interval = interval

    def get_current_window(self) -> int:
        return int(time.time() // self.interval)

    def generate_token(self, window_offset: int = 0) -> tuple[str, int]:
        target_window = self.get_current_window() + window_offset
        message = f"{self.room_id}:{target_window}".encode('utf-8')
        digest = hmac.new(self.secret_key, message, hashlib.sha256).hexdigest()
        token = digest[:8].upper()
        return token, target_window

    def validate_token(self, token: str) -> bool:
        # Check current, previous, and next windows (allow +- 60 mins drift to handle bad system clocks)
        for offset in range(-1000, 1001):
            valid_token, _ = self.generate_token(offset)
            if valid_token == token:
                return True
        return False


class BLEAdvertiserManager:
    def __init__(self, room_id: str, tx_power: int):
        self.room_id = room_id
        self.tx_power = tx_power
        self.company_id = 0xFFFF
        self.publisher = None
        self.adv_module = None
        self.streams_module = None
        self._init_os_bluetooth()

    def _init_os_bluetooth(self):
        if sys.platform == "win32":
            try:
                import winsdk.windows.devices.bluetooth.advertisement as ble_adv
                import winsdk.windows.storage.streams as streams
                self.adv_module = ble_adv
                self.streams_module = streams
                
                # Single persistent publisher
                self.publisher = ble_adv.BluetoothLEAdvertisementPublisher()
                
                # Status tracking callback
                def on_status_changed(sender, args):
                    status_name = str(args.status)
                    if "Aborted" in status_name:
                        print(f"[BLE CRITICAL] Advertisement Aborted by Windows! Error: {args.error}")
                
                self.publisher.add_status_changed(on_status_changed)
                print("[BLE] Native Windows BLE Advertisement Engine initialized.")
            except ImportError as e:
                print(f"[BLE WARNING] 'winsdk' library not found. Error: {e}")
                self.adv_module = None
        else:
            print("[BLE] Running on Linux/Posix environment. Configure BlueZ.")
            self.adv_module = None

    def build_manufacturer_payload(self, token: str) -> bytes:
        room_bytes = self.room_id.encode('utf-8').ljust(4, b'\x00')[:4]
        token_bytes = token.encode('utf-8')[:8]
        tx_power_byte = struct.pack('b', self.tx_power)
        return room_bytes + token_bytes + tx_power_byte

    def update_broadcast(self, token: str):
        payload = self.build_manufacturer_payload(token)
        
        try:
            with open("simulated_ble_air.txt", "w") as f:
                f.write(f"ROOM_101,{token}")
        except:
            pass

        if sys.platform == "win32" and self.adv_module and self.publisher:
            try:
                self.publisher.stop()
                time.sleep(0.15)

                self.publisher.advertisement.manufacturer_data.clear()

                mfg_data = self.adv_module.BluetoothLEManufacturerData()
                mfg_data.company_id = self.company_id

                writer = self.streams_module.DataWriter()
                writer.write_bytes(payload)
                mfg_data.data = writer.detach_buffer()

                self.publisher.advertisement.manufacturer_data.append(mfg_data)
                self.publisher.start()
            except Exception as e:
                print(f"[BLE ERROR] Failed to push Windows BLE frame: {e}")

    def stop_broadcast(self):
        if self.publisher is not None:
            try:
                self.publisher.stop()
                print("[BLE] Broadcast safely stopped.")
            except Exception as e:
                print(f"[BLE ERROR] Error stopping publisher: {e}")


import threading

class BLEService:
    def __init__(self):
        self.is_running = False
        self._thread = None
        self.security_engine = RollingSecurityEngine(CLASSROOM_ID, CLASSROOM_SECRET_KEY, CYCLE_INTERVAL_SEC)
        self.ble_broadcaster = BLEAdvertiserManager(CLASSROOM_ID, CALIBRATED_TX_POWER)

    def _run_loop(self):
        current_window = -1
        while self.is_running:
            window_now = self.security_engine.get_current_window()
            if window_now != current_window:
                current_window = window_now
                active_token, _ = self.security_engine.generate_token()
                self.ble_broadcaster.update_broadcast(active_token)
                print(f"[BLE_ENGINE] Emitted Token: {active_token}")
            time.sleep(0.5)

    def start(self):
        if not self.is_running:
            self.is_running = True
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()
            print("[BLE_ENGINE] Started broadcasting.")

    def stop(self):
        if self.is_running:
            self.is_running = False
            self.ble_broadcaster.stop_broadcast()
            print("[BLE_ENGINE] Stopped broadcasting.")

ble_service = BLEService()

if __name__ == "__main__":
    service = BLEService()
    try:
        service.start()
        print("Broadcasting active. Press Ctrl+C to terminate...")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        service.stop()
        print("\nProcess terminated by user.")
