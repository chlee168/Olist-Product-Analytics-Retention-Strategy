# 🛒 Olist E-Commerce: Product Analytics & Growth Strategy

## 📈 Executive Summary
This project analyzes **100,000+ orders** to identify why customers churn and how to improve retention. By engineering **Acquisition Cohorts** and performing **Anomaly Detection**, I identified that logistics delays are the primary driver of one-time buyer behavior.

## 🚀 Key Business Insights
*   **Retention Cliff:** 95% of users churn after the first month (Month 2). The product is currently transactional, not habit-forming.
*   **Logistics Anomaly:** Customers who churned experienced delivery delays **3 days longer** than repeat buyers. Logistics is a revenue driver.
*   **Whale Risk:** 5% of users (Whales) contribute ~20% of revenue, suggesting a need for a VIP Loyalty Program.
*   **Salary Cycle Spikes:** Engagement peaks during the **first week of every month**, aligning with the Brazilian salary cycle.

## 🛠 Tech Stack
*   **Python:** Pandas (Data Engineering), Seaborn (Statistical Visualization).
*   **Product Metrics:** Cohort Analysis, Retention Rate, DAU, AOV.
*   **Power BI:** DAX for advanced calculated measures and interactive reporting.

## 📂 Project Structure
*   `notebooks/`: Contains the end-to-end data cleaning and statistical analysis.
*   `dashboard/`: The Power BI file used for executive reporting.
*   `data/`: Cleaned dataset ready for visualization.

---

## 🔍 Analytical Deep Dive

### 1. Cohort Retention Matrix
I calculated the **Cohort Index** to align users from different years onto a single timeline. This revealed that Month 2 is the most critical window for re-engagement.

### 2. Root Cause of Churn (Anomaly Detection)
I correlated **Delivery Performance** with customer loyalty. The data proves that late deliveries are the #1 reason users do not return for a second purchase.

### 3. DAU "Heartbeat" Analysis
By analyzing daily activity, I proved that **purchasing power is cyclical**, peaking in the first 7 days of the month.
