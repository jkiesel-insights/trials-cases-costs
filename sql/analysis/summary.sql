-- =========================================================
-- Summary: State profiles, regional patterns, and project
--          headline numbers
-- Approach: Combine all state-level measures (Q9-Q12) into one
--           view, add U.S. Census regions, and compare regions.
--           A final query collects headline totals in one row.
-- Key finding: The Midwest has the best trial access (50.8 open sites
--              per 1,000 new cancer cases) and no underserved states,
--              despite the highest average cancer rate (473.5 new cases
--              per 100,000 people, age-adjusted). The South has the
--              lowest access (27.6), about half the Midwest's, and 11 of
--              the 14 underserved states. The Northeast has a similar
--              cancer rate to the South, only slightly better access
--              (29.7), and the other 3 underserved states. The West has
--              the lowest cancer rate (415.4) and no underserved states,
--              though access varies widely within the region.
-- Headline totals: 107,273 cancer trials; 11,820 immunotherapy trials;
--                  14,287 stopped early (5,025 for low enrollment);
--                  579,483 U.S. trial sites; 14 underserved states.
-- Note: Running these totals caught an arithmetic error in Q5's key
--       finding (14,307 corrected to 14,287).
-- =========================================================

-- Part 1: Create a state profile view with Census regions
CREATE OR REPLACE VIEW project.state_profile AS
SELECT
  sc.*,
  CASE
    WHEN sc.state IN ('Connecticut', 'Maine', 'Massachusetts', 'New Hampshire',
                      'Rhode Island', 'Vermont', 'New Jersey', 'New York',
                      'Pennsylvania')
      THEN 'Northeast'
    WHEN sc.state IN ('Illinois', 'Indiana', 'Michigan', 'Ohio', 'Wisconsin',
                      'Iowa', 'Kansas', 'Minnesota', 'Missouri', 'Nebraska',
                      'North Dakota', 'South Dakota')
      THEN 'Midwest'
    WHEN sc.state IN ('Delaware', 'District of Columbia', 'Florida', 'Georgia',
                      'Maryland', 'North Carolina', 'South Carolina', 'Virginia',
                      'West Virginia', 'Alabama', 'Kentucky', 'Mississippi',
                      'Tennessee', 'Arkansas', 'Louisiana', 'Oklahoma', 'Texas')
      THEN 'South'
    ELSE 'West'
  END AS census_region,
  RANK() OVER (ORDER BY sc.recruiting_per_1000_cases ASC) AS rank_least_access,
  RANK() OVER (ORDER BY sc.incidence_rate DESC)           AS rank_highest_cancer_rate
FROM project.state_classification sc;


-- Part 2: Trial access and underserved states by region
SELECT
  census_region,
  COUNT(*) AS states,
  COUNT(*) FILTER (WHERE access_group = 'Underserved') AS underserved_states,
  ROUND(AVG(incidence_rate), 1)            AS avg_cancer_rate,
  ROUND(AVG(recruiting_per_1000_cases), 1) AS avg_open_sites_per_1000_cases,
  ROUND(AVG(sites_per_million), 1)         AS avg_sites_per_million
FROM project.state_profile
GROUP BY census_region
ORDER BY avg_open_sites_per_1000_cases;


-- Part 3: Project headline numbers
SELECT
  (SELECT COUNT(*) FROM project.cancer_trials)                       AS cancer_trials,
  (SELECT COUNT(*) FROM project.immuno_trials it
     JOIN project.cancer_trials c USING (nct_id))                    AS immunotherapy_trials,
  (SELECT COUNT(*) FROM project.stopped_reasons)                     AS stopped_early_trials,
  (SELECT COUNT(*) FROM project.stopped_reasons
     WHERE reason_category = 'Low enrollment')                       AS stopped_for_low_enrollment,
  (SELECT SUM(trial_sites) FROM project.state_sites)                 AS us_trial_sites,
  (SELECT COUNT(*) FROM project.state_profile
     WHERE access_group = 'Underserved')                             AS underserved_states;


-- Part 4: Map-ready data, one row per state (for Tableau)
SELECT
  state,
  census_region,
  access_group,
  recruiting_per_1000_cases,
  incidence_rate,
  sites_per_million,
  avg_chemo_payment
FROM project.state_profile
ORDER BY state;
