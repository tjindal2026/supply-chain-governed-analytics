/*=============================================================
  Send login credentials to evaluators via Snowflake email.
  
  PRE-REQUISITE: Each evaluator's email must be verified first.
  Run this to re-send verification:
    SELECT SYSTEM$START_USER_EMAIL_VERIFICATION('EVALUATOR_GMAIL');
    SELECT SYSTEM$START_USER_EMAIL_VERIFICATION('EVALUATOR_HACK2SKILL');

  Once verified, update the notification integration and send.
=============================================================*/

-- Step 1: Update integration with newly verified emails
-- (add emails as they get verified — remove any that error)
CREATE OR REPLACE NOTIFICATION INTEGRATION evaluator_email_int
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = (
    'tjindal2026@gmail.com',
    'hack2skillevaluator@gmail.com',
    'evaluator@hack2skill.com'
  );

-- Step 2: Send to hack2skillevaluator@gmail.com
CALL SYSTEM$SEND_EMAIL(
  'EVALUATOR_EMAIL_INT',
  'hack2skillevaluator@gmail.com',
  'Supply Chain Analytics App - Your Login Credentials',
  'Hello,

You have been invited to evaluate the Supply Chain Analytics application.

LOGIN URL: https://app.snowflake.com/XGQISOQ/bc75017/

Username: hack2skillevaluator@gmail.com
Password: SCeval@GM15Oct!

This password is valid for 15 days. No password change required.

After logging in, open the app:
https://app.snowflake.com/XGQISOQ/bc75017/#/streamlit-apps/SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_CHAT

Choose a persona (Planning, Procurement, or Logistics) and ask supply chain questions.

This is an automated message from Snowflake.
Do not reply to this email.'
);

-- Step 3: Send to evaluator@hack2skill.com
CALL SYSTEM$SEND_EMAIL(
  'EVALUATOR_EMAIL_INT',
  'evaluator@hack2skill.com',
  'Supply Chain Analytics App - Your Login Credentials',
  'Hello,

You have been invited to evaluate the Supply Chain Analytics application.

LOGIN URL: https://app.snowflake.com/XGQISOQ/bc75017/

Username: evaluator@hack2skill.com
Password: SCeval@HS15Oct!

This password is valid for 15 days. No password change required.

After logging in, open the app:
https://app.snowflake.com/XGQISOQ/bc75017/#/streamlit-apps/SUPPLY_CHAIN.CORE.SUPPLY_CHAIN_CHAT

Choose a persona (Planning, Procurement, or Logistics) and ask supply chain questions.

This is an automated message from Snowflake.
Do not reply to this email.'
);
