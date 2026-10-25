
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

BASE_DIR = Path(__file__).resolve().parent
PRODUCTS_FILE = BASE_DIR / "olist_products_dataset.csv"
ITEMS_FILE = BASE_DIR / "olist_order_items_dataset.csv"
ORDERS_FILE = BASE_DIR / "olist_orders_dataset.csv"
OUTPUT_FILE = BASE_DIR / "inventory_simulated.csv"

RANDOM_SEED = 42
FORECAST_DAYS = 30
rng = np.random.default_rng(RANDOM_SEED)

for file in [PRODUCTS_FILE, ITEMS_FILE, ORDERS_FILE]:
    if not file.exists():
        raise FileNotFoundError(f"Required file not found: {file}")

products = pd.read_csv(PRODUCTS_FILE)
items = pd.read_csv(ITEMS_FILE)
orders = pd.read_csv(ORDERS_FILE)

products = products[["product_id", "product_category_name"]].copy()
products["product_category_name"] = (
    products["product_category_name"].fillna("unknown")
)

items["price"] = pd.to_numeric(items["price"], errors="coerce")
items["order_item_id"] = pd.to_numeric(
    items["order_item_id"], errors="coerce"
)

orders["order_purchase_timestamp"] = pd.to_datetime(
    orders["order_purchase_timestamp"], errors="coerce"
)

items = items.merge(
    orders[["order_id", "order_purchase_timestamp"]],
    on="order_id",
    how="left"
)

sales = items.groupby("product_id").agg(
    units_sold=("order_id", "size"),
    average_price=("price", "mean"),
    first_sale=("order_purchase_timestamp", "min"),
    last_sale=("order_purchase_timestamp", "max")
).reset_index()

inventory = products.merge(sales, on="product_id", how="left")

inventory["units_sold"] = (
    inventory["units_sold"].fillna(0).astype(int)
)

inventory["average_price"] = inventory["average_price"].fillna(0)

valid_dates = orders["order_purchase_timestamp"].dropna()

if valid_dates.empty:
    observation_days = 365
else:
    observation_days = max(
        1,
        (valid_dates.max() - valid_dates.min()).days + 1
    )

inventory["daily_sales_rate"] = (
    inventory["units_sold"] / observation_days
)

seasonality_options = ["Summer", "Autumn", "Winter", "Spring"]
weather_options = ["Sunny", "Rainy", "Cloudy", "Stormy"]
locations = ["Warehouse_A", "Warehouse_B", "Warehouse_C", "Warehouse_D"]

seasonality = rng.choice(
    seasonality_options, size=len(inventory),
    p=[0.25, 0.25, 0.25, 0.25]
)

season_factors = {
    "Summer": 1.15,
    "Autumn": 0.95,
    "Winter": 1.05,
    "Spring": 1.10
}

inventory["seasonality"] = seasonality

inventory["demand_forecast"] = (
    inventory["daily_sales_rate"]
    * FORECAST_DAYS
    * inventory["seasonality"].map(season_factors)
    * rng.uniform(0.90, 1.10, size=len(inventory))
).round(2)

inventory["inventory_level"] = np.ceil(
    inventory["demand_forecast"]
    * rng.uniform(0.50, 1.50, size=len(inventory))
).astype(int)

target_stock = np.ceil(
    inventory["demand_forecast"] * 1.25
).astype(int)

inventory["units_ordered"] = (
    target_stock - inventory["inventory_level"]
).clip(lower=0).astype(int)

inventory["discount"] = np.round(
    rng.choice(
        [0, 0.05, 0.10, 0.15, 0.20],
        size=len(inventory),
        p=[0.40, 0.20, 0.20, 0.12, 0.08]
    ), 2
)

inventory["price"] = inventory["average_price"].round(2)

inventory["location"] = rng.choice(
    locations, size=len(inventory)
)

inventory["weather_condition"] = rng.choice(
    weather_options, size=len(inventory)
)

inventory["holiday_promotion"] = rng.choice(
    ["Yes", "No"], size=len(inventory), p=[0.20, 0.80]
)

inventory["inventory_id"] = [
    f"INV{i:07d}" for i in range(1, len(inventory) + 1)
]

inventory["source_system"] = "Olist_Simulated"
inventory["load_timestamp"] = datetime.now().strftime(
    "%Y-%m-%d %H:%M:%S"
)

final_columns = [
    "inventory_id",
    "product_id",
    "product_category_name",
    "location",
    "inventory_level",
    "units_sold",
    "units_ordered",
    "demand_forecast",
    "price",
    "discount",
    "weather_condition",
    "holiday_promotion",
    "seasonality",
    "source_system",
    "load_timestamp"
]

inventory = inventory[final_columns].rename(
    columns={"product_category_name": "category"}
)

inventory.to_csv(OUTPUT_FILE, index=False)

print("\nINVENTORY SIMULATION COMPLETED")
print("-" * 45)
print(f"Products processed: {len(inventory):,}")
print(f"Total historical units sold: {inventory['units_sold'].sum():,}")
print(f"Total simulated stock: {inventory['inventory_level'].sum():,}")
print(f"Total replenishment quantity: {inventory['units_ordered'].sum():,}")
print(f"Output file: {OUTPUT_FILE}")
print("\nSample records:")
print(inventory.head(10).to_string(index=False))
print("\nMissing values:")
print(inventory.isnull().sum())
