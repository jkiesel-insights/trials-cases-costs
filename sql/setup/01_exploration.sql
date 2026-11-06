-- 01_exploration.sql
-- Previewing the key AACT tables used in this project

-- Core study info: phase, status, dates, why_stopped
SELECT nct_id, brief_title, phase, overall_status, start_date, completion_date, why_stopped
FROM studies LIMIT 20;

-- Standardized condition terms (used to find cancer trials)
SELECT * FROM browse_conditions LIMIT 20;

-- Free-text conditions as entered by researchers
SELECT * FROM conditions LIMIT 20;

-- Sponsors: lead vs. collaborator, industry vs. other
SELECT * FROM sponsors LIMIT 20;

-- Trial sites: city, state, country
SELECT nct_id, name, city, state, country FROM facilities LIMIT 20;

-- Interventions: drugs, biologicals, etc.
SELECT * FROM interventions LIMIT 20;

-- Standardized intervention categories (used in Q6)
SELECT * FROM browse_interventions LIMIT 20;

-- Pre-calculated fields
SELECT * FROM calculated_values LIMIT 20;

-- Outcome results (for the remission question)
SELECT nct_id, outcome_type, title, units FROM outcomes LIMIT 20;
