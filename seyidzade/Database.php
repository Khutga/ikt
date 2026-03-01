<?php
/**
 * Database - PDO bağlantı yönetimi
 * 
 * Singleton pattern ile tek bir bağlantı üzerinden çalışır.
 * Prepared statements ile SQL injection koruması sağlar.
 */

class Database
{
    private static ?PDO $instance = null;
    private static array $config;

    /**
     * PDO bağlantısını döndürür (lazy initialization)
     */
    public static function getConnection(): PDO
    {
        if (self::$instance === null) {
            self::$config = require __DIR__ . '/../config/config.php';
            $db = self::$config['db'];

            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                $db['host'],
                $db['port'],
                $db['name'],
                $db['charset']
            );

            try {
                self::$instance = new PDO($dsn, $db['user'], $db['password'], [
                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE  => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES    => false,
                    PDO::MYSQL_ATTR_INIT_COMMAND  => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
                ]);
            } catch (PDOException $e) {
                // Üretim ortamında detaylı hata mesajı verme
                error_log('Database connection failed: ' . $e->getMessage());
                throw new RuntimeException('Veritabanı bağlantısı kurulamadı.');
            }
        }

        return self::$instance;
    }

    /**
     * Bağlantıyı kapat (test/cleanup için)
     */
    public static function close(): void
    {
        self::$instance = null;
    }

    // Singleton: new ile oluşturulamaz
    private function __construct() {}
    private function __clone() {}
}