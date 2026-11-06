-- =========================================================
-- Q2: Which cancer types have the most trials?
-- Approach: Map MeSH condition terms to 17 major cancer types
--           with CASE + regex; count distinct trials per type.
--           Only cancer-specific terms are used, so unrelated
--           tags (e.g., "liver diseases") aren't miscounted.
-- Note: A trial can study more than one cancer type, so
--       percentages can sum to more than 100%.
-- Key finding: Breast (14,549 trials; 13.6%) and lung (11,763; 11.0%)
--              cancers are the most studied. Prostate cancer, the 2nd
--              most diagnosed cancer in the U.S. (CDC 2023), ranks only
--              7th in trials (6.1%).
-- Note: "Head & neck" follows MeSH, which includes thyroid and eye
--       cancers, so it ranks higher than mouth/throat cancers alone would.
-- =========================================================

-- Assign each cancer term to a major cancer type
WITH typed AS (
  SELECT DISTINCT
    b.nct_id,
    CASE
      WHEN b.downcase_mesh_term ~ 'breast'                                   THEN 'Breast'
      WHEN b.downcase_mesh_term ~ 'lung|bronch'                              THEN 'Lung'
      WHEN b.downcase_mesh_term ~ 'colorectal|colonic|rectal'                THEN 'Colorectal'
      WHEN b.downcase_mesh_term ~ 'prostat'                                  THEN 'Prostate'
      WHEN b.downcase_mesh_term ~ 'leukemia'                                 THEN 'Leukemia'
      WHEN b.downcase_mesh_term ~ 'lymphoma'                                 THEN 'Lymphoma'
      WHEN b.downcase_mesh_term ~ 'myeloma'                                  THEN 'Multiple myeloma'
      WHEN b.downcase_mesh_term ~ 'pancrea'                                  THEN 'Pancreatic'
      WHEN b.downcase_mesh_term ~ 'liver|hepatocellular'                     THEN 'Liver'
      WHEN b.downcase_mesh_term ~ 'brain|glioma|glioblastoma|central nervous system' THEN 'Brain & CNS'
      WHEN b.downcase_mesh_term ~ 'ovarian'                                  THEN 'Ovarian'
      WHEN b.downcase_mesh_term ~ 'melanoma'                                 THEN 'Melanoma'
      WHEN b.downcase_mesh_term ~ 'head and neck|oropharyn|nasopharyn|laryn|mouth' THEN 'Head & neck'
      WHEN b.downcase_mesh_term ~ 'kidney|renal cell'                        THEN 'Kidney'
      WHEN b.downcase_mesh_term ~ 'urinary bladder'                          THEN 'Bladder'
      WHEN b.downcase_mesh_term ~ 'stomach|esophageal'                       THEN 'Stomach & esophageal'
      WHEN b.downcase_mesh_term ~ 'uterine|endometrial'                      THEN 'Cervical & uterine'
    END AS cancer_type
  FROM browse_conditions b
  JOIN project.cancer_trials c USING (nct_id)
  -- Only use terms that are themselves cancer terms
  WHERE b.downcase_mesh_term ~ '(cancer|carcinoma|neoplasm|lymphoma|leukemia|sarcoma|melanoma|myeloma|glioma|blastoma|tumor)'
)

-- Count trials per type and compare to all cancer trials
SELECT
  cancer_type,
  COUNT(DISTINCT nct_id) AS trials,
  ROUND(100.0 * COUNT(DISTINCT nct_id) / (SELECT COUNT(*) FROM project.cancer_trials), 1) AS pct_of_cancer_trials
FROM typed
WHERE cancer_type IS NOT NULL
GROUP BY cancer_type
ORDER BY trials DESC;
