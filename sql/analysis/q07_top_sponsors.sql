-- =========================================================
-- Q7: Who are the top 10 sponsors of cancer trials?
-- Approach: Count trials by lead sponsor and rank with RANK().
--           Also rank sponsors within each sponsor type using
--           RANK() OVER (PARTITION BY ...).
-- Name cleaning rule:
--   Combined: (1) spelling variants of the same organization
--   (e.g., "Novartis" + "Novartis Pharmaceuticals") and
--   (2) names that explicitly state their parent company
--   (e.g., "Wyeth is now a wholly owned subsidiary of Pfizer").
--   Kept separate: look-alike names that are different
--   organizations: Merck KGaA (Germany) vs. Merck & Co. (U.S.);
--   other countries' "National Cancer Institute"; university-
--   affiliated hospitals (independent institutions).
-- Caveat: Subsidiaries whose names don't mention a parent stay
--   separate (e.g., Genentech, owned by Roche).
-- Key finding: The U.S. National Cancer Institute leads all sponsors
--              (3,055 trials). Academic centers fill the rest of the
--              top 5: MD Anderson, Memorial Sloan Kettering, and two
--              Chinese universities (Sun Yat-sen, Fudan). Industry first
--              appears at #6 (Novartis); four drug companies make the
--              top 10. Even combined, the top 10 lead only ~12% of
--              cancer trials. Research is spread across thousands
--              of organizations.
-- =========================================================

-- Step A: Create a reusable view of trial counts per lead sponsor
CREATE OR REPLACE VIEW project.lead_sponsor_counts AS
WITH lead AS (
  SELECT
    c.nct_id,
    -- Standardize spelling variants and named subsidiaries
    CASE
      WHEN sp.name ~* '^novartis'                           THEN 'Novartis'
      WHEN sp.name ~* 'merck sharp|merck & co'              THEN 'Merck & Co. (MSD)'
      WHEN sp.name ~* 'pfizer' AND sp.name !~* 'viatris'    THEN 'Pfizer'
      WHEN sp.name ~* 'bristol-myers squibb'                THEN 'Bristol-Myers Squibb'
      WHEN sp.name ~* 'eli lilly'                           THEN 'Eli Lilly and Company'
      ELSE sp.name
    END AS sponsor,
    CASE
      WHEN sp.agency_class = 'INDUSTRY' THEN 'Industry'
      WHEN sp.agency_class = 'OTHER'    THEN 'Academic & medical centers'
      WHEN sp.agency_class = 'NETWORK'  THEN 'Research networks'
      WHEN sp.agency_class IN ('NIH', 'FED', 'OTHER_GOV') THEN 'Government'
      ELSE 'Individual or unknown'
    END AS sponsor_type
  FROM project.cancer_trials c
  JOIN sponsors sp USING (nct_id)
  WHERE sp.lead_or_collaborator = 'lead'
)
SELECT
  sponsor,
  sponsor_type,
  COUNT(*) AS trials,
  RANK() OVER (ORDER BY COUNT(*) DESC) AS overall_rank,
  RANK() OVER (PARTITION BY sponsor_type ORDER BY COUNT(*) DESC) AS rank_within_type
FROM lead
GROUP BY sponsor, sponsor_type;


-- Part 1: Top 10 sponsors overall
SELECT
  overall_rank,
  sponsor,
  sponsor_type,
  trials,
  ROUND(100.0 * trials / (SELECT COUNT(*) FROM project.cancer_trials), 1) AS pct_of_cancer_trials
FROM project.lead_sponsor_counts
WHERE overall_rank <= 10
ORDER BY overall_rank;


-- Part 2: Top 3 sponsors within each sponsor type
SELECT
  sponsor_type,
  rank_within_type,
  sponsor,
  trials
FROM project.lead_sponsor_counts
WHERE rank_within_type <= 3
  AND sponsor_type <> 'Individual or unknown'
ORDER BY sponsor_type, rank_within_type;


-- =========================================================
-- Validation: Which original names were combined?
-- Note: "Pfizer's Upjohn has merged with Mylan to form Viatris" appears
--       because it contains "Pfizer," but is NOT counted toward Pfizer
--       (Viatris is a separate company).
-- =========================================================
SELECT sp.name AS original_name,
       COUNT(*) AS trials
FROM project.cancer_trials c
JOIN sponsors sp USING (nct_id)
WHERE sp.lead_or_collaborator = 'lead'
  AND sp.name ~* '^novartis|merck sharp|merck & co|pfizer|bristol-myers squibb|eli lilly'
GROUP BY sp.name
ORDER BY sp.name;
