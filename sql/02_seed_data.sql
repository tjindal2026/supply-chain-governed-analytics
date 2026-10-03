/*=============================================================
  SUPPLY_CHAIN.CORE  –  Synthetic Seed Data
  Generates realistic supply-chain data with ~17 k rows total.
  Run AFTER 01_ontology_ddl.sql.
=============================================================*/

USE SCHEMA SUPPLY_CHAIN.CORE;

-- ============================================================
-- HIERARCHY / REFERENCE DATA
-- ============================================================

INSERT INTO COUNTRY VALUES
  (1,'USA','United States'),(2,'CAN','Canada'),(3,'MEX','Mexico'),
  (4,'DEU','Germany'),(5,'GBR','United Kingdom'),(6,'FRA','France'),
  (7,'JPN','Japan'),(8,'CHN','China'),(9,'KOR','South Korea'),
  (10,'BRA','Brazil'),(11,'IND','India'),(12,'AUS','Australia');

INSERT INTO REGION VALUES
  (1,'Northeast US',1),(2,'Southeast US',1),(3,'Midwest US',1),(4,'West US',1),
  (5,'Ontario',2),(6,'Quebec',2),(7,'Bavaria',4),(8,'North Rhine-Westphalia',4),
  (9,'South East England',5),(10,'Ile-de-France',6),(11,'Kanto',7),(12,'Guangdong',8),
  (13,'Shanghai',8),(14,'Gyeonggi',9),(15,'Sao Paulo',10),(16,'Maharashtra',11),
  (17,'New South Wales',12),(18,'Northern Mexico',3),(19,'Central Mexico',3),(20,'British Columbia',2);

INSERT INTO PART_CATEGORY VALUES
  (1,'Electronics','Semiconductors, PCBs, sensors'),
  (2,'Mechanical','Gears, bearings, shafts, housings'),
  (3,'Fasteners','Bolts, screws, nuts, rivets'),
  (4,'Raw Materials','Steel, aluminum, plastics, composites'),
  (5,'Packaging','Boxes, pallets, shrink wrap, labels'),
  (6,'Electrical','Wiring, connectors, switches, relays'),
  (7,'Hydraulics','Pumps, valves, cylinders, hoses'),
  (8,'Chemicals','Adhesives, coatings, lubricants');

-- ============================================================
-- DIMENSION DATA
-- ============================================================

-- 50 suppliers
INSERT INTO SUPPLIER (SUPPLIER_ID, SUPPLIER_NAME, COUNTRY_ID, CONTACT_EMAIL, LEAD_TIME_DAYS, RELIABILITY_SCORE)
SELECT
    SEQ4() + 1,
    'Supplier-' || LPAD(SEQ4()+1, 3, '0'),
    UNIFORM(1, 12, RANDOM()),
    'contact@supplier' || (SEQ4()+1) || '.com',
    UNIFORM(3, 45, RANDOM()),
    ROUND(UNIFORM(0.60, 0.99, RANDOM())::FLOAT, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- 200 parts
INSERT INTO PART (PART_ID, PART_NUMBER, PART_NAME, CATEGORY_ID, UNIT_WEIGHT_KG, UNIT_COST)
SELECT
    SEQ4() + 1,
    'PN-' || LPAD(SEQ4()+1, 5, '0'),
    CASE UNIFORM(1,8,RANDOM())
        WHEN 1 THEN 'Sensor Module'
        WHEN 2 THEN 'Drive Shaft'
        WHEN 3 THEN 'Hex Bolt M'
        WHEN 4 THEN 'Steel Sheet'
        WHEN 5 THEN 'Carton Box'
        WHEN 6 THEN 'Wire Harness'
        WHEN 7 THEN 'Hydraulic Valve'
        ELSE 'Epoxy Adhesive'
    END || '-' || (SEQ4()+1),
    UNIFORM(1, 8, RANDOM()),
    ROUND(UNIFORM(0.05, 50.0, RANDOM())::FLOAT, 2),
    ROUND(UNIFORM(0.50, 500.00, RANDOM())::FLOAT, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- 30 plants
INSERT INTO PLANT (PLANT_ID, PLANT_NAME, REGION_ID, PLANT_TYPE, CAPACITY, OPENED_DATE)
SELECT
    SEQ4() + 1,
    'Plant-' || LPAD(SEQ4()+1, 2, '0'),
    UNIFORM(1, 20, RANDOM()),
    CASE UNIFORM(1,3,RANDOM())
        WHEN 1 THEN 'Manufacturing'
        WHEN 2 THEN 'Assembly'
        ELSE 'Distribution'
    END,
    UNIFORM(500, 10000, RANDOM()),
    DATEADD('day', -UNIFORM(365, 7300, RANDOM()), CURRENT_DATE())
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- 300 customers
INSERT INTO CUSTOMER (CUSTOMER_ID, CUSTOMER_NAME, COUNTRY_ID, SEGMENT, CREDIT_LIMIT)
SELECT
    SEQ4() + 1,
    'Customer-' || LPAD(SEQ4()+1, 4, '0'),
    UNIFORM(1, 12, RANDOM()),
    CASE UNIFORM(1,4,RANDOM())
        WHEN 1 THEN 'Enterprise'
        WHEN 2 THEN 'Mid-Market'
        WHEN 3 THEN 'SMB'
        ELSE 'Government'
    END,
    ROUND(UNIFORM(10000, 5000000, RANDOM())::FLOAT, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 300));

-- ============================================================
-- TRANSACTIONAL / FACT DATA
-- ============================================================

-- 2 000 orders spanning ~2 years
INSERT INTO ORDER_HEADER (ORDER_ID, CUSTOMER_ID, PLANT_ID, ORDER_DATE, ORDER_STATUS, TOTAL_AMOUNT)
SELECT
    SEQ4() + 1,
    UNIFORM(1, 300, RANDOM()),
    UNIFORM(1, 30, RANDOM()),
    DATEADD('day', -UNIFORM(0, 730, RANDOM()), CURRENT_DATE()),
    CASE UNIFORM(1,5,RANDOM())
        WHEN 1 THEN 'Open'
        WHEN 2 THEN 'Confirmed'
        WHEN 3 THEN 'Shipped'
        WHEN 4 THEN 'Delivered'
        ELSE 'Cancelled'
    END,
    ROUND(UNIFORM(500, 250000, RANDOM())::FLOAT, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

-- 5 000 order lines
INSERT INTO ORDER_LINE (ORDER_LINE_ID, ORDER_ID, PART_ID, SUPPLIER_ID, QUANTITY, UNIT_PRICE, LINE_AMOUNT)
SELECT
    SEQ4() + 1,
    UNIFORM(1, 2000, RANDOM()),
    UNIFORM(1, 200, RANDOM()),
    UNIFORM(1, 50, RANDOM()),
    qty,
    price,
    ROUND(qty * price, 2)
FROM (
    SELECT
        SEQ4(),
        UNIFORM(1, 500, RANDOM()) AS qty,
        ROUND(UNIFORM(1.00, 500.00, RANDOM())::FLOAT, 2) AS price
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
);

-- 6 000 shipments  (~20% late, ~25% partial, ~5% still in-transit)
INSERT INTO SHIPMENT (
    SHIPMENT_ID, ORDER_LINE_ID, SHIPMENT_NUMBER, SHIPPED_QUANTITY, IS_PARTIAL,
    REQUESTED_DATE, CONFIRMED_DATE, SHIP_DATE, ACTUAL_DELIVERY_DATE,
    CARRIER, TRACKING_NUMBER, FREIGHT_COST, DUTY_COST, HANDLING_COST, SHIPMENT_STATUS
)
WITH base AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
        UNIFORM(1, 5000, RANDOM()) AS ol_id,
        UNIFORM(1, 100, RANDOM()) AS delay_roll,
        UNIFORM(1, 100, RANDOM()) AS partial_roll,
        DATEADD('day', -UNIFORM(10, 700, RANDOM()), CURRENT_DATE()) AS req_dt,
        UNIFORM(5, 30, RANDOM()) AS transit_days,
        UNIFORM(1, 500, RANDOM()) AS full_qty
    FROM TABLE(GENERATOR(ROWCOUNT => 6000))
)
SELECT
    rn,
    ol_id,
    'SH-' || LPAD(rn, 6, '0'),
    CASE WHEN partial_roll <= 25
         THEN GREATEST(1, FLOOR(full_qty * UNIFORM(0.30, 0.80, RANDOM())))
         ELSE full_qty
    END,
    partial_roll <= 25,
    req_dt,
    -- confirmed_date = promised delivery date (request + transit window)
    DATEADD('day', transit_days + UNIFORM(-2, 3, RANDOM()), req_dt),
    DATEADD('day', UNIFORM(0, 3, RANDOM()) + UNIFORM(1, 5, RANDOM()), req_dt),
    CASE
        WHEN delay_roll <= 5  THEN NULL
        WHEN delay_roll <= 25 THEN DATEADD('day', transit_days + UNIFORM(5, 30, RANDOM()), req_dt)
        ELSE DATEADD('day', transit_days, req_dt)
    END,
    CASE UNIFORM(1,5,RANDOM())
        WHEN 1 THEN 'FedEx'
        WHEN 2 THEN 'UPS'
        WHEN 3 THEN 'DHL'
        WHEN 4 THEN 'Maersk'
        ELSE 'DB Schenker'
    END,
    'TRK' || LPAD(rn, 10, '0'),
    ROUND(UNIFORM(25, 5000, RANDOM())::FLOAT, 2),
    ROUND(UNIFORM(0, 2000, RANDOM())::FLOAT, 2),
    ROUND(UNIFORM(10, 500, RANDOM())::FLOAT, 2),
    CASE
        WHEN delay_roll <= 5  THEN 'In Transit'
        WHEN delay_roll <= 25 THEN 'Delivered Late'
        WHEN partial_roll <= 25 THEN 'Partial Delivery'
        ELSE 'Delivered'
    END
FROM base;

-- 4 000 inventory snapshots (weekly, ~12 weeks, across plants and parts)
INSERT INTO INVENTORY_SNAPSHOT (
    SNAPSHOT_ID, SNAPSHOT_DATE, PLANT_ID, PART_ID,
    QUANTITY_ON_HAND, QUANTITY_RESERVED, QUANTITY_AVAILABLE, REORDER_POINT, UNIT_COST
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()),
    DATEADD('week', -UNIFORM(0, 12, RANDOM()), CURRENT_DATE()),
    UNIFORM(1, 30, RANDOM()),
    UNIFORM(1, 200, RANDOM()),
    oh,
    rsv,
    GREATEST(0, oh - rsv),
    UNIFORM(10, 200, RANDOM()),
    ROUND(UNIFORM(0.50, 500.00, RANDOM())::FLOAT, 2)
FROM (
    SELECT
        SEQ4(),
        UNIFORM(0, 2000, RANDOM()) AS oh,
        UNIFORM(0, 500, RANDOM()) AS rsv
    FROM TABLE(GENERATOR(ROWCOUNT => 4000))
);
