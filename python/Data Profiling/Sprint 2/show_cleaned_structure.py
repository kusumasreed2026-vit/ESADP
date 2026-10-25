import os
import pandas as pd

FOLDER = r"D:\Shrihi\M.Tech  VITCC\Data Engineering\Use Case\data_cleaned\cleaned_pass_1"

print("\n" + "=" * 80)
print("CLEANED DATASET STRUCTURE")
print("=" * 80)

files = sorted([f for f in os.listdir(FOLDER) if f.lower().endswith(".csv")])

for file in files:
    path = os.path.join(FOLDER, file)

    try:
        df = pd.read_csv(path, nrows=5, encoding="utf-8")
    except UnicodeDecodeError:
        df = pd.read_csv(path, nrows=5, encoding="latin1")

    print("\n" + "-" * 80)
    print(f"FILE: {file}")
    print(f"COLUMNS: {len(df.columns)}")
    print("-" * 80)

    for col in df.columns:
        print(f"{col:<40} {str(df[col].dtype)}")

print("\n" + "=" * 80)
print(f"TOTAL CSV FILES: {len(files)}")
print("=" * 80)