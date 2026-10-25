import os
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, inspect, text
from urllib.parse import quote_plus

DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "YOUR_DATABASE_NAME"
DB_USER = "postgres"
DB_PASSWORD = "YOUR_PASSWORD"

OUTPUT_DIR = "profiling_output"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "Sprint2_Data_Profiling_Report.xlsx")

os.makedirs(OUTPUT_DIR, exist_ok=True)

password = quote_plus(DB_PASSWORD)

connection_string = (
    f"postgresql+psycopg2://{DB_USER}:{password}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

engine = create_engine(connection_string)

print("=" * 70)
print("SPRINT 2 - PYTHON DATA PROFILING")
print("=" * 70)

with engine.connect() as conn:
    conn.execute(text("SELECT 1"))

print("\nPostgreSQL connection successful.")

inspector = inspect(engine)

tables = inspector.get_table_names(schema="staging")

if not tables:
    raise Exception("No tables found in the staging schema.")

print(f"\nTotal staging tables found: {len(tables)}")

table_rows = []
column_rows = []
missing_rows = []
duplicate_rows = []
numeric_rows = []
categorical_rows = []
datetime_rows = []

for table_name in tables:

    print(f"\nProfiling: staging.{table_name}")

    query = f'SELECT * FROM staging."{table_name}"'
    df = pd.read_sql(query, engine)

    row_count = len(df)
    column_count = len(df.columns)
    duplicate_count = int(df.duplicated().sum())

    table_rows.append({
        "Schema": "staging",
        "Table": table_name,
        "Rows": row_count,
        "Columns": column_count,
        "Duplicate Rows": duplicate_count,
        "Memory Usage (MB)": round(df.memory_usage(deep=True).sum() / (1024 ** 2), 2)
    })

    for column in df.columns:

        series = df[column]

        null_count = int(series.isna().sum())
        null_percentage = round((null_count / row_count) * 100, 2) if row_count > 0 else 0
        unique_count = int(series.nunique(dropna=True))
        unique_percentage = round((unique_count / row_count) * 100, 2) if row_count > 0 else 0

        column_rows.append({
            "Table": table_name,
            "Column": column,
            "Data Type": str(series.dtype),
            "Rows": row_count,
            "Null Count": null_count,
            "Null %": null_percentage,
            "Unique Count": unique_count,
            "Unique %": unique_percentage
        })

        if null_count > 0:
            missing_rows.append({
                "Table": table_name,
                "Column": column,
                "Null Count": null_count,
                "Null %": null_percentage,
                "Non-Null Count": row_count - null_count
            })

        if pd.api.types.is_numeric_dtype(series):
            if series.notna().any():
                numeric_rows.append({
                    "Table": table_name,
                    "Column": column,
                    "Min": series.min(),
                    "Max": series.max(),
                    "Mean": round(series.mean(), 4),
                    "Median": round(series.median(), 4),
                    "Std Dev": round(series.std(), 4) if len(series.dropna()) > 1 else np.nan,
                    "Zero Count": int((series == 0).sum()),
                    "Negative Count": int((series < 0).sum())
                })

        elif pd.api.types.is_datetime64_any_dtype(series):
            if series.notna().any():
                datetime_rows.append({
                    "Table": table_name,
                    "Column": column,
                    "Minimum Date": series.min(),
                    "Maximum Date": series.max()
                })

        else:
            non_null = series.dropna()

            if len(non_null) > 0:
                value_counts = non_null.astype(str).value_counts().head(10)

                for value, count in value_counts.items():
                    categorical_rows.append({
                        "Table": table_name,
                        "Column": column,
                        "Value": value,
                        "Frequency": int(count),
                        "Percentage": round((count / len(non_null)) * 100, 2)
                    })

    if duplicate_count > 0:
        duplicate_rows.append({
            "Table": table_name,
            "Rows": row_count,
            "Duplicate Rows": duplicate_count,
            "Duplicate %": round((duplicate_count / row_count) * 100, 2) if row_count > 0 else 0
        })

summary_df = pd.DataFrame(table_rows)
column_df = pd.DataFrame(column_rows)
missing_df = pd.DataFrame(missing_rows)
duplicate_df = pd.DataFrame(duplicate_rows)
numeric_df = pd.DataFrame(numeric_rows)
categorical_df = pd.DataFrame(categorical_rows)
datetime_df = pd.DataFrame(datetime_rows)

if missing_df.empty:
    missing_df = pd.DataFrame(columns=[
        "Table", "Column", "Null Count", "Null %", "Non-Null Count"
    ])

if duplicate_df.empty:
    duplicate_df = pd.DataFrame(columns=[
        "Table", "Rows", "Duplicate Rows", "Duplicate %"
    ])

if numeric_df.empty:
    numeric_df = pd.DataFrame(columns=[
        "Table", "Column", "Min", "Max", "Mean",
        "Median", "Std Dev", "Zero Count", "Negative Count"
    ])

if categorical_df.empty:
    categorical_df = pd.DataFrame(columns=[
        "Table", "Column", "Value", "Frequency", "Percentage"
    ])

if datetime_df.empty:
    datetime_df = pd.DataFrame(columns=[
        "Table", "Column", "Minimum Date", "Maximum Date"
    ])

summary_df = summary_df.sort_values("Table")
column_df = column_df.sort_values(["Table", "Column"])
missing_df = missing_df.sort_values(["Table", "Null %"], ascending=[True, False])
duplicate_df = duplicate_df.sort_values("Duplicate Rows", ascending=False)
numeric_df = numeric_df.sort_values(["Table", "Column"])
categorical_df = categorical_df.sort_values(
    ["Table", "Column", "Frequency"],
    ascending=[True, True, False]
)
datetime_df = datetime_df.sort_values(["Table", "Column"])

total_rows = int(summary_df["Rows"].sum())
total_columns = int(summary_df["Columns"].sum())
total_duplicates = int(summary_df["Duplicate Rows"].sum())
tables_with_missing = int(missing_df["Table"].nunique()) if not missing_df.empty else 0
tables_with_duplicates = int(duplicate_df["Table"].nunique()) if not duplicate_df.empty else 0

overview_df = pd.DataFrame({
    "Metric": [
        "Profiling Date",
        "Schema Profiled",
        "Number of Tables",
        "Total Rows Across Tables",
        "Total Columns Across Tables",
        "Total Duplicate Rows",
        "Tables With Missing Values",
        "Tables With Duplicate Rows"
    ],
    "Value": [
        pd.Timestamp.now().strftime("%Y-%m-%d %H:%M:%S"),
        "staging",
        len(summary_df),
        total_rows,
        total_columns,
        total_duplicates,
        tables_with_missing,
        tables_with_duplicates
    ]
})

with pd.ExcelWriter(OUTPUT_FILE, engine="openpyxl") as writer:

    overview_df.to_excel(
        writer,
        sheet_name="Overview",
        index=False
    )

    summary_df.to_excel(
        writer,
        sheet_name="Table_Profile",
        index=False
    )

    column_df.to_excel(
        writer,
        sheet_name="Column_Profile",
        index=False
    )

    missing_df.to_excel(
        writer,
        sheet_name="Missing_Values",
        index=False
    )

    duplicate_df.to_excel(
        writer,
        sheet_name="Duplicates",
        index=False
    )

    numeric_df.to_excel(
        writer,
        sheet_name="Numeric_Stats",
        index=False
    )

    categorical_df.to_excel(
        writer,
        sheet_name="Categorical_Stats",
        index=False
    )

    datetime_df.to_excel(
        writer,
        sheet_name="Date_Stats",
        index=False
    )

    for worksheet in writer.book.worksheets:
        for column_cells in worksheet.columns:
            max_length = 0
            column_letter = column_cells[0].column_letter

            for cell in column_cells:
                try:
                    max_length = max(max_length, len(str(cell.value)))
                except:
                    pass

            worksheet.column_dimensions[column_letter].width = min(max_length + 2, 40)

print("\n" + "=" * 70)
print("PROFILING COMPLETED")
print("=" * 70)

print(f"\nTables profiled       : {len(summary_df)}")
print(f"Total rows            : {total_rows:,}")
print(f"Total columns         : {total_columns:,}")
print(f"Duplicate rows        : {total_duplicates:,}")
print(f"Tables with NULLs     : {tables_with_missing}")
print(f"Tables with duplicates: {tables_with_duplicates}")

print(f"\nReport generated:")
print(os.path.abspath(OUTPUT_FILE))

print("\nSheets created:")
print("1. Overview")
print("2. Table_Profile")
print("3. Column_Profile")
print("4. Missing_Values")
print("5. Duplicates")
print("6. Numeric_Stats")
print("7. Categorical_Stats")
print("8. Date_Stats")