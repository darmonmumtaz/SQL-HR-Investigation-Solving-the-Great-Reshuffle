# SQL-HR-Investigation-Solving-the-Great-Reshuffle

## Project Overview

This project analyzes workforce data using advanced SQL to uncover patterns in:

* Employee attrition
* Management effectiveness
* Gender pay equity
* Performance trends
* Flight risk prediction

Using a normalized HR database (5 relational tables), the project demonstrates how SQL can transform raw HR data into strategic insights for leadership decision-making.

Rather than relying on dashboards alone, this project focuses on **analytical SQL logic** — turning business problems into structured, query-driven solutions.

## Business Questions Addressed

* What is the overall attrition rate?
* Which departments and managers have the highest team attrition?
* Is there a measurable gender pay gap by department and job level?
* Which active employees show early warning signs of leaving?
* What patterns emerge from exit interview data?

The queries provide measurable outputs such as:

* Department-level attrition percentages
* Manager risk categorization (High / Moderate / Stable)
* Gender pay gap % with severity thresholds
* Flight risk scores (0–100 weighted scoring model)
* Intersectional workforce analysis (ethnicity × gender)

## Technical Skills Demonstrated

### Advanced SQL Techniques

* Complex Common Table Expressions (CTEs)
* Window Functions (`OVER PARTITION BY`)
* Conditional Aggregation (`CASE WHEN`)
* Correlated Subqueries
* Derived Metrics & Risk Scoring Models
* Tenure Bucketing Logic using `DATEDIFF`
* Statistical Pay Gap Calculations
* Executive Dashboard Query Design
* Multi-table Joins with Foreign Keys
* Normalized Relational Data Modeling

## Analytical Highlights

### 1. Attrition Analysis

* Company-wide attrition rate calculation
* Tenure bucket breakdown (0–6 months, 6–12 months, 1–3 years, etc.)
* Department-level attrition comparison
* Manager-level attrition risk flagging

### 2. Gender Pay Gap (DEI Focus)

* Salary comparison by job level & department
* Gap percentage calculation
* Severity classification (Within Range / Moderate / Critical)

### 3. Flight Risk Prediction Model

Custom weighted scoring model based on:

* Performance rating
* Salary growth vs department average
* Tenure stage

Outputs:

* Flight Risk Score (0–100)
* Risk Category (Low → Critical)

### 4. Intersectionality & Exit Analysis

* Salary and performance trends by gender and ethnicity
* Attrition rate by demographic group
* Exit reason frequency and satisfaction scoring

## Database Structure

**5 Normalized Tables:**

* `Departments`
* `Employees`
* `Salaries`
* `Performance_Reviews`
* `Attrition_Data`

Includes:

* Foreign key relationships
* Historical salary tracking
* Performance review history
* Dedicated attrition tracking table

## Executive Dashboard Queries

The project includes dashboard-ready queries for:

* Headcount trends
* Attrition rate (rolling 12 months)
* Gender diversity ratio
* Prioritized HR recommendations

## Tools & Technologies

* **MySQL**
* SQL (Advanced Query Design)
* Excel (Data population)
* Data modeling & normalization principles

## 📁 Repository Structure

```
SQL_Scripts/
│── 01_database_setup.sql
│── 02_data_generation.sql
│── 03_analytical_queries.sql
│── 04_executive_dashboard.sql

Visualizations/
Presentation/
README.md
```

## Why This Project Stands Out

* Focuses on business impact, not just queries
* Demonstrates predictive thinking using SQL only
* Applies HR analytics concepts (DEI, retention, management risk)
* Bridges technical SQL skills with strategic workforce insights
* Structured like a real-world enterprise HR analytics initiative

## Key Takeaway

Data-driven HR is not about reports — it’s about identifying risk early, improving retention strategy, and enabling equitable compensation decisions through measurable analytics.

This project demonstrates how SQL alone can power executive-level workforce intelligence.

## darmonmumtaz00@gmail.com
## https://www.linkedin.com/in/darmonmumtaz/
