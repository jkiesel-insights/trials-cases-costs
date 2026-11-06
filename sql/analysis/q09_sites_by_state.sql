-- =========================================================
-- Q9: How many cancer trial sites does each state have?
-- Approach: Count U.S. trial sites (one site = one location
--           participating in one trial) by state, joined to the
--           CDC table to standardize state names and add
--           population. Compare total sites and sites per million
--           residents, ranked with RANK().
-- Note: The view created here is reused in Q10-Q12.
-- Key finding: The most populous states lead in total sites (California
--              49,989; Illinois 36,283; Ohio 35,296), but per resident
--              they split: Ohio (11th), Illinois (12th), and Michigan
--              (10th) rank high, while California (39th), Florida (42nd),
--              and Texas (46th) rank low. Smaller Midwest and Plains
--              states lead per capita (Montana #1 at 6,427 per million;
--              DC, Kansas, North Dakota, Minnesota follow). The bottom
--              six per capita are all Southern states: Mississippi (760
--              per million, last), Alabama, Oklahoma, Arkansas, Georgia,
--              and Texas.
-- Caveats: Large network trials list many community sites, which can
--          boost smaller states. Patients cross state lines (e.g., DC
--          hospitals serve Maryland and Virginia residents).
-- Validation: 579,483 of 579,484 U.S. sites matched a state.
-- =========================================================

-- Step A: Create a reusable view of trial sites per state
CREATE OR REPLACE VIEW project.state_sites AS
SELECT
  i.state,
  COUNT(*) AS trial_sites,
  COUNT(DISTINCT f.nct_id) AS trials,
  COUNT(*) FILTER (WHERE UPPER(f.status) = 'RECRUITING') AS recruiting_sites_now,
  i.population,
  ROUND(1000000.0 * COUNT(*) / i.population, 1) AS sites_per_million
FROM facilities f
JOIN project.cancer_trials c USING (nct_id)
JOIN project.state_incidence i ON f.state = i.state
WHERE f.country = 'United States'
GROUP BY i.state, i.population;


-- Main query: All states, ranked two ways
SELECT
  state,
  trial_sites,
  trials,
  recruiting_sites_now,
  sites_per_million,
  RANK() OVER (ORDER BY trial_sites DESC)       AS rank_by_total_sites,
  RANK() OVER (ORDER BY sites_per_million DESC) AS rank_per_million
FROM project.state_sites
ORDER BY rank_by_total_sites;


-- =========================================================
-- Validation: Do the state totals account for all U.S. sites?
-- (Day 1 found only 2 unmatched sites, entered as "Ill")
-- =========================================================
SELECT
  (SELECT COUNT(*)
   FROM facilities f
   JOIN project.cancer_trials c USING (nct_id)
   WHERE f.country = 'United States') AS all_us_sites,
  (SELECT SUM(trial_sites) FROM project.state_sites) AS sites_matched_to_states;
