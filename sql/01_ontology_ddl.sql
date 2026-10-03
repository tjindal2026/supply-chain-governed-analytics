/*=============================================================
  SUPPLY_CHAIN.CORE  –  Supply-Chain Ontology DDL
  Generated for: supply-chain-governed-analytics
=============================================================*/

CREATE DATABASE IF NOT EXISTS SUPPLY_CHAIN;
CREATE SCHEMA IF NOT EXISTS SUPPLY_CHAIN.CORE;

-- ============================================================
-- HIERARCHY / REFERENCE TABLES
-- ============================================================

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.COUNTRY (
    COUNTRY_ID      INT          NOT NULL PRIMARY KEY,
    COUNTRY_CODE    VARCHAR(3)   NOT NULL,
    COUNTRY_NAME    VARCHAR(100) NOT NULL
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.COUNTRY IS
  'Reference dimension of countries used to locate suppliers, plants, and customers.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.COUNTRY.COUNTRY_ID IS
  'Surrogate key uniquely identifying a country.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.COUNTRY.COUNTRY_CODE IS
  'ISO 3166-1 alpha-3 country code.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.COUNTRY.COUNTRY_NAME IS
  'Full English name of the country.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.REGION (
    REGION_ID    INT          NOT NULL PRIMARY KEY,
    REGION_NAME  VARCHAR(100) NOT NULL,
    COUNTRY_ID   INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.COUNTRY(COUNTRY_ID)
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.REGION IS
  'Sub-national geographic regions that roll up to a country. Plants are assigned to regions.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.REGION.REGION_ID IS
  'Surrogate key uniquely identifying a region.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.REGION.REGION_NAME IS
  'Descriptive name of the region (e.g. Northeast US, Bavaria).';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.REGION.COUNTRY_ID IS
  'Foreign key to COUNTRY. Establishes the Region → Country hierarchy.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.PART_CATEGORY (
    CATEGORY_ID   INT          NOT NULL PRIMARY KEY,
    CATEGORY_NAME VARCHAR(100) NOT NULL,
    DESCRIPTION   VARCHAR(500)
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.PART_CATEGORY IS
  'Classification hierarchy for parts. Every part belongs to exactly one category.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART_CATEGORY.CATEGORY_ID IS
  'Surrogate key uniquely identifying a part category.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART_CATEGORY.CATEGORY_NAME IS
  'Short label for the category (e.g. Electronics, Fasteners).';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART_CATEGORY.DESCRIPTION IS
  'Free-text description of what the category encompasses.';

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.SUPPLIER (
    SUPPLIER_ID       INT          NOT NULL PRIMARY KEY,
    SUPPLIER_NAME     VARCHAR(200) NOT NULL,
    COUNTRY_ID        INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.COUNTRY(COUNTRY_ID),
    CONTACT_EMAIL     VARCHAR(200),
    LEAD_TIME_DAYS    INT,
    RELIABILITY_SCORE FLOAT,
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.SUPPLIER IS
  'Vendor entities that supply parts. Each supplier is domiciled in one country.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.SUPPLIER_ID IS
  'Surrogate key uniquely identifying a supplier.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.SUPPLIER_NAME IS
  'Business name of the supplier.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.COUNTRY_ID IS
  'Foreign key to COUNTRY where the supplier is headquartered.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.CONTACT_EMAIL IS
  'Primary contact email address for the supplier.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.LEAD_TIME_DAYS IS
  'Average number of calendar days from PO to delivery for this supplier.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.RELIABILITY_SCORE IS
  'Score between 0 and 1 representing historical on-time-in-full delivery rate.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SUPPLIER.CREATED_AT IS
  'Timestamp when the supplier record was first created.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.PART (
    PART_ID        INT          NOT NULL PRIMARY KEY,
    PART_NUMBER    VARCHAR(50)  NOT NULL,
    PART_NAME      VARCHAR(200) NOT NULL,
    CATEGORY_ID    INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.PART_CATEGORY(CATEGORY_ID),
    UNIT_WEIGHT_KG FLOAT,
    UNIT_COST      NUMBER(12,2),
    CURRENCY       VARCHAR(3)   DEFAULT 'USD'
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.PART IS
  'Master catalog of parts (SKUs) that flow through the supply chain.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.PART_ID IS
  'Surrogate key uniquely identifying a part.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.PART_NUMBER IS
  'Human-readable part number used on purchase orders and labels.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.PART_NAME IS
  'Descriptive name of the part.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.CATEGORY_ID IS
  'Foreign key to PART_CATEGORY. Establishes the Part → Category hierarchy.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.UNIT_WEIGHT_KG IS
  'Weight of one unit in kilograms, used for freight cost estimation.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.UNIT_COST IS
  'Standard cost per unit in the part currency.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PART.CURRENCY IS
  'ISO 4217 currency code for UNIT_COST. Defaults to USD.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.PLANT (
    PLANT_ID    INT          NOT NULL PRIMARY KEY,
    PLANT_NAME  VARCHAR(200) NOT NULL,
    REGION_ID   INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.REGION(REGION_ID),
    PLANT_TYPE  VARCHAR(50),
    CAPACITY    INT,
    OPENED_DATE DATE
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.PLANT IS
  'Physical facilities (factories, assembly lines, distribution centers) in the Plant → Region → Country hierarchy.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PLANT.PLANT_ID IS
  'Surrogate key uniquely identifying a plant.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PLANT.PLANT_NAME IS
  'Short name or code for the plant.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PLANT.REGION_ID IS
  'Foreign key to REGION. Establishes the Plant → Region → Country hierarchy.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PLANT.PLANT_TYPE IS
  'Functional type: Manufacturing, Assembly, or Distribution.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PLANT.CAPACITY IS
  'Maximum annual throughput in units.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.PLANT.OPENED_DATE IS
  'Date the plant became operational.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.CUSTOMER (
    CUSTOMER_ID   INT          NOT NULL PRIMARY KEY,
    CUSTOMER_NAME VARCHAR(200) NOT NULL,
    COUNTRY_ID    INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.COUNTRY(COUNTRY_ID),
    SEGMENT       VARCHAR(50),
    CREDIT_LIMIT  NUMBER(12,2),
    CREATED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.CUSTOMER IS
  'Downstream buyers who place orders. Each customer is domiciled in one country.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.CUSTOMER.CUSTOMER_ID IS
  'Surrogate key uniquely identifying a customer.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.CUSTOMER.CUSTOMER_NAME IS
  'Legal or trading name of the customer.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.CUSTOMER.COUNTRY_ID IS
  'Foreign key to COUNTRY where the customer is based.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.CUSTOMER.SEGMENT IS
  'Market segment: Enterprise, Mid-Market, SMB, or Government.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.CUSTOMER.CREDIT_LIMIT IS
  'Maximum outstanding receivable balance allowed for this customer in USD.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.CUSTOMER.CREATED_AT IS
  'Timestamp when the customer record was first created.';

-- ============================================================
-- TRANSACTIONAL / FACT TABLES
-- ============================================================

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.ORDER_HEADER (
    ORDER_ID       INT          NOT NULL PRIMARY KEY,
    CUSTOMER_ID    INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.CUSTOMER(CUSTOMER_ID),
    PLANT_ID       INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.PLANT(PLANT_ID),
    ORDER_DATE     DATE         NOT NULL,
    ORDER_STATUS   VARCHAR(30)  NOT NULL,
    TOTAL_AMOUNT   NUMBER(14,2),
    CURRENCY       VARCHAR(3)   DEFAULT 'USD'
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.ORDER_HEADER IS
  'Customer purchase orders. Each order is fulfilled from a single plant.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.ORDER_ID IS
  'Surrogate key uniquely identifying an order.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.CUSTOMER_ID IS
  'Foreign key to CUSTOMER who placed the order.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.PLANT_ID IS
  'Foreign key to PLANT responsible for fulfilling the order.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.ORDER_DATE IS
  'Calendar date the order was placed.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.ORDER_STATUS IS
  'Current lifecycle state: Open, Confirmed, Shipped, Delivered, or Cancelled.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.TOTAL_AMOUNT IS
  'Total monetary value of the order in the order currency.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_HEADER.CURRENCY IS
  'ISO 4217 currency code for TOTAL_AMOUNT. Defaults to USD.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.ORDER_LINE (
    ORDER_LINE_ID  INT          NOT NULL PRIMARY KEY,
    ORDER_ID       INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.ORDER_HEADER(ORDER_ID),
    PART_ID        INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.PART(PART_ID),
    SUPPLIER_ID    INT          NOT NULL REFERENCES SUPPLY_CHAIN.CORE.SUPPLIER(SUPPLIER_ID),
    QUANTITY       INT          NOT NULL,
    UNIT_PRICE     NUMBER(12,2) NOT NULL,
    LINE_AMOUNT    NUMBER(14,2) NOT NULL
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.ORDER_LINE IS
  'Line items on a purchase order, each referencing a specific part and supplier.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.ORDER_LINE_ID IS
  'Surrogate key uniquely identifying an order line.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.ORDER_ID IS
  'Foreign key to ORDER_HEADER this line belongs to.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.PART_ID IS
  'Foreign key to PART being ordered on this line.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.SUPPLIER_ID IS
  'Foreign key to SUPPLIER fulfilling this line item.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.QUANTITY IS
  'Number of units ordered.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.UNIT_PRICE IS
  'Agreed price per unit for this line.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.ORDER_LINE.LINE_AMOUNT IS
  'Total value of the line (QUANTITY × UNIT_PRICE).';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.SHIPMENT (
    SHIPMENT_ID          INT            NOT NULL PRIMARY KEY,
    ORDER_LINE_ID        INT            NOT NULL REFERENCES SUPPLY_CHAIN.CORE.ORDER_LINE(ORDER_LINE_ID),
    SHIPMENT_NUMBER      VARCHAR(30)    NOT NULL,
    SHIPPED_QUANTITY     INT            NOT NULL,
    IS_PARTIAL           BOOLEAN        NOT NULL DEFAULT FALSE,
    REQUESTED_DATE       DATE           NOT NULL,
    CONFIRMED_DATE       DATE           NOT NULL,
    SHIP_DATE            DATE,
    ACTUAL_DELIVERY_DATE DATE,
    CARRIER              VARCHAR(100),
    TRACKING_NUMBER      VARCHAR(100),
    FREIGHT_COST         NUMBER(12,2),
    DUTY_COST            NUMBER(12,2),
    HANDLING_COST        NUMBER(12,2),
    SHIPMENT_STATUS      VARCHAR(30)    NOT NULL
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.SHIPMENT IS
  'Physical shipments against order lines. Supports partial shipments, delivery-date tracking (requested vs confirmed vs actual), and landed-cost breakdown (freight, duty, handling).';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.SHIPMENT_ID IS
  'Surrogate key uniquely identifying a shipment.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.ORDER_LINE_ID IS
  'Foreign key to ORDER_LINE this shipment fulfills (fully or partially).';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.SHIPMENT_NUMBER IS
  'Human-readable shipment reference number.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.SHIPPED_QUANTITY IS
  'Number of units included in this shipment.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.IS_PARTIAL IS
  'TRUE when this shipment does not cover the full order-line quantity.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.REQUESTED_DATE IS
  'Date the customer originally requested delivery.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.CONFIRMED_DATE IS
  'Date the supplier or logistics provider confirmed they can deliver.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.SHIP_DATE IS
  'Date the goods physically left the origin facility.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.ACTUAL_DELIVERY_DATE IS
  'Date the goods were received at destination. NULL if still in transit.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.CARRIER IS
  'Name of the freight carrier (e.g. FedEx, Maersk, DHL).';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.TRACKING_NUMBER IS
  'Carrier-assigned tracking identifier.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.FREIGHT_COST IS
  'Transportation cost in USD for this shipment.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.DUTY_COST IS
  'Import duties and tariffs in USD for this shipment.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.HANDLING_COST IS
  'Warehouse handling and loading/unloading cost in USD.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.SHIPMENT.SHIPMENT_STATUS IS
  'Current state: In Transit, Delivered, Delivered Late, or Partial Delivery.';

CREATE OR REPLACE TABLE SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT (
    SNAPSHOT_ID        INT           NOT NULL PRIMARY KEY,
    SNAPSHOT_DATE      DATE          NOT NULL,
    PLANT_ID           INT           NOT NULL REFERENCES SUPPLY_CHAIN.CORE.PLANT(PLANT_ID),
    PART_ID            INT           NOT NULL REFERENCES SUPPLY_CHAIN.CORE.PART(PART_ID),
    QUANTITY_ON_HAND   INT           NOT NULL,
    QUANTITY_RESERVED  INT           NOT NULL DEFAULT 0,
    QUANTITY_AVAILABLE INT           NOT NULL,
    REORDER_POINT      INT,
    UNIT_COST          NUMBER(12,2)
);
COMMENT ON TABLE SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT IS
  'Periodic (weekly) point-in-time snapshot of inventory levels by plant and part, used for trend analysis and reorder monitoring.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.SNAPSHOT_ID IS
  'Surrogate key uniquely identifying a snapshot row.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.SNAPSHOT_DATE IS
  'Calendar date the inventory count was captured.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.PLANT_ID IS
  'Foreign key to PLANT where inventory is held.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.PART_ID IS
  'Foreign key to PART being counted.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.QUANTITY_ON_HAND IS
  'Total physical units present at the plant.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.QUANTITY_RESERVED IS
  'Units allocated to open orders but not yet shipped.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.QUANTITY_AVAILABLE IS
  'Units available for new orders (ON_HAND minus RESERVED).';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.REORDER_POINT IS
  'Threshold below which a replenishment order should be triggered.';
COMMENT ON COLUMN SUPPLY_CHAIN.CORE.INVENTORY_SNAPSHOT.UNIT_COST IS
  'Carrying cost per unit at time of snapshot in USD.';
