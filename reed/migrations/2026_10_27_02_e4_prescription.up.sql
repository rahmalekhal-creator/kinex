-- e4 (standing hip abduction) prescriptions: the lifted leg is patientexercise.side (as the arm of e1-e3);
-- target_deg = the physiotherapist's target lift angle in degrees (NULL = not set: the app uses 75 % of the
-- patient's usual lift, or the default angle). Existing rows get NULL: e1-e3 data is unchanged.
-- Run once (MySQL has no ADD COLUMN IF NOT EXISTS); the PHP endpoints add it by themselves if it is missing.
ALTER TABLE `patientexercise` ADD COLUMN `target_deg` DECIMAL(5,1) NULL DEFAULT NULL;
