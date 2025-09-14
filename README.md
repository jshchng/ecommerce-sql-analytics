# Northwestern Commerce SQL Analytics Project

---

## Project Overview

Comprehensive SQL analytics project analyzing e-commerce business performance, customer behavior, and operational metrics for Northwestern Commerce, a simulated online retailer.

## Business Impact
- Identified $15.1M in annual revenue from top 20% of customers
- Discovered 3,478 customers as churn risks requiring immediate retention strategies
- Found cross-selling opportunities worth $2,809 in potential revenue lift
- Automated reporting pipeline reducing analysis time from days to minutes

## Key Findings
1. **Customer Segmentation**: High Value customers (8,313 customers) generate $31.3M / 99% of revenue
2. **Seasonal Trends**: Q3 generates the highest revenue ($10.7M), while Q4 shows decline to $5.6M
3. **Product Performance**: Clothing category leads in profit margin (45.63%), followed by Electronics (45.43%)
4. **Growth Patterns**: Peak monthly revenue of $2.6M achieved in August 2025 with 18.43% growth

## Technical Skills Demonstrated
- **Advanced SQL**: CTEs, Window Functions, Complex JOINs
- **Customer Analytics**: RFM segmentation, cohort analysis, churn prediction
- **Business Intelligence**: KPI dashboards, trend analysis, performance metrics
- **Database Design**: Normalized schema, optimized indexing, data integrity

---

## Prerequisites

- MySQL or compatible relational database  
- SQL client (MySQL Workbench, CLI, or VS Code SQL extension)  
- Optional: Python or R for additional analysis or visualization  

---

## Setup Instructions

1. **Clone and Setup Database**
```bash
git clone https://github.com/jshchng/ecommerce-sql-analytics
cd ecommerce-sql-analytics
mysql -u root -p < data/schema.sql
```

2. **Generate Sample Data**
```bash
pip install -r requirements.txt
python data/generate_data.py
```

3. **Execute Analysis**
```bash
mysql -u root -p northwestern_commerce < analysis/01_exploratory_analysis.sql > reports/exploratory_results.txt
mysql -u root -p northwestern_commerce < analysis/02_customer_segmentation.sql > reports/segmentation_results.txt
mysql -u root -p northwestern_commerce < analysis/03_product_performance.sql > reports/product_results.txt
mysql -u root -p northwestern_commerce < analysis/04_cohort_analysis.sql > reports/cohort_results.txt
mysql -u root -p northwestern_commerce < analysis/05_business_metrics.sql > reports/kpi_results.txt
```

---

## Analysis Results
Detailed analysis outputs are available in `/reports`:
- `exploratory_results.txt` - Basic business metrics and trends
- `segmentation_results.txt` - Customer RFM analysis
- `product_results.txt` - Product performance analysis
- `cohort_results.txt` - Customer retention analysis
- `kpi_results.txt` - Executive dashboard metrics

