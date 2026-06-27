import pandas as pd
from sqlalchemy import create_engine
from pathlib import Path
import time
from urllib.parse import quote_plus

# -----------------------------
# Database Configuration
# -----------------------------
# UPDATE THESE WITH YOUR ACTUAL MYSQL CREDENTIALS
# -----------------------------
# Database Configuration
# -----------------------------
DB_USER = "root"
DB_PASS = "Password"  # <--- Keep your actual password exactly as it is here
DB_HOST = "localhost"
DB_PORT = "3306"
DB_NAME = "capital_markets"

# This safely encodes the @ symbol in your password!
encoded_pass = quote_plus(DB_PASS)

# Notice we are using {encoded_pass} here now
engine_url = f"mysql+pymysql://{DB_USER}:{encoded_pass}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

print("Connecting to MySQL Database...")
try:
    engine = create_engine(engine_url)
    connection = engine.connect()
    print("✅ Connection Successful!\n")
except Exception as e:
    print("❌ Connection Failed. Please check your password and ensure MySQL is running.")
    print(e)
    exit()

# -----------------------------
# Loading Configuration
# -----------------------------
data_dir = Path("data/generated")

# ORDER IS CRITICAL! 
# Parent tables (clients, companies) must be loaded before child tables (trades, portfolio)
tables_to_load = [
    {"file": "clients.csv", "table": "clients"},
    {"file": "companies.csv", "table": "companies"},
    {"file": "market_indices.csv", "table": "market_indices"},
    {"file": "stock_prices.csv", "table": "stock_prices"},
    {"file": "trades.csv", "table": "trades"},
    {"file": "portfolio.csv", "table": "portfolio"}
]

# -----------------------------
# Execution
# -----------------------------
print("Starting Data Load Pipeline...")
print("=" * 50)
total_start_time = time.time()

for item in tables_to_load:
    file_path = data_dir / item["file"]
    table_name = item["table"]
    
    if not file_path.exists():
        print(f"⚠️ Warning: {file_path} not found. Skipping...")
        continue
        
    print(f"Loading {item['file']} into '{table_name}' table...")
    start_time = time.time()
    
    # Read CSV
    df = pd.read_csv(file_path)
    
    # Push to SQL in chunks of 10,000 to prevent memory overload
    try:
        df.to_sql(name=table_name, 
                  con=engine, 
                  if_exists='append', 
                  index=False, 
                  chunksize=10000)
        
        elapsed_time = round(time.time() - start_time, 2)
        print(f"✅ Successfully inserted {len(df):,} rows into {table_name} in {elapsed_time} seconds.\n")
    
    except Exception as e:
        print(f"❌ Failed to load {table_name}.")
        print(e)
        print("\n")

connection.close()
total_elapsed = round(time.time() - total_start_time, 2)
print("=" * 50)
print(f"🎉 All Data Loaded Successfully in {total_elapsed} seconds!")
print("=" * 50)