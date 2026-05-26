-- Initialize food_db and create replication user
CREATE DATABASE IF NOT EXISTS food_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create application user
CREATE USER IF NOT EXISTS 'food_user'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON food_db.* TO 'food_user'@'%';

-- Create replication user
CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'replicator'@'%';

FLUSH PRIVILEGES;
