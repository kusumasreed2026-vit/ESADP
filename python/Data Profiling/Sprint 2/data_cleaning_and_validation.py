import os
import glob
import shutil
import pandas as pd
import numpy as np
from datetime import datetime


INPUT_FOLDER = r"D:\Shrihi\M.Tech  VITCC\Data Engineering\Use Case\CSV files"

OUTPUT_ROOT = r"D:\Shrihi\M.Tech  VITCC\Data Engineering\Use Case\data_cleaned"

CLEANED_FOLDER = os.path.join(
    OUTPUT_ROOT,
    "cleaned_csv_files"
)

QUARANTINE_FOLDER = os.path.join(
    OUTPUT_ROOT,
    "quarantine"
)

REPORT_FOLDER = os.path.join(
    OUTPUT_ROOT,
    "validation_reports"
)

MAX_PASSES = 3


os.makedirs(
    CLEANED_FOLDER,
    exist_ok=True
)

os.makedirs(
    QUARANTINE_FOLDER,
    exist_ok=True
)

os.makedirs(
    REPORT_FOLDER,
    exist_ok=True
)


cleaning_log = []
validation_results = []


def log_action(
    pass_number,
    dataset,
    column,
    action,
    records_affected,
    reason
):

    cleaning_log.append({

        "Pass": pass_number,

        "Dataset": dataset,

        "Column": column,

        "Action": action,

        "Records Affected": int(
            records_affected
        ),

        "Reason": reason

    })


def load_csv(filepath):

    try:

        return pd.read_csv(
            filepath,
            low_memory=False
        )

    except UnicodeDecodeError:

        return pd.read_csv(
            filepath,
            encoding="latin1",
            low_memory=False
        )


def save_csv(df, filepath):

    df.to_csv(
        filepath,
        index=False,
        encoding="utf-8-sig"
    )


def clean_strings(
    df,
    dataset,
    pass_number
):

    for column in df.columns:

        if df[column].dtype == "object":

            original = df[column].copy()

            df[column] = (
                df[column]
                .astype("string")
                .str.strip()
            )

            blank_mask = (
                df[column]
                .isin(
                    [
                        "",
                        "nan",
                        "None",
                        "NULL",
                        "null"
                    ]
                )
            )

            blank_count = int(
                blank_mask.sum()
            )

            if blank_count > 0:

                df.loc[
                    blank_mask,
                    column
                ] = pd.NA

                log_action(

                    pass_number,

                    dataset,

                    column,

                    "Blank strings converted to NULL",

                    blank_count,

                    "Blank or whitespace-only values are treated as missing."

                )

    return df


def remove_exact_duplicates(
    df,
    dataset,
    pass_number
):

    before = len(df)

    duplicate_mask = df.duplicated(
        keep="first"
    )

    duplicate_count = int(
        duplicate_mask.sum()
    )

    if duplicate_count > 0:

        df = df[
            ~duplicate_mask
        ].copy()

        log_action(

            pass_number,

            dataset,

            "Full Record",

            "Exact duplicate rows removed",

            duplicate_count,

            "Identical complete records are redundant."

        )

    return df


def clean_order_items(
    df,
    dataset,
    pass_number
):

    if "price" in df.columns:

        values = pd.to_numeric(
            df["price"],
            errors="coerce"
        )

        invalid = values < 0

        count = int(
            invalid.sum()
        )

        if count > 0:

            df.loc[
                invalid,
                "price"
            ] = np.nan

            log_action(

                pass_number,

                dataset,

                "price",

                "Negative values converted to NULL",

                count,

                "Negative item prices are invalid for sales analytics."

            )


    if "freight_value" in df.columns:

        values = pd.to_numeric(
            df["freight_value"],
            errors="coerce"
        )

        invalid = values < 0

        count = int(
            invalid.sum()
        )

        if count > 0:

            df.loc[
                invalid,
                "freight_value"
            ] = np.nan

            log_action(

                pass_number,

                dataset,

                "freight_value",

                "Negative values converted to NULL",

                count,

                "Negative freight values require correction or exclusion."

            )


    return df


def clean_products(
    df,
    dataset,
    pass_number
):

    measurement_columns = [

        "product_weight_g",

        "product_length_cm",

        "product_height_cm",

        "product_width_cm"

    ]

    for column in measurement_columns:

        if column not in df.columns:

            continue

        values = pd.to_numeric(
            df[column],
            errors="coerce"
        )

        invalid = values < 0

        count = int(
            invalid.sum()
        )

        if count > 0:

            df.loc[
                invalid,
                column
            ] = np.nan

            log_action(

                pass_number,

                dataset,

                column,

                "Negative measurement converted to NULL",

                count,

                "Negative physical product measurements are invalid."

            )


    if "product_category_name" in df.columns:

        missing = (
            df[
                "product_category_name"
            ].isna()
        )

        count = int(
            missing.sum()
        )

        if count > 0:

            df.loc[
                missing,
                "product_category_name"
            ] = "Unknown"

            log_action(

                pass_number,

                dataset,

                "product_category_name",

                "Missing category replaced with Unknown",

                count,

                "Missing product categories are represented explicitly for warehouse processing."

            )


    return df


def clean_order_dates(
    df,
    dataset,
    pass_number
):

    date_columns = [

        "order_purchase_timestamp",

        "order_approved_at",

        "order_delivered_carrier_date",

        "order_delivered_customer_date",

        "order_estimated_delivery_date"

    ]

    for column in date_columns:

        if column in df.columns:

            original_non_null = int(
                df[column].notna().sum()
            )

            df[column] = pd.to_datetime(
                df[column],
                errors="coerce"
            )

            new_non_null = int(
                df[column].notna().sum()
            )

            invalid_count = (
                original_non_null -
                new_non_null
            )

            if invalid_count > 0:

                log_action(

                    pass_number,

                    dataset,

                    column,

                    "Invalid dates converted to NULL",

                    invalid_count,

                    "Values that cannot be parsed as dates cannot be safely retained as dates."

                )


    if (
        "order_purchase_timestamp" in df.columns
        and
        "order_approved_at" in df.columns
    ):

        mask = (

            df[
                "order_approved_at"
            ].notna()

            &

            df[
                "order_purchase_timestamp"
            ].notna()

            &

            (
                df[
                    "order_approved_at"
                ]

                <

                df[
                    "order_purchase_timestamp"
                ]
            )

        )

        count = int(
            mask.sum()
        )

        if count > 0:

            df.loc[
                mask,
                "order_approved_at"
            ] = pd.NaT

            log_action(

                pass_number,

                dataset,

                "order_approved_at",

                "Invalid approval timestamp cleared",

                count,

                "Approval cannot occur before purchase."

            )


    if (
        "order_delivered_carrier_date" in df.columns
        and
        "order_purchase_timestamp" in df.columns
    ):

        mask = (

            df[
                "order_delivered_carrier_date"
            ].notna()

            &

            df[
                "order_purchase_timestamp"
            ].notna()

            &

            (
                df[
                    "order_delivered_carrier_date"
                ]

                <

                df[
                    "order_purchase_timestamp"
                ]
            )

        )

        count = int(
            mask.sum()
        )

        if count > 0:

            df.loc[
                mask,
                "order_delivered_carrier_date"
            ] = pd.NaT

            log_action(

                pass_number,

                dataset,

                "order_delivered_carrier_date",

                "Invalid carrier delivery timestamp cleared",

                count,

                "Carrier delivery cannot occur before purchase."

            )


    if (
        "order_delivered_customer_date" in df.columns
        and
        "order_delivered_carrier_date" in df.columns
    ):

        mask = (

            df[
                "order_delivered_customer_date"
            ].notna()

            &

            df[
                "order_delivered_carrier_date"
            ].notna()

            &

            (
                df[
                    "order_delivered_customer_date"
                ]

                <

                df[
                    "order_delivered_carrier_date"
                ]
            )

        )

        count = int(
            mask.sum()
        )

        if count > 0:

            df.loc[
                mask,
                "order_delivered_customer_date"
            ] = pd.NaT

            log_action(

                pass_number,

                dataset,

                "order_delivered_customer_date",

                "Invalid customer delivery timestamp cleared",

                count,

                "Customer delivery cannot occur before carrier delivery."

            )


    if (
        "order_estimated_delivery_date" in df.columns
        and
        "order_purchase_timestamp" in df.columns
    ):

        purchase = (
            df[
                "order_purchase_timestamp"
            ].dt.normalize()
        )

        estimated = (
            df[
                "order_estimated_delivery_date"
            ].dt.normalize()
        )

        mask = (

            purchase.notna()

            &

            estimated.notna()

            &

            (
                estimated
                <
                purchase
            )

        )

        count = int(
            mask.sum()
        )

        if count > 0:

            df.loc[
                mask,
                "order_estimated_delivery_date"
            ] = pd.NaT

            log_action(

                pass_number,

                dataset,

                "order_estimated_delivery_date",

                "Invalid estimated delivery date cleared",

                count,

                "Estimated delivery cannot occur before purchase."

            )


    return df


def clean_dataset(
    df,
    filename,
    pass_number
):

    original_rows = len(df)

    df = clean_strings(
        df,
        filename,
        pass_number
    )

    df = remove_exact_duplicates(
        df,
        filename,
        pass_number
    )


    if filename == "olist_order_items_dataset.csv":

        df = clean_order_items(
            df,
            filename,
            pass_number
        )


    if filename == "olist_products_dataset.csv":

        df = clean_products(
            df,
            filename,
            pass_number
        )


    if filename == "olist_orders_dataset.csv":

        df = clean_order_dates(
            df,
            filename,
            pass_number
        )


    final_rows = len(df)

    if original_rows != final_rows:

        print(
            f"  Rows: {original_rows:,} -> {final_rows:,}"
        )

    return df


def validate_dataset(
    df,
    filename
):

    result = {

        "Dataset": filename,

        "Rows After Cleaning": len(df),

        "Columns": len(df.columns),

        "Missing Cells": int(
            df.isna().sum().sum()
        ),

        "Exact Duplicate Rows": int(
            df.duplicated().sum()
        ),

        "Negative Numeric Issues": 0,

        "Invalid Date Issues": 0,

        "Validation Status": "PASS"

    }


    numeric_columns = df.select_dtypes(
        include=np.number
    ).columns


    for column in numeric_columns:

        column_lower = column.lower()

        if (
            "latitude" in column_lower
            or
            "longitude" in column_lower
        ):

            continue

        if (
            "price" in column_lower
            or
            "freight" in column_lower
            or
            "weight" in column_lower
            or
            "length" in column_lower
            or
            "height" in column_lower
            or
            "width" in column_lower
        ):

            count = int(
                (
                    df[column] < 0
                ).sum()
            )

            result[
                "Negative Numeric Issues"
            ] += count


    date_columns = [

        "order_purchase_timestamp",

        "order_approved_at",

        "order_delivered_carrier_date",

        "order_delivered_customer_date",

        "order_estimated_delivery_date"

    ]


    for column in date_columns:

        if column in df.columns:

            converted = pd.to_datetime(
                df[column],
                errors="coerce"
            )

            invalid = int(
                (
                    df[column].notna()
                    &
                    converted.isna()
                ).sum()
            )

            result[
                "Invalid Date Issues"
            ] += invalid


    if result[
        "Exact Duplicate Rows"
    ] > 0:

        result[
            "Validation Status"
        ] = "FAIL"


    if result[
        "Negative Numeric Issues"
    ] > 0:

        result[
            "Validation Status"
        ] = "FAIL"


    if result[
        "Invalid Date Issues"
    ] > 0:

        result[
            "Validation Status"
        ] = "FAIL"


    return result


def validate_relationships(
    datasets
):

    results = []


    orders = datasets.get(
        "olist_orders_dataset.csv"
    )

    order_items = datasets.get(
        "olist_order_items_dataset.csv"
    )

    payments = datasets.get(
        "olist_order_payments_dataset.csv"
    )

    products = datasets.get(
        "olist_products_dataset.csv"
    )

    sellers = datasets.get(
        "olist_sellers_dataset.csv"
    )


    if orders is not None:

        order_ids = set(
            orders[
                "order_id"
            ].dropna()
        )

    else:

        order_ids = set()


    if order_items is not None:

        orphan_items = int(

            (
                ~order_items[
                    "order_id"
                ].isin(order_ids)
            ).sum()

        )

        results.append({

            "Check":
            "Order Items -> Orders",

            "Records Affected":
            orphan_items,

            "Status":
            "PASS"
            if orphan_items == 0
            else "REVIEW",

            "Action":
            "No automatic deletion; investigate orphan records."

        })


        if orders is not None:

            item_order_ids = set(
                order_items[
                    "order_id"
                ].dropna()
            )

            missing_items = int(

                (
                    ~orders[
                        "order_id"
                    ].isin(item_order_ids)
                ).sum()

            )

            results.append({

                "Check":
                "Orders -> Order Items",

                "Records Affected":
                missing_items,

                "Status":
                "PASS"
                if missing_items == 0
                else "REVIEW",

                "Action":
                "Review against order status before treatment."

            })


    if payments is not None:

        orphan_payments = int(

            (
                ~payments[
                    "order_id"
                ].isin(order_ids)
            ).sum()

        )

        results.append({

            "Check":
            "Payments -> Orders",

            "Records Affected":
            orphan_payments,

            "Status":
            "PASS"
            if orphan_payments == 0
            else "REVIEW",

            "Action":
            "No automatic deletion; investigate orphan payment records."

        })


    if (
        order_items is not None
        and
        products is not None
    ):

        product_ids = set(
            products[
                "product_id"
            ].dropna()
        )

        orphan_products = int(

            (
                ~order_items[
                    "product_id"
                ].isin(product_ids)
            ).sum()

        )

        results.append({

            "Check":
            "Order Items -> Products",

            "Records Affected":
            orphan_products,

            "Status":
            "PASS"
            if orphan_products == 0
            else "REVIEW",

            "Action":
            "Investigate orphan product references."

        })


    if (
        order_items is not None
        and
        sellers is not None
    ):

        seller_ids = set(
            sellers[
                "seller_id"
            ].dropna()
        )

        orphan_sellers = int(

            (
                ~order_items[
                    "seller_id"
                ].isin(seller_ids)
            ).sum()

        )

        results.append({

            "Check":
            "Order Items -> Sellers",

            "Records Affected":
            orphan_sellers,

            "Status":
            "PASS"
            if orphan_sellers == 0
            else "REVIEW",

            "Action":
            "Investigate orphan seller references."

        })


    return results


print("=" * 80)
print("SPRINT 2 - AUTOMATED DATA CLEANING AND VALIDATION")
print("=" * 80)


csv_files = sorted(

    glob.glob(

        os.path.join(
            INPUT_FOLDER,
            "**",
            "*.csv"
        ),

        recursive=True

    )

)


if not csv_files:

    raise FileNotFoundError(
        "No CSV files found. Check INPUT_FOLDER."
    )


print(
    f"\nSource CSV files found: {len(csv_files)}"
)


current_folder = CLEANED_FOLDER


for pass_number in range(
    1,
    MAX_PASSES + 1
):

    print("\n")
    print("=" * 80)
    print(
        f"CLEANING PASS {pass_number}"
    )
    print("=" * 80)


    if pass_number == 1:

        source_files = csv_files

    else:

        source_files = sorted(

            glob.glob(

                os.path.join(
                    current_folder,
                    "*.csv"
                )

            )

        )


    new_cleaned_folder = os.path.join(

        OUTPUT_ROOT,

        f"cleaned_pass_{pass_number}"

    )


    os.makedirs(
        new_cleaned_folder,
        exist_ok=True
    )


    cleaned_datasets = {}


    for source_file in source_files:

        filename = os.path.basename(
            source_file
        )

        print(
            f"\nProcessing: {filename}"
        )


        df = load_csv(
            source_file
        )


        print(
            f"  Original rows: {len(df):,}"
        )


        df = clean_dataset(

            df,

            filename,

            pass_number

        )


        output_file = os.path.join(

            new_cleaned_folder,

            filename

        )


        save_csv(

            df,

            output_file

        )


        cleaned_datasets[
            filename
        ] = df


        print(
            f"  Cleaned rows: {len(df):,}"
        )


    print("\nRunning validation...")


    pass_results = []


    for filename, df in cleaned_datasets.items():

        result = validate_dataset(

            df,

            filename

        )

        result[
            "Pass"
        ] = pass_number

        pass_results.append(
            result
        )


    relationship_results = validate_relationships(

        cleaned_datasets

    )


    relationship_df = pd.DataFrame(

        relationship_results

    )


    validation_df = pd.DataFrame(

        pass_results

    )


    validation_results.extend(

        pass_results

    )


    validation_output = os.path.join(

        REPORT_FOLDER,

        f"validation_pass_{pass_number}.xlsx"

    )


    with pd.ExcelWriter(

        validation_output,

        engine="openpyxl"

    ) as writer:

        validation_df.to_excel(

            writer,

            sheet_name="Dataset Validation",

            index=False

        )


        relationship_df.to_excel(

            writer,

            sheet_name="Relationship Validation",

            index=False

        )


        pd.DataFrame(
            cleaning_log
        ).to_excel(

            writer,

            sheet_name="Cleaning Log",

            index=False

        )


    dataset_failures = int(

        (
            validation_df[
                "Validation Status"
            ] == "FAIL"
        ).sum()

    )


    relationship_reviews = int(

        (
            relationship_df[
                "Status"
            ] == "REVIEW"
        ).sum()

    )


    print(

        f"\nDataset validation failures: "
        f"{dataset_failures}"

    )

    print(

        f"Relationship checks requiring review: "
        f"{relationship_reviews}"

    )


    current_folder = new_cleaned_folder


    if dataset_failures == 0:

        print(
            "\nAll automatically correctable dataset-level "
            "issues have been resolved."
        )

        break


print("\n" + "=" * 80)
print("FINAL VALIDATION")
print("=" * 80)


final_source_files = sorted(

    glob.glob(

        os.path.join(
            current_folder,
            "*.csv"
        )

    )

)


final_datasets = {}


for filepath in final_source_files:

    filename = os.path.basename(
        filepath
    )

    final_datasets[
        filename
    ] = load_csv(
        filepath
    )


final_validation = []


for filename, df in final_datasets.items():

    result = validate_dataset(

        df,

        filename

    )

    final_validation.append(
        result
    )


final_validation_df = pd.DataFrame(

    final_validation

)


final_relationships = validate_relationships(

    final_datasets

)


final_relationship_df = pd.DataFrame(

    final_relationships

)


original_summary = []


for filepath in csv_files:

    filename = os.path.basename(
        filepath
    )

    original_df = load_csv(
        filepath
    )

    final_df = final_datasets.get(
        filename
    )

    if final_df is None:

        continue

    original_summary.append({

        "Dataset":
        filename,

        "Original Rows":
        len(original_df),

        "Final Rows":
        len(final_df),

        "Rows Removed":
        len(original_df) - len(final_df),

        "Original Columns":
        len(original_df.columns),

        "Final Columns":
        len(final_df.columns),

        "Original Missing Cells":
        int(
            original_df.isna().sum().sum()
        ),

        "Final Missing Cells":
        int(
            final_df.isna().sum().sum()
        )

    })


comparison_df = pd.DataFrame(

    original_summary

)


final_report = os.path.join(

    REPORT_FOLDER,

    "FINAL_Data_Cleaning_Validation_Report.xlsx"

)


with pd.ExcelWriter(

    final_report,

    engine="openpyxl"

) as writer:

    comparison_df.to_excel(

        writer,

        sheet_name="Before_After",

        index=False

    )


    final_validation_df.to_excel(

        writer,

        sheet_name="Final_Validation",

        index=False

    )


    final_relationship_df.to_excel(

        writer,

        sheet_name="Relationships",

        index=False

    )


    pd.DataFrame(
        cleaning_log
    ).to_excel(

        writer,

        sheet_name="Complete_Cleaning_Log",

        index=False

    )


print("\nFinal cleaned files:")
print(
    current_folder
)


print("\nFinal validation report:")
print(
    final_report
)


print("\nCleaning log:")
print(
    os.path.join(
        REPORT_FOLDER,
        "Complete_Cleaning_Log.xlsx"
    )
)


print("\n" + "=" * 80)
print("CLEANING AND VALIDATION COMPLETED")
print("=" * 80)


print(
    f"\nOriginal CSV files : {len(csv_files)}"
)

print(
    f"Final CSV files    : {len(final_datasets)}"
)

print(
    f"Cleaning actions   : {len(cleaning_log)}"
)

print(
    "\nFinal validation:"
)

print(
    final_validation_df[
        [
            "Dataset",
            "Rows After Cleaning",
            "Exact Duplicate Rows",
            "Negative Numeric Issues",
            "Invalid Date Issues",
            "Validation Status"
        ]
    ].to_string(
        index=False
    )
)


print("\nRelationship validation:")

print(
    final_relationship_df.to_string(
        index=False
    )
)

print("\n" + "=" * 80)