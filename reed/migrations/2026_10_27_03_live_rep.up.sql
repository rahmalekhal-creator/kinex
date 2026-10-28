-- Per-rep results of the live sets (all tracked exercises), and two new counts per set.
--   status: good / mistake / unsure / not_scored / below_target (e4: good form under the range target) /
--           wrong_side (done with the other arm or leg: not counted)
--   label:  the model class (e1-e3: good, elb, rngdown, imb, shld, lean, wrong; e4: good, knee, leanin, leanout),
--           or not_scored / wrong_side
--   peak_deg / target_deg: e4 only, the leg angle at the top of the rep and the target it was judged against.
-- The patient's usual e4 lift = the median peak_deg of their good-form reps (computed from these rows).
-- live_set is created by reed/notifications_lib.php; run this after it exists. Existing rows get 0 in the new counts.
CREATE TABLE IF NOT EXISTS `live_rep` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `live_set_id` INT NOT NULL,
  `ppid` INT NOT NULL,
  `patient_id` INT NOT NULL,
  `ai_exercise` VARCHAR(8) NULL,
  `rep` INT NOT NULL,
  `label` VARCHAR(16) NOT NULL,
  `status` VARCHAR(16) NOT NULL,
  `confidence` FLOAT NULL,
  `peak_deg` FLOAT NULL,
  `target_deg` FLOAT NULL,
  `created_at` DATETIME NOT NULL,
  UNIQUE KEY `uq_live_rep` (`live_set_id`, `rep`),
  KEY `idx_live_rep_patient` (`patient_id`, `ai_exercise`, `label`),
  CONSTRAINT `chk_live_rep_status` CHECK (`status` IN ('good','mistake','unsure','not_scored','below_target','wrong_side')),
  CONSTRAINT `chk_live_rep_label` CHECK (`label` IN ('good','elb','rngdown','imb','shld','lean','wrong','knee','leanin','leanout','not_scored','wrong_side'))
) DEFAULT CHARSET=utf8mb4;

ALTER TABLE `live_set` ADD COLUMN `below_target` INT NOT NULL DEFAULT 0;
ALTER TABLE `live_set` ADD COLUMN `wrong_side` INT NOT NULL DEFAULT 0;
