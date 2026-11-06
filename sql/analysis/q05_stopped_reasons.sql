-- =========================================================
-- Q5: How many cancer trials were stopped early, and why?
-- Approach: Include all "stopped early" statuses from Q1
--           (terminated, withdrawn, suspended). Sort the free-text
--           why_stopped field into categories with case-insensitive
--           keyword matching (~*). Categories are checked in order;
--           a reason goes to the FIRST category it matches, so
--           safety and efficacy are checked before enrollment.
-- Validation: Coverage check and random sample of unclassified
--             reasons below.
-- Note: "Accrual" is the clinical term for enrolling patients.
-- Key finding: Of 14,287 stopped cancer trials, low enrollment is the
--              #1 reason (35.2%), more than three times safety concerns
--              and lack of efficacy combined (10.4%). Sponsor or business
--              decisions account for 11.7%, and 11.0% gave no reason.
-- Coverage: 84.9% of trials that gave a reason were classified (up from
--           80.3% after refining keywords from a random sample of
--           unclassified reasons). The remaining 13.4% are one-off
--           explanations.
-- =========================================================

-- Step A: Create a reusable view of stopped trials with reason categories
-- (Keywords refined after reviewing a random sample of unclassified reasons)
CREATE OR REPLACE VIEW project.stopped_reasons AS
SELECT
  s.nct_id,
  s.overall_status,
  s.why_stopped,
  CASE
    WHEN s.why_stopped IS NULL OR TRIM(s.why_stopped) = ''
      THEN 'No reason given'
    WHEN s.why_stopped ~* 'safety|toxic|adverse|side effect|death|toler'
      THEN 'Safety concerns'
    WHEN s.why_stopped ~* 'efficacy|futil|ineffective|benefit|interim analysis|scientific'
      THEN 'Lack of efficacy'
    WHEN s.why_stopped ~* 'accru|accural|enrol|recruit|particip|inclusion|no (patients|subjects)'
      THEN 'Low enrollment'
    WHEN s.why_stopped ~* 'fund|financ|budget|grant'
      THEN 'Funding'
    WHEN s.why_stopped ~* 'sponsor|business|strateg|company|commercial|portfolio|priorit|develop|no go|compound'
      THEN 'Sponsor or business decision'
    WHEN s.why_stopped ~* 'covid|pandemic|coronavirus'
      THEN 'COVID-19'
    WHEN s.why_stopped ~* '\mpi\M|investigator|institution|administrat|staff|logistic|irb|regulat|feasib'
      THEN 'Investigator or administrative'
    WHEN s.why_stopped ~* 'drug supply|supply|manufactur|availab'
      THEN 'Drug supply'
    WHEN s.why_stopped ~* 'never (started|opened|activated)|not (started|opened|activated)'
      THEN 'Study never started'
    WHEN s.why_stopped ~* 'design|protocol|amend|device'
      THEN 'Design or protocol change'
    ELSE 'Other / unclassified'
  END AS reason_category
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
WHERE s.overall_status IN ('TERMINATED', 'WITHDRAWN', 'SUSPENDED');


-- Main query: Stopped trials by reason category and status
SELECT
  reason_category,
  COUNT(*) AS trials,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_stopped,
  COUNT(*) FILTER (WHERE overall_status = 'TERMINATED') AS terminated,
  COUNT(*) FILTER (WHERE overall_status = 'WITHDRAWN')  AS withdrawn,
  COUNT(*) FILTER (WHERE overall_status = 'SUSPENDED')  AS suspended
FROM project.stopped_reasons
GROUP BY reason_category
ORDER BY trials DESC;


-- =========================================================
-- Validation
-- =========================================================

-- Coverage: share of trials with a reason that matched a category
SELECT
  COUNT(*) FILTER (WHERE reason_category NOT IN ('Other / unclassified', 'No reason given')) AS classified,
  COUNT(*) FILTER (WHERE reason_category = 'Other / unclassified') AS unclassified,
  ROUND(100.0 * COUNT(*) FILTER (WHERE reason_category NOT IN ('Other / unclassified', 'No reason given'))
        / COUNT(*) FILTER (WHERE reason_category <> 'No reason given'), 1) AS pct_classified_of_given_reasons
FROM project.stopped_reasons;

-- Random sample of unclassified reasons, to check for missed themes
SELECT why_stopped
FROM project.stopped_reasons
WHERE reason_category = 'Other / unclassified'
ORDER BY random()
LIMIT 25;
