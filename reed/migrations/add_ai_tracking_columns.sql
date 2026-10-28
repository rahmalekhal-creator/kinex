-- Live camera tracking chosen by the physiotherapist when assigning an exercise.
-- The PHP endpoints add these columns by themselves if they are missing; run this only if you prefer to do it by hand.
ALTER TABLE `patientexercise` ADD COLUMN `ai_exercise` VARCHAR(8) NULL DEFAULT NULL;
ALTER TABLE `patientexercise` ADD COLUMN `side` VARCHAR(8) NULL DEFAULT NULL;
