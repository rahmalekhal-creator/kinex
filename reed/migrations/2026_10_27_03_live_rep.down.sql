-- Undo 2026_10_27_03_live_rep.up.sql (the per-rep results and the two counts are lost).
ALTER TABLE `live_set` DROP COLUMN `wrong_side`;
ALTER TABLE `live_set` DROP COLUMN `below_target`;
DROP TABLE IF EXISTS `live_rep`;
