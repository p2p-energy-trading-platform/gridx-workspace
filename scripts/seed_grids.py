#!/usr/bin/env python3
import os
import sys
import subprocess
import yaml

def main():
    # Load configuration paths
    yaml_path = "iot-simulation/config/grids.yaml"
    env_path = "iot-ingestion-dispatch/.env"

    if not os.path.exists(yaml_path):
        print(f"Error: Grid config not found at {yaml_path}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(env_path):
        print(f"Error: Env file not found at {env_path}", file=sys.stderr)
        sys.exit(1)

    # Parse DOCKER_POSTGRES_URL from the .env file
    db_url = None
    with open(env_path, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("DOCKER_POSTGRES_URL="):
                db_url = line.split("=", 1)[1].strip()
                break

    if not db_url:
        print("Error: DOCKER_POSTGRES_URL not found in .env file", file=sys.stderr)
        sys.exit(1)

    # Check if table is already populated
    check_cmd = [
        "docker", "exec", "-i", "gridx-infrastructure-timescaledb-1", 
        "psql", db_url, "-t", "-A", "-c", 
        "SELECT COUNT(*) FROM iot_data.grids;"
    ]
    
    try:
        res = subprocess.run(check_cmd, capture_output=True, text=True, check=True)
        count_str = res.stdout.strip()
        if count_str.isdigit():
            count = int(count_str)
            if count > 0:
                print(f"Warning: Table 'iot_data.grids' is already populated with {count} row(s). Seeding skipped. To seed new data truncate the tables of iot-ingestion-dispatch service!", file=sys.stderr)
                sys.exit(0)
    except Exception as e:
        print(f"Notice: Unable to verify existing rows (table might not exist yet): {e}", file=sys.stderr)

    # Load YAML file
    try:
        with open(yaml_path, "r") as f:
            data = yaml.safe_load(f)
            grids = data.get("grids", [])
    except Exception as e:
        print(f"Error parsing YAML file: {e}", file=sys.stderr)
        sys.exit(1)

    if not grids:
        print("No grids found to seed.", file=sys.stdout)
        return

    # Generate SQL Upsert Statements
    sql_statements = []
    for g in grids:
        grid_id = g.get("grid_id")
        display_name = g.get("display_name")
        lat = g.get("location", {}).get("lat")
        lon = g.get("location", {}).get("lon")

        if not grid_id or not display_name or lat is None or lon is None:
            print(f"Skipping malformed grid entry: {g}", file=sys.stderr)
            continue

        stmt = f"""
        INSERT INTO iot_data.grids (grid_id, lat, lon, display_name, updated_at)
        VALUES ('{grid_id}', {lat}, {lon}, '{display_name}', NOW())
        ON CONFLICT (grid_id) 
        DO UPDATE SET 
            lat = EXCLUDED.lat, 
            lon = EXCLUDED.lon, 
            display_name = EXCLUDED.display_name,
            updated_at = NOW();
        """
        sql_statements.append(stmt)

    full_sql = "\n".join(sql_statements)

    # Execute via docker container
    docker_cmd = [
        "docker", "exec", "-i", "gridx-infrastructure-timescaledb-1", 
        "psql", db_url
    ]

    print(f"Seeding {len(grids)} grids into TimescaleDB via Docker container...")
    result = subprocess.run(docker_cmd, input=full_sql, text=True, capture_output=True)

    if result.returncode != 0:
        print(f"Database seeding failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    else:
        print("Successfully seeded all grids into iot_data.grids!")

if __name__ == "__main__":
    main()