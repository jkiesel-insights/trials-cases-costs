-- =========================================================
-- Q4: Which blood cancer trials report the highest complete
--     remission rates, and how do rates differ by phase and
--     sponsor type?
-- Approach: Build a view of blood cancer trials (leukemia,
--           lymphoma, myeloma) reporting complete remission/
--           response as a percentage of participants. Combine
--           arms into a per-trial average, then compare by
--           phase and lead sponsor, and list the top 10.
-- Cleaning: Keeps only percentage units (10+ spellings);
--           excludes outcomes that combine complete with partial
--           response, and time-based measures (duration, survival).
-- Limitations: Trials define remission differently and measure it at
--              different time points, and arm sizes aren't available,
--              so small arms can show extreme rates. Treat these as
--              reported results, not a head-to-head comparison of
--              treatments.
-- Key finding: 318 blood cancer trials posted complete remission
--              results as a percentage of patients. In a typical
--              (median) trial, 22% of patients reached complete
--              remission in Phase 1 trials, 36% in Phase 2, and 30%
--              in Phase 3. University- and hospital-led trials
--              reported higher rates than industry-led trials (47% vs.
--              28%), likely because they more often enroll newly
--              diagnosed patients, who respond better. Research network
--              (7 trials) and government (19 trials) results are too
--              few to compare.
-- =========================================================

-- Step A: Create a reusable view of cleaned remission results
CREATE OR REPLACE VIEW project.blood_cancer_cr AS
WITH blood_cancer_trials AS (
  SELECT DISTINCT nct_id
  FROM browse_conditions
  WHERE downcase_mesh_term ~ 'leukemia|lymphoma|myeloma'
),
cr_results AS (
  -- One row per treatment arm reporting a complete remission %
  SELECT o.nct_id, om.param_value_num AS cr_pct
  FROM outcomes o
  JOIN outcome_measurements om ON om.outcome_id = o.id
  JOIN blood_cancer_trials b ON b.nct_id = o.nct_id
  JOIN project.cancer_trials c ON c.nct_id = o.nct_id
  WHERE o.title ~* 'complete (remission|response)'
    AND o.title !~* 'partial|overall|objective|duration|time to|progression|survival|minimal residual|MRD|relapse'
    AND LOWER(o.units) ~ '^(percent|percentage) of (participants|patients)'
    AND (om.category IS NULL OR om.category !~* 'partial|stable|progress|no response')
    AND om.param_value_num BETWEEN 0 AND 100
),
trial_level AS (
  -- Combine arms into one row per trial
  SELECT nct_id,
         MAX(cr_pct) AS best_arm_cr_pct,
         ROUND(AVG(cr_pct)::numeric, 1) AS avg_arm_cr_pct
  FROM cr_results
  GROUP BY nct_id
)
SELECT
  t.nct_id,
  s.brief_title,
  t.best_arm_cr_pct,
  t.avg_arm_cr_pct,
  CASE
    WHEN s.phase IN ('EARLY_PHASE1', 'PHASE1', 'PHASE1/PHASE2') THEN 'Phase 1 & 1/2'
    WHEN s.phase = 'PHASE2' THEN 'Phase 2'
    WHEN s.phase IN ('PHASE2/PHASE3', 'PHASE3') THEN 'Phase 2/3 & 3'
    ELSE 'Phase 4, NA or missing'
  END AS phase_group,
  CASE
    WHEN sp.agency_class = 'INDUSTRY' THEN 'Industry'
    WHEN sp.agency_class = 'OTHER'    THEN 'Academic & medical centers'
    WHEN sp.agency_class = 'NETWORK'  THEN 'Research networks'
    WHEN sp.agency_class IN ('NIH', 'FED', 'OTHER_GOV') THEN 'Government'
    ELSE 'Individual or unknown'
  END AS sponsor_type
FROM trial_level t
JOIN studies s USING (nct_id)
JOIN sponsors sp ON sp.nct_id = t.nct_id AND sp.lead_or_collaborator = 'lead';


-- Part 1: Complete remission rates by phase
SELECT
  phase_group,
  COUNT(*) AS trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_arm_cr_pct)::numeric, 1) AS median_cr_pct,
  ROUND(AVG(avg_arm_cr_pct), 1) AS mean_cr_pct
FROM project.blood_cancer_cr
GROUP BY phase_group
ORDER BY phase_group;


-- Part 2: Complete remission rates by lead sponsor type
SELECT
  sponsor_type,
  COUNT(*) AS trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_arm_cr_pct)::numeric, 1) AS median_cr_pct,
  ROUND(AVG(avg_arm_cr_pct), 1) AS mean_cr_pct
FROM project.blood_cancer_cr
GROUP BY sponsor_type
ORDER BY trials DESC;


-- Part 3: Top 10 trials by highest reported arm
-- Note: 9 of the top 10 report 100% complete remission in at least one
--       arm (the 10th reports 97.6%). Perfect rates usually come from
--       small arms where every patient responded, so this list shows
--       the highest reported results, not the most effective treatments.
SELECT nct_id, brief_title, phase_group, sponsor_type, best_arm_cr_pct
FROM project.blood_cancer_cr
ORDER BY best_arm_cr_pct DESC, nct_id
LIMIT 10;
