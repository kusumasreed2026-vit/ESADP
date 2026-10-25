import os
import glob
import pandas as pd
import numpy as np

INPUT_FOLDER = r"D:\Shrihi\M.Tech  VITCC\Data Engineering\Use Case\CSV files"
OUTPUT_FOLDER = r"D:\Shrihi\M.Tech  VITCC\Data Engineering\Use Case\data_profiling_reports"

OUTPUT_FILE = os.path.join(
    OUTPUT_FOLDER,
    "Sprint2_Source_Data_Profiling_Report.xlsx"
)

os.makedirs(OUTPUT_FOLDER, exist_ok=True)

print("=" * 70)
print("SPRINT 2 - OLIST SOURCE DATA PROFILING")
print("=" * 70)

csv_files = glob.glob(
    os.path.join(INPUT_FOLDER, "**", "*.csv"),
    recursive=True
)

csv_files = sorted(csv_files)

print(f"\nCSV files found: {len(csv_files)}")

if not csv_files:
    raise Exception(
        "No CSV files found. Check the INPUT_FOLDER path."
    )


file_summary = []
column_profile = []
missing_values = []
duplicate_records = []
numeric_statistics = []
categorical_statistics = []
date_statistics = []


for filepath in csv_files:

    file_name = os.path.basename(filepath)
    data_source = os.path.splitext(file_name)[0]

    print("\n" + "-" * 70)
    print(f"Profiling: {file_name}")

    try:

        df = pd.read_csv(
            filepath,
            low_memory=False
        )

        row_count = len(df)
        column_count = len(df.columns)

        duplicate_count = int(
            df.duplicated().sum()
        )

        duplicate_percentage = (
            duplicate_count / row_count * 100
            if row_count > 0
            else 0
        )

        file_summary.append({
            "Data Source": data_source,
            "File": file_name,
            "Number of Rows": row_count,
            "Number of Columns": column_count,
            "Duplicate Records": duplicate_count,
            "Duplicate %": round(
                duplicate_percentage,
                2
            )
        })

        print(f"Rows       : {row_count:,}")
        print(f"Columns    : {column_count}")
        print(f"Duplicates : {duplicate_count:,}")


        for column in df.columns:

            series = df[column]

            null_count = int(
                series.isna().sum()
            )

            null_percentage = (
                null_count / row_count * 100
                if row_count > 0
                else 0
            )

            unique_count = int(
                series.nunique(
                    dropna=True
                )
            )

            unique_percentage = (
                unique_count / row_count * 100
                if row_count > 0
                else 0
            )

            column_profile.append({
                "Data Source": data_source,
                "File": file_name,
                "Column Name": column,
                "Data Type": str(series.dtype),
                "Number of Rows": row_count,
                "Missing Values": null_count,
                "Missing %": round(
                    null_percentage,
                    2
                ),
                "Unique Values": unique_count,
                "Unique %": round(
                    unique_percentage,
                    2
                )
            })


            if null_count > 0:

                missing_values.append({
                    "Data Source": data_source,
                    "File": file_name,
                    "Column": column,
                    "Missing Count": null_count,
                    "Missing %": round(
                        null_percentage,
                        2
                    )
                })


            if pd.api.types.is_numeric_dtype(
                series
            ):

                non_null = series.dropna()

                if len(non_null) > 0:

                    numeric_statistics.append({
                        "Data Source": data_source,
                        "File": file_name,
                        "Column": column,
                        "Min": non_null.min(),
                        "Max": non_null.max(),
                        "Mean": non_null.mean(),
                        "Median": non_null.median(),
                        "Std Dev": (
                            non_null.std()
                            if len(non_null) > 1
                            else np.nan
                        ),
                        "Zero Count": int(
                            (non_null == 0).sum()
                        ),
                        "Negative Count": int(
                            (non_null < 0).sum()
                        )
                    })


            if pd.api.types.is_object_dtype(
                series
            ):

                non_null = series.dropna()

                if len(non_null) > 0:

                    value_counts = (
                        non_null
                        .astype(str)
                        .value_counts()
                        .head(10)
                    )

                    for value, frequency in (
                        value_counts.items()
                    ):

                        categorical_statistics.append({
                            "Data Source": data_source,
                            "File": file_name,
                            "Column": column,
                            "Value": value,
                            "Frequency": int(
                                frequency
                            ),
                            "Percentage": round(
                                frequency /
                                len(non_null) *
                                100,
                                2
                            )
                        })


            column_lower = column.lower()

            if any(
                keyword in column_lower
                for keyword in [
                    "date",
                    "time",
                    "timestamp"
                ]
            ):

                converted = pd.to_datetime(
                    series,
                    errors="coerce"
                )

                valid_dates = converted.dropna()

                if len(valid_dates) > 0:

                    date_statistics.append({
                        "Data Source": data_source,
                        "File": file_name,
                        "Column": column,
                        "Minimum Date": valid_dates.min(),
                        "Maximum Date": valid_dates.max(),
                        "Valid Date Values": len(valid_dates),
                        "Invalid Date Values": int(
                            series.notna().sum()
                            - len(valid_dates)
                        )
                    })


        if duplicate_count > 0:

            duplicate_records.append({
                "Data Source": data_source,
                "File": file_name,
                "Duplicate Records": duplicate_count,
                "Duplicate %": round(
                    duplicate_percentage,
                    2
                )
            })


        print("Profiling completed successfully.")

    except Exception as e:

        print(
            f"ERROR while processing "
            f"{file_name}: {e}"
        )


file_summary_df = pd.DataFrame(
    file_summary
)

column_profile_df = pd.DataFrame(
    column_profile
)

missing_values_df = pd.DataFrame(
    missing_values
)

duplicate_records_df = pd.DataFrame(
    duplicate_records
)

numeric_statistics_df = pd.DataFrame(
    numeric_statistics
)

categorical_statistics_df = pd.DataFrame(
    categorical_statistics
)

date_statistics_df = pd.DataFrame(
    date_statistics
)


if missing_values_df.empty:

    missing_values_df = pd.DataFrame(
        columns=[
            "Data Source",
            "File",
            "Column",
            "Missing Count",
            "Missing %"
        ]
    )


if duplicate_records_df.empty:

    duplicate_records_df = pd.DataFrame(
        columns=[
            "Data Source",
            "File",
            "Duplicate Records",
            "Duplicate %"
        ]
    )


if numeric_statistics_df.empty:

    numeric_statistics_df = pd.DataFrame(
        columns=[
            "Data Source",
            "File",
            "Column",
            "Min",
            "Max",
            "Mean",
            "Median",
            "Std Dev",
            "Zero Count",
            "Negative Count"
        ]
    )


if categorical_statistics_df.empty:

    categorical_statistics_df = pd.DataFrame(
        columns=[
            "Data Source",
            "File",
            "Column",
            "Value",
            "Frequency",
            "Percentage"
        ]
    )


if date_statistics_df.empty:

    date_statistics_df = pd.DataFrame(
        columns=[
            "Data Source",
            "File",
            "Column",
            "Minimum Date",
            "Maximum Date",
            "Valid Date Values",
            "Invalid Date Values"
        ]
    )


overview_df = pd.DataFrame({
    "Metric": [
        "Profiling Date",
        "Source",
        "Files Analyzed",
        "Total Rows",
        "Total Columns",
        "Total Duplicate Records",
        "Files With Missing Values",
        "Files With Duplicate Records"
    ],
    "Value": [
        pd.Timestamp.now().strftime(
            "%Y-%m-%d %H:%M:%S"
        ),
        "Olist Kaggle Source CSV Files",
        len(file_summary_df),
        int(
            file_summary_df[
                "Number of Rows"
            ].sum()
        ),
        int(
            file_summary_df[
                "Number of Columns"
            ].sum()
        ),
        int(
            file_summary_df[
                "Duplicate Records"
            ].sum()
        ),
        missing_values_df[
            "File"
        ].nunique(),
        duplicate_records_df[
            "File"
        ].nunique()
    ]
})


with pd.ExcelWriter(
    OUTPUT_FILE,
    engine="openpyxl"
) as writer:

    overview_df.to_excel(
        writer,
        sheet_name="Overview",
        index=False
    )

    file_summary_df.to_excel(
        writer,
        sheet_name="File_Summary",
        index=False
    )

    column_profile_df.to_excel(
        writer,
        sheet_name="Column_Profile",
        index=False
    )

    missing_values_df.to_excel(
        writer,
        sheet_name="Missing_Values",
        index=False
    )

    duplicate_records_df.to_excel(
        writer,
        sheet_name="Duplicate_Records",
        index=False
    )

    numeric_statistics_df.to_excel(
        writer,
        sheet_name="Numeric_Statistics",
        index=False
    )

    categorical_statistics_df.to_excel(
        writer,
        sheet_name="Categorical_Statistics",
        index=False
    )

    date_statistics_df.to_excel(
        writer,
        sheet_name="Date_Columns",
        index=False
    )

    for worksheet in writer.book.worksheets:

        for column_cells in worksheet.columns:

            max_length = 0

            column_letter = (
                column_cells[0]
                .column_letter
            )

            for cell in column_cells:

                try:

                    max_length = max(
                        max_length,
                        len(str(cell.value))
                    )

                except:
                    pass

            worksheet.column_dimensions[
                column_letter
            ].width = min(
                max_length + 2,
                40
            )


print("\n" + "=" * 70)
print("SOURCE DATA PROFILING COMPLETED")
print("=" * 70)

print(
    f"\nFiles analyzed : "
    f"{len(file_summary_df)}"
)

print(
    f"Total rows     : "
    f"{int(file_summary_df['Number of Rows'].sum()):,}"
)

print(
    f"Total columns  : "
    f"{int(file_summary_df['Number of Columns'].sum()):,}"
)

print(
    f"Duplicates     : "
    f"{int(file_summary_df['Duplicate Records'].sum()):,}"
)

print(
    "\nReport generated at:"
)

print(
    os.path.abspath(OUTPUT_FILE)
)