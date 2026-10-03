/*=============================================================
  SUPPLY_CHAIN.CORE  -  Semantic View: SUPPLY_CHAIN_ANALYTICS
  Deploy via SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML.
  Run AFTER 01_ontology_ddl.sql and 02_seed_data.sql.
=============================================================*/

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'SUPPLY_CHAIN.CORE',
  $$
name: SUPPLY_CHAIN_ANALYTICS
description: >-
  Supply chain analytics semantic view covering supplier performance (OTD, fill rate),
  shipment logistics (landed cost, delivery tracking), inventory health (days of inventory,
  reorder alerts), and order management across the Supplier → Part → Plant → Shipment → Order → Customer
  chain. Includes geographic hierarchy (Plant → Region → Country) and product hierarchy (Part → Category).

  Canonical metrics:
  - On-Time Delivery % (OTD): shipments delivered on or before confirmed_date / total delivered shipments.
  - Fill Rate %: sum of shipped quantity / sum of ordered quantity.
  - Landed Cost: freight + duty + handling per shipment (also available per unit).
  - Days of Inventory: average on-hand quantity / average daily consumption.
tables:
  - name: COUNTRY
    description: Reference dimension of countries used to locate suppliers, plants, and customers.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: COUNTRY
    primary_key:
      columns:
        - COUNTRY_ID
    dimensions:
      - name: COUNTRY_ID
        description: Surrogate key uniquely identifying a country.
        expr: COUNTRY_ID
        data_type: NUMBER
      - name: COUNTRY_CODE
        description: ISO 3166-1 alpha-3 country code.
        expr: COUNTRY_CODE
        data_type: VARCHAR
        synonyms:
          - iso code
          - country iso
      - name: COUNTRY_NAME
        description: Full English name of the country.
        expr: COUNTRY_NAME
        data_type: VARCHAR
        synonyms:
          - country
          - nation

  - name: REGION
    description: Sub-national geographic regions that roll up to a country. Forms the middle tier of the Plant → Region → Country hierarchy.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: REGION
    primary_key:
      columns:
        - REGION_ID
    foreign_keys:
      - fkey_columns:
          - COUNTRY_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: COUNTRY
        pkey_columns:
          - COUNTRY_ID
    dimensions:
      - name: REGION_ID
        description: Surrogate key uniquely identifying a region.
        expr: REGION_ID
        data_type: NUMBER
      - name: REGION_NAME
        description: Descriptive name of the region (e.g. Northeast US, Bavaria).
        expr: REGION_NAME
        data_type: VARCHAR
        synonyms:
          - region
          - geography
          - area
      - name: COUNTRY_ID
        description: Foreign key to COUNTRY. Establishes the Region → Country hierarchy.
        expr: COUNTRY_ID
        data_type: NUMBER

  - name: PART_CATEGORY
    description: Classification hierarchy for parts. Every part belongs to exactly one category. Top tier of the Part → Category hierarchy.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: PART_CATEGORY
    primary_key:
      columns:
        - CATEGORY_ID
    dimensions:
      - name: CATEGORY_ID
        description: Surrogate key uniquely identifying a part category.
        expr: CATEGORY_ID
        data_type: NUMBER
      - name: CATEGORY_NAME
        description: Short label for the category (e.g. Electronics, Fasteners).
        expr: CATEGORY_NAME
        data_type: VARCHAR
        synonyms:
          - part category
          - product category
          - category
          - part type
      - name: DESCRIPTION
        description: Free-text description of what the category encompasses.
        expr: DESCRIPTION
        data_type: VARCHAR

  - name: SUPPLIER
    description: Vendor entities that supply parts. Each supplier is domiciled in one country. Key dimension for OTD and fill rate analysis.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: SUPPLIER
    primary_key:
      columns:
        - SUPPLIER_ID
    foreign_keys:
      - fkey_columns:
          - COUNTRY_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: COUNTRY
        pkey_columns:
          - COUNTRY_ID
    dimensions:
      - name: SUPPLIER_ID
        description: Surrogate key uniquely identifying a supplier.
        expr: SUPPLIER_ID
        data_type: NUMBER
      - name: SUPPLIER_NAME
        description: Business name of the supplier.
        expr: SUPPLIER_NAME
        data_type: VARCHAR
        synonyms:
          - supplier
          - vendor
          - vendor name
      - name: COUNTRY_ID
        description: Foreign key to COUNTRY where the supplier is headquartered.
        expr: COUNTRY_ID
        data_type: NUMBER
      - name: CONTACT_EMAIL
        description: Primary contact email address for the supplier.
        expr: CONTACT_EMAIL
        data_type: VARCHAR
      - name: LEAD_TIME_DAYS
        description: Average number of calendar days from PO to delivery for this supplier.
        expr: LEAD_TIME_DAYS
        data_type: NUMBER
        synonyms:
          - lead time
          - supplier lead time
    time_dimensions:
      - name: CREATED_AT
        description: Timestamp when the supplier record was first created.
        expr: CREATED_AT
        data_type: TIMESTAMP_NTZ
    facts:
      - name: RELIABILITY_SCORE
        description: Score between 0 and 1 representing historical on-time-in-full delivery rate.
        expr: RELIABILITY_SCORE
        data_type: FLOAT
        synonyms:
          - OTIF score
          - supplier reliability

  - name: PART
    description: Master catalog of parts (SKUs) that flow through the supply chain. Each part belongs to one category (Part → Category hierarchy).
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: PART
    primary_key:
      columns:
        - PART_ID
    foreign_keys:
      - fkey_columns:
          - CATEGORY_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: PART_CATEGORY
        pkey_columns:
          - CATEGORY_ID
    dimensions:
      - name: PART_ID
        description: Surrogate key uniquely identifying a part.
        expr: PART_ID
        data_type: NUMBER
      - name: PART_NUMBER
        description: Human-readable part number used on purchase orders and labels.
        expr: PART_NUMBER
        data_type: VARCHAR
        synonyms:
          - PN
          - SKU
          - part code
      - name: PART_NAME
        description: Descriptive name of the part.
        expr: PART_NAME
        data_type: VARCHAR
        synonyms:
          - part
          - component
          - item
      - name: CATEGORY_ID
        description: Foreign key to PART_CATEGORY. Establishes the Part → Category hierarchy.
        expr: CATEGORY_ID
        data_type: NUMBER
      - name: CURRENCY
        description: ISO 4217 currency code for UNIT_COST. Defaults to USD.
        expr: CURRENCY
        data_type: VARCHAR
    facts:
      - name: UNIT_WEIGHT_KG
        description: Weight of one unit in kilograms, used for freight cost estimation.
        expr: UNIT_WEIGHT_KG
        data_type: FLOAT
        synonyms:
          - weight
          - part weight
      - name: UNIT_COST
        description: Standard cost per unit in the part currency.
        expr: UNIT_COST
        data_type: NUMBER
        synonyms:
          - part cost
          - standard cost

  - name: PLANT
    description: >-
      Physical facilities (factories, assembly lines, distribution centers).
      Bottom tier of the Plant → Region → Country geographic hierarchy.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: PLANT
    primary_key:
      columns:
        - PLANT_ID
    foreign_keys:
      - fkey_columns:
          - REGION_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: REGION
        pkey_columns:
          - REGION_ID
    dimensions:
      - name: PLANT_ID
        description: Surrogate key uniquely identifying a plant.
        expr: PLANT_ID
        data_type: NUMBER
      - name: PLANT_NAME
        description: Short name or code for the plant.
        expr: PLANT_NAME
        data_type: VARCHAR
        synonyms:
          - plant
          - facility
          - factory
          - site
      - name: REGION_ID
        description: Foreign key to REGION. Establishes the Plant → Region → Country hierarchy.
        expr: REGION_ID
        data_type: NUMBER
      - name: PLANT_TYPE
        description: 'Functional type: Manufacturing, Assembly, or Distribution.'
        expr: PLANT_TYPE
        data_type: VARCHAR
        synonyms:
          - facility type
          - plant classification
      - name: CAPACITY
        description: Maximum annual throughput in units.
        expr: CAPACITY
        data_type: NUMBER
        synonyms:
          - plant capacity
          - max throughput
    time_dimensions:
      - name: OPENED_DATE
        description: Date the plant became operational.
        expr: OPENED_DATE
        data_type: DATE

  - name: CUSTOMER
    description: Downstream buyers who place orders. Each customer is domiciled in one country.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: CUSTOMER
    primary_key:
      columns:
        - CUSTOMER_ID
    foreign_keys:
      - fkey_columns:
          - COUNTRY_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: COUNTRY
        pkey_columns:
          - COUNTRY_ID
    dimensions:
      - name: CUSTOMER_ID
        description: Surrogate key uniquely identifying a customer.
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: CUSTOMER_NAME
        description: Legal or trading name of the customer.
        expr: CUSTOMER_NAME
        data_type: VARCHAR
        synonyms:
          - customer
          - buyer
          - client
      - name: COUNTRY_ID
        description: Foreign key to COUNTRY where the customer is based.
        expr: COUNTRY_ID
        data_type: NUMBER
      - name: SEGMENT
        description: 'Market segment: Enterprise, Mid-Market, SMB, or Government.'
        expr: SEGMENT
        data_type: VARCHAR
        synonyms:
          - customer segment
          - market segment
          - customer tier
    time_dimensions:
      - name: CREATED_AT
        description: Timestamp when the customer record was first created.
        expr: CREATED_AT
        data_type: TIMESTAMP_NTZ
    facts:
      - name: CREDIT_LIMIT
        description: Maximum outstanding receivable balance allowed for this customer in USD.
        expr: CREDIT_LIMIT
        data_type: NUMBER
        synonyms:
          - credit line
          - credit cap

  - name: ORDER_HEADER
    description: Customer purchase orders. Each order is fulfilled from a single plant.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: ORDER_HEADER
    primary_key:
      columns:
        - ORDER_ID
    foreign_keys:
      - fkey_columns:
          - CUSTOMER_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: CUSTOMER
        pkey_columns:
          - CUSTOMER_ID
      - fkey_columns:
          - PLANT_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: PLANT
        pkey_columns:
          - PLANT_ID
    dimensions:
      - name: ORDER_ID
        description: Surrogate key uniquely identifying an order.
        expr: ORDER_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        description: Foreign key to CUSTOMER who placed the order.
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: PLANT_ID
        description: Foreign key to PLANT responsible for fulfilling the order.
        expr: PLANT_ID
        data_type: NUMBER
      - name: ORDER_STATUS
        description: 'Current lifecycle state: Open, Confirmed, Shipped, Delivered, or Cancelled.'
        expr: ORDER_STATUS
        data_type: VARCHAR
        synonyms:
          - status
          - order state
      - name: CURRENCY
        description: ISO 4217 currency code for TOTAL_AMOUNT. Defaults to USD.
        expr: CURRENCY
        data_type: VARCHAR
    time_dimensions:
      - name: ORDER_DATE
        description: Calendar date the order was placed.
        expr: ORDER_DATE
        data_type: DATE
        synonyms:
          - date ordered
          - purchase date
    facts:
      - name: TOTAL_AMOUNT
        description: Total monetary value of the order in the order currency.
        expr: TOTAL_AMOUNT
        data_type: NUMBER
        synonyms:
          - order value
          - order amount
          - revenue

  - name: ORDER_LINE
    description: Line items on a purchase order, each referencing a specific part and supplier. Central fact table linking orders to parts and suppliers.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: ORDER_LINE
    primary_key:
      columns:
        - ORDER_LINE_ID
    foreign_keys:
      - fkey_columns:
          - ORDER_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: ORDER_HEADER
        pkey_columns:
          - ORDER_ID
      - fkey_columns:
          - PART_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: PART
        pkey_columns:
          - PART_ID
      - fkey_columns:
          - SUPPLIER_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: SUPPLIER
        pkey_columns:
          - SUPPLIER_ID
    dimensions:
      - name: ORDER_LINE_ID
        description: Surrogate key uniquely identifying an order line.
        expr: ORDER_LINE_ID
        data_type: NUMBER
      - name: ORDER_ID
        description: Foreign key to ORDER_HEADER this line belongs to.
        expr: ORDER_ID
        data_type: NUMBER
      - name: PART_ID
        description: Foreign key to PART being ordered on this line.
        expr: PART_ID
        data_type: NUMBER
      - name: SUPPLIER_ID
        description: Foreign key to SUPPLIER fulfilling this line item.
        expr: SUPPLIER_ID
        data_type: NUMBER
    facts:
      - name: QUANTITY
        description: Number of units ordered on this line. Used as denominator for fill rate calculation.
        expr: QUANTITY
        data_type: NUMBER
        synonyms:
          - qty ordered
          - order quantity
          - ordered quantity
      - name: UNIT_PRICE
        description: Agreed price per unit for this line.
        expr: UNIT_PRICE
        data_type: NUMBER
      - name: LINE_AMOUNT
        description: Total value of the line (QUANTITY x UNIT_PRICE).
        expr: LINE_AMOUNT
        data_type: NUMBER
        synonyms:
          - line value
          - line total

  - name: SHIPMENT
    description: >-
      Physical shipments against order lines. Supports partial shipments, three-date delivery tracking
      (requested_date, confirmed_date, actual_delivery_date), and landed-cost breakdown (freight, duty, handling).
      Primary table for OTD, fill rate, and landed cost metrics.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: SHIPMENT
    primary_key:
      columns:
        - SHIPMENT_ID
    foreign_keys:
      - fkey_columns:
          - ORDER_LINE_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: ORDER_LINE
        pkey_columns:
          - ORDER_LINE_ID
    dimensions:
      - name: SHIPMENT_ID
        description: Surrogate key uniquely identifying a shipment.
        expr: SHIPMENT_ID
        data_type: NUMBER
      - name: ORDER_LINE_ID
        description: Foreign key to ORDER_LINE this shipment fulfills (fully or partially).
        expr: ORDER_LINE_ID
        data_type: NUMBER
      - name: SHIPMENT_NUMBER
        description: Human-readable shipment reference number.
        expr: SHIPMENT_NUMBER
        data_type: VARCHAR
        synonyms:
          - shipment ref
          - shipment code
      - name: IS_PARTIAL
        description: TRUE when this shipment does not cover the full order-line quantity. Indicates a partial delivery.
        expr: IS_PARTIAL
        data_type: BOOLEAN
        synonyms:
          - partial shipment
          - partial delivery
          - split shipment
      - name: CARRIER
        description: Name of the freight carrier (e.g. FedEx, Maersk, DHL).
        expr: CARRIER
        data_type: VARCHAR
        synonyms:
          - freight carrier
          - logistics provider
          - shipping company
      - name: TRACKING_NUMBER
        description: Carrier-assigned tracking identifier.
        expr: TRACKING_NUMBER
        data_type: VARCHAR
      - name: SHIPMENT_STATUS
        description: 'Current state: In Transit, Delivered, Delivered Late, or Partial Delivery.'
        expr: SHIPMENT_STATUS
        data_type: VARCHAR
        synonyms:
          - delivery status
          - shipment state
    time_dimensions:
      - name: REQUESTED_DATE
        description: Date the customer originally requested delivery. Baseline for customer-facing SLA.
        expr: REQUESTED_DATE
        data_type: DATE
        synonyms:
          - customer request date
          - required date
      - name: CONFIRMED_DATE
        description: Date the supplier or logistics provider confirmed they can deliver. Baseline for OTD calculation.
        expr: CONFIRMED_DATE
        data_type: DATE
        synonyms:
          - promise date
          - committed date
      - name: SHIP_DATE
        description: Date the goods physically left the origin facility.
        expr: SHIP_DATE
        data_type: DATE
        synonyms:
          - dispatch date
          - departure date
      - name: ACTUAL_DELIVERY_DATE
        description: Date the goods were received at destination. NULL if still in transit. Compared against CONFIRMED_DATE for OTD.
        expr: ACTUAL_DELIVERY_DATE
        data_type: DATE
        synonyms:
          - delivery date
          - receipt date
          - arrival date
    facts:
      - name: SHIPPED_QUANTITY
        description: Number of units included in this shipment. Used as numerator for fill rate calculation.
        expr: SHIPPED_QUANTITY
        data_type: NUMBER
        synonyms:
          - qty shipped
          - shipped qty
          - units shipped
      - name: FREIGHT_COST
        description: Transportation cost in USD for this shipment. Component of landed cost.
        expr: FREIGHT_COST
        data_type: NUMBER
        synonyms:
          - shipping cost
          - transport cost
      - name: DUTY_COST
        description: Import duties and tariffs in USD for this shipment. Component of landed cost.
        expr: DUTY_COST
        data_type: NUMBER
        synonyms:
          - import duty
          - tariff cost
          - customs cost
      - name: HANDLING_COST
        description: Warehouse handling and loading/unloading cost in USD. Component of landed cost.
        expr: HANDLING_COST
        data_type: NUMBER
        synonyms:
          - warehousing cost
          - loading cost
      - name: LANDED_COST
        description: >-
          Total landed cost per shipment = freight + duty + handling.
          The all-in logistics cost to get goods from origin to destination.
        expr: FREIGHT_COST + DUTY_COST + HANDLING_COST
        data_type: NUMBER
        synonyms:
          - total logistics cost
          - total shipping cost
          - all-in cost
          - total landed cost
      - name: LANDED_COST_PER_UNIT
        description: >-
          Landed cost per unit shipped = (freight + duty + handling) / shipped_quantity.
          Use to compare per-unit logistics efficiency across carriers or lanes.
        expr: (FREIGHT_COST + DUTY_COST + HANDLING_COST) / NULLIF(SHIPPED_QUANTITY, 0)
        data_type: NUMBER
        synonyms:
          - unit landed cost
          - cost per unit shipped
          - per unit logistics cost

  - name: INVENTORY_SNAPSHOT
    description: >-
      Periodic (weekly) point-in-time snapshot of inventory levels by plant and part.
      Used for days-of-inventory calculation, trend analysis, and reorder monitoring.
      This is a snapshot fact table — do not sum quantities across dates.
    base_table:
      database: SUPPLY_CHAIN
      schema: CORE
      table: INVENTORY_SNAPSHOT
    primary_key:
      columns:
        - SNAPSHOT_ID
    foreign_keys:
      - fkey_columns:
          - PART_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: PART
        pkey_columns:
          - PART_ID
      - fkey_columns:
          - PLANT_ID
        pkey_table:
          database: SUPPLY_CHAIN
          schema: CORE
          table: PLANT
        pkey_columns:
          - PLANT_ID
    dimensions:
      - name: SNAPSHOT_ID
        description: Surrogate key uniquely identifying a snapshot row.
        expr: SNAPSHOT_ID
        data_type: NUMBER
      - name: PLANT_ID
        description: Foreign key to PLANT where inventory is held.
        expr: PLANT_ID
        data_type: NUMBER
      - name: PART_ID
        description: Foreign key to PART being counted.
        expr: PART_ID
        data_type: NUMBER
    time_dimensions:
      - name: SNAPSHOT_DATE
        description: Calendar date the inventory count was captured.
        expr: SNAPSHOT_DATE
        data_type: DATE
        synonyms:
          - inventory date
          - count date
    facts:
      - name: QUANTITY_ON_HAND
        description: Total physical units present at the plant.
        expr: QUANTITY_ON_HAND
        data_type: NUMBER
        synonyms:
          - on hand
          - stock on hand
          - QOH
          - inventory level
      - name: QUANTITY_RESERVED
        description: Units allocated to open orders but not yet shipped.
        expr: QUANTITY_RESERVED
        data_type: NUMBER
        synonyms:
          - reserved stock
          - allocated inventory
      - name: QUANTITY_AVAILABLE
        description: Units available for new orders (ON_HAND minus RESERVED).
        expr: QUANTITY_AVAILABLE
        data_type: NUMBER
        synonyms:
          - available stock
          - free stock
          - ATP
          - available to promise
      - name: REORDER_POINT
        description: Threshold below which a replenishment order should be triggered.
        expr: REORDER_POINT
        data_type: NUMBER
        synonyms:
          - ROP
          - reorder level
          - min stock
      - name: UNIT_COST
        description: Carrying cost per unit at time of snapshot in USD.
        expr: UNIT_COST
        data_type: NUMBER
        synonyms:
          - inventory cost
          - carrying cost

relationships:
  - name: REGION_TO_COUNTRY
    description: Region rolls up to Country in the geographic hierarchy.
    left_table: REGION
    right_table: COUNTRY
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: COUNTRY_ID
        right_column: COUNTRY_ID
  - name: PLANT_TO_REGION
    description: Plant belongs to a Region (Plant → Region → Country hierarchy).
    left_table: PLANT
    right_table: REGION
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: REGION_ID
        right_column: REGION_ID
  - name: PART_TO_PART_CATEGORY
    description: Part belongs to a Part Category (Part → Category hierarchy).
    left_table: PART
    right_table: PART_CATEGORY
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CATEGORY_ID
        right_column: CATEGORY_ID
  - name: SUPPLIER_TO_COUNTRY
    description: Supplier is headquartered in a Country.
    left_table: SUPPLIER
    right_table: COUNTRY
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: COUNTRY_ID
        right_column: COUNTRY_ID
  - name: CUSTOMER_TO_COUNTRY
    description: Customer is domiciled in a Country.
    left_table: CUSTOMER
    right_table: COUNTRY
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: COUNTRY_ID
        right_column: COUNTRY_ID
  - name: ORDER_HEADER_TO_CUSTOMER
    description: Order placed by a Customer.
    left_table: ORDER_HEADER
    right_table: CUSTOMER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: ORDER_HEADER_TO_PLANT
    description: Order fulfilled from a Plant.
    left_table: ORDER_HEADER
    right_table: PLANT
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: PLANT_ID
        right_column: PLANT_ID
  - name: ORDER_LINE_TO_ORDER_HEADER
    description: Order line belongs to an Order.
    left_table: ORDER_LINE
    right_table: ORDER_HEADER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: ORDER_ID
        right_column: ORDER_ID
  - name: ORDER_LINE_TO_PART
    description: Order line references a specific Part.
    left_table: ORDER_LINE
    right_table: PART
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: PART_ID
        right_column: PART_ID
  - name: ORDER_LINE_TO_SUPPLIER
    description: Order line is fulfilled by a Supplier.
    left_table: ORDER_LINE
    right_table: SUPPLIER
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: SUPPLIER_ID
        right_column: SUPPLIER_ID
  - name: SHIPMENT_TO_ORDER_LINE
    description: Shipment fulfills (fully or partially) an Order Line.
    left_table: SHIPMENT
    right_table: ORDER_LINE
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: ORDER_LINE_ID
        right_column: ORDER_LINE_ID
  - name: INVENTORY_SNAPSHOT_TO_PART
    description: Inventory snapshot counts a specific Part.
    left_table: INVENTORY_SNAPSHOT
    right_table: PART
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: PART_ID
        right_column: PART_ID
  - name: INVENTORY_SNAPSHOT_TO_PLANT
    description: Inventory snapshot is located at a Plant.
    left_table: INVENTORY_SNAPSHOT
    right_table: PLANT
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: PLANT_ID
        right_column: PLANT_ID

verified_queries:
  - name: otd_by_supplier
    question: What is OTD by supplier?
    sql: >-
      SELECT s.SUPPLIER_NAME,
             COUNT(CASE WHEN sh.ACTUAL_DELIVERY_DATE <= sh.CONFIRMED_DATE THEN 1 END) * 100.0
               / NULLIF(COUNT(sh.ACTUAL_DELIVERY_DATE), 0) AS on_time_delivery_pct
        FROM shipment AS sh
        JOIN order_line AS ol ON sh.ORDER_LINE_ID = ol.ORDER_LINE_ID
        JOIN supplier AS s ON ol.SUPPLIER_ID = s.SUPPLIER_ID
       WHERE sh.ACTUAL_DELIVERY_DATE IS NOT NULL
       GROUP BY s.SUPPLIER_NAME
       ORDER BY on_time_delivery_pct
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: fill_rate_by_plant
    question: What is the fill rate by plant?
    sql: >-
      SELECT pl.PLANT_NAME,
             SUM(sh.SHIPPED_QUANTITY) * 100.0 / NULLIF(SUM(ol.QUANTITY), 0) AS fill_rate_pct
        FROM shipment AS sh
        JOIN order_line AS ol ON sh.ORDER_LINE_ID = ol.ORDER_LINE_ID
        JOIN order_header AS oh ON ol.ORDER_ID = oh.ORDER_ID
        JOIN plant AS pl ON oh.PLANT_ID = pl.PLANT_ID
       GROUP BY pl.PLANT_NAME
       ORDER BY fill_rate_pct
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: landed_cost_by_carrier
    question: What is the landed cost by carrier?
    sql: >-
      SELECT sh.CARRIER,
             SUM(sh.FREIGHT_COST + sh.DUTY_COST + sh.HANDLING_COST) AS total_landed_cost,
             SUM(sh.FREIGHT_COST + sh.DUTY_COST + sh.HANDLING_COST)
               / NULLIF(SUM(sh.SHIPPED_QUANTITY), 0) AS landed_cost_per_unit
        FROM shipment AS sh
       GROUP BY sh.CARRIER
       ORDER BY total_landed_cost DESC
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: days_of_inventory_by_category
    question: What are the days of inventory by part category?
    sql: >-
      SELECT pc.CATEGORY_NAME,
             AVG(inv.QUANTITY_ON_HAND) / NULLIF(AVG(sh.SHIPPED_QUANTITY), 0) AS days_of_inventory
        FROM inventory_snapshot AS inv
        JOIN part AS p ON inv.PART_ID = p.PART_ID
        JOIN part_category AS pc ON p.CATEGORY_ID = pc.CATEGORY_ID
        LEFT JOIN order_line AS ol ON ol.PART_ID = p.PART_ID
        LEFT JOIN shipment AS sh ON sh.ORDER_LINE_ID = ol.ORDER_LINE_ID
       GROUP BY pc.CATEGORY_NAME
       ORDER BY days_of_inventory DESC
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: order_value_by_status
    question: What is the total order value by order status?
    sql: >-
      SELECT oh.ORDER_STATUS,
             COUNT(*) AS order_count,
             SUM(oh.TOTAL_AMOUNT) AS total_value
        FROM order_header AS oh
       GROUP BY oh.ORDER_STATUS
       ORDER BY total_value DESC
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: top_customers_by_spend
    question: Who are the top 20 customers by total spend?
    sql: >-
      SELECT c.CUSTOMER_NAME, c.SEGMENT,
             COUNT(oh.ORDER_ID) AS order_count,
             SUM(oh.TOTAL_AMOUNT) AS total_spent
        FROM customer AS c
        JOIN order_header AS oh ON c.CUSTOMER_ID = oh.CUSTOMER_ID
       GROUP BY c.CUSTOMER_NAME, c.SEGMENT
       ORDER BY total_spent DESC
       LIMIT 20
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: shipment_status_distribution
    question: What is the shipment status distribution?
    sql: >-
      SELECT sh.SHIPMENT_STATUS,
             COUNT(*) AS shipment_count,
             ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
        FROM shipment AS sh
       GROUP BY sh.SHIPMENT_STATUS
       ORDER BY shipment_count DESC
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: inventory_by_plant_region_country
    question: Show current inventory levels by plant, region, and country
    sql: >-
      SELECT co.COUNTRY_NAME, r.REGION_NAME, pl.PLANT_NAME,
             SUM(inv.QUANTITY_ON_HAND) AS total_on_hand,
             SUM(inv.QUANTITY_AVAILABLE) AS total_available
        FROM inventory_snapshot AS inv
        JOIN plant AS pl ON inv.PLANT_ID = pl.PLANT_ID
        JOIN region AS r ON pl.REGION_ID = r.REGION_ID
        JOIN country AS co ON r.COUNTRY_ID = co.COUNTRY_ID
       WHERE inv.SNAPSHOT_DATE = (SELECT MAX(SNAPSHOT_DATE) FROM inventory_snapshot)
       GROUP BY co.COUNTRY_NAME, r.REGION_NAME, pl.PLANT_NAME
       ORDER BY total_on_hand DESC
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: worst_supplier_delays
    question: Which suppliers have the worst delivery delays?
    sql: >-
      SELECT s.SUPPLIER_NAME,
             AVG(DATEDIFF(DAY, sh.CONFIRMED_DATE, sh.ACTUAL_DELIVERY_DATE)) AS avg_delay_days,
             COUNT(*) AS late_shipments
        FROM shipment AS sh
        JOIN order_line AS ol ON sh.ORDER_LINE_ID = ol.ORDER_LINE_ID
        JOIN supplier AS s ON ol.SUPPLIER_ID = s.SUPPLIER_ID
       WHERE sh.ACTUAL_DELIVERY_DATE > sh.CONFIRMED_DATE
       GROUP BY s.SUPPLIER_NAME
       ORDER BY avg_delay_days DESC
       LIMIT 10
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  - name: monthly_order_trend
    question: Show monthly order volume and revenue trend
    sql: >-
      SELECT DATE_TRUNC('MONTH', oh.ORDER_DATE) AS order_month,
             COUNT(oh.ORDER_ID) AS orders,
             SUM(oh.TOTAL_AMOUNT) AS revenue
        FROM order_header AS oh
       WHERE oh.ORDER_STATUS <> 'Cancelled'
       GROUP BY order_month
       ORDER BY order_month
    verified_at: 1791040732
    verified_by: Semantic Model Generator
  $$
);
