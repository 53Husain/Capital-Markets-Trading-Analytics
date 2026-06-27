USE capital_markets;

-- ============================================================================
-- 1. SECTOR PERFORMANCE (Which sectors have the highest trading volume?)
-- ============================================================================
SELECT 
    c.sector,
    COUNT(t.trade_id) AS total_trades,
    SUM(t.quantity) AS total_volume_traded,
    ROUND(SUM(t.quantity * t.price), 2) AS total_trade_value
FROM trades t
JOIN companies c ON t.company_id = c.company_id
GROUP BY c.sector
ORDER BY total_trade_value DESC;


-- ============================================================================
-- 2. CLIENT PROFITABILITY (Top 10 Most Valuable Portfolios)
-- ============================================================================
SELECT 
    cl.client_id,
    CONCAT(cl.first_name, ' ', cl.last_name) AS client_name,
    cl.risk_profile,
    COUNT(p.company_id) AS unique_stocks_held,
    ROUND(SUM(p.current_value), 2) AS total_portfolio_value,
    ROUND(SUM(p.current_value - (p.quantity_held * p.average_buy_price)), 2) AS unrealized_profit
FROM portfolio p
JOIN clients cl ON p.client_id = cl.client_id
GROUP BY cl.client_id, client_name, cl.risk_profile
ORDER BY total_portfolio_value DESC
LIMIT 10;


-- ============================================================================
-- 3. STOCK VOLATILITY (Window Function: Find the highest single-day price swings)
-- ============================================================================
WITH DailySwings AS (
    SELECT 
        c.stock_symbol,
        sp.trade_date,
        sp.high_price,
        sp.low_price,
        ROUND(sp.high_price - sp.low_price, 2) AS price_swing,
        ROUND(((sp.high_price - sp.low_price) / sp.open_price) * 100, 2) AS swing_percentage
    FROM stock_prices sp
    JOIN companies c ON sp.company_id = c.company_id
)
SELECT * FROM DailySwings
WHERE swing_percentage > 2.0 -- Showing only days with high volatility (>2% swing)
ORDER BY swing_percentage DESC
LIMIT 20;


-- ============================================================================
-- 4. BROKERAGE REVENUE (How much in fees did the firm make per month?)
-- ============================================================================
SELECT 
    DATE_FORMAT(trade_datetime, '%Y-%m') AS trade_month,
    COUNT(trade_id) AS total_trades,
    ROUND(SUM(brokerage_fee), 2) AS total_brokerage_revenue
FROM trades
GROUP BY trade_month
ORDER BY trade_month DESC;


-- ============================================================================
-- 5. RISK ANALYSIS (High-Risk Clients heavily invested in a single stock)
-- ============================================================================
-- Using CTE to find clients whose single stock holding is over 500,000
WITH HeavyBags AS (
    SELECT 
        p.client_id,
        c.stock_symbol,
        p.current_value,
        RANK() OVER(PARTITION BY p.client_id ORDER BY p.current_value DESC) as portfolio_rank
    FROM portfolio p
    JOIN companies c ON p.company_id = c.company_id
)
SELECT 
    cl.client_id,
    CONCAT(cl.first_name, ' ', cl.last_name) AS client_name,
    cl.risk_profile,
    hb.stock_symbol AS largest_holding,
    hb.current_value AS holding_value
FROM HeavyBags hb
JOIN clients cl ON hb.client_id = cl.client_id
WHERE hb.portfolio_rank = 1 
  AND cl.risk_profile = 'High'
  AND hb.current_value > 500000
ORDER BY hb.current_value DESC;