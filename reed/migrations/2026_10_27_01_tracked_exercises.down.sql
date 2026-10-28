-- Undo 2026_10_27_01_tracked_exercises.up.sql. patientexercise.ai_exercise keeps its values (e1-e4): it never
-- referenced these tables.
DROP TABLE IF EXISTS `tracked_exercise`;
DROP TABLE IF EXISTS `body_region`;
