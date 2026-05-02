import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

def run_script(script_name):
    script_path = BASE_DIR / script_name

    print(f"Running {script_name}...")

    result = subprocess.run(
        [sys.executable, str(script_path)],
        capture_output=True,
        text=True
    )

    print(result.stdout)

    if result.stderr:
        print(result.stderr)

    if result.returncode != 0:
        raise Exception(f"{script_name} failed.")

    print(f"{script_name} completed successfully.")


if __name__ == "__main__":
    print("Starting full Weather + Air Quality pipeline...")

    run_script("weather_etl.py")
    run_script("air_pollution_etl.py")

    print("Full Weather + Air Quality pipeline completed.")
