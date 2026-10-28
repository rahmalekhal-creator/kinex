-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Oct 09, 2026 at 09:36 PM
-- Server version: 9.1.0
-- PHP Version: 8.3.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `physio_clinic`
--

-- --------------------------------------------------------

--
-- Table structure for table `account`
--

DROP TABLE IF EXISTS `account`;
CREATE TABLE IF NOT EXISTS `account` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('clinic','therapist','patient','admin') NOT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `Photo` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `account`
--

INSERT INTO `account` (`id`, `email`, `password_hash`, `role`, `is_active`, `created_at`, `Photo`) VALUES
(5, 'clinique1@gmail.com', '$2y$10$8KjZ.V.zX9Y7v9Qf1a7kOe9Gv7Z2p7l8M9N0O1P2Q3R4S5T6U7V8W', 'clinic', 1, '2026-05-03 21:00:36', 'uploads/profiles/profile_5_1780481701_af0885d0.jpg'),
(6, 'patient1@gmail.com', '$2y$10$2SoqkMG7eYeuQTEweMBpROos/v3wf2B8KHayIhYcRqCGMwYdgLXoW', 'patient', 1, '2026-05-03 21:30:30', 'uploads/photos/profile_6_1777892341.jpg'),
(7, 'physio1@gmail.com', '$2y$10$DU1tvQfI08EaAbHZznTayu9lvTER/jl8u2tXs5fStN5DzeVFqVOY.', 'therapist', 0, '2026-05-03 21:31:22', ''),
(8, 'admin1@gmail.com', '$2y$10$2SoqkMG7eYeuQTEweMBpROos/v3wf2B8KHayIhYcRqCGMwYdgLXoW', 'admin', 1, '2026-05-12 14:34:36', ''),
(9, 'clinique2@gmail.com', '$2y$10$O1Hj3vchBVI2od2gfTmISOy33YO.jUXlamfWriCw8ciRY7Cwrkc6q', 'clinic', 1, '2026-05-12 14:36:23', 'uploads/profiles/profile_9_1778618039_d4f73865.jpg'),
(10, 'physio2@gmail.com', '$2y$10$vTtVRV1BvyG2UpRAdL4BC.7J0jWd.7imXjpWQjv2ioxN4tpbwaDLW', 'therapist', 1, '2026-05-12 14:38:52', ''),
(11, 'patient2@gmail.com', '$2y$10$f/ahEc3DBgyEwzjt8pIKxueS5taN/zNm5MBdIzRSsOihK5KX4jsMS', 'patient', 1, '2026-05-12 14:44:50', ''),
(12, 'physio3@gmail.com', '$2y$10$oZgRQI2g6MibjqIAdXDnfO2Jh8ULWTsZzxKDeyqfus6k11VNqysWK', 'therapist', 1, '2026-05-12 15:12:06', ''),
(13, 'clinique3@gmail.com', '$2y$10$UqHC3Gl68iJiqzr37SroGOpAaxbFrRUW0Ck8tsa5Jq9D4pwmDe1le', 'clinic', 1, '2026-06-02 23:13:30', 'uploads/profiles/profile_13_1780439614_36df96bc.jpg'),
(14, 'physio4@gmail.com', '$2y$10$6pJWt6gG982TtFLCeQMWW.mkfPWcHbGei/18Ia3sSd6LFak0HcZci', 'therapist', 1, '2026-06-02 23:34:24', ''),
(15, 'patient3@gmail.com', '$2y$10$35mbx8Oe3VnjemevKgCsIOmWf2u5W/JE8eDzJcyQdZXWSiztDrmBC', 'patient', 1, '2026-06-02 23:35:34', ''),
(16, 'clinique4@gmail.com', '$2y$10$fYYuNJiXOub9c6iL7KuV3OgauY3WVOocLp8IHYm6VkGst.rXWVkyW', 'clinic', 1, '2026-06-03 11:08:54', 'uploads/profiles/profile_16_1780481433_3f646373.jpg'),
(17, 'physio5@gmail.com', '$2y$10$5tEL.GHdPMyMb0aam9UYM.9fRwJNAJ3i9.7MbWlmcBcWNV4XfLYg.', 'therapist', 1, '2026-06-03 11:11:17', ''),
(18, 'patient5@gmail.com', '$2y$10$X8W3YgOcWJu9T00uqXRoku7LMdwng4r02Ij3UL..hKA8rMSZAK34C', 'patient', 1, '2026-06-03 11:11:48', ''),
(19, 'clinicouissal@gmail.com', '$2y$10$iAoa4y6lpj.EEKeSRR0IYOl15Xu4smgRi6pLzRC3N1UPBoS/8dDnW', 'clinic', 1, '2026-10-06 21:30:52', ''),
(20, 'admin2@gmail.com', '$2y$10$Pod3bVHM1EL9dJIBSZ5BB.XvClwiYlo7jyEVlRR5X6.WYEcsrgERK', 'admin', 1, '2026-10-06 21:40:03', ''),
(22, 'sirine@gmail.com', '$2y$10$DtIJ7wcCBVSYHNDlFFib6usimsIJqx0VCnyw/H9IF1bYdo7arr8N2', 'therapist', 1, '2026-10-06 21:49:54', ''),
(23, 'ouissal@gmail.com', '$2y$10$Ucf7OLgBV4xf4F7T/EzQyOqGiqDybHTNpxNc9NFnIkYINgpfADhlu', 'patient', 1, '2026-10-06 21:51:52', '');

-- --------------------------------------------------------

--
-- Table structure for table `aifeedback`
--

DROP TABLE IF EXISTS `aifeedback`;
CREATE TABLE IF NOT EXISTS `aifeedback` (
  `id` int NOT NULL AUTO_INCREMENT,
  `analysis` text,
  `score` float DEFAULT NULL,
  `generated_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `progressreport_id` int NOT NULL,
  `vid_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  PRIMARY KEY (`id`,`progressreport_id`),
  KEY `fk_aifeedback_progressreport1_idx` (`progressreport_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `clinic`
--

DROP TABLE IF EXISTS `clinic`;
CREATE TABLE IF NOT EXISTS `clinic` (
  `id` int NOT NULL AUTO_INCREMENT,
  `account_id` int NOT NULL,
  `name` varchar(255) NOT NULL,
  `address` text,
  `phone` varchar(20) DEFAULT NULL,
  `justif` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_id` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `clinic`
--

INSERT INTO `clinic` (`id`, `account_id`, `name`, `address`, `phone`, `justif`) VALUES
(2, 5, 'Clinique1', 'Adresse 1', '06666666', ''),
(3, 9, 'clinique2', '1234', '123445', 'uploads/justif/justif_1778592983_83d6e9d5.jpeg'),
(4, 13, 'clinique3', 'clinique3', '123456', 'uploads/justif/justif_1780438410_09979411.jpeg'),
(5, 16, 'clinique4', 'gagag', '1234151', 'uploads/justif/justif_1780481334_3395b6e5.jpeg'),
(6, 19, 'clinicouissal', 'lkhroub', '0123456789', 'uploads/justif/justif_1791318652_1aa1f91a.jpg');

-- --------------------------------------------------------

--
-- Table structure for table `complaintform`
--

DROP TABLE IF EXISTS `complaintform`;
CREATE TABLE IF NOT EXISTS `complaintform` (
  `id` int NOT NULL AUTO_INCREMENT,
  `patient_id` int NOT NULL,
  `description` text,
  `symptoms` text,
  `submitted_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(50) DEFAULT 'pending',
  PRIMARY KEY (`id`),
  KEY `patient_id` (`patient_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `complaintform`
--

INSERT INTO `complaintform` (`id`, `patient_id`, `description`, `symptoms`, `submitted_at`, `status`) VALUES
(2, 2, 'abcd', 'headache', '2026-05-04 11:50:25', 'pending'),
(3, 3, 'testa', 'test', '2026-05-12 21:52:12', 'pending'),
(4, 4, 'tests', 'ayayay', '2026-06-03 00:01:06', 'pending'),
(5, 5, 'tagag', 'gagaga', '2026-06-03 11:16:47', 'pending');

-- --------------------------------------------------------

--
-- Table structure for table `exercise`
--

DROP TABLE IF EXISTS `exercise`;
CREATE TABLE IF NOT EXISTS `exercise` (
  `id` int NOT NULL AUTO_INCREMENT,
  `therapist_id` int NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text,
  `video_url` varchar(500) DEFAULT NULL,
  `difficulty` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `therapist_id` (`therapist_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `exercise`
--

INSERT INTO `exercise` (`id`, `therapist_id`, `name`, `description`, `video_url`, `difficulty`) VALUES
(5, 2, 'AAROM Shoulder Flexion', 'This exercise improves shoulder mobility and flexibility. Hold the stick with both hands and gently raise your arms forward and overhead, using the stronger arm to assist the movement.', 'https://www.youtube.com/watch?v=T8WgORjc4cI', 'Easy'),
(6, 2, 'arm abduction', 'The arm abduction exercise helps improve shoulder mobility and strength. Slowly raise your arm out to the side until it reaches a comfortable height, then lower it back down.\n', 'https://www.youtube.com/watch?v=jP0WF6ymeTM', 'Moderate'),
(7, 2, 'external rotation shoulder', 'This exercise helps strengthen the shoulder and improve external rotation. Keep your elbow close to your body and slowly rotate your forearm outward, then return to the starting position.', 'https://www.youtube.com/watch?v=Ccsu1i5A7Zw', 'Easy'),
(9, 2, 'Standing Hip Abduction', 'This exercise strengthens the hip muscles and improves stability. Stand upright and slowly lift one leg out to the side, keeping your body straight, then return to the starting position.', 'https://www.youtube.com/watch?v=zuPfEhL_2qU', 'Easy');

-- --------------------------------------------------------

--
-- Table structure for table `message`
--

DROP TABLE IF EXISTS `message`;
CREATE TABLE IF NOT EXISTS `message` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sender_id` int NOT NULL,
  `receiver_id` int NOT NULL,
  `content` text NOT NULL,
  `sent_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `is_read` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `sender_id` (`sender_id`),
  KEY `receiver_id` (`receiver_id`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `message`
--

INSERT INTO `message` (`id`, `sender_id`, `receiver_id`, `content`, `sent_at`, `is_read`) VALUES
(6, 6, 7, 'test', '2026-05-03 21:53:05', 0),
(7, 7, 6, 'test', '2026-05-03 22:15:42', 0),
(8, 6, 7, 'HELLOOOO', '2026-05-04 00:47:34', 0),
(9, 7, 6, 'hello', '2026-05-04 01:00:11', 0),
(10, 7, 6, 'abcd', '2026-05-04 11:46:25', 0),
(11, 6, 7, 'abcdef', '2026-05-04 11:50:08', 0),
(12, 6, 7, 'test', '2026-05-04 12:12:52', 0),
(13, 10, 11, 'test', '2026-05-12 18:53:10', 0),
(14, 11, 10, 'test2', '2026-05-12 19:02:40', 0),
(15, 11, 10, 'aaa', '2026-05-12 21:52:04', 0),
(16, 14, 15, 'hello', '2026-06-02 23:42:44', 0),
(17, 15, 14, 'hello', '2026-06-02 23:45:28', 0),
(18, 15, 14, 'hello', '2026-06-03 00:01:20', 0),
(19, 15, 14, 'test2', '2026-06-03 00:27:19', 0),
(20, 17, 18, 'test', '2026-06-03 11:13:54', 0),
(21, 18, 17, 'ABD', '2026-06-03 11:15:09', 0);

-- --------------------------------------------------------

--
-- Table structure for table `patient`
--

DROP TABLE IF EXISTS `patient`;
CREATE TABLE IF NOT EXISTS `patient` (
  `id` int NOT NULL AUTO_INCREMENT,
  `account_id` int NOT NULL,
  `clinic_id` int NOT NULL,
  `therapist_id` int DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_id` (`account_id`),
  KEY `clinic_id` (`clinic_id`),
  KEY `therapist_id` (`therapist_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `patient`
--

INSERT INTO `patient` (`id`, `account_id`, `clinic_id`, `therapist_id`, `name`, `phone`, `birth_date`) VALUES
(2, 6, 2, 2, 'patient1', '0666666', '2000-01-01'),
(3, 11, 3, 3, 'patient2', '123', '2025-12-12'),
(4, 15, 4, 5, 'patient3', '123456', '1996-01-17'),
(5, 18, 5, 6, 'patient5', '14214214', '1996-01-09'),
(7, 23, 6, 7, 'ouissal', '0123456789', '2003-06-03');

-- --------------------------------------------------------

--
-- Table structure for table `patientexercise`
--

DROP TABLE IF EXISTS `patientexercise`;
CREATE TABLE IF NOT EXISTS `patientexercise` (
  `id` int NOT NULL AUTO_INCREMENT,
  `patient_id` int NOT NULL,
  `exercise_id` int NOT NULL,
  `assigned_by` int NOT NULL,
  `assigned_date` date DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `Sets` int NOT NULL,
  `Reps` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `patient_id` (`patient_id`),
  KEY `exercise_id` (`exercise_id`),
  KEY `assigned_by` (`assigned_by`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `patientexercise`
--

INSERT INTO `patientexercise` (`id`, `patient_id`, `exercise_id`, `assigned_by`, `assigned_date`, `status`, `Sets`, `Reps`) VALUES
(7, 2, 7, 2, '2026-05-03', 'Completed', 2, 10),
(8, 2, 5, 2, '2026-05-03', 'Pending', 3, 12),
(9, 2, 6, 2, '2026-05-03', 'Pending', 2, 10),
(11, 2, 7, 2, '2026-05-04', 'Completed', 4, 10),
(12, 3, 5, 3, '2026-05-12', 'Completed', 3, 10),
(14, 3, 6, 3, '2026-05-12', 'Pending', 2, 10),
(15, 4, 7, 5, '2026-06-02', 'Completed', 2, 10),
(16, 4, 5, 5, '2026-06-02', 'Pending', 3, 12),
(17, 4, 6, 5, '2026-06-03', 'Pending', 2, 10),
(18, 5, 7, 6, '2026-06-03', 'Pending', 2, 10),
(19, 5, 5, 6, '2026-06-03', 'Completed', 3, 12),
(20, 2, 5, 2, '2026-10-06', 'Pending', 3, 10),
(21, 7, 5, 7, '2026-10-06', 'Pending', 3, 10),
(22, 7, 6, 7, '2026-10-06', 'Pending', 2, 10),
(23, 7, 7, 7, '2026-10-09', 'Pending', 2, 10);

-- --------------------------------------------------------

--
-- Table structure for table `physiotherapist`
--

DROP TABLE IF EXISTS `physiotherapist`;
CREATE TABLE IF NOT EXISTS `physiotherapist` (
  `id` int NOT NULL AUTO_INCREMENT,
  `account_id` int NOT NULL,
  `clinic_id` int NOT NULL,
  `name` varchar(255) NOT NULL,
  `specialization` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_id` (`account_id`),
  KEY `clinic_id` (`clinic_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `physiotherapist`
--

INSERT INTO `physiotherapist` (`id`, `account_id`, `clinic_id`, `name`, `specialization`, `phone`) VALUES
(2, 7, 2, 'physio1', 'Sports Rehab', '0666666'),
(3, 10, 3, 'physio2', 'Orthopedic', '123'),
(4, 12, 3, 'physio3', 'Sports', '123'),
(5, 14, 4, 'physio4', 'Orthopedi', '123456'),
(6, 17, 5, 'physio5', 'Ortho', '121412421'),
(7, 22, 6, 'sirine', 'Rheumatology', '0123456789');

-- --------------------------------------------------------

--
-- Table structure for table `progressreport`
--

DROP TABLE IF EXISTS `progressreport`;
CREATE TABLE IF NOT EXISTS `progressreport` (
  `id` int NOT NULL AUTO_INCREMENT,
  `date` datetime DEFAULT CURRENT_TIMESTAMP,
  `notes` text,
  `pain_level` int DEFAULT NULL,
  `reps_done` int NOT NULL,
  `ppid` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  KEY `fk_progressreport_patientexercise1_idx` (`ppid`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `progressreport`
--

INSERT INTO `progressreport` (`id`, `date`, `notes`, `pain_level`, `reps_done`, `ppid`) VALUES
(3, '2026-05-03 23:44:43', NULL, 5, 21, 8),
(4, '2026-05-03 23:45:12', NULL, 5, 20, 7),
(5, '2026-05-04 00:47:55', 'TEST', 7, 14, 9),
(6, '2026-05-04 11:49:51', 'was too hard', 7, 40, 11),
(7, '2026-05-12 21:51:49', 'NOT FULL', 7, 0, 14),
(8, '2026-05-12 19:02:27', NULL, 6, 30, 12),
(9, '2026-06-02 23:46:51', 'test', 6, 12, 16),
(10, '2026-06-02 23:46:58', NULL, 3, 20, 15),
(11, '2026-06-03 11:16:15', 'TEST', 5, 36, 19),
(12, '2026-06-03 11:16:19', NULL, 5, 10, 18);

-- --------------------------------------------------------

--
-- Table structure for table `subscription`
--

DROP TABLE IF EXISTS `subscription`;
CREATE TABLE IF NOT EXISTS `subscription` (
  `id` int NOT NULL AUTO_INCREMENT,
  `clinic_id` int NOT NULL,
  `plan` varchar(100) DEFAULT NULL,
  `amount` float DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `clinic_id` (`clinic_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `subscription`
--

INSERT INTO `subscription` (`id`, `clinic_id`, `plan`, `amount`, `start_date`, `end_date`, `status`) VALUES
(6, 3, 'yearly', 50.1, '2026-05-12', '2027-05-12', 'active'),
(7, 4, 'yearly', 50.1, '2026-06-02', '2027-06-02', 'active'),
(8, 5, 'yearly', 50.1, '2026-06-03', '2027-06-03', 'active'),
(9, 6, 'yearly', 50.1, '2026-10-06', '2027-10-06', 'active');

--
-- Constraints for dumped tables
--

--
-- Constraints for table `aifeedback`
--
ALTER TABLE `aifeedback`
  ADD CONSTRAINT `fk_aifeedback_progressreport1` FOREIGN KEY (`progressreport_id`) REFERENCES `progressreport` (`id`);

--
-- Constraints for table `clinic`
--
ALTER TABLE `clinic`
  ADD CONSTRAINT `clinic_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `complaintform`
--
ALTER TABLE `complaintform`
  ADD CONSTRAINT `complaintform_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `exercise`
--
ALTER TABLE `exercise`
  ADD CONSTRAINT `exercise_ibfk_1` FOREIGN KEY (`therapist_id`) REFERENCES `physiotherapist` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `message`
--
ALTER TABLE `message`
  ADD CONSTRAINT `message_ibfk_1` FOREIGN KEY (`sender_id`) REFERENCES `account` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `message_ibfk_2` FOREIGN KEY (`receiver_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `patient`
--
ALTER TABLE `patient`
  ADD CONSTRAINT `patient_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patient_ibfk_2` FOREIGN KEY (`clinic_id`) REFERENCES `clinic` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patient_ibfk_3` FOREIGN KEY (`therapist_id`) REFERENCES `physiotherapist` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `patientexercise`
--
ALTER TABLE `patientexercise`
  ADD CONSTRAINT `patientexercise_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patientexercise_ibfk_2` FOREIGN KEY (`exercise_id`) REFERENCES `exercise` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patientexercise_ibfk_3` FOREIGN KEY (`assigned_by`) REFERENCES `physiotherapist` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `physiotherapist`
--
ALTER TABLE `physiotherapist`
  ADD CONSTRAINT `physiotherapist_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `physiotherapist_ibfk_2` FOREIGN KEY (`clinic_id`) REFERENCES `clinic` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `progressreport`
--
ALTER TABLE `progressreport`
  ADD CONSTRAINT `fk_progressreport_patientexercise1` FOREIGN KEY (`ppid`) REFERENCES `patientexercise` (`id`);

--
-- Constraints for table `subscription`
--
ALTER TABLE `subscription`
  ADD CONSTRAINT `subscription_ibfk_1` FOREIGN KEY (`clinic_id`) REFERENCES `clinic` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
