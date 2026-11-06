-- =========================================================
-- Q6: How have immunotherapy trials grown year over year?
--
-- Scope: Treatments that activate the immune system against
--   cancer: checkpoint inhibitors, CAR-T and other immune cell
--   therapies, cancer vaccines, and oncolytic viruses. Excludes
--   other monoclonal antibodies (e.g., trastuzumab, rituximab),
--   bispecific antibodies, and cytokines, which NCI's broader
--   definition of immunotherapy also includes.
--
-- Approach: No AACT column labels a trial as immunotherapy, so
--   trials are identified three ways (combined with UNION):
--   Method 1: MeSH intervention categories (e.g., Immune
--             Checkpoint Inhibitors)
--   Method 2: Drug naming conventions, because MeSH files drugs
--             by chemical structure, not by how they work
--   Method 3: Treatment descriptions, to catch drugs listed by
--             lab code (e.g., "SHR-1210, an anti-PD-1 antibody")
--   Then count trials by start year and use LAG() to compare
--   each year with the one before.
--
-- Term sources:
--   Definition: National Cancer Institute (cancer.gov),
--     "Immunotherapy to Treat Cancer"
--   MeSH categories: chosen from Discovery Step 1
--   Drug-name endings: WHO International Nonproprietary Names
--     (INN) rules: -li(m)- = immune-modulating antibodies;
--     -cel/-leucel = cell therapies (Discovery Step 3)
--   Cell therapy and vaccine wording: Discovery Step 4
--
-- Years: 2005-2025. Registration became widely required around
--   2005; 2026 is excluded as an incomplete year.
--
-- Coverage: 11,820 immunotherapy trials found. A missed-trial
--   check (Validation 3) estimates ~1,000 more are uncounted,
--   mostly vaccines and drugs listed only by lab code, so
--   coverage is ~92%. Counts are a conservative lower bound.
--
-- Key finding: Immunotherapy held a steady ~2.5-3.7% share of cancer
--              trials from 2005-2013 (mostly cancer vaccines). The
--              checkpoint-inhibitor era changed that: from 2014 to 2017
--              the share rose from 4.7% to 15.9%, with 2015 up 87% over
--              2014, following the first U.S. PD-1 approvals (2014) and
--              CAR-T (2017). Since 2018 the share has plateaued at
--              ~16-17.5%, peaking at 1,082 trials in 2024.
-- Caveats: Counts are a conservative lower bound (~92% coverage).
--          The 2025 dip may reflect late registrations.
-- =========================================================


-- =========================================================
-- Discovery Step 1: Which MeSH intervention categories relate
-- to the immune system? Some describe treatments (Immune
-- Checkpoint Inhibitors, Immunotherapy); others are lab tests
-- (Immunohistochemistry) or too broad (Immunoglobulins).
-- Result: "Immune Checkpoint Inhibitors" appears in only 260
-- cancer trials, far fewer than expected.
-- =========================================================
SELECT bi.mesh_term,
       bi.mesh_type,
       COUNT(DISTINCT bi.nct_id) AS trials
FROM browse_interventions bi
JOIN project.cancer_trials c USING (nct_id)
WHERE bi.downcase_mesh_term ~ 'immun|checkpoint'
GROUP BY bi.mesh_term, bi.mesh_type
ORDER BY trials DESC
LIMIT 40;


-- =========================================================
-- Discovery Step 2: Why so few? Test case: pembrolizumab
-- (Keytruda), the most common checkpoint inhibitor.
-- Result: MeSH lists it in 2,058 trials, but its parent
-- categories are chemical (Antibodies, Immunoglobulins,
-- Proteins), not "Immune Checkpoint Inhibitors."
-- =========================================================
SELECT bi.mesh_term,
       bi.mesh_type,
       COUNT(DISTINCT bi.nct_id) AS trials
FROM browse_interventions bi
JOIN project.cancer_trials c USING (nct_id)
WHERE bi.nct_id IN (SELECT nct_id FROM interventions WHERE name ~* 'pembrolizumab')
GROUP BY bi.mesh_term, bi.mesh_type
ORDER BY trials DESC
LIMIT 15;


-- =========================================================
-- Discovery Step 3: Drug naming conventions fill the gap.
-- Result: Nearly all matches are checkpoint inhibitors or
-- CAR-T, except tocilizumab, which suppresses the immune
-- system (excluded below, along with similar sarilumab).
-- =========================================================
SELECT i.name, COUNT(DISTINCT i.nct_id) AS trials
FROM interventions i
JOIN project.cancer_trials c USING (nct_id)
WHERE i.name ~* '(lizumab|limumab|lumab|limab|leucel)\M'
GROUP BY i.name
ORDER BY trials DESC
LIMIT 30;


-- =========================================================
-- Discovery Step 4: How do researchers name cell therapies
-- and vaccines? Result: CAR-T is written many ways ("CAR-T
-- cells," "CAR T cells," "Chimeric Antigen Receptor T-Cell
-- Therapy"); "tumor vaccine" is used alongside "cancer
-- vaccine"; "Oncolytic Virotherapy" is a MeSH category.
-- =========================================================
SELECT bi.mesh_term AS mesh_category,
       i.name AS intervention_name,
       COUNT(DISTINCT i.nct_id) AS trials
FROM browse_interventions bi
JOIN interventions i USING (nct_id)
JOIN project.cancer_trials c USING (nct_id)
WHERE bi.downcase_mesh_term IN ('immunotherapy, adoptive', 'cancer vaccines', 'oncolytic virotherapy')
GROUP BY bi.mesh_term, i.name
ORDER BY trials DESC
LIMIT 30;


-- =========================================================
-- Step A: Create a reusable view of immunotherapy trials
-- =========================================================
CREATE OR REPLACE VIEW project.immuno_trials AS
-- Method 1: MeSH categories
SELECT bi.nct_id
FROM browse_interventions bi
WHERE bi.downcase_mesh_term IN ('immune checkpoint inhibitors',
                                'immunotherapy',
                                'immunotherapy, adoptive',
                                'antineoplastic agents, immunological',
                                'cancer vaccines',
                                'oncolytic virotherapy')
UNION
-- Method 2: drug naming conventions and therapy names
-- (excludes tocilizumab and sarilumab: they end in -lizumab/-lumab
--  but suppress the immune system, mainly to treat CAR-T side effects)
SELECT i.nct_id
FROM interventions i
WHERE i.name ~* '((lizumab|limumab|lumab|limab|leucel)\M|\mcar[- ]?t\M|chimeric antigen receptor|tumor infiltrating lymphocyte|oncolytic|cancer vaccine|tumor vaccine)'
  AND i.name !~* 'tocilizumab|sarilumab'
UNION
-- Method 3: treatment name + description (catches code-named
-- drugs and generic wording); excludes infection/preventive
-- vaccines, imaging agents, and immune-suppressing drugs
SELECT i.nct_id
FROM interventions i
WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL', 'GENETIC', 'COMBINATION_PRODUCT')
  AND (i.name || ' ' || COALESCE(i.description, '')) ~* '(anti-?pd-?l?1|pd-?l?1 (antibody|inhibitor|blockade)|ctla-?4|checkpoint inhibitor|\mcar[- /]?t\M|chimeric antigen receptor|dendritic cell|tumor[- ]infiltrating lymphocyte|oncolytic|vaccin|immunotherap)'
  AND (i.name || ' ' || COALESCE(i.description, '')) !~* '(influenza|covid|coronavirus|sars-cov|pneumococ|zoster|shingles|pylori|gardasil|cervarix|quadrivalent|bivalent|nonavalent|\mpet\M|positron|imaging|tracer|tocilizumab|sarilumab)';


-- =========================================================
-- Main query: Immunotherapy trials by start year
-- =========================================================

-- Count all cancer trials and immunotherapy trials by start year
WITH yearly AS (
  SELECT
    EXTRACT(YEAR FROM s.start_date)::int AS start_year,
    COUNT(*) AS all_cancer_trials,
    COUNT(*) FILTER (WHERE it.nct_id IS NOT NULL) AS immuno_trials
  FROM project.cancer_trials c
  JOIN studies s USING (nct_id)
  LEFT JOIN project.immuno_trials it USING (nct_id)
  WHERE s.start_date >= '2005-01-01'
    AND s.start_date <  '2026-01-01'
  GROUP BY 1
)

-- Compare each year with the year before using LAG()
SELECT
  start_year,
  all_cancer_trials,
  immuno_trials,
  ROUND(100.0 * immuno_trials / all_cancer_trials, 1) AS pct_immuno,
  LAG(immuno_trials) OVER (ORDER BY start_year) AS prev_year_immuno,
  ROUND(100.0 * (immuno_trials - LAG(immuno_trials) OVER (ORDER BY start_year))
        / NULLIF(LAG(immuno_trials) OVER (ORDER BY start_year), 0), 1) AS yoy_growth_pct
FROM yearly
ORDER BY start_year;


-- =========================================================
-- Validation 1: Less common names matched by Method 2
-- (rows 31-60; rows 1-30 reviewed in Discovery Step 3).
-- Result: all genuine immunotherapies.
-- =========================================================
SELECT i.name, COUNT(DISTINCT i.nct_id) AS trials
FROM interventions i
JOIN project.cancer_trials c USING (nct_id)
WHERE i.name ~* '((lizumab|limumab|lumab|limab|leucel)\M|\mcar[- ]?t\M|chimeric antigen receptor|tumor infiltrating lymphocyte|oncolytic|cancer vaccine|tumor vaccine)'
  AND i.name !~* 'tocilizumab|sarilumab'
GROUP BY i.name
ORDER BY trials DESC
LIMIT 30 OFFSET 30;


-- =========================================================
-- Validation 2: What did Method 3 add? Random sample of
-- trials found only by treatment descriptions.
-- Result: ~80% genuine before exclusions; false matches
-- (preventive vaccines, PET tracers) led to the exclusion list.
-- =========================================================
SELECT s.nct_id, s.brief_title, i.name
FROM interventions i
JOIN project.cancer_trials c USING (nct_id)
JOIN studies s USING (nct_id)
WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL', 'GENETIC', 'COMBINATION_PRODUCT')
  AND (i.name || ' ' || COALESCE(i.description, '')) ~* '(anti-?pd-?l?1|pd-?l?1 (antibody|inhibitor|blockade)|ctla-?4|checkpoint inhibitor|\mcar[- /]?t\M|chimeric antigen receptor|dendritic cell|tumor[- ]infiltrating lymphocyte|oncolytic|vaccin|immunotherap)'
  AND (i.name || ' ' || COALESCE(i.description, '')) !~* '(influenza|covid|coronavirus|sars-cov|pneumococ|zoster|shingles|pylori|gardasil|cervarix|quadrivalent|bivalent|nonavalent|\mpet\M|positron|imaging|tracer|tocilizumab|sarilumab)'
  AND i.name !~* '((lizumab|limumab|lumab|limab|leucel)\M|\mcar[- ]?t\M|chimeric antigen receptor|tumor infiltrating lymphocyte|oncolytic|cancer vaccine|tumor vaccine)'
ORDER BY random()
LIMIT 25;


-- =========================================================
-- Validation 3: Missed-trial check. Trials whose TITLES use
-- immunotherapy language but weren't flagged.
-- Results: 3,373 before Method 3; 2,023 after. A random sample
-- of 25 showed ~half are real immunotherapy (vaccines, unusual
-- cell-therapy wording, lab-code drug names such as BMS-936558
-- = nivolumab); the rest are correctly excluded (observational
-- or biomarker studies, trials AFTER immunotherapy, imaging,
-- preventive vaccines). Estimated ~1,000 missed, ~92% coverage.
-- =========================================================

-- Count of possibly missed trials
SELECT COUNT(*) AS possibly_missed
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
WHERE s.brief_title ~* 'immunotherap|checkpoint|pd-1|pd-l1|ctla-4|car-t|car t|cell therapy|vaccine|oncolytic'
  AND c.nct_id NOT IN (SELECT nct_id FROM project.immuno_trials);

-- Random sample of possibly missed trials
SELECT s.nct_id, s.brief_title
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
WHERE s.brief_title ~* 'immunotherap|checkpoint|pd-1|pd-l1|ctla-4|car-t|car t|cell therapy|vaccine|oncolytic'
  AND c.nct_id NOT IN (SELECT nct_id FROM project.immuno_trials)
ORDER BY random()
LIMIT 25;

-- Total immunotherapy trials found (11,820)
SELECT COUNT(*) AS immuno_trials_found
FROM project.immuno_trials it
JOIN project.cancer_trials c USING (nct_id);
