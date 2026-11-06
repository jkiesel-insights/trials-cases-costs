-- =========================================================
-- Q12: Which states look underserved overall?
-- Definition: "Underserved" = BOTH
--   (1) a cancer rate above the national median (CDC 2023,
--       age-adjusted, which removes the effect of older
--       populations), AND
--   (2) trial access below the median (open trial sites per
--       1,000 new cancer cases, from Q10).
-- Approach: Calculate both medians, attach them to every state
--           with CROSS JOIN, and sort states into four groups
--           with CASE. Underserved states are ranked from least
--           to most access.
-- Key finding: 14 states are underserved, with both an above-median
--              cancer rate and below-median trial access. 11 of the 14
--              are in the South (Mississippi, Oklahoma, West Virginia,
--              Louisiana, Georgia, Arkansas, Florida, Kentucky, North
--              Carolina, Tennessee, Maryland); the rest are in the
--              Northeast (New Hampshire, Maine, New Jersey). Kentucky
--              has the highest cancer rate in the group (530.5 per
--              100,000). Underserved states average 20.8 open trial
--              sites per 1,000 new cancer cases, about 2.5x less than
--              the best-served group (51.6).
-- Notes: Alabama has very low access but a cancer rate just below the
--        median, so it is classed "Lower need, low access." States
--        near a median (e.g., Florida's cancer rate, Maryland's access)
--        are borderline.
-- =========================================================

-- Step A: Create a reusable view classifying each state
CREATE OR REPLACE VIEW project.state_classification AS
WITH medians AS (
  SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY incidence_rate)            AS median_incidence,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY recruiting_per_1000_cases) AS median_access
  FROM project.state_access
)
SELECT
  a.state,
  a.incidence_rate,
  a.recruiting_per_1000_cases,
  a.sites_per_million,
  a.avg_chemo_payment,
  ROUND(m.median_incidence::numeric, 1) AS median_incidence,
  ROUND(m.median_access::numeric, 1)    AS median_access,
  CASE
    WHEN a.incidence_rate > m.median_incidence
     AND a.recruiting_per_1000_cases < m.median_access THEN 'Underserved'
    WHEN a.incidence_rate > m.median_incidence         THEN 'High need, better served'
    WHEN a.recruiting_per_1000_cases < m.median_access THEN 'Lower need, low access'
    ELSE 'Lower need, better served'
  END AS access_group
FROM project.state_access a
CROSS JOIN medians m;   -- attaches the one-row medians to every state


-- Part 1: How many states fall in each group?
SELECT
  access_group,
  COUNT(*) AS states,
  ROUND(AVG(incidence_rate), 1)            AS avg_cancer_rate,
  ROUND(AVG(recruiting_per_1000_cases), 1) AS avg_open_sites_per_1000_cases
FROM project.state_classification
GROUP BY access_group
ORDER BY access_group;


-- Part 2: The underserved states, ranked from least to most access
SELECT
  RANK() OVER (ORDER BY recruiting_per_1000_cases ASC) AS rank_least_access,
  state,
  incidence_rate,
  recruiting_per_1000_cases,
  median_incidence,
  median_access
FROM project.state_classification
WHERE access_group = 'Underserved'
ORDER BY rank_least_access;


-- Part 3: All states with their group (for charts)
SELECT state, access_group, incidence_rate, recruiting_per_1000_cases, sites_per_million, avg_chemo_payment
FROM project.state_classification
ORDER BY access_group, recruiting_per_1000_cases;
