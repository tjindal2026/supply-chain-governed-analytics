# Supply Chain Ontology & Governed Conversational Analytics
Snowflake CoCo CLI Hackathon entry

## Problem
Supply chain data is spread across ERP, logistics, supplier and IoT
systems with inconsistent definitions, so the same question gets
different answers from different teams.

## Approach
1. Ontology: Supplier -> Part -> Plant -> Shipment -> Order -> Customer,
   plus inventory snapshots, with hierarchies (plant > region > country,
   part > category).
2. Canonical metrics defined once: On-Time Delivery, Fill Rate,
   Days of Inventory, Landed Cost.
3. Ontology encoded as Snowflake Semantic Views.
4. Cortex Agent on top for natural-language, cross-domain questions.
5. Demo: the same metric returns identical results for Planning,
   Procurement and Logistics personas.

## Status
- [x] Ontology design and DDL
- [x] Synthetic ERP-style data
- [ ] Semantic view with canonical metrics
- [ ] Cortex Agent
- [ ] Streamlit chat app
- [ ] Persona-consistency demo

## Built with
Snowflake, Cortex Code CLI, Cortex Analyst, Cortex Agents, Streamlit.
All data is synthetic.
