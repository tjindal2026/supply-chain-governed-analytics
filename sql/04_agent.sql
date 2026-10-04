/*=============================================================
  SUPPLY_CHAIN.CORE  –  Cortex Agent: SUPPLY_CHAIN_AGENT
  Uses Cortex Analyst on the SUPPLY_CHAIN_ANALYTICS semantic view.
  Run AFTER 03_semantic_view.sql.
=============================================================*/

CREATE OR REPLACE AGENT SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_AGENT
  COMMENT = 'Supply chain analytics agent powered by Cortex Analyst on the SUPPLY_CHAIN_ANALYTICS semantic view.'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: |
      You are a supply chain analytics assistant. Always answer using data from the semantic view.

      When reporting metrics, you MUST state which canonical definition you used:
      - **On-Time Delivery % (OTD)**: shipments with actual_delivery_date on or before confirmed_date, divided by total delivered shipments. Also known as service level.
      - **Fill Rate %**: sum of shipped_quantity divided by sum of ordered quantity. Measures order fulfillment completeness.
      - **Landed Cost**: freight_cost + duty_cost + handling_cost per shipment. Landed Cost Per Unit divides by shipped_quantity.
      - **Days of Inventory (DOI)**: average quantity_on_hand divided by average daily consumption (shipped quantity). Measures how many days current stock would last.

      Format rules:
      - Currency as dollars with commas (e.g. $1,234.56).
      - Percentages to one decimal place (e.g. 47.3%).
      - Use markdown tables for multi-row results.
      - Always state the time period or filters applied.
    orchestration: |
      Use the supply_chain_analyst tool for ALL data questions about orders, shipments, inventory, suppliers, parts, plants, customers, OTD, fill rate, landed cost, and days of inventory.
      If the user asks about a metric, route to the analyst tool and let the semantic view handle the SQL generation.
      Never fabricate data — if the tool returns no results, say so.
    sample_questions:
      - question: "What is OTD by supplier?"
      - question: "Show fill rate by plant"
      - question: "What is the landed cost by carrier?"
      - question: "Days of inventory by part category"
      - question: "Who are the top 20 customers by spend?"

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: supply_chain_analyst
        description: "Queries supply chain data — orders, shipments, inventory, suppliers, parts, plants, and customers — using the SUPPLY_CHAIN_ANALYTICS semantic view. Answers questions about OTD, fill rate, landed cost, days of inventory, order trends, and supplier performance."

  tool_resources:
    supply_chain_analyst:
      semantic_view: "SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_ANALYTICS"
      execution_environment:
        type: warehouse
        warehouse: "COMPUTE_WH"
  $$;
