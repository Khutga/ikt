-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Mar 08, 2026 at 04:47 AM
-- Server version: 10.6.25-MariaDB
-- PHP Version: 8.4.16

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `seyidzade_macro_dashboard`
--
CREATE DATABASE IF NOT EXISTS `seyidzade_macro_dashboard` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `seyidzade_macro_dashboard`;

-- --------------------------------------------------------

--
-- Table structure for table `analysis_cache`
--

CREATE TABLE `analysis_cache` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `cache_key` varchar(255) NOT NULL COMMENT 'Hash key: indicator_ids + period + type',
  `analysis_type` enum('correlation','moving_avg','trend','comparison','statistics') NOT NULL,
  `indicator_ids` longtext NOT NULL COMMENT 'Analiz edilen gösterge ID listesi' CHECK (json_valid(`indicator_ids`)),
  `parameters` longtext DEFAULT NULL COMMENT 'Analiz parametreleri' CHECK (json_valid(`parameters`)),
  `result` longtext NOT NULL COMMENT 'Analiz sonucu' CHECK (json_valid(`result`)),
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Cache süresi',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Analiz sonucu cache';

-- --------------------------------------------------------

--
-- Table structure for table `categories`
--

CREATE TABLE `categories` (
  `id` int(10) UNSIGNED NOT NULL,
  `code` varchar(50) NOT NULL COMMENT 'Dahili kategori kodu',
  `name_tr` varchar(255) NOT NULL,
  `name_en` varchar(255) NOT NULL,
  `icon` varchar(50) DEFAULT NULL COMMENT 'Flutter ikonu için tanımlayıcı',
  `color` varchar(7) DEFAULT NULL COMMENT 'Hex renk kodu (#FF5733)',
  `sort_order` tinyint(3) UNSIGNED DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Gösterge kategorileri';

-- --------------------------------------------------------

--
-- Table structure for table `countries`
--

CREATE TABLE `countries` (
  `id` int(10) UNSIGNED NOT NULL,
  `iso_code` char(3) NOT NULL COMMENT 'ISO 3166-1 alpha-3 (TUR, USA, DEU...)',
  `iso2` char(2) NOT NULL COMMENT 'ISO 3166-1 alpha-2 (TR, US, DE...)',
  `name_tr` varchar(100) NOT NULL,
  `name_en` varchar(100) NOT NULL,
  `flag_emoji` varchar(10) DEFAULT NULL COMMENT '?? gibi emoji bayrak',
  `region_tr` varchar(50) DEFAULT NULL COMMENT 'Bölge: Avrupa, Asya, Amerika...',
  `is_active` tinyint(1) DEFAULT 1,
  `sort_order` tinyint(3) UNSIGNED DEFAULT 10,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Kıyaslama için ülke tanımları';

-- --------------------------------------------------------

--
-- Table structure for table `data_points`
--

CREATE TABLE `data_points` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `indicator_id` int(10) UNSIGNED NOT NULL,
  `date` date NOT NULL,
  `value` decimal(20,6) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Zaman serisi veri noktaları';

-- --------------------------------------------------------

--
-- Table structure for table `external_fetch_logs`
--

CREATE TABLE `external_fetch_logs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `source_type` varchar(30) NOT NULL COMMENT 'worldbank, ember, iea...',
  `indicator_code` varchar(100) DEFAULT NULL,
  `status` enum('success','error','partial') NOT NULL,
  `records_fetched` int(10) UNSIGNED DEFAULT 0,
  `records_inserted` int(10) UNSIGNED DEFAULT 0,
  `error_message` text DEFAULT NULL,
  `execution_time_ms` int(10) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Dışsal veri çekme logları';

-- --------------------------------------------------------

--
-- Table structure for table `fetch_logs`
--

CREATE TABLE `fetch_logs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `indicator_id` int(10) UNSIGNED DEFAULT NULL,
  `fetch_type` enum('single','bulk','category') NOT NULL DEFAULT 'single',
  `status` enum('success','error','partial') NOT NULL,
  `records_fetched` int(10) UNSIGNED DEFAULT 0,
  `records_inserted` int(10) UNSIGNED DEFAULT 0,
  `error_message` mediumtext DEFAULT NULL,
  `execution_time_ms` int(10) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Veri çekme işlem logları';

-- --------------------------------------------------------

--
-- Table structure for table `indicators`
--

CREATE TABLE `indicators` (
  `id` int(10) UNSIGNED NOT NULL,
  `category_id` int(10) UNSIGNED NOT NULL,
  `evds_code` varchar(100) NOT NULL COMMENT 'TCMB EVDS seri kodu (ör: TP.FG.J0)',
  `name_tr` varchar(255) NOT NULL,
  `name_en` varchar(255) NOT NULL,
  `description_tr` mediumtext DEFAULT NULL,
  `education_tr` text DEFAULT NULL,
  `education_en` text DEFAULT NULL,
  `description_en` mediumtext DEFAULT NULL,
  `unit` varchar(50) NOT NULL COMMENT 'Birim: %, TL, USD, endeks, milyon USD...',
  `frequency` enum('daily','weekly','monthly','quarterly','yearly') NOT NULL DEFAULT 'monthly',
  `source` varchar(100) DEFAULT 'TCMB' COMMENT 'Veri kaynağı: TCMB, TÜİK, BDDK...',
  `decimal_places` tinyint(3) UNSIGNED DEFAULT 2,
  `is_active` tinyint(1) DEFAULT 1,
  `last_fetched_at` timestamp NULL DEFAULT NULL COMMENT 'Son veri çekme zamanı',
  `last_value` decimal(20,6) DEFAULT NULL COMMENT 'Hızlı erişim için son değer cache',
  `last_value_date` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Ekonomik göstergeler / veri serileri';

-- --------------------------------------------------------

--
-- Table structure for table `international_data_points`
--

CREATE TABLE `international_data_points` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `intl_indicator_id` int(10) UNSIGNED NOT NULL,
  `country_id` int(10) UNSIGNED NOT NULL,
  `date` date NOT NULL,
  `value` decimal(20,6) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Ülke bazlı uluslararası veri noktaları';

-- --------------------------------------------------------

--
-- Table structure for table `international_indicators`
--

CREATE TABLE `international_indicators` (
  `id` int(10) UNSIGNED NOT NULL,
  `category_id` int(10) UNSIGNED NOT NULL,
  `source_type` enum('worldbank','imf','ember','iea','manual') NOT NULL DEFAULT 'worldbank',
  `source_code` varchar(100) NOT NULL COMMENT 'Kaynak API kodu (ör: FP.CPI.TOTL.ZG)',
  `name_tr` varchar(255) NOT NULL,
  `name_en` varchar(255) NOT NULL,
  `description_tr` text DEFAULT NULL,
  `unit` varchar(50) NOT NULL,
  `frequency` enum('daily','weekly','monthly','quarterly','yearly') NOT NULL DEFAULT 'yearly',
  `decimal_places` tinyint(3) UNSIGNED DEFAULT 2,
  `is_active` tinyint(1) DEFAULT 1,
  `last_fetched_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Uluslararası kaynaklardan gelen gösterge tanımları';

-- --------------------------------------------------------

--
-- Table structure for table `user_favorites`
--

CREATE TABLE `user_favorites` (
  `id` int(10) UNSIGNED NOT NULL,
  `device_id` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL COMMENT 'Flutter cihaz kimliği',
  `indicator_ids` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT 'Favori gösterge listesi' CHECK (json_valid(`indicator_ids`)),
  `dashboard_config` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Kullanıcı dashboard ayarları' CHECK (json_valid(`dashboard_config`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci COMMENT='Kullanıcı favori göstergeleri';

--
-- Indexes for dumped tables
--

--
-- Indexes for table `analysis_cache`
--
ALTER TABLE `analysis_cache`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `cache_key` (`cache_key`),
  ADD KEY `idx_cache_key` (`cache_key`),
  ADD KEY `idx_expires` (`expires_at`),
  ADD KEY `idx_type` (`analysis_type`);

--
-- Indexes for table `categories`
--
ALTER TABLE `categories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`),
  ADD KEY `idx_active_sort` (`is_active`,`sort_order`);

--
-- Indexes for table `countries`
--
ALTER TABLE `countries`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `iso_code` (`iso_code`),
  ADD KEY `idx_iso` (`iso_code`),
  ADD KEY `idx_active` (`is_active`,`sort_order`);

--
-- Indexes for table `data_points`
--
ALTER TABLE `data_points`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_indicator_date` (`indicator_id`,`date`),
  ADD KEY `idx_date` (`date`);

--
-- Indexes for table `external_fetch_logs`
--
ALTER TABLE `external_fetch_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_source` (`source_type`),
  ADD KEY `idx_created` (`created_at`);

--
-- Indexes for table `fetch_logs`
--
ALTER TABLE `fetch_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `indicator_id` (`indicator_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created` (`created_at`);

--
-- Indexes for table `indicators`
--
ALTER TABLE `indicators`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `evds_code` (`evds_code`),
  ADD KEY `idx_category` (`category_id`),
  ADD KEY `idx_active` (`is_active`),
  ADD KEY `idx_frequency` (`frequency`),
  ADD KEY `idx_last_fetched` (`last_fetched_at`);

--
-- Indexes for table `international_data_points`
--
ALTER TABLE `international_data_points`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_indicator_country_date` (`intl_indicator_id`,`country_id`,`date`),
  ADD KEY `idx_country` (`country_id`),
  ADD KEY `idx_date` (`date`);

--
-- Indexes for table `international_indicators`
--
ALTER TABLE `international_indicators`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_source_code` (`source_type`,`source_code`),
  ADD KEY `idx_category` (`category_id`),
  ADD KEY `idx_active` (`is_active`);

--
-- Indexes for table `user_favorites`
--
ALTER TABLE `user_favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_device` (`device_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `analysis_cache`
--
ALTER TABLE `analysis_cache`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `categories`
--
ALTER TABLE `categories`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `countries`
--
ALTER TABLE `countries`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `data_points`
--
ALTER TABLE `data_points`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `external_fetch_logs`
--
ALTER TABLE `external_fetch_logs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `fetch_logs`
--
ALTER TABLE `fetch_logs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `indicators`
--
ALTER TABLE `indicators`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `international_data_points`
--
ALTER TABLE `international_data_points`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `international_indicators`
--
ALTER TABLE `international_indicators`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_favorites`
--
ALTER TABLE `user_favorites`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `data_points`
--
ALTER TABLE `data_points`
  ADD CONSTRAINT `data_points_ibfk_1` FOREIGN KEY (`indicator_id`) REFERENCES `indicators` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `fetch_logs`
--
ALTER TABLE `fetch_logs`
  ADD CONSTRAINT `fetch_logs_ibfk_1` FOREIGN KEY (`indicator_id`) REFERENCES `indicators` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `indicators`
--
ALTER TABLE `indicators`
  ADD CONSTRAINT `indicators_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`);

--
-- Constraints for table `international_data_points`
--
ALTER TABLE `international_data_points`
  ADD CONSTRAINT `international_data_points_ibfk_1` FOREIGN KEY (`intl_indicator_id`) REFERENCES `international_indicators` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `international_data_points_ibfk_2` FOREIGN KEY (`country_id`) REFERENCES `countries` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `international_indicators`
--
ALTER TABLE `international_indicators`
  ADD CONSTRAINT `international_indicators_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
