-- =========================================================
-- Q10: Which states have the fewest trial sites per cancer case?
-- Approach: Join trial sites per state (view from Q9) to CDC 2023
--           new cancer cases. Compare all-time sites and currently
--           recruiting sites per 1,000 new cases, ranked from
--           fewest (rank 1) to most with RANK().
-- Why per case: States with older populations have more cancer
--               per resident, so this measures trial supply
--               against actual need, not just population.
-- Note: All-time sites span many years while cases are one year
--       (2023), so the all-time ratio is a comparison index, not a
--       literal count per patient.
-- Key finding: Mississippi (13.6), Alabama (13.7), Oklahoma (14.3),
--              West Virginia (15.4), and New Hampshire (15.5) have the
--              fewest currently recruiting sites per 1,000 new cancer
--              cases; DC (108.9), Montana (80.0), North Dakota (68.5),
--              Wisconsin (67.2), and Minnesota (65.9) have the most.
--              Patients in Wisconsin or Minnesota have ~5x as many open
--              trial sites per new case as those in Mississippi or
--              Alabama. The South and Appalachia cluster at the bottom
--              on both measures. Florida ranks 6th-fewest on all-time
--              sites per case, reflecting high cancer incidence.
-- Caveat: Patients near major hubs may cross state lines (e.g., New
--         Hampshire residents traveling to Boston cancer centers).
-- Validation: All 51 states/DC had 2023 case counts.
-- =========================================================

SELECT
  s.state,
  i.case_count AS new_cases_2023,
  s.trial_sites,
  s.recruiting_sites_now,
  ROUND(1000.0 * s.trial_sites / i.case_count, 1)          AS sites_per_1000_cases,
  ROUND(1000.0 * s.recruiting_sites_now / i.case_count, 1) AS recruiting_per_1000_cases,
  -- Rank 1 = fewest sites per case
  RANK() OVER (ORDER BY 1.0 * s.trial_sites / i.case_count ASC)          AS rank_fewest_all_time,
  RANK() OVER (ORDER BY 1.0 * s.recruiting_sites_now / i.case_count ASC) AS rank_fewest_recruiting
FROM project.state_sites s
JOIN project.state_incidence i USING (state)
WHERE i.case_count IS NOT NULL
ORDER BY rank_fewest_recruiting;


-- =========================================================
-- Validation: Any states missing case counts? (should be 0)
-- =========================================================
SELECT COUNT(*) AS states_missing_cases
FROM project.state_incidence
WHERE case_count IS NULL;
