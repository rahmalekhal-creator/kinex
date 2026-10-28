-- Undo 2026_10_27_02_e4_prescription.up.sql (the e4 target angles are lost).
ALTER TABLE `patientexercise` DROP COLUMN `target_deg`;
