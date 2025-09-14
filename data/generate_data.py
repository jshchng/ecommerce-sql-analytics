#!/usr/bin/env python3
"""
Data generation script for Northwestern Commerce e-commerce database
Generates realistic sample data with business patterns and seasonality
"""

import pandas as pd
import numpy as np
from faker import Faker
import random
from datetime import datetime, timedelta
import mysql.connector
from mysql.connector import Error
import os
import getpass

# Initialize Faker
fake = Faker('en_US')
fake.seed_instance(42)  # For reproducible results
np.random.seed(42)
random.seed(42)

def get_db_config():
    """Get database configuration with password input"""
    password = getpass.getpass("Enter MySQL root password: ")
    return {
        'host': 'localhost',
        'database': 'northwestern_commerce',
        'user': 'root',
        'password': password
    }

def connect_to_database():
    """Create database connection"""
    try:
        db_config = get_db_config()
        connection = mysql.connector.connect(**db_config)
        if connection.is_connected():
            print("Successfully connected to MySQL database")
            return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

def generate_customers(n_customers=10000):
    """Generate customer data"""
    print(f"Generating {n_customers} customers...")
    
    # Define realistic distributions
    states = ['CA', 'NY', 'TX', 'FL', 'IL', 'PA', 'OH', 'MI', 'GA', 'NC', 
              'NJ', 'VA', 'WA', 'AZ', 'MA', 'TN', 'IN', 'MO', 'MD', 'WI']
    
    # State probabilities that sum to 1
    state_weights = [12, 6, 9, 6, 4, 4, 4, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 38]
    total_weight = sum(state_weights)
    state_probs = [w / total_weight for w in state_weights]
    
    customers = []
    
    for i in range(n_customers):
        # Generate registration date (2020–2024)
        reg_date = fake.date_between(start_date='-4y', end_date='today')
        
        # Generate birth date (age 18–70)
        birth_date = fake.date_of_birth(minimum_age=18, maximum_age=70)
        
        # State selection with proper distribution
        state = np.random.choice(states, p=state_probs)
        
        customer = {
            'email': fake.unique.email(),
            'first_name': fake.first_name(),
            'last_name': fake.last_name(),
            'registration_date': reg_date,
            'birth_date': birth_date,
            'gender': np.random.choice(['Male', 'Female', 'Other'], p=[0.48, 0.48, 0.04]),
            'city': fake.city(),
            'state': state,
            'country': 'USA',
            'customer_lifetime_value': round(np.random.gamma(2, 50), 2)  # Realistic CLV distribution
        }
        customers.append(customer)
    
    return pd.DataFrame(customers)

def generate_products(n_products=1000):
    """Generate product data"""
    print(f"Generating {n_products} products...")
    
    categories = {
        'Electronics': ['Smartphones', 'Laptops', 'Tablets', 'Accessories', 'Gaming'],
        'Clothing': ['Mens', 'Womens', 'Kids', 'Shoes', 'Accessories'],
        'Home': ['Furniture', 'Kitchen', 'Decor', 'Garden', 'Storage'],
        'Sports': ['Fitness', 'Outdoor', 'Team Sports', 'Water Sports', 'Winter'],
        'Books': ['Fiction', 'Non-Fiction', 'Educational', 'Children', 'Reference']
    }
    
    brands = {
        'Electronics': ['Apple', 'Samsung', 'Sony', 'HP', 'Dell', 'Microsoft'],
        'Clothing': ['Nike', 'Adidas', 'Zara', 'H&M', 'Gap', 'Levis'],
        'Home': ['IKEA', 'Target', 'Home Depot', 'Wayfair', 'West Elm'],
        'Sports': ['Nike', 'Adidas', 'Under Armour', 'REI', 'Patagonia'],
        'Books': ['Penguin', 'Harper', 'Random House', 'Scholastic', 'McGraw Hill']
    }
    
    products = []
    
    for i in range(n_products):
        category = np.random.choice(list(categories.keys()))
        subcategory = np.random.choice(categories[category])
        brand = np.random.choice(brands[category])
        
        # Generate realistic pricing
        if category == 'Electronics':
            cost_price = round(np.random.uniform(50, 800), 2)
        elif category == 'Clothing':
            cost_price = round(np.random.uniform(10, 150), 2)
        elif category == 'Home':
            cost_price = round(np.random.uniform(20, 300), 2)
        elif category == 'Sports':
            cost_price = round(np.random.uniform(15, 200), 2)
        else:  # Books
            cost_price = round(np.random.uniform(8, 40), 2)
        
        list_price = round(cost_price * np.random.uniform(1.3, 2.5), 2)
        
        product = {
            'product_name': f"{brand} {subcategory} {fake.catch_phrase()}",
            'category': category,
            'subcategory': subcategory,
            'brand': brand,
            'cost_price': cost_price,
            'list_price': list_price
        }
        products.append(product)
    
    return pd.DataFrame(products)

def generate_campaigns(n_campaigns=50):
    """Generate marketing campaign data"""
    print(f"Generating {n_campaigns} marketing campaigns...")
    
    channels = ['Google Ads', 'Facebook', 'Instagram', 'Email', 'YouTube', 'TikTok', 'Pinterest']
    
    campaigns = []
    start_date = datetime(2020, 1, 1)
    
    for i in range(n_campaigns):
        campaign_start = fake.date_between(start_date=start_date, end_date='today')
        campaign_end = campaign_start + timedelta(days=np.random.randint(7, 90))
        
        campaign = {
            'campaign_name': f"{fake.company()} {fake.catch_phrase()} Campaign",
            'start_date': campaign_start,
            'end_date': campaign_end,
            'budget': round(np.random.uniform(1000, 50000), 2),
            'channel': np.random.choice(channels)
        }
        campaigns.append(campaign)
    
    return pd.DataFrame(campaigns)

def generate_orders_and_items(customers_df, products_df, campaigns_df, n_orders=50000):
    """Generate orders and order items with realistic patterns"""
    print(f"Generating {n_orders} orders with items...")
    
    orders = []
    order_items = []
    customer_acquisitions = []
    
    # Customer behavior segments
    customers_df['segment'] = np.random.choice(['high_value', 'medium_value', 'low_value'], 
                                             size=len(customers_df), p=[0.2, 0.3, 0.5])
    
    order_statuses = ['Completed', 'Pending', 'Shipped', 'Cancelled', 'Returned']
    payment_methods = ['Credit Card', 'Debit Card', 'PayPal', 'Apple Pay', 'Google Pay']
    
    for order_id in range(1, n_orders + 1):
        # Select customer with some customers having higher probability of ordering
        customer_weights = customers_df['segment'].map({'high_value': 3, 'medium_value': 2, 'low_value': 1})
        customer_idx = np.random.choice(customers_df.index, p=customer_weights/customer_weights.sum())
        customer = customers_df.iloc[customer_idx]
        
        # Generate order date after customer registration
        order_date = fake.date_between(
            start_date=max(customer['registration_date'], datetime(2020, 1, 1).date()),
            end_date='today'
        )
        
        # Seasonal adjustment (higher sales in Nov-Dec)
        month_multiplier = 1.5 if order_date.month in [11, 12] else 1.0
        
        # Generate order
        ship_date = order_date + timedelta(days=np.random.randint(1, 10))
        
        order = {
            'order_id': order_id,
            'customer_id': customer['customer_id'],
            'order_date': order_date,
            'ship_date': ship_date if np.random.random() > 0.1 else None,
            'order_status': np.random.choice(order_statuses, p=[0.7, 0.1, 0.1, 0.05, 0.05]),
            'shipping_cost': round(np.random.uniform(0, 25), 2),
            'payment_method': np.random.choice(payment_methods)
        }
        orders.append(order)
        
        # Generate order items (1-5 items per order)
        n_items = np.random.choice([1, 2, 3, 4, 5], p=[0.4, 0.3, 0.15, 0.1, 0.05])
        selected_products = products_df.sample(n_items)
        
        for _, product in selected_products.iterrows():
            quantity = np.random.choice([1, 2, 3], p=[0.7, 0.2, 0.1])
            unit_price = product['list_price']
            discount = round(unit_price * np.random.uniform(0, 0.3), 2) if np.random.random() > 0.7 else 0
            
            order_item = {
                'order_id': order_id,
                'product_id': product['product_id'],
                'quantity': quantity,
                'unit_price': unit_price,
                'discount_amount': discount
            }
            order_items.append(order_item)
        
        # Generate customer acquisition data (for some orders)
        if np.random.random() > 0.8:  # 20% of orders have acquisition data
            campaign = campaigns_df.sample(1).iloc[0]
            acquisition = {
                'customer_id': customer['customer_id'],
                'campaign_id': campaign['campaign_id'],
                'acquisition_date': order_date,
                'acquisition_cost': round(np.random.uniform(5, 100), 2)
            }
            customer_acquisitions.append(acquisition)
    
    return pd.DataFrame(orders), pd.DataFrame(order_items), pd.DataFrame(customer_acquisitions)

def insert_data_to_db(connection, table_name, df):
    """Insert DataFrame data into MySQL table"""
    if df.empty:
        print(f"No data to insert for {table_name}")
        return
    
    cursor = connection.cursor()
    
    # Get column names excluding auto-increment IDs that aren't in the df
    if table_name == 'customers' and 'customer_id' not in df.columns:
        columns = ', '.join([col for col in df.columns])
    elif table_name == 'products' and 'product_id' not in df.columns:
        columns = ', '.join([col for col in df.columns])
    elif table_name == 'marketing_campaigns' and 'campaign_id' not in df.columns:
        columns = ', '.join([col for col in df.columns])
    else:
        columns = ', '.join(df.columns)
    
    placeholders = ', '.join(['%s'] * len(df.columns))
    
    # Insert query
    query = f"INSERT INTO {table_name} ({columns}) VALUES ({placeholders})"
    
    # Convert DataFrame to list of tuples, handling None values
    data = []
    for row in df.values:
        row_data = tuple(None if pd.isna(val) else val for val in row)
        data.append(row_data)
    
    try:
        cursor.executemany(query, data)
        connection.commit()
        print(f"Successfully inserted {len(data)} records into {table_name}")
    except Error as e:
        print(f"Error inserting data into {table_name}: {e}")
        connection.rollback()
    finally:
        cursor.close()

def main():
    """Main execution function"""
    print("Starting data generation for Northwestern Commerce...")
    
    # Connect to database
    connection = connect_to_database()
    if not connection:
        return
    
    try:
        # Clear existing data
        cursor = connection.cursor()
        cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
        cursor.execute("TRUNCATE TABLE customer_acquisition")
        cursor.execute("TRUNCATE TABLE order_items")
        cursor.execute("TRUNCATE TABLE orders")
        cursor.execute("TRUNCATE TABLE marketing_campaigns")
        cursor.execute("TRUNCATE TABLE products")
        cursor.execute("TRUNCATE TABLE customers")
        cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
        cursor.close()
        print("Cleared existing data...")
        
        # Generate data
        customers_df = generate_customers(10000)
        products_df = generate_products(1000)
        campaigns_df = generate_campaigns(50)
        
        # Insert customers first (for foreign key references)
        insert_data_to_db(connection, 'customers', customers_df)
        
        # Get customer IDs after insertion
        cursor = connection.cursor()
        cursor.execute("SELECT customer_id, email FROM customers ORDER BY customer_id")
        customer_data = cursor.fetchall()
        
        # Map emails to customer_ids
        email_to_id = {}
        for customer_id, email in customer_data:
            email_to_id[email] = customer_id
        
        # Add customer_id to dataframe
        customers_df['customer_id'] = customers_df['email'].map(email_to_id)
        
        # Insert products and campaigns
        insert_data_to_db(connection, 'products', products_df)
        insert_data_to_db(connection, 'marketing_campaigns', campaigns_df)
        
        # Get product and campaign IDs
        cursor.execute("SELECT product_id FROM products ORDER BY product_id")
        product_ids = [row[0] for row in cursor.fetchall()]
        products_df['product_id'] = product_ids
        
        cursor.execute("SELECT campaign_id FROM marketing_campaigns ORDER BY campaign_id")
        campaign_ids = [row[0] for row in cursor.fetchall()]
        campaigns_df['campaign_id'] = campaign_ids
        
        # Generate and insert orders and related data
        orders_df, order_items_df, acquisitions_df = generate_orders_and_items(
            customers_df, products_df, campaigns_df, 50000
        )
        
        insert_data_to_db(connection, 'orders', orders_df)
        insert_data_to_db(connection, 'order_items', order_items_df)
        insert_data_to_db(connection, 'customer_acquisition', acquisitions_df)
        
        print("\nData generation completed successfully!")
        print("Database is ready for analysis.")
        
        # Verify data was created
        cursor.execute("""
            SELECT 
                'customers' as table_name, COUNT(*) as record_count FROM customers
                UNION ALL
                SELECT 'products', COUNT(*) FROM products  
                UNION ALL
                SELECT 'orders', COUNT(*) FROM orders
                UNION ALL
                SELECT 'order_items', COUNT(*) FROM order_items
                UNION ALL
                SELECT 'marketing_campaigns', COUNT(*) FROM marketing_campaigns
                UNION ALL
                SELECT 'customer_acquisition', COUNT(*) FROM customer_acquisition
        """)
        
        results = cursor.fetchall()
        print("\n=== Data Summary ===")
        for table_name, count in results:
            print(f"{table_name}: {count:,} records")
        
        cursor.close()
        
    except Exception as e:
        print(f"Error during data generation: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if connection and connection.is_connected():
            connection.close()
            print("\nMySQL connection closed.")

if __name__ == "__main__":
    main()
