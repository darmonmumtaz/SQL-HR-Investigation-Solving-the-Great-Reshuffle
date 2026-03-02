-- Datebase Setup and Data Generation

-- STEP 1: CREATE THE DATABASE AND TABLES

CREATE DATABASE EmployeeAnalytics;
USE EmployeeAnalytics;

-- 1. Creating Tables

-- 1.1 Create Departments table
CREATE TABLE Departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    cost_center VARCHAR(20),
    headcount_budget INT
);

-- 1.2 Create Employees table (core table)
CREATE TABLE Employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    gender VARCHAR(20),
    ethnicity VARCHAR(50),
    age INT,
    hire_date DATE,
    termination_date DATE NULL,
    termination_reason VARCHAR(100) NULL,
    department_id INT,
    manager_id INT,
    job_title VARCHAR(100),
    location VARCHAR(100),
    FOREIGN KEY (department_id) REFERENCES Departments(department_id),
    FOREIGN KEY (manager_id) REFERENCES Employees(employee_id)
);

-- 1.3 Create Salaries table (historical salary data)
CREATE TABLE Salaries (
    salary_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT,
    salary_amount DECIMAL(10,2),
    effective_date DATE,
    end_date DATE NULL,
    change_reason VARCHAR(50),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);

-- 1.4 Create Performance_Reviews table
CREATE TABLE Performance_Reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT,
    review_date DATE,
    review_period VARCHAR(20),
    rating DECIMAL(3,2), -- e.g., 1.0 to 5.0
    reviewer_id INT,
    comments TEXT,
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id),
    FOREIGN KEY (reviewer_id) REFERENCES Employees(employee_id)
);

-- 1.5 Create a dedicated Attrition table for terminated employees
CREATE TABLE Attrition_Data (
    attrition_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT,
    termination_date DATE,
    termination_reason VARCHAR(100),
    exit_interview_feedback TEXT,
    years_at_company DECIMAL(5,2),
    last_performance_rating DECIMAL(3,2),
    satisfaction_score INT, -- 1-10 scale from exit survey
    eligible_for_rehire BOOLEAN,
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);

-- 2. Tables populated using Excel/ CSV

-- 3. BUSINESS ANALYSIS QUERIES

-- 3.1 OVERALL ATTRITION METRICS
-- Calculate company-wide attrition rate
SELECT 
    COUNT(DISTINCT CASE WHEN termination_date IS NOT NULL THEN employee_id END) as terminated_count,
    COUNT(DISTINCT employee_id) as total_employees,
    ROUND(100 * COUNT(DISTINCT CASE WHEN termination_date IS NOT NULL THEN employee_id END) / 
          NULLIF(COUNT(DISTINCT employee_id), 0), 2) as attrition_rate_percent
FROM Employees;

-- 3.2 ATTRITION BY DEPARTMENT

SELECT 
    d.department_name,
    COUNT(e.employee_id) as total_employees,
    SUM (CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) AS terminated_employees,
    ROUND(
        100 * SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) / 
        NULLIF(COUNT(e.employee_id), 0), 
        2
    ) as attrition_rate,
    GROUP_CONCAT(DISTINCT e.termination_reason) as reasons
FROM Employees e
JOIN Departments d ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY attrition_rate DESC;

-- 3.3 ATTRITION BY TENURE BUCKETS (Critical Analysis)

WITH tenure_analysis AS (
    SELECT 
        employee_id,
        CASE 
            WHEN termination_date IS NOT NULL THEN 'Terminated'
            ELSE 'Active'
        END as employment_status,
        CASE 
            WHEN DATEDIFF(COALESCE(termination_date, CURDATE()), hire_date) < 180 THEN '0-6 months'
            WHEN DATEDIFF(COALESCE(termination_date, CURDATE()), hire_date) BETWEEN 180 AND 365 THEN '6-12 months'
            WHEN DATEDIFF(COALESCE(termination_date, CURDATE()), hire_date) BETWEEN 366 AND 1095 THEN '1-3 years'
            WHEN DATEDIFF(COALESCE(termination_date, CURDATE()), hire_date) BETWEEN 1096 AND 1825 THEN '3-5 years'
            ELSE '5+ years'
        END as tenure_bucket,
        termination_reason
    FROM Employees
)

SELECT 
    tenure_bucket,
    COUNT(*) as total_employees_in_bucket,
    SUM(CASE WHEN employment_status = 'Terminated' THEN 1 ELSE 0 END) as terminated_count,
    ROUND(100 * SUM(CASE WHEN employment_status = 'Terminated' THEN 1 ELSE 0 END) / 
          NULLIF(COUNT(*), 0), 2) as attrition_rate,
    -- Top reasons for this tenure bucket
    (SELECT termination_reason 
     FROM tenure_analysis t2 
     WHERE t2.tenure_bucket = t1.tenure_bucket 
       AND t2.termination_reason IS NOT NULL
     GROUP BY termination_reason 
     ORDER BY COUNT(*) DESC 
     LIMIT 1) as primary_reason
FROM tenure_analysis t1
GROUP BY tenure_bucket
ORDER BY 
    CASE tenure_bucket
        WHEN '0-6 months' THEN 1
        WHEN '6-12 months' THEN 2
        WHEN '1-3 years' THEN 3
        WHEN '3-5 years' THEN 4
        ELSE 5
    END;
    
-- 3.4 ATTRITION BY MANAGER (Identifying management issues)
SELECT 
    CONCAT(m.first_name, ' ', m.last_name) as manager_name,
    d.department_name,
    COUNT(e.employee_id) as team_size,
    SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) as team_terminations,
    ROUND(100 * SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) / 
          NULLIF(COUNT(e.employee_id), 0), 2) as team_attrition_rate,
    ROUND(AVG(pr.rating), 2) as avg_team_performance,
    -- Flag managers with high attrition
    CASE 
        WHEN ROUND(100 * SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) / 
             NULLIF(COUNT(e.employee_id), 0), 2) > 25 THEN 'HIGH RISK MANAGER'
        WHEN ROUND(100 * SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) / 
             NULLIF(COUNT(e.employee_id), 0), 2) BETWEEN 15 AND 25 THEN 'MODERATE RISK'
        ELSE 'STABLE'
    END as risk_status
FROM Employees e
JOIN Employees m ON e.manager_id = m.employee_id
JOIN Departments d ON m.department_id = d.department_id
LEFT JOIN Performance_Reviews pr ON e.employee_id = pr.employee_id
GROUP BY m.employee_id, manager_name, d.department_name
HAVING COUNT(e.employee_id) >= 3  -- Only managers with at least 3 direct reports
ORDER BY team_attrition_rate DESC;

-- 3.5 GENDER PAY GAP ANALYSIS (DEI Focus)
WITH current_salaries AS (
    SELECT 
        e.employee_id,
        e.gender,
        e.ethnicity,
        e.job_title,
        e.department_id,
        d.department_name,
        s.salary_amount,
        CASE 
            WHEN e.job_title LIKE '%VP%' OR e.job_title LIKE '%Chief%' THEN 'Executive'
            WHEN e.job_title LIKE '%Director%' THEN 'Director'
            WHEN e.job_title LIKE '%Manager%' THEN 'Manager'
            WHEN e.job_title LIKE '%Senior%' OR e.job_title LIKE '%Lead%' THEN 'Senior Individual'
            ELSE 'Individual Contributor'
        END as job_level
    FROM Employees e
    JOIN Salaries s ON e.employee_id = s.employee_id
    JOIN Departments d ON e.department_id = d.department_id
    WHERE s.end_date > CURDATE()
)
SELECT 
    job_level,
    -- Less granular grouping for more results
    department_name,
    -- Male stats
    ROUND(AVG(CASE WHEN gender = 'Male' THEN salary_amount END), 0) as avg_male_salary,
    COUNT(CASE WHEN gender = 'Male' THEN 1 END) as male_count,
    -- Female stats
    ROUND(AVG(CASE WHEN gender = 'Female' THEN salary_amount END), 0) as avg_female_salary,
    COUNT(CASE WHEN gender = 'Female' THEN 1 END) as female_count,
    -- Pay gap calculation
    ROUND(
        100 * (AVG(CASE WHEN gender = 'Male' THEN salary_amount END) - 
               AVG(CASE WHEN gender = 'Female' THEN salary_amount END)) / 
        NULLIF(AVG(CASE WHEN gender = 'Male' THEN salary_amount END), 0), 
    2) as gender_pay_gap_percent,
    CASE 
        WHEN ROUND(100 * (AVG(CASE WHEN gender = 'Male' THEN salary_amount END) - 
                         AVG(CASE WHEN gender = 'Female' THEN salary_amount END)) / 
                  NULLIF(AVG(CASE WHEN gender = 'Male' THEN salary_amount END), 0), 2) > 10 THEN 'CRITICAL GAP'
        WHEN ROUND(100 * (AVG(CASE WHEN gender = 'Male' THEN salary_amount END) - 
                         AVG(CASE WHEN gender = 'Female' THEN salary_amount END)) / 
                  NULLIF(AVG(CASE WHEN gender = 'Male' THEN salary_amount END), 0), 2) BETWEEN 5 AND 10 THEN 'MODERATE GAP'
        ELSE 'WITHIN RANGE'
    END as gap_severity
FROM current_salaries
WHERE gender IN ('Male', 'Female')
-- Removed job_title from GROUP BY to get more results
GROUP BY job_level, department_name  
-- Relaxed the HAVING condition
HAVING male_count >= 2 AND female_count >= 2  
ORDER BY gender_pay_gap_percent DESC;

-- 3.6 FLIGHT RISK ANALYSIS (Predictive Indicator)

WITH salary_history AS (
    -- Calculate salary increases over last 2 years
    SELECT 
        employee_id,
        MAX(CASE WHEN effective_date >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR) THEN salary_amount END) as salary_2y_ago,
        MAX(CASE WHEN effective_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN salary_amount END) as salary_1y_ago,
        MAX(salary_amount) as current_salary
    FROM Salaries
    GROUP BY employee_id
),
performance_history AS (
    -- Get latest performance ratings
    SELECT 
        employee_id,
        AVG(rating) as avg_rating,
        COUNT(*) as review_count,
        MAX(review_date) as last_review
    FROM Performance_Reviews
    GROUP BY employee_id
),
flight_risk_calculation AS (
    SELECT 
        e.employee_id,
        CONCAT(e.first_name, ' ', e.last_name) as employee_name,
        e.job_title,
        d.department_name,
        CONCAT(m.first_name, ' ', m.last_name) as manager_name,
        e.hire_date,
        DATEDIFF(CURDATE(), e.hire_date)/365 as years_at_company,
        ph.avg_rating as performance_rating,
        -- Calculate salary increase percentage
        ROUND(100 * (sh.current_salary - sh.salary_2y_ago) / NULLIF(sh.salary_2y_ago, 0), 2) as salary_increase_2yr_pct,
        -- Compare to department average increase
        ROUND(AVG(100 * (sh.current_salary - sh.salary_2y_ago) / NULLIF(sh.salary_2y_ago, 0)) OVER (PARTITION BY e.department_id), 2) as dept_avg_increase_pct,
        -- Tenure bucket
        CASE 
            WHEN DATEDIFF(CURDATE(), e.hire_date) < 180 THEN '0-6 months'
            WHEN DATEDIFF(CURDATE(), e.hire_date) BETWEEN 180 AND 365 THEN '6-12 months'
            WHEN DATEDIFF(CURDATE(), e.hire_date) BETWEEN 366 AND 1095 THEN '1-3 years'
            WHEN DATEDIFF(CURDATE(), e.hire_date) BETWEEN 1096 AND 1825 THEN '3-5 years'
            ELSE '5+ years'
        END as tenure_bucket
    FROM Employees e
    JOIN Departments d ON e.department_id = d.department_id
    LEFT JOIN Employees m ON e.manager_id = m.employee_id
    LEFT JOIN salary_history sh ON e.employee_id = sh.employee_id
    LEFT JOIN performance_history ph ON e.employee_id = ph.employee_id
    WHERE e.termination_date IS NULL  -- Only active employees
)
SELECT 
    employee_name,
    job_title,
    department_name,
    manager_name,
    tenure_bucket,
    years_at_company,
    performance_rating,
    salary_increase_2yr_pct,
    dept_avg_increase_pct,
    -- Calculate Flight Risk Score (0-100)
    ROUND(
        (CASE 
            WHEN performance_rating >= 4.5 THEN 30  -- High performers more likely to leave if underpaid
            WHEN performance_rating >= 4.0 THEN 20
            ELSE 10
         END +
         CASE 
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct * 0.5 THEN 40  -- Significantly under market
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct THEN 25
            ELSE 10
         END +
         CASE 
            WHEN tenure_bucket = '6-12 months' THEN 30  -- High risk period
            WHEN tenure_bucket = '1-3 years' THEN 20
            WHEN tenure_bucket = '3-5 years' THEN 15
            ELSE 10
         END)
    , 0) as flight_risk_score,
    -- Risk Category
    CASE 
        WHEN (CASE 
            WHEN performance_rating >= 4.5 THEN 30
            WHEN performance_rating >= 4.0 THEN 20
            ELSE 10
         END +
         CASE 
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct * 0.5 THEN 40
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct THEN 25
            ELSE 10
         END +
         CASE 
            WHEN tenure_bucket = '6-12 months' THEN 30
            WHEN tenure_bucket = '1-3 years' THEN 20
            WHEN tenure_bucket = '3-5 years' THEN 15
            ELSE 10
         END) >= 70 THEN 'CRITICAL FLIGHT RISK'
        WHEN (CASE 
            WHEN performance_rating >= 4.5 THEN 30
            WHEN performance_rating >= 4.0 THEN 20
            ELSE 10
         END +
         CASE 
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct * 0.5 THEN 40
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct THEN 25
            ELSE 10
         END +
         CASE 
            WHEN tenure_bucket = '6-12 months' THEN 30
            WHEN tenure_bucket = '1-3 years' THEN 20
            WHEN tenure_bucket = '3-5 years' THEN 15
            ELSE 10
         END) BETWEEN 50 AND 69 THEN 'HIGH FLIGHT RISK'
        WHEN (CASE 
            WHEN performance_rating >= 4.5 THEN 30
            WHEN performance_rating >= 4.0 THEN 20
            ELSE 10
         END +
         CASE 
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct * 0.5 THEN 40
            WHEN salary_increase_2yr_pct < dept_avg_increase_pct THEN 25
            ELSE 10
         END +
         CASE 
            WHEN tenure_bucket = '6-12 months' THEN 30
            WHEN tenure_bucket = '1-3 years' THEN 20
            WHEN tenure_bucket = '3-5 years' THEN 15
            ELSE 10
         END) BETWEEN 30 AND 49 THEN 'MODERATE RISK'
        ELSE 'LOW RISK'
    END as risk_category
FROM flight_risk_calculation
WHERE performance_rating IS NOT NULL
ORDER BY flight_risk_score DESC
LIMIT 20;

-- 3.7 INTERSECTIONALITY ANALYSIS (DEI Deep Dive)
SELECT 
    e.ethnicity,
    e.gender,
    COUNT(DISTINCT e.employee_id) as employee_count,
    ROUND(AVG(s.salary_amount), 0) as avg_salary,
    ROUND(AVG(pr.rating), 2) as avg_performance,
    SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) as terminated_count,
    ROUND(100 * SUM(CASE WHEN e.termination_date IS NOT NULL THEN 1 ELSE 0 END) / 
          NULLIF(COUNT(DISTINCT e.employee_id), 0), 2) as attrition_rate,
    -- Representation percentage
    ROUND(100 * COUNT(DISTINCT e.employee_id) / 
          (SELECT COUNT(*) FROM Employees), 2) as pct_of_workforce
FROM Employees e
LEFT JOIN Salaries s ON e.employee_id = s.employee_id AND s.end_date > CURDATE()
LEFT JOIN Performance_Reviews pr ON e.employee_id = pr.employee_id
GROUP BY e.ethnicity, e.gender
HAVING COUNT(DISTINCT e.employee_id) >= 3
ORDER BY avg_salary DESC;

-- 3.8 EXIT INTERVIEW ANALYSIS (Qualitative Patterns)
SELECT 
    termination_reason,
    COUNT(*) as frequency,
    ROUND(AVG(years_at_company), 1) as avg_tenure_years,
    ROUND(AVG(last_performance_rating), 2) as avg_perf_before_exit,
    ROUND(AVG(satisfaction_score), 1) as avg_exit_satisfaction,
    -- Most common demographic leaving for this reason
    (SELECT e2.gender 
     FROM Attrition_Data a2 
     JOIN Employees e2 ON a2.employee_id = e2.employee_id
     WHERE a2.termination_reason = a1.termination_reason
     GROUP BY e2.gender 
     ORDER BY COUNT(*) DESC 
     LIMIT 1) as predominant_gender,
    -- Department most affected
    (SELECT d.department_name 
     FROM Attrition_Data a2 
     JOIN Employees e2 ON a2.employee_id = e2.employee_id
     JOIN Departments d ON e2.department_id = d.department_id
     WHERE a2.termination_reason = a1.termination_reason
     GROUP BY d.department_name 
     ORDER BY COUNT(*) DESC 
     LIMIT 1) as department_most_affected
FROM Attrition_Data a1
GROUP BY termination_reason
ORDER BY frequency DESC;


-- STEP 4: EXECUTIVE SUMMARY DASHBOARD QUERIES

-- 4.1 Key HR Metrics Dashboard
SELECT 
    'HEADCOUNT' as metric,
    COUNT(*) as current_value,
    (SELECT COUNT(*) FROM Employees WHERE hire_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)) as previous_year,
    ROUND(100 * (COUNT(*) - (SELECT COUNT(*) FROM Employees WHERE hire_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR))) / 
          NULLIF((SELECT COUNT(*) FROM Employees WHERE hire_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)), 0), 2) as growth_pct
FROM Employees
WHERE termination_date IS NULL

UNION ALL

SELECT 
    'ATTRITION_RATE' as metric,
    ROUND(100 * SUM(CASE WHEN termination_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN 1 ELSE 0 END) / 
          NULLIF(COUNT(CASE WHEN hire_date <= DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN 1 END), 0), 2) as current_value,
    NULL as previous_year,
    NULL as growth_pct
FROM Employees

UNION ALL

SELECT 
    'GENDER_DIVERSITY_SCORE' as metric,
    ROUND(100 * SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) / COUNT(*), 2) as current_value,
    NULL as previous_year,
    NULL as growth_pct
FROM Employees
WHERE termination_date IS NULL;

-- 4.2 Retention Recommendations Generator
WITH insights AS (
    -- Tenure insight
    SELECT 
        'TENURE' as insight_type,
        '6-12 month employees have highest attrition' as finding,
        'Implement structured onboarding buddy program and 9-month check-ins' as recommendation,
        1 as priority
    UNION
    -- Manager insight
    SELECT 
        'MANAGEMENT' as insight_type,
        '3 managers have >25% attrition rates' as finding,
        'Provide additional management training and 360-degree feedback' as recommendation,
        1 as priority
    UNION
    -- Pay gap insight
    SELECT 
        'COMPENSATION' as insight_type,
        '5% pay gap exists in mid-management roles' as finding,
        'Conduct compensation equity review and adjustments' as recommendation,
        2 as priority
    UNION
    -- Flight risk insight
    SELECT 
        'RETENTION' as insight_type,
        'High performers with low salary increases identified' as finding,
        'Create retention bonus program and career pathing' as recommendation,
        1 as priority
    UNION
    -- Exit reason insight
    SELECT 
        'EXIT_REASONS' as insight_type,
        'Career growth and compensation top exit reasons' as finding,
        'Enhance internal mobility programs and promotion pathways' as recommendation,
        2 as priority
)
SELECT * FROM insights
ORDER BY priority, insight_type;

