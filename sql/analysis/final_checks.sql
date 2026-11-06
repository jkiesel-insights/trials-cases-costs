-- =========================================================
-- Final checks: confirms all project views exist and that key
-- numbers quoted in each question's key finding match the data.
-- Each column name includes the expected value from the finding.
-- Result (Nov 5, 2026): all 10 views present; all key numbers match.
-- =========================================================

-- Check 2: All project views exist (expect 10)
SELECT table_name AS project_view
FROM information_schema.views
WHERE table_schema = 'project'
ORDER BY table_name;


-- Check 3: Key numbers from the findings, recomputed from the views
SELECT
  (SELECT COUNT(*) FROM project.cancer_trials)                                AS setup_107273,
  (SELECT COUNT(*) FROM project.blood_cancer_cr)                              AS q4_318,
  (SELECT COUNT(*) FROM project.stopped_reasons)                              AS q5_14287,
  (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE reason_category = 'Low enrollment')
          / COUNT(*), 1) FROM project.stopped_reasons)                        AS q5_35_2_pct,
  (SELECT COUNT(*) FROM project.immuno_trials it
     JOIN project.cancer_trials c USING (nct_id))                             AS q6_11820,
  (SELECT trials FROM project.lead_sponsor_counts WHERE overall_rank = 1)     AS q7_3055,
  (SELECT COUNT(*) FROM project.trial_durations
     WHERE duration_years <= 0 OR duration_years > 20)                        AS q8_526,
  (SELECT sites_per_million FROM project.state_sites WHERE state = 'Montana') AS q9_6427_1,
  (SELECT recruiting_per_1000_cases FROM project.state_access
     WHERE state = 'Mississippi')                                             AS q10_13_6,
  (SELECT ROUND(CORR(avg_chemo_payment, recruiting_per_1000_cases)::numeric, 2)
     FROM project.state_access)                                               AS q11_0_06,
  (SELECT COUNT(*) FROM project.state_classification
     WHERE access_group = 'Underserved')                                      AS q12_14;
