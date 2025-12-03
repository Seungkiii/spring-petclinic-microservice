-- Spring PetClinic 데이터베이스 스키마 생성 스크립트
-- RDS MySQL용 통합 스키마
-- 실행 방법: mysql -h <RDS_ENDPOINT> -u <USERNAME> -p < init-database.sql

CREATE DATABASE IF NOT EXISTS petclinic;
USE petclinic;

-- UTF-8 설정
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ============================================
-- Customers Service 테이블
-- ============================================

-- 애완동물 타입 테이블
CREATE TABLE IF NOT EXISTS types (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80),
  INDEX(name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 주인(Owner) 테이블
CREATE TABLE IF NOT EXISTS owners (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(30),
  last_name VARCHAR(30),
  address VARCHAR(255),
  city VARCHAR(80),
  telephone VARCHAR(20),
  INDEX(last_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 애완동물(Pet) 테이블
CREATE TABLE IF NOT EXISTS pets (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(30),
  birth_date DATE,
  type_id INT(4) UNSIGNED NOT NULL,
  owner_id INT(4) UNSIGNED NOT NULL,
  INDEX(name),
  FOREIGN KEY (owner_id) REFERENCES owners(id),
  FOREIGN KEY (type_id) REFERENCES types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Vets Service 테이블
-- ============================================

-- 수의사(Vet) 테이블
CREATE TABLE IF NOT EXISTS vets (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(30),
  last_name VARCHAR(30),
  INDEX(last_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 전문 분야(Specialty) 테이블
CREATE TABLE IF NOT EXISTS specialties (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80),
  INDEX(name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 수의사-전문 분야 연관 테이블
CREATE TABLE IF NOT EXISTS vet_specialties (
  vet_id INT(4) UNSIGNED NOT NULL,
  specialty_id INT(4) UNSIGNED NOT NULL,
  FOREIGN KEY (vet_id) REFERENCES vets(id),
  FOREIGN KEY (specialty_id) REFERENCES specialties(id),
  UNIQUE (vet_id, specialty_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Visits Service 테이블
-- ============================================

-- 방문 기록(Visit) 테이블
CREATE TABLE IF NOT EXISTS visits (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  pet_id INT(4) UNSIGNED NOT NULL,
  visit_date DATETIME(6) NOT NULL,
  description VARCHAR(8192),
  FOREIGN KEY (pet_id) REFERENCES pets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 테스트용 샘플 데이터 (선택사항)
-- ============================================

-- 애완동물 타입 샘플 데이터
INSERT IGNORE INTO types (id, name) VALUES 
(1, 'cat'),
(2, 'dog'),
(3, 'lizard'),
(4, 'snake'),
(5, 'bird'),
(6, 'hamster');

-- 수의사 샘플 데이터
INSERT IGNORE INTO vets (id, first_name, last_name) VALUES 
(1, 'James', 'Carter'),
(2, 'Helen', 'Leary'),
(3, 'Linda', 'Douglas'),
(4, 'Rafael', 'Ortega'),
(5, 'Henry', 'Stevens'),
(6, 'Sharon', 'Jenkins');

-- 전문 분야 샘플 데이터
INSERT IGNORE INTO specialties (id, name) VALUES 
(1, 'radiology'),
(2, 'surgery'),
(3, 'dentistry');

-- 수의사-전문 분야 연관 샘플 데이터
INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES 
(2, 1),
(3, 2),
(3, 3),
(4, 2),
(5, 1);

-- 완료 메시지
SELECT 'Database schema created successfully!' AS status;

