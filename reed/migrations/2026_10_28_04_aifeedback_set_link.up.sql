-- aifeedback.live_set_id: the live set an AI feedback row was written for, so the session log opens the feedback of
-- each set. Existing rows keep NULL (they are matched to their sets by order). The PHP endpoints add it on first use.
ALTER TABLE `aifeedback` ADD COLUMN `live_set_id` INT NULL DEFAULT NULL;
