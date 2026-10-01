CREATE DATABASE IF NOT EXISTS kinetic_booking
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE kinetic_booking;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  username VARCHAR(80) NULL,
  email VARCHAR(190) NULL,
  phone VARCHAR(30) NULL,
  password_hash VARCHAR(255) NULL,
  role ENUM('user','admin','superadmin') NOT NULL DEFAULT 'user',
  status ENUM('pending','active','suspended') NOT NULL DEFAULT 'active',
  bio VARCHAR(500) NULL,
  photo_url VARCHAR(500) NULL,
  firebase_uid VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_phone (phone),
  UNIQUE KEY uq_users_firebase_uid (firebase_uid),
  KEY idx_users_role_status (role, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grounds (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(180) NOT NULL,
  sport_type VARCHAR(80) NOT NULL,
  city VARCHAR(100) NOT NULL,
  location VARCHAR(255) NOT NULL,
  latitude DECIMAL(10,7) NOT NULL DEFAULT 0,
  longitude DECIMAL(10,7) NOT NULL DEFAULT 0,
  amenities JSON NULL,
  rules TEXT NULL,
  status ENUM('pending','approved','rejected','active','inactive') NOT NULL DEFAULT 'pending',
  price_morning DECIMAL(10,2) NOT NULL DEFAULT 0,
  price_afternoon DECIMAL(10,2) NOT NULL DEFAULT 0,
  price_evening DECIMAL(10,2) NOT NULL DEFAULT 0,
  price_weekend DECIMAL(10,2) NOT NULL DEFAULT 0,
  firebase_id VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_grounds_firebase_id (firebase_id),
  KEY idx_grounds_admin_created (admin_id, created_at),
  KEY idx_grounds_city_status (city, status),
  CONSTRAINT fk_grounds_admin FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ground_images (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ground_id BIGINT UNSIGNED NOT NULL,
  image_url VARCHAR(500) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ground_images_ground (ground_id),
  CONSTRAINT fk_ground_images_ground FOREIGN KEY (ground_id) REFERENCES grounds(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS slots (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ground_id BIGINT UNSIGNED NOT NULL,
  sport_type VARCHAR(80) NOT NULL DEFAULT '',
  slot_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  price DECIMAL(10,2) NOT NULL DEFAULT 0,
  status ENUM('available','booked','blocked') NOT NULL DEFAULT 'available',
  firebase_id VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
UNIQUE KEY uq_slot_ground_sport_date_time (
  ground_id, sport_type, slot_date, start_time, end_time
),
  UNIQUE KEY uq_slots_firebase_id (firebase_id),
  KEY idx_slots_ground_date_status (ground_id, slot_date, status),
  CONSTRAINT fk_slots_ground FOREIGN KEY (ground_id)
    REFERENCES grounds(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bookings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  admin_id BIGINT UNSIGNED NOT NULL,
  ground_id BIGINT UNSIGNED NOT NULL,
  slot_id BIGINT UNSIGNED NOT NULL,
  ground_name VARCHAR(180) NOT NULL,
  booking_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  payment_status ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
  booking_status ENUM('upcoming','completed','cancelled') NOT NULL DEFAULT 'upcoming',
  payment_reference VARCHAR(190) NULL,
  cancellation_reason VARCHAR(500) NULL,
  firebase_id VARCHAR(128) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bookings_firebase_id (firebase_id),
  KEY idx_bookings_admin_created (admin_id, created_at),
  KEY idx_bookings_user_created (user_id, created_at),
  KEY idx_bookings_date (booking_date),
  CONSTRAINT fk_bookings_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_bookings_admin FOREIGN KEY (admin_id) REFERENCES users(id),
  CONSTRAINT fk_bookings_ground FOREIGN KEY (ground_id) REFERENCES grounds(id),
  CONSTRAINT fk_bookings_slot FOREIGN KEY (slot_id) REFERENCES slots(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(40) NOT NULL DEFAULT 'manual',
  provider_payment_id VARCHAR(190) NULL,
  amount DECIMAL(10,2) NOT NULL,
  status ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
  raw_payload JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_payments_booking (booking_id),
  CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
  CONSTRAINT fk_payments_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS refund_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  reason VARCHAR(500) NOT NULL,
  status ENUM('pending','approved','rejected','processed') NOT NULL DEFAULT 'pending',
  admin_note VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_refunds_user_status (user_id, status),
  CONSTRAINT fk_refund_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
  CONSTRAINT fk_refund_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  type VARCHAR(80) NOT NULL,
  title VARCHAR(180) NOT NULL,
  message VARCHAR(600) NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  metadata JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notifications_user_read (user_id, is_read, created_at),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_otps (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  phone VARCHAR(30) NOT NULL,
  otp_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_user_otps_phone_expiry (phone, expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ground_fieldname (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  fieldname VARCHAR(150) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ground_fieldname_name (fieldname)
) ENGINE=InnoDB;