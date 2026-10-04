/*=============================================================
  Integration tests for SUPPLY_CHAIN_AGENT
  Run in Snowflake via: snow sql -f tests/test_agent_integration.sql
  All assertions use IFF — a failing test returns FAIL.
=============================================================*/

-- ────────────────────────────────────────────────────────────
-- Test 1: Agent exists and is configured
-- ────────────────────────────────────────────────────────────
SHOW AGENTS LIKE 'SUPPLY_CHAIN_AGENT' IN SCHEMA SUPPLY_CHAIN.CORE;

SELECT 'test_agent_exists' AS test_name,
       IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ────────────────────────────────────────────────────────────
-- Test 2: Semantic view exists
-- ────────────────────────────────────────────────────────────
SHOW SEMANTIC VIEWS LIKE 'SUPPLY_CHAIN_ANALYTICS' IN SCHEMA SUPPLY_CHAIN.CORE;

SELECT 'test_semantic_view_exists' AS test_name,
       IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS result
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ────────────────────────────────────────────────────────────
-- Test 3: Agent responds to a simple question (non-empty)
-- ────────────────────────────────────────────────────────────
SELECT 'test_agent_simple_question' AS test_name,
       IFF(
         resp:status::STRING = 'completed'
         AND ARRAY_SIZE(resp:content) > 0,
         'PASS', 'FAIL'
       ) AS result
FROM (
  SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
      'SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_AGENT',
      $${"messages":[{"role":"user","content":[{"type":"text","text":"How many orders are there?"}]}]}$$
    )
  ) AS resp
);

-- ────────────────────────────────────────────────────────────
-- Test 4: Agent returns SQL in tool_result for an analytics question
-- ────────────────────────────────────────────────────────────
SELECT 'test_agent_returns_sql' AS test_name,
       IFF(
         CAST(resp AS VARCHAR) ILIKE '%system_execute_sql%'
         AND CAST(resp AS VARCHAR) ILIKE '%SELECT%',
         'PASS', 'FAIL'
       ) AS result
FROM (
  SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
      'SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_AGENT',
      $${"messages":[{"role":"user","content":[{"type":"text","text":"What is the total order value by status?"}]}]}$$
    )
  ) AS resp
);

-- ────────────────────────────────────────────────────────────
-- Test 5: Agent cites canonical OTD definition
-- ────────────────────────────────────────────────────────────
SELECT 'test_agent_cites_otd_definition' AS test_name,
       IFF(
         CAST(resp AS VARCHAR) ILIKE '%confirmed%date%'
         AND CAST(resp AS VARCHAR) ILIKE '%deliver%',
         'PASS', 'FAIL'
       ) AS result
FROM (
  SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
      'SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_AGENT',
      $${"messages":[{"role":"user","content":[{"type":"text","text":"What is OTD by supplier? Show top 5 only."}]}]}$$
    )
  ) AS resp
);

-- ────────────────────────────────────────────────────────────
-- Test 6: Agent handles landed cost question
-- ────────────────────────────────────────────────────────────
SELECT 'test_agent_landed_cost' AS test_name,
       IFF(
         resp:status::STRING = 'completed'
         AND CAST(resp AS VARCHAR) ILIKE '%freight%'
         AND CAST(resp AS VARCHAR) ILIKE '%carrier%',
         'PASS', 'FAIL'
       ) AS result
FROM (
  SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
      'SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_AGENT',
      $${"messages":[{"role":"user","content":[{"type":"text","text":"What is the landed cost by carrier?"}]}]}$$
    )
  ) AS resp
);

-- ────────────────────────────────────────────────────────────
-- Test 7: All base tables have data
-- ────────────────────────────────────────────────────────────
SELECT 'test_all_tables_have_data' AS test_name,
       IFF(MIN(cnt) > 0, 'PASS', 'FAIL') AS result
FROM (
  SELECT COUNT(*) AS cnt FROM SUPPLY_CHAIN.CORE.COUNTRY
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.REGION
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.PART_CATEGORY
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.SUPPLIER
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.PART
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.PLANT
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.CUSTOMER
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.ORDER_HEADER
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.ORDER_LINE
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.SHIPMENT
  UNION ALL SELECT COUNT(*) FROM SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT
);

-- ────────────────────────────────────────────────────────────
-- Test 8: Shipment data has expected status values
-- ────────────────────────────────────────────────────────────
SELECT 'test_shipment_statuses' AS test_name,
       IFF(COUNT(DISTINCT SHIPMENT_STATUS) = 4, 'PASS', 'FAIL') AS result
FROM SUPPLY_CHAIN.CORE.SHIPMENT;

-- ────────────────────────────────────────────────────────────
-- Test 9: Partial shipments exist (~25%)
-- ────────────────────────────────────────────────────────────
SELECT 'test_partial_shipments_exist' AS test_name,
       IFF(
         partial_pct BETWEEN 15 AND 35,
         'PASS', 'FAIL'
       ) AS result
FROM (
  SELECT COUNT(CASE WHEN IS_PARTIAL THEN 1 END) * 100.0 / COUNT(*) AS partial_pct
  FROM SUPPLY_CHAIN.CORE.SHIPMENT
);

-- ────────────────────────────────────────────────────────────
-- Test 10: OTD metric returns values between 0-100%
-- ────────────────────────────────────────────────────────────
SELECT 'test_otd_metric_range' AS test_name,
       IFF(
         MIN(otd_pct) >= 0 AND MAX(otd_pct) <= 100,
         'PASS', 'FAIL'
       ) AS result
FROM (
  SELECT s.SUPPLIER_ID,
         COUNT(CASE WHEN sh.ACTUAL_DELIVERY_DATE <= sh.CONFIRMED_DATE THEN 1 END) * 100.0
           / NULLIF(COUNT(sh.ACTUAL_DELIVERY_DATE), 0) AS otd_pct
  FROM SUPPLY_CHAIN.CORE.SHIPMENT sh
  JOIN SUPPLY_CHAIN.CORE.ORDER_LINE ol ON sh.ORDER_LINE_ID = ol.ORDER_LINE_ID
  JOIN SUPPLY_CHAIN.CORE.SUPPLIER s ON ol.SUPPLIER_ID = s.SUPPLIER_ID
  WHERE sh.ACTUAL_DELIVERY_DATE IS NOT NULL
  GROUP BY s.SUPPLIER_ID
);
