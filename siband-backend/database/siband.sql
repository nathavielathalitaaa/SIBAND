-- MySQL dump 10.13  Distrib 8.4.11, for Linux (x86_64)
--
-- Host: localhost    Database: siband
-- ------------------------------------------------------
-- Server version	8.4.11-0ubuntu0.26.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `cache`
--

DROP TABLE IF EXISTS `cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache`
--

LOCK TABLES `cache` WRITE;
/*!40000 ALTER TABLE `cache` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cache_locks`
--

DROP TABLE IF EXISTS `cache_locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache_locks` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_locks_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache_locks`
--

LOCK TABLES `cache_locks` WRITE;
/*!40000 ALTER TABLE `cache_locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache_locks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `children`
--

DROP TABLE IF EXISTS `children`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `children` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `nickname` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `birth_year` year NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `children_user_id_foreign` (`user_id`),
  CONSTRAINT `children_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `children`
--

LOCK TABLES `children` WRITE;
/*!40000 ALTER TABLE `children` DISABLE KEYS */;
INSERT INTO `children` VALUES (1,1,'Anak Demo',2018,'2026-10-29 20:53:32','2026-10-29 20:53:32');
/*!40000 ALTER TABLE `children` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `devices`
--

DROP TABLE IF EXISTS `devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `devices` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `child_id` bigint unsigned DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `mac` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_seen_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `devices_mac_unique` (`mac`),
  KEY `devices_child_id_foreign` (`child_id`),
  CONSTRAINT `devices_child_id_foreign` FOREIGN KEY (`child_id`) REFERENCES `children` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `devices`
--

LOCK TABLES `devices` WRITE;
/*!40000 ALTER TABLE `devices` DISABLE KEYS */;
INSERT INTO `devices` VALUES (1,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF','2026-10-29 20:53:32','2026-10-29 20:53:32','2026-10-29 20:53:32');
/*!40000 ALTER TABLE `devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_notes`
--

DROP TABLE IF EXISTS `event_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_notes` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `child_id` bigint unsigned NOT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `occurred_at` timestamp NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_notes_child_id_occurred_at_index` (`child_id`,`occurred_at`),
  CONSTRAINT `event_notes_child_id_foreign` FOREIGN KEY (`child_id`) REFERENCES `children` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_notes`
--

LOCK TABLES `event_notes` WRITE;
/*!40000 ALTER TABLE `event_notes` DISABLE KEYS */;
INSERT INTO `event_notes` VALUES (1,1,'aktivitas_fisik',NULL,'2026-10-28 03:12:11','2026-10-29 20:53:32','2026-10-29 20:53:32'),(2,1,'meltdown','Velit sit dolore deleniti.','2026-10-29 03:28:56','2026-10-29 20:53:32','2026-10-29 20:53:32'),(3,1,'lainnya','Et quas pariatur temporibus dolor non.','2026-10-28 22:34:58','2026-10-29 20:53:32','2026-10-29 20:53:32'),(4,1,'suara_keras','Qui doloremque debitis deserunt dolorem aperiam.','2026-10-29 12:42:12','2026-10-29 20:53:32','2026-10-29 20:53:32'),(5,1,'suara_keras','Et explicabo animi debitis est.','2026-10-11 09:24:17','2026-10-29 20:53:32','2026-10-29 20:53:32');
/*!40000 ALTER TABLE `event_notes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `failed_jobs`
--

DROP TABLE IF EXISTS `failed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `failed_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`),
  KEY `failed_jobs_connection_queue_failed_at_index` (`connection`,`queue`,`failed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `failed_jobs`
--

LOCK TABLES `failed_jobs` WRITE;
/*!40000 ALTER TABLE `failed_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `failed_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `heart_rate_logs`
--

DROP TABLE IF EXISTS `heart_rate_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `heart_rate_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned DEFAULT NULL,
  `device_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_mac` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bpm` smallint unsigned NOT NULL,
  `recorded_at` timestamp NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `child_id` bigint unsigned DEFAULT NULL,
  `device_id` bigint unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `heart_rate_logs_user_id_foreign` (`user_id`),
  KEY `heart_rate_logs_device_id_foreign` (`device_id`),
  KEY `heart_rate_logs_child_id_recorded_at_index` (`child_id`,`recorded_at`),
  CONSTRAINT `heart_rate_logs_child_id_foreign` FOREIGN KEY (`child_id`) REFERENCES `children` (`id`) ON DELETE SET NULL,
  CONSTRAINT `heart_rate_logs_device_id_foreign` FOREIGN KEY (`device_id`) REFERENCES `devices` (`id`) ON DELETE SET NULL,
  CONSTRAINT `heart_rate_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=101 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `heart_rate_logs`
--

LOCK TABLES `heart_rate_logs` WRITE;
/*!40000 ALTER TABLE `heart_rate_logs` DISABLE KEYS */;
INSERT INTO `heart_rate_logs` VALUES (1,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',95,'2026-10-29 13:32:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(2,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',108,'2026-10-29 10:58:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(3,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',72,'2026-10-29 07:19:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(4,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',88,'2026-10-29 20:30:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(5,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',103,'2026-10-29 19:01:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(6,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',77,'2026-10-29 02:51:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(7,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',84,'2026-10-29 02:15:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(8,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',98,'2026-10-28 21:10:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(9,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',99,'2026-10-29 00:34:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(10,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',90,'2026-10-29 09:11:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(11,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',89,'2026-10-29 05:52:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(12,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',79,'2026-10-29 03:52:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(13,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',100,'2026-10-29 05:56:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(14,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',109,'2026-10-29 09:36:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(15,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',79,'2026-10-28 23:28:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(16,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',86,'2026-10-29 19:50:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(17,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',102,'2026-10-29 04:36:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(18,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',95,'2026-10-29 08:34:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(19,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',107,'2026-10-29 08:32:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(20,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',73,'2026-10-29 01:59:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(21,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',104,'2026-10-29 05:28:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(22,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',107,'2026-10-29 12:26:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(23,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',109,'2026-10-29 02:28:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(24,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',72,'2026-10-29 10:38:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(25,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',104,'2026-10-29 08:52:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(26,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',76,'2026-10-28 21:58:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(27,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',109,'2026-10-29 11:26:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(28,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',110,'2026-10-29 11:45:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(29,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',100,'2026-10-29 10:46:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(30,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',72,'2026-10-28 22:49:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(31,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',99,'2026-10-29 09:56:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(32,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',88,'2026-10-29 16:34:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(33,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',107,'2026-10-29 11:25:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(34,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',96,'2026-10-29 19:17:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(35,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',71,'2026-10-28 20:53:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(36,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',71,'2026-10-29 12:34:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(37,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',77,'2026-10-29 18:05:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(38,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',106,'2026-10-29 08:41:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(39,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',89,'2026-10-28 22:57:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(40,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',80,'2026-10-29 00:29:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(41,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',81,'2026-10-29 02:03:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(42,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',75,'2026-10-29 06:11:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(43,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',92,'2026-10-29 19:49:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(44,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',98,'2026-10-29 09:14:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(45,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',105,'2026-10-29 19:04:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(46,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',87,'2026-10-29 03:38:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(47,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',105,'2026-10-29 07:13:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(48,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',73,'2026-10-29 11:55:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(49,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',95,'2026-10-29 00:22:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(50,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',89,'2026-10-28 23:28:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(51,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',83,'2026-10-29 12:47:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(52,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',105,'2026-10-29 19:12:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(53,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',81,'2026-10-29 00:22:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(54,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',106,'2026-10-29 14:21:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(55,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',80,'2026-10-29 17:06:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(56,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',78,'2026-10-29 18:03:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(57,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',85,'2026-10-29 12:03:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(58,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',70,'2026-10-29 08:08:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(59,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',77,'2026-10-29 08:35:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(60,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',98,'2026-10-29 08:35:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(61,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',109,'2026-10-29 06:51:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(62,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',105,'2026-10-29 10:02:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(63,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',106,'2026-10-29 01:19:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(64,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',87,'2026-10-29 20:29:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(65,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',78,'2026-10-29 14:12:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(66,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',81,'2026-10-29 14:23:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(67,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',82,'2026-10-29 05:13:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(68,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',79,'2026-10-29 08:31:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(69,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',88,'2026-10-29 17:57:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(70,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',78,'2026-10-29 04:26:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(71,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',107,'2026-10-29 02:37:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(72,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',110,'2026-10-28 22:26:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(73,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',84,'2026-10-29 19:40:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(74,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',86,'2026-10-29 02:48:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(75,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',89,'2026-10-29 14:40:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(76,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',108,'2026-10-29 06:12:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(77,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',84,'2026-10-29 11:59:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(78,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',108,'2026-10-29 19:44:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(79,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',89,'2026-10-28 23:40:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(80,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',86,'2026-10-29 05:41:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(81,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',103,'2026-10-29 07:08:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(82,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',103,'2026-10-29 17:42:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(83,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',98,'2026-10-28 23:27:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(84,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',95,'2026-10-29 18:45:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(85,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',79,'2026-10-29 09:19:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(86,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',105,'2026-10-29 19:38:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(87,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',108,'2026-10-29 02:53:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(88,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',95,'2026-10-29 04:42:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(89,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',84,'2026-10-29 13:40:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(90,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',84,'2026-10-29 02:52:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(91,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',88,'2026-10-29 13:29:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(92,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',98,'2026-10-28 22:17:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(93,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',84,'2026-10-29 08:44:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(94,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',102,'2026-10-29 06:37:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(95,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',110,'2026-10-29 16:45:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(96,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',77,'2026-10-29 09:41:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(97,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',83,'2026-10-29 09:10:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(98,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',86,'2026-10-29 13:25:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(99,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',93,'2026-10-28 21:54:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1),(100,1,'Infinix XWatch H4','AA:BB:CC:DD:EE:FF',98,'2026-10-29 02:34:32','2026-10-29 20:53:32','2026-10-29 20:53:32',1,1);
/*!40000 ALTER TABLE `heart_rate_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_batches`
--

DROP TABLE IF EXISTS `job_batches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_batches` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_jobs` int NOT NULL,
  `pending_jobs` int NOT NULL,
  `failed_jobs` int NOT NULL,
  `failed_job_ids` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `options` mediumtext COLLATE utf8mb4_unicode_ci,
  `cancelled_at` int DEFAULT NULL,
  `created_at` int NOT NULL,
  `finished_at` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `job_batches`
--

LOCK TABLES `job_batches` WRITE;
/*!40000 ALTER TABLE `job_batches` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_batches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `attempts` smallint unsigned NOT NULL,
  `reserved_at` int unsigned DEFAULT NULL,
  `available_at` int unsigned NOT NULL,
  `created_at` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `jobs`
--

LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `migrations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES (1,'0001_01_01_000000_create_users_table',1),(2,'0001_01_01_000001_create_cache_table',1),(3,'0001_01_01_000002_create_jobs_table',1),(4,'2026_08_18_024118_create_personal_access_tokens_table',1),(5,'2026_08_18_024216_create_heart_rate_logs_table',1),(6,'2026_09_17_000000_add_user_id_to_heart_rate_logs_table',1),(7,'2026_10_29_025823_create_children_table',1),(8,'2026_10_29_025858_create_devices_table',1),(9,'2026_10_29_025925_add_child_device_to_heart_rate_logs',1),(10,'2026_10_30_032950_create_event_notes_table',1);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_reset_tokens`
--

DROP TABLE IF EXISTS `password_reset_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `password_reset_tokens` (
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_reset_tokens`
--

LOCK TABLES `password_reset_tokens` WRITE;
/*!40000 ALTER TABLE `password_reset_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_reset_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `personal_access_tokens`
--

DROP TABLE IF EXISTS `personal_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `personal_access_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tokenable_id` bigint unsigned NOT NULL,
  `name` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `abilities` text COLLATE utf8mb4_unicode_ci,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`),
  KEY `personal_access_tokens_expires_at_index` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `personal_access_tokens`
--

LOCK TABLES `personal_access_tokens` WRITE;
/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `personal_access_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint unsigned DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_activity` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sessions_user_id_index` (`user_id`),
  KEY `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Demo User','demo@siband.test',NULL,'$2y$12$K8An7Ue1jLxpMLy4RIleLewjbLqIJK8YI0BsY8ySg9Qfl9g26DB.C',NULL,'2026-10-29 20:53:32','2026-10-29 20:53:32'),(2,'Test User','test@example.com','2026-10-29 20:53:32','$2y$12$.GvvZUhisDaG9kj9BEw33O.9qxi4zEK9gk6ENmDWUeyLhSGc5Vbam','b1VrUv6ykg','2026-10-29 20:53:33','2026-10-29 20:53:33');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-30 10:54:59
