-- 02_setup_cancer_filter.sql
-- Identifies cancer trials using MeSH condition terms.
-- Note: "neoplasm" terms may include a small number of benign tumor studies.

-- Preview matching terms
SELECT downcase_mesh_term, COUNT(DISTINCT nct_id) AS trials
FROM browse_conditions
WHERE downcase_mesh_term ~ '(cancer|carcinoma|neoplasm|lymphoma|leukemia|sarcoma|melanoma|myeloma|glioma|blastoma|tumor)'
GROUP BY downcase_mesh_term
ORDER BY trials DESC
LIMIT 40;

-- Excludes "tumor virus infections" (viral infections like HPV) and
-- "pseudotumor" terms (non-cancer conditions) found during Q2 review.
CREATE OR REPLACE VIEW project.cancer_trials AS
SELECT DISTINCT nct_id
FROM browse_conditions
WHERE downcase_mesh_term ~ '(cancer|carcinoma|neoplasm|lymphoma|leukemia|sarcoma|melanoma|myeloma|glioma|blastoma|tumor)'
  AND downcase_mesh_term !~ '(tumor virus infections|pseudotumor)';

-- Result: 107,273 cancer trials (107,889 before exclusions)
SELECT COUNT(*) FROM project.cancer_trials;

-- Spot-check random trials
SELECT s.nct_id, s.brief_title
FROM project.cancer_trials c
JOIN studies s USING (nct_id)
ORDER BY random()
LIMIT 20;
