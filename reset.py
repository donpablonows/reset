#!/usr/bin/env python3
'''
Cursor Trial Reset Tool

This script resets the device IDs in Cursor's configuration file to generate a new random device ID.
It kills any running cursor.exe processes, removes the ~/.cursor directory, and backs up and resets the configuration.

Repository: https://github.com/ultrasev/cursor-reset
Author: @ultrasev
Created: 10/Dec/2024
'''

import json
import os
import shutil
import uuid
from datetime import datetime
from pathlib import Path
import platform
import psutil  # For killing running processes


def backup_file(file_path: str):
    """Create a timestamped backup of the given file."""
    if os.path.exists(file_path):
        backup_path = f"{file_path}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        shutil.copy2(file_path, backup_path)
        print(f"Backup created: {backup_path}")


def get_storage_file():
    """Determine the storage file location based on the operating system."""
    system = platform.system()
    if system == "Windows":
        return Path(os.getenv("APPDATA")) / "Cursor" / "User" / "globalStorage" / "storage.json"
    elif system == "Darwin":  # macOS
        return Path(os.path.expanduser("~")) / "Library" / "Application Support" / "Cursor" / "User" / "globalStorage" / "storage.json"
    elif system == "Linux":
        return Path(os.path.expanduser("~")) / ".config" / "Cursor" / "User" / "globalStorage" / "storage.json"
    else:
        raise OSError(f"Unsupported operating system: {system}")


def remove_cursor_directory():
    """Remove the ~/.cursor directory (if it exists)."""
    cursor_dir = Path(os.path.expanduser("~")) / ".cursor"
    if cursor_dir.exists() and cursor_dir.is_dir():
        try:
            shutil.rmtree(cursor_dir)
            print(f"🎉 Removed the directory: {cursor_dir}")
        except Exception as e:
            print(f"Error removing {cursor_dir}: {e}")
    else:
        print("No ~/.cursor directory found to remove.")


def kill_cursor_processes():
    """Kill all running instances of cursor.exe."""
    print("🔴 Killing all running instances of cursor.exe...")
    for proc in psutil.process_iter(attrs=['pid', 'name']):
        try:
            if 'cursor.exe' in proc.info['name'].lower():  # Match the process name case-insensitively
                proc.terminate()  # Terminate the process
                print(f"Terminated cursor.exe (PID: {proc.info['pid']})")
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass  # Ignore any process that no longer exists or is inaccessible


def reset_cursor_id():
    # Kill any running cursor.exe processes
    kill_cursor_processes()

    # Remove the ~/.cursor directory
    remove_cursor_directory()

    # Reset device IDs in the configuration file
    storage_file = get_storage_file()
    storage_file.parent.mkdir(parents=True, exist_ok=True)
    backup_file(storage_file)

    # Read the existing configuration or initialize it
    if not storage_file.exists():
        data = {}
    else:
        with open(storage_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

    # Generate new random device IDs
    machine_id = os.urandom(32).hex()
    mac_machine_id = os.urandom(32).hex()
    dev_device_id = str(uuid.uuid4())

    # Update the configuration file with new IDs
    data["telemetry.machineId"] = machine_id
    data["telemetry.macMachineId"] = mac_machine_id
    data["telemetry.devDeviceId"] = dev_device_id

    with open(storage_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

    print("🎉 Device IDs have been successfully reset. The new device IDs are: \n")
    print(
        json.dumps(
            {
                "machineId": machine_id,
                "macMachineId": mac_machine_id,
                "devDeviceId": dev_device_id,
            },
            indent=2))


if __name__ == "__main__":
    reset_cursor_id()
