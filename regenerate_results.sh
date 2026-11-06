#!/bin/bash
# Rebuilds every CSV in results/ directly from the project views in PostgreSQL.
# Run from Terminal:  bash ~/Desktop/trials-cases-costs/regenerate_results.sh
# Requires Postgres.app running on port 5433 with the aact database.

OUT="$(cd "$(dirname "$0")" && pwd)/results"
mkdir -p "$OUT"

run() {  # usage: run <file_name>  (query read from stdin)
  local q; q="$(cat)"
  psql -p 5433 -d aact -q -c "COPY ( ${q%;} ) TO STDOUT WITH CSV HEADER" > "$OUT/$1.csv" \
    && echo "  saved $1.csv" || echo "  FAILED $1.csv"
}

echo "Exporting results to $OUT"

run q01_phase_status <<'SQL'
WITH labeled AS (
  SELECT s.nct_id,
    CASE WHEN s.phase='EARLY_PHASE1' THEN 'Early Phase 1' WHEN s.phase='PHASE1' THEN 'Phase 1'
         WHEN s.phase='PHASE1/PHASE2' THEN 'Phase 1/2' WHEN s.phase='PHASE2' THEN 'Phase 2'
         WHEN s.phase='PHASE2/PHASE3' THEN 'Phase 2/3' WHEN s.phase='PHASE3' THEN 'Phase 3'
         WHEN s.phase='PHASE4' THEN 'Phase 4' WHEN s.phase='NA' THEN 'Not applicable'
         WHEN s.study_type='OBSERVATIONAL' THEN 'Observational (no phase)' ELSE 'Phase missing' END AS phase_label,
    CASE WHEN s.phase='EARLY_PHASE1' THEN 1 WHEN s.phase='PHASE1' THEN 2 WHEN s.phase='PHASE1/PHASE2' THEN 3
         WHEN s.phase='PHASE2' THEN 4 WHEN s.phase='PHASE2/PHASE3' THEN 5 WHEN s.phase='PHASE3' THEN 6
         WHEN s.phase='PHASE4' THEN 7 WHEN s.phase='NA' THEN 8
         WHEN s.study_type='OBSERVATIONAL' THEN 9 ELSE 10 END AS sort_order,
    CASE WHEN s.overall_status IN ('RECRUITING','ACTIVE_NOT_RECRUITING','NOT_YET_RECRUITING','ENROLLING_BY_INVITATION') THEN 'Active'
         WHEN s.overall_status='COMPLETED' THEN 'Completed'
         WHEN s.overall_status IN ('TERMINATED','WITHDRAWN','SUSPENDED') THEN 'Stopped early'
         WHEN s.overall_status='UNKNOWN' THEN 'Unknown' ELSE 'Expanded access' END AS status_group
  FROM project.cancer_trials c JOIN studies s USING (nct_id))
SELECT phase_label AS phase, COUNT(*) AS total_trials,
  COUNT(*) FILTER (WHERE status_group='Active') AS active,
  COUNT(*) FILTER (WHERE status_group='Completed') AS completed,
  COUNT(*) FILTER (WHERE status_group='Stopped early') AS stopped_early,
  COUNT(*) FILTER (WHERE status_group='Unknown') AS unknown,
  ROUND(100.0*COUNT(*) FILTER (WHERE status_group='Stopped early')/COUNT(*),1) AS pct_stopped_early
FROM labeled WHERE status_group <> 'Expanded access'
GROUP BY phase_label, sort_order ORDER BY sort_order
SQL

run q02_cancer_types <<'SQL'
WITH typed AS (
  SELECT DISTINCT b.nct_id,
    CASE WHEN b.downcase_mesh_term ~ 'breast' THEN 'Breast'
         WHEN b.downcase_mesh_term ~ 'lung|bronch' THEN 'Lung'
         WHEN b.downcase_mesh_term ~ 'colorectal|colonic|rectal' THEN 'Colorectal'
         WHEN b.downcase_mesh_term ~ 'prostat' THEN 'Prostate'
         WHEN b.downcase_mesh_term ~ 'leukemia' THEN 'Leukemia'
         WHEN b.downcase_mesh_term ~ 'lymphoma' THEN 'Lymphoma'
         WHEN b.downcase_mesh_term ~ 'myeloma' THEN 'Multiple myeloma'
         WHEN b.downcase_mesh_term ~ 'pancrea' THEN 'Pancreatic'
         WHEN b.downcase_mesh_term ~ 'liver|hepatocellular' THEN 'Liver'
         WHEN b.downcase_mesh_term ~ 'brain|glioma|glioblastoma|central nervous system' THEN 'Brain & CNS'
         WHEN b.downcase_mesh_term ~ 'ovarian' THEN 'Ovarian'
         WHEN b.downcase_mesh_term ~ 'melanoma' THEN 'Melanoma'
         WHEN b.downcase_mesh_term ~ 'head and neck|oropharyn|nasopharyn|laryn|mouth' THEN 'Head & neck'
         WHEN b.downcase_mesh_term ~ 'kidney|renal cell' THEN 'Kidney'
         WHEN b.downcase_mesh_term ~ 'urinary bladder' THEN 'Bladder'
         WHEN b.downcase_mesh_term ~ 'stomach|esophageal' THEN 'Stomach & esophageal'
         WHEN b.downcase_mesh_term ~ 'uterine|endometrial' THEN 'Cervical & uterine' END AS cancer_type
  FROM browse_conditions b JOIN project.cancer_trials c USING (nct_id)
  WHERE b.downcase_mesh_term ~ '(cancer|carcinoma|neoplasm|lymphoma|leukemia|sarcoma|melanoma|myeloma|glioma|blastoma|tumor)')
SELECT cancer_type, COUNT(DISTINCT nct_id) AS trials,
  ROUND(100.0*COUNT(DISTINCT nct_id)/(SELECT COUNT(*) FROM project.cancer_trials),1) AS pct_of_cancer_trials
FROM typed WHERE cancer_type IS NOT NULL GROUP BY cancer_type ORDER BY trials DESC
SQL

run q03_sponsors_lead <<'SQL'
WITH lead_sponsor AS (
  SELECT c.nct_id,
    CASE WHEN sp.agency_class='INDUSTRY' THEN 'Industry' WHEN sp.agency_class='OTHER' THEN 'Academic & medical centers'
         WHEN sp.agency_class='NETWORK' THEN 'Research networks'
         WHEN sp.agency_class IN ('NIH','FED','OTHER_GOV') THEN 'Government' ELSE 'Individual or unknown' END AS sponsor_type
  FROM project.cancer_trials c JOIN sponsors sp USING (nct_id) WHERE sp.lead_or_collaborator='lead')
SELECT ls.sponsor_type, COUNT(*) AS trials,
  ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct_of_trials,
  ROUND(100.0*COUNT(*) FILTER (WHERE s.phase IN ('PHASE3','PHASE2/PHASE3'))/COUNT(*),1) AS pct_late_stage
FROM lead_sponsor ls JOIN studies s USING (nct_id) GROUP BY ls.sponsor_type ORDER BY trials DESC
SQL

run q03_industry_involvement <<'SQL'
WITH involvement AS (
  SELECT c.nct_id,
    BOOL_OR(sp.agency_class='INDUSTRY' AND sp.lead_or_collaborator='lead') AS industry_lead,
    BOOL_OR(sp.agency_class='INDUSTRY' AND sp.lead_or_collaborator='collaborator') AS industry_partner
  FROM project.cancer_trials c JOIN sponsors sp USING (nct_id) GROUP BY c.nct_id)
SELECT COUNT(*) FILTER (WHERE industry_lead) AS industry_led,
  COUNT(*) FILTER (WHERE NOT industry_lead AND industry_partner) AS other_led_with_industry_partner,
  COUNT(*) FILTER (WHERE NOT industry_lead AND NOT industry_partner) AS no_industry_involvement,
  ROUND(100.0*COUNT(*) FILTER (WHERE industry_lead OR industry_partner)/COUNT(*),1) AS pct_any_industry
FROM involvement
SQL

run q04_remission_by_phase <<'SQL'
SELECT phase_group, COUNT(*) AS trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_arm_cr_pct)::numeric,1) AS median_cr_pct,
  ROUND(AVG(avg_arm_cr_pct),1) AS mean_cr_pct
FROM project.blood_cancer_cr GROUP BY phase_group ORDER BY phase_group
SQL

run q04_remission_by_sponsor <<'SQL'
SELECT sponsor_type, COUNT(*) AS trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_arm_cr_pct)::numeric,1) AS median_cr_pct,
  ROUND(AVG(avg_arm_cr_pct),1) AS mean_cr_pct
FROM project.blood_cancer_cr GROUP BY sponsor_type ORDER BY trials DESC
SQL

run q04_remission_top10 <<'SQL'
SELECT nct_id, brief_title, phase_group, sponsor_type, best_arm_cr_pct
FROM project.blood_cancer_cr ORDER BY best_arm_cr_pct DESC, nct_id LIMIT 10
SQL

run q05_stopped_reasons <<'SQL'
SELECT reason_category, COUNT(*) AS trials,
  ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct_of_stopped,
  COUNT(*) FILTER (WHERE overall_status='TERMINATED') AS terminated,
  COUNT(*) FILTER (WHERE overall_status='WITHDRAWN') AS withdrawn,
  COUNT(*) FILTER (WHERE overall_status='SUSPENDED') AS suspended
FROM project.stopped_reasons GROUP BY reason_category ORDER BY trials DESC
SQL

run q06_immunotherapy_growth <<'SQL'
WITH yearly AS (
  SELECT EXTRACT(YEAR FROM s.start_date)::int AS start_year, COUNT(*) AS all_cancer_trials,
    COUNT(*) FILTER (WHERE it.nct_id IS NOT NULL) AS immuno_trials
  FROM project.cancer_trials c JOIN studies s USING (nct_id)
  LEFT JOIN project.immuno_trials it USING (nct_id)
  WHERE s.start_date >= '2005-01-01' AND s.start_date < '2026-01-01' GROUP BY 1)
SELECT start_year, all_cancer_trials, immuno_trials,
  ROUND(100.0*immuno_trials/all_cancer_trials,1) AS pct_immuno,
  LAG(immuno_trials) OVER (ORDER BY start_year) AS prev_year_immuno,
  ROUND(100.0*(immuno_trials - LAG(immuno_trials) OVER (ORDER BY start_year))
        / NULLIF(LAG(immuno_trials) OVER (ORDER BY start_year),0),1) AS yoy_growth_pct
FROM yearly ORDER BY start_year
SQL

run q07_top_sponsors <<'SQL'
SELECT overall_rank, sponsor, sponsor_type, trials,
  ROUND(100.0*trials/(SELECT COUNT(*) FROM project.cancer_trials),1) AS pct_of_cancer_trials
FROM project.lead_sponsor_counts WHERE overall_rank <= 10 ORDER BY overall_rank
SQL

run q07_top_by_type <<'SQL'
SELECT sponsor_type, rank_within_type, sponsor, trials
FROM project.lead_sponsor_counts
WHERE rank_within_type <= 3 AND sponsor_type <> 'Individual or unknown'
ORDER BY sponsor_type, rank_within_type
SQL

run q08_duration_by_phase <<'SQL'
SELECT phase_label AS phase, COUNT(*) AS completed_trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_years)::numeric,1) AS median_years,
  ROUND(AVG(duration_years),1) AS mean_years
FROM project.trial_durations
WHERE overall_status='COMPLETED' AND duration_years > 0 AND duration_years <= 20
GROUP BY phase_label, sort_order ORDER BY sort_order
SQL

run q08_completed_vs_stopped <<'SQL'
SELECT CASE WHEN overall_status='COMPLETED' THEN 'Completed' ELSE 'Stopped early (terminated)' END AS outcome,
  COUNT(*) AS trials,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_years)::numeric,1) AS median_years,
  ROUND(AVG(duration_years),1) AS mean_years
FROM project.trial_durations
WHERE overall_status IN ('COMPLETED','TERMINATED') AND duration_years > 0 AND duration_years <= 20
GROUP BY 1 ORDER BY 1
SQL

run q09_sites_by_state <<'SQL'
SELECT state, trial_sites, trials, recruiting_sites_now, sites_per_million,
  RANK() OVER (ORDER BY trial_sites DESC) AS rank_by_total_sites,
  RANK() OVER (ORDER BY sites_per_million DESC) AS rank_per_million
FROM project.state_sites ORDER BY rank_by_total_sites
SQL

run q10_sites_per_case <<'SQL'
SELECT s.state, i.case_count AS new_cases_2023, s.trial_sites, s.recruiting_sites_now,
  ROUND(1000.0*s.trial_sites/i.case_count,1) AS sites_per_1000_cases,
  ROUND(1000.0*s.recruiting_sites_now/i.case_count,1) AS recruiting_per_1000_cases,
  RANK() OVER (ORDER BY 1.0*s.trial_sites/i.case_count ASC) AS rank_fewest_all_time,
  RANK() OVER (ORDER BY 1.0*s.recruiting_sites_now/i.case_count ASC) AS rank_fewest_recruiting
FROM project.state_sites s JOIN project.state_incidence i USING (state)
WHERE i.case_count IS NOT NULL ORDER BY rank_fewest_recruiting
SQL

run q11_cost_quartiles <<'SQL'
WITH ranked AS (
  SELECT *, NTILE(4) OVER (ORDER BY avg_chemo_payment) AS cost_quartile
  FROM project.state_access WHERE avg_chemo_payment IS NOT NULL)
SELECT cost_quartile, COUNT(*) AS states, MIN(avg_chemo_payment) AS lowest_cost,
  MAX(avg_chemo_payment) AS highest_cost,
  ROUND(AVG(recruiting_per_1000_cases),1) AS avg_recruiting_per_1000_cases,
  ROUND(AVG(sites_per_million),1) AS avg_sites_per_million
FROM ranked GROUP BY cost_quartile ORDER BY cost_quartile
SQL

run q11_cost_correlation <<'SQL'
SELECT COUNT(*) AS states,
  ROUND(CORR(avg_chemo_payment, recruiting_per_1000_cases)::numeric,2) AS corr_cost_vs_recruiting_per_case,
  ROUND(CORR(avg_chemo_payment, sites_per_million)::numeric,2) AS corr_cost_vs_sites_per_million
FROM project.state_access WHERE avg_chemo_payment IS NOT NULL
SQL

run q11_cost_by_state <<'SQL'
SELECT state, avg_chemo_payment, recruiting_per_1000_cases, sites_per_million,
  NTILE(4) OVER (ORDER BY avg_chemo_payment) AS cost_quartile
FROM project.state_access WHERE avg_chemo_payment IS NOT NULL ORDER BY avg_chemo_payment DESC
SQL

run q12_access_groups <<'SQL'
SELECT access_group, COUNT(*) AS states, ROUND(AVG(incidence_rate),1) AS avg_cancer_rate,
  ROUND(AVG(recruiting_per_1000_cases),1) AS avg_open_sites_per_1000_cases
FROM project.state_classification GROUP BY access_group ORDER BY access_group
SQL

run q12_underserved_states <<'SQL'
SELECT RANK() OVER (ORDER BY recruiting_per_1000_cases ASC) AS rank_least_access,
  state, incidence_rate, recruiting_per_1000_cases, median_incidence, median_access
FROM project.state_classification WHERE access_group='Underserved' ORDER BY rank_least_access
SQL

run q12_all_states <<'SQL'
SELECT state, access_group, incidence_rate, recruiting_per_1000_cases, sites_per_million, avg_chemo_payment
FROM project.state_classification ORDER BY access_group, recruiting_per_1000_cases
SQL

run summary_regions <<'SQL'
SELECT census_region, COUNT(*) AS states,
  COUNT(*) FILTER (WHERE access_group='Underserved') AS underserved_states,
  ROUND(AVG(incidence_rate),1) AS avg_cancer_rate,
  ROUND(AVG(recruiting_per_1000_cases),1) AS avg_open_sites_per_1000_cases,
  ROUND(AVG(sites_per_million),1) AS avg_sites_per_million
FROM project.state_profile GROUP BY census_region ORDER BY avg_open_sites_per_1000_cases
SQL

run summary_headline <<'SQL'
SELECT (SELECT COUNT(*) FROM project.cancer_trials) AS cancer_trials,
  (SELECT COUNT(*) FROM project.immuno_trials it JOIN project.cancer_trials c USING (nct_id)) AS immunotherapy_trials,
  (SELECT COUNT(*) FROM project.stopped_reasons) AS stopped_early_trials,
  (SELECT COUNT(*) FROM project.stopped_reasons WHERE reason_category='Low enrollment') AS stopped_for_low_enrollment,
  (SELECT SUM(trial_sites) FROM project.state_sites) AS us_trial_sites,
  (SELECT COUNT(*) FROM project.state_profile WHERE access_group='Underserved') AS underserved_states
SQL

run map_state_data <<'SQL'
SELECT state, census_region, access_group, recruiting_per_1000_cases, incidence_rate,
  sites_per_million, avg_chemo_payment
FROM project.state_profile ORDER BY state
SQL

echo "Done. CSV count: $(ls "$OUT"/*.csv | wc -l) (expect 24)"
