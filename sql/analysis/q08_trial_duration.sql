-- =========================================================
-- Q8: What is the average trial duration by phase?
-- Approach: Duration = completion date - start date, in years.
--           Only trials with an ACTUAL (not estimated) completion
--           date. Part 1: completed trials by phase (median and
--           mean). Part 2: completed vs. stopped-early trials.
-- Cleaning: Durations of 0 or less, or over 20 years, are treated
--           as data-entry errors and excluded (see Validation).
-- Key finding: Trials get longer as they advance: median 3.2 years for
--              Early Phase 1, 3.7 for Phase 1, 4.5 for Phase 2, and 5.3
--              for Phase 3. Post-approval Phase 4 trials are shortest
--              (2.8). Terminated trials ran a median of 2.8 years before
--              stopping, about three-quarters as long as completed
--              trials (3.6). Paired with Q5 (low enrollment is the #1
--              reason trials stop), many trials appear to spend years
--              struggling to enroll before ending.
-- Data quality: 526 of 55,312 trials (~1%) excluded as likely
--               date-entry errors (duration <= 0 or > 20 years).
-- =========================================================

-- Step A: Create a reusable view of trial durations
CREATE OR REPLACE VIEW project.trial_durations AS
SELECT
  s.nct_id,
  s.overall_status,
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
  -- Date math: subtracting two dates gives days; divide to get years
  ROUND((s.completion_date - s.start_date) / 365.25, 2) AS duration_years
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
WHERE s.start_date IS NOT NULL
  AND s.completion_date IS NOT NULL
  AND UPPER(s.completion_date_type) = 'ACTUAL';


-- Part 1: Duration of completed trials by phase
SELECT
  phase_label AS phase,
  COUNT(*) AS completed_trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_years)::numeric, 1) AS median_years,
  ROUND(AVG(duration_years), 1) AS mean_years
FROM project.trial_durations
WHERE overall_status = 'COMPLETED'
  AND duration_years > 0
  AND duration_years <= 20
GROUP BY phase_label, sort_order
ORDER BY sort_order;


-- Part 2: How long do stopped trials run before stopping,
-- compared with completed trials?
SELECT
  CASE
    WHEN overall_status = 'COMPLETED' THEN 'Completed'
    ELSE 'Stopped early (terminated)'
  END AS outcome,
  COUNT(*) AS trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_years)::numeric, 1) AS median_years,
  ROUND(AVG(duration_years), 1) AS mean_years
FROM project.trial_durations
WHERE overall_status IN ('COMPLETED', 'TERMINATED')
  AND duration_years > 0
  AND duration_years <= 20
GROUP BY 1
ORDER BY 1;


-- =========================================================
-- Validation: How many trials were excluded as likely errors?
-- =========================================================
SELECT
  COUNT(*) FILTER (WHERE duration_years <= 0) AS zero_or_negative,
  COUNT(*) FILTER (WHERE duration_years > 20) AS over_20_years,
  COUNT(*) AS all_trials_with_actual_dates
FROM project.trial_durations;
