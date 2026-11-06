-- =========================================================
-- Q3: How do industry and academic sponsors compare in trial count?
-- Approach: Part 1 classifies each trial by its lead sponsor
--           (every trial has exactly one) and compares counts,
--           share of all cancer trials, and share in late-stage
--           (Phase 2/3 or 3) testing. Part 2 measures how often
--           industry is involved as a collaborator on trials it
--           doesn't lead.
-- Note: AACT has no "academic" class; universities, hospitals,
--       and cancer centers are classed as OTHER.
-- Key finding: Academic and medical centers lead 70.8% of cancer
--              trials, vs. 21.2% for industry. But industry trials are
--              2.5x more likely to be late-stage (16.2% vs. 6.5%), and
--              research networks lead in late-stage share (26.3%).
--              Industry is involved in 31.8% of trials overall: it leads
--              22,780 and partners on 11,366 more.
-- Caveat: Academic centers run most observational studies (no phase),
--         which lowers their late-stage share.
-- =========================================================

-- Part 1: Trials by lead sponsor type
WITH lead_sponsor AS (
  SELECT
    c.nct_id,
    CASE
      WHEN sp.agency_class = 'INDUSTRY' THEN 'Industry'
      WHEN sp.agency_class = 'OTHER'    THEN 'Academic & medical centers'
      WHEN sp.agency_class = 'NETWORK'  THEN 'Research networks'
      WHEN sp.agency_class IN ('NIH', 'FED', 'OTHER_GOV') THEN 'Government'
      ELSE 'Individual or unknown'
    END AS sponsor_type
  FROM project.cancer_trials c
  JOIN sponsors sp USING (nct_id)
  WHERE sp.lead_or_collaborator = 'lead'
)
SELECT
  ls.sponsor_type,
  COUNT(*) AS trials,
  -- Window function: share of all cancer trials
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_trials,
  -- Share of each group's trials that are late-stage
  ROUND(100.0 * COUNT(*) FILTER (WHERE s.phase IN ('PHASE3', 'PHASE2/PHASE3')) / COUNT(*), 1) AS pct_late_stage
FROM lead_sponsor ls
JOIN studies s USING (nct_id)
GROUP BY ls.sponsor_type
ORDER BY trials DESC;


-- Part 2: How often is industry involved at all?
WITH involvement AS (
  SELECT
    c.nct_id,
    BOOL_OR(sp.agency_class = 'INDUSTRY' AND sp.lead_or_collaborator = 'lead')         AS industry_lead,
    BOOL_OR(sp.agency_class = 'INDUSTRY' AND sp.lead_or_collaborator = 'collaborator') AS industry_partner
  FROM project.cancer_trials c
  JOIN sponsors sp USING (nct_id)
  GROUP BY c.nct_id
)
SELECT
  COUNT(*) FILTER (WHERE industry_lead)                              AS industry_led,
  COUNT(*) FILTER (WHERE NOT industry_lead AND industry_partner)     AS other_led_with_industry_partner,
  COUNT(*) FILTER (WHERE NOT industry_lead AND NOT industry_partner) AS no_industry_involvement,
  ROUND(100.0 * COUNT(*) FILTER (WHERE industry_lead OR industry_partner) / COUNT(*), 1) AS pct_any_industry
FROM involvement;
