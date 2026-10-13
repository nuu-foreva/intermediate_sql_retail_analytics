# Retail Sales Analytics --- Intermediate SQL Portfolio Project

## Overview

This project analyzes a fictional retail business using PostgreSQL. It
demonstrates intermediate SQL skills through data-quality checks, text
cleaning, CTEs, aggregate analysis, window functions, month-over-month
growth, customer value ranking, and RFM-style segmentation.

**Dataset:** `data/retail_orders.csv` --- 250 fictional order records
dated in 2025. Names and transactions are synthetic and do not represent
real customers.

## Business questions

1.  How clean and complete is the data?
2.  How does monthly revenue change over time?
3.  Which product categories and products generate the most revenue?
4.  Who are the highest-value customers?
5.  Which customers are loyal, recent, at risk, or one-time buyers?
6.  Which payment methods contribute the most revenue?
7.  Which categories have the highest return/cancellation rates?
8.  Do stored order totals match recalculated totals?

## Skills demonstrated

-   `CREATE TABLE`, `VIEW`, `DROP TABLE`
-   CSV loading with PostgreSQL `\copy`
-   Data cleaning with `TRIM`, `INITCAP`, `NULLIF`, and `COALESCE`
-   Aggregations and conditional aggregates using `FILTER`
-   CTEs (`WITH`)
-   Window functions: `LAG`, `DENSE_RANK`, and windowed `SUM`
-   Date functions and month-level grouping
-   Safe division with `NULLIF`
-   Customer metrics and CASE-based segmentation

## Requirements

-   PostgreSQL 14 or newer
-   `psql` command-line client, or a PostgreSQL GUI such as pgAdmin

## How to run

1.  Create an empty database, for example `retail_analytics`.

2.  Open a terminal in this project folder.

3.  Run:

    ``` bash
    psql -U postgres -d retail_analytics -f sql/retail_sales_analysis.sql
    ```

    Replace `postgres` with your PostgreSQL username if needed.

4.  The script drops and recreates the `retail_orders` table and the
    `cleaned_retail_orders` view, imports the CSV, and runs the analysis
    queries. It is safe to re-run.

5.  Review the result sets in the terminal or your SQL client.

**Important:** PostgreSQL's `\copy` command reads
`data/retail_orders.csv` relative to your current terminal directory.
Run the command from the project root. If you use pgAdmin's query tool,
import the CSV using its Import/Export feature, then run the SQL from
the `CREATE OR REPLACE VIEW` section onward (skip the `\copy` line).

## Repository structure

``` text
intermediate_sql_retail_analytics/
├── data/
│   └── retail_orders.csv
├── sql/
│   └── retail_sales_analysis.sql
├── .gitignore
└── README.md
```

## Portfolio note

This is a practice project built on synthetic data. Before presenting
findings in a portfolio, run the queries and write a short results
summary based on the actual output. Do not claim business findings that
you have not verified.

## Possible extensions

-   Add indexes and compare query plans with `EXPLAIN ANALYZE`.
-   Build a monthly sales dashboard in Power BI or Tableau.
-   Create a stored procedure to refresh the analysis.
-   Add tests for duplicate IDs, invalid statuses, and inconsistent
    totals.
