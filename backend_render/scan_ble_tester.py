import asyncio
from bleak import BleakScanner
import struct

async def main():
    print("Scanning for Teacher BLE Signals (ROOM_101)...")
    print("Make sure you pressed 'START SESSION' on your phone app!")
    print("Press Ctrl+C to stop.\n")
    
    def detection_callback(device, advertisement_data):
        # We are looking for company ID 0xFFFF (65535)
        mfg_data = advertisement_data.manufacturer_data
        if 0xFFFF in mfg_data:
            data = mfg_data[0xFFFF]
            try:
                # The first 4 bytes are 'ROOM', next 8 bytes are Token
                if data[:4] == b"ROOM":
                    token = data[4:12].decode('utf-8')
                    print(f"[FOUND SIGNAL] From Phone: {device.address} | Token: {token} | RSSI: {advertisement_data.rssi}")
            except Exception as e:
                pass

    scanner = BleakScanner(detection_callback)
    await scanner.start()
    await asyncio.sleep(60.0)
    await scanner.stop()

if __name__ == "__main__":
    asyncio.run(main())
