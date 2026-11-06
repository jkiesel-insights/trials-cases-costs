-- 03_import_state_data.sql
-- Loads CDC cancer incidence (2023) and CMS Medicare inpatient chemo costs
-- (2024, DRGs 846-848) into the project schema, then checks that state
-- names match across all three sources.
--
-- Load commands (run in Terminal after creating the raw tables below):
-- psql -p 5433 -d aact -c "\copy project.cdc_byarea_raw FROM '/Users/jessicakiesel/Desktop/trials-cases-costs/data/BYAREA.TXT' WITH (FORMAT csv, DELIMITER '|', HEADER true)"
-- psql -p 5433 -d aact -c "\copy project.cms_inpatient_raw FROM '/Users/jessicakiesel/Desktop/trials-cases-costs/data/cms_inpatient_geo.csv' WITH (FORMAT csv, HEADER true)"

-- =========================================================
-- CDC U.S. Cancer Statistics (BYAREA.TXT, pipe-delimited)
-- =========================================================
-- All TEXT at first: the CDC uses symbols like "~" for suppressed counts
CREATE TABLE project.cdc_byarea_raw (
  area                  TEXT,
  age_adjusted_ci_lower TEXT,
  age_adjusted_ci_upper TEXT,
  age_adjusted_rate     TEXT,
  count                 TEXT,
  event_type            TEXT,
  population            TEXT,
  race                  TEXT,
  sex                   TEXT,
  site                  TEXT,
  year                  TEXT
);

-- Keep 2023 new cases, all cancers, both sexes, all races (51 rows)
CREATE TABLE project.state_incidence AS
SELECT
  area AS state,
  CASE WHEN count ~ '^[0-9]+$' THEN count::int END AS case_count,
  CASE WHEN age_adjusted_rate ~ '^[0-9.]+$' THEN age_adjusted_rate::numeric END AS age_adj_rate,
  CASE WHEN population ~ '^[0-9]+$' THEN population::bigint END AS population
FROM project.cdc_byarea_raw
WHERE event_type = 'Incidence'
  AND site = 'All Cancer Sites Combined'
  AND sex = 'Male and Female'
  AND race = 'All Races'
  AND year = '2023';

-- =========================================================
-- CMS Medicare Inpatient Hospitals by Geography and Service (2024)
-- =========================================================
CREATE TABLE project.cms_inpatient_raw (
  geo_lvl            TEXT,
  geo_cd             TEXT,
  geo_desc           TEXT,
  drg_cd             TEXT,
  drg_desc           TEXT,
  tot_dschrgs        TEXT,
  avg_submtd_chrg    TEXT,
  avg_tot_pymt       TEXT,
  avg_mdcr_pymt      TEXT
);

-- One average payment per state for chemotherapy DRGs 846-848,
-- weighted by number of discharges (50 rows; Wyoming not published)
CREATE TABLE project.chemo_costs AS
SELECT
  geo_desc AS state,
  SUM(tot_dschrgs::int) AS chemo_discharges,
  ROUND(SUM(avg_tot_pymt::numeric * tot_dschrgs::int) / SUM(tot_dschrgs::int), 2) AS avg_chemo_payment
FROM project.cms_inpatient_raw
WHERE geo_lvl = 'State'
  AND drg_cd IN ('846', '847', '848')
GROUP BY geo_desc;

-- =========================================================
-- Validation: state names match across sources
-- =========================================================
SELECT * FROM project.state_incidence ORDER BY state;          -- 51 rows
SELECT * FROM project.chemo_costs ORDER BY avg_chemo_payment DESC;  -- 50 rows

-- States in the CDC table with no match in the CMS table (Result: Wyoming)
SELECT i.state
FROM project.state_incidence i
LEFT JOIN project.chemo_costs c ON i.state = c.state
WHERE c.state IS NULL;

-- States in the CMS table with no match in the CDC table (Result: none)
SELECT c.state
FROM project.chemo_costs c
LEFT JOIN project.state_incidence i ON c.state = i.state
WHERE i.state IS NULL;

-- U.S. trial-site states that don't match CDC names
-- (Result: only 2 sites entered as "Ill"; left as is)
SELECT f.state, COUNT(*) AS sites
FROM facilities f
LEFT JOIN project.state_incidence i ON f.state = i.state
WHERE f.country = 'United States'
  AND i.state IS NULL
GROUP BY f.state
ORDER BY sites DESC;
