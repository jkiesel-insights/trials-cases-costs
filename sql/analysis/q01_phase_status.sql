-- =========================================================
-- Q1: How many cancer trials are there by phase and status?
-- Approach: Join cancer_trials view to studies; relabel phase
--           codes and group 13 statuses into 4 categories
--           with CASE; count each combination with FILTER.
--           Expanded-access programs excluded (not trials).
-- Note on non-phase studies: Phases apply only to drug and
--   biological trials. Observational studies have no phase,
--   and "NA" marks interventional studies of non-drug
--   treatments (procedures, behavioral, devices, radiation).
--   See validation queries below.
-- Key finding: Phase 2 is the most common cancer trial phase (27,014).
--              The share of trials stopped early falls as trials advance:
--              18.5-21.4% for Early Phase 1 through Phase 1/2,
--              17.3% for Phase 2, and ~12% for Phases 3 and 4.
-- =========================================================

-- Join cancer_trials view to studies; relabel phase codes
WITH labeled AS (
  SELECT
    s.nct_id,
    CASE
      WHEN s.phase = 'EARLY_PHASE1'  THEN 'Early Phase 1'
      WHEN s.phase = 'PHASE1'        THEN 'Phase 1'
      WHEN s.phase = 'PHASE1/PHASE2' THEN 'Phase 1/2'
      WHEN s.phase = 'PHASE2'        THEN 'Phase 2'
      WHEN s.phase = 'PHASE2/PHASE3' THEN 'Phase 2/3'
      WHEN s.phase = 'PHASE3'        THEN 'Phase 3'
      WHEN s.phase = 'PHASE4'        THEN 'Phase 4'
      WHEN s.phase = 'NA'            THEN 'Not applicable'
      WHEN s.study_type = 'OBSERVATIONAL' THEN 'Observational (no phase)'
      ELSE 'Phase missing'
    END AS phase_label,

    -- Sort phases in logical order rather than alphabetically
    CASE
      WHEN s.phase = 'EARLY_PHASE1'  THEN 1
      WHEN s.phase = 'PHASE1'        THEN 2
      WHEN s.phase = 'PHASE1/PHASE2' THEN 3
      WHEN s.phase = 'PHASE2'        THEN 4
      WHEN s.phase = 'PHASE2/PHASE3' THEN 5
      WHEN s.phase = 'PHASE3'        THEN 6
      WHEN s.phase = 'PHASE4'        THEN 7
      WHEN s.phase = 'NA'            THEN 8
      WHEN s.study_type = 'OBSERVATIONAL' THEN 9
      ELSE 10
    END AS sort_order,

    -- Group 13 statuses into 4 categories
    CASE
      WHEN s.overall_status IN ('RECRUITING', 'ACTIVE_NOT_RECRUITING',
                                'NOT_YET_RECRUITING', 'ENROLLING_BY_INVITATION') THEN 'Active'
      WHEN s.overall_status = 'COMPLETED' THEN 'Completed'
      WHEN s.overall_status IN ('TERMINATED', 'WITHDRAWN', 'SUSPENDED') THEN 'Stopped early'
      WHEN s.overall_status = 'UNKNOWN' THEN 'Unknown'
      ELSE 'Expanded access'
    END AS status_group

  FROM project.cancer_trials c
  JOIN studies s USING (nct_id)
)

-- Count each phase/status combination with FILTER
SELECT
  phase_label AS phase,
  COUNT(*) AS total_trials,
  COUNT(*) FILTER (WHERE status_group = 'Active')        AS active,
  COUNT(*) FILTER (WHERE status_group = 'Completed')     AS completed,
  COUNT(*) FILTER (WHERE status_group = 'Stopped early') AS stopped_early,
  COUNT(*) FILTER (WHERE status_group = 'Unknown')       AS unknown,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status_group = 'Stopped early') / COUNT(*), 1) AS pct_stopped_early
FROM labeled
WHERE status_group <> 'Expanded access'   -- not trials; excluded
GROUP BY phase_label, sort_order
ORDER BY sort_order;


-- =========================================================
-- Validation: Why so many studies without a phase?
-- =========================================================

-- Blank phases are almost all observational studies;
-- "NA" phases are all interventional
SELECT COALESCE(s.phase, '(blank)') AS phase,
       s.study_type,
       COUNT(*) AS trials
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
WHERE s.phase IS NULL OR s.phase = 'NA'
GROUP BY 1, 2
ORDER BY 1, trials DESC;

-- "NA" trials mostly test non-drug interventions
-- (one trial can have several intervention types)
SELECT i.intervention_type,
       COUNT(DISTINCT s.nct_id) AS trials
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
JOIN interventions i USING (nct_id)
WHERE s.phase = 'NA'
GROUP BY i.intervention_type
ORDER BY trials DESC;
