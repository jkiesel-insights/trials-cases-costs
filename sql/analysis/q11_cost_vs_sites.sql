-- =========================================================
-- Q11: Do states with higher chemo costs have more or fewer
--      trial sites?
-- Cost measure: Average total Medicare payment per inpatient
--   chemotherapy stay (CMS 2024, DRGs 846-848), weighted by
--   discharges. Reflects regional hospital price differences.
-- Access measures:
--   Sites per million residents: a state's trial sites for every
--     1 million people living there. Compares states fairly, no
--     matter their size.
--   Open sites per 1,000 new cancer cases: trial sites currently
--     enrolling for every 1,000 people diagnosed with cancer.
--     Compares access against the number of people who need it.
-- Approach: (1) Split states into cost quartiles with NTILE(4)
--           and compare trial access across quartiles.
--           (2) Measure the relationship with CORR() (Pearson
--           correlation, -1 to +1).
-- Note: Wyoming has no published CMS chemo cost data and is
--       excluded from cost comparisons (n = 50 incl. DC).
-- Key finding: The cost of an inpatient chemo stay varies widely by
--              state, from about $10,400 to $27,200 (DC is highest).
--              But cost is not linked to trial access. We compared cost
--              with two access measures:
--                - open trial sites per 1,000 people newly diagnosed
--                  with cancer, and
--                - total trial sites per 1 million residents.
--              Neither rises or falls with cost: correlations are close
--              to zero (0.06 and -0.10 on a scale of -1 to +1). States
--              in every cost group average a similar 31-39 open trial
--              sites per 1,000 new cancer cases.
-- Caveat: Measures Medicare INPATIENT chemotherapy only; most chemo is
--         given outpatient, so this is a narrow slice of patient costs.
-- =========================================================

-- Step A: Create a combined state view (reused in Q12 and the summary)
CREATE OR REPLACE VIEW project.state_access AS
SELECT
  s.state,
  i.population,
  i.case_count AS new_cases_2023,
  i.age_adj_rate AS incidence_rate,
  s.trial_sites,
  s.recruiting_sites_now,
  s.sites_per_million,
  ROUND(1000.0 * s.trial_sites / i.case_count, 1)          AS sites_per_1000_cases,
  ROUND(1000.0 * s.recruiting_sites_now / i.case_count, 1) AS recruiting_per_1000_cases,
  cc.avg_chemo_payment,
  cc.chemo_discharges
FROM project.state_sites s
JOIN project.state_incidence i USING (state)
LEFT JOIN project.chemo_costs cc USING (state);   -- LEFT JOIN keeps Wyoming


-- Part 1: Trial access by chemo cost quartile
WITH ranked AS (
  SELECT *,
         NTILE(4) OVER (ORDER BY avg_chemo_payment) AS cost_quartile
  FROM project.state_access
  WHERE avg_chemo_payment IS NOT NULL
)
SELECT
  cost_quartile,                              -- 1 = cheapest, 4 = most expensive
  COUNT(*) AS states,
  MIN(avg_chemo_payment) AS lowest_cost,
  MAX(avg_chemo_payment) AS highest_cost,
  ROUND(AVG(recruiting_per_1000_cases), 1) AS avg_recruiting_per_1000_cases,
  ROUND(AVG(sites_per_million), 1)         AS avg_sites_per_million
FROM ranked
GROUP BY cost_quartile
ORDER BY cost_quartile;


-- Part 2: Correlation between chemo cost and trial access
SELECT
  COUNT(*) AS states,
  ROUND(CORR(avg_chemo_payment, recruiting_per_1000_cases)::numeric, 2) AS corr_cost_vs_recruiting_per_case,
  ROUND(CORR(avg_chemo_payment, sites_per_million)::numeric, 2)         AS corr_cost_vs_sites_per_million
FROM project.state_access
WHERE avg_chemo_payment IS NOT NULL;


-- Part 3: All states, most to least expensive (for charts)
SELECT
  state,
  avg_chemo_payment,
  recruiting_per_1000_cases,
  sites_per_million,
  NTILE(4) OVER (ORDER BY avg_chemo_payment) AS cost_quartile
FROM project.state_access
WHERE avg_chemo_payment IS NOT NULL
ORDER BY avg_chemo_payment DESC;
