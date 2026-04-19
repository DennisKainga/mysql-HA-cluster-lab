-- Create a clean lab database
CREATE DATABASE IF NOT EXISTS library_lab;
USE library_lab;

-- 1. Authors Table
CREATE TABLE IF NOT EXISTS authors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Books Table (Belongs to an Author)
CREATE TABLE IF NOT EXISTS books (
    id INT AUTO_INCREMENT PRIMARY KEY,
    author_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    isbn VARCHAR(20) UNIQUE,
    published_year YEAR,
    CONSTRAINT fk_author FOREIGN KEY (author_id) 
        REFERENCES authors(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3. Comments Table (Belongs to a Book - simulating a review system)
CREATE TABLE IF NOT EXISTS comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    user_name VARCHAR(100),
    comment_text TEXT NOT NULL,
    rating TINYINT CHECK (rating BETWEEN 1 AND 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_book FOREIGN KEY (book_id) 
        REFERENCES books(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Seed Data
INSERT INTO authors (name, bio) VALUES 
('Robert Greene', 'Specializes in strategy, power, and seduction.'),
('Marcus Aurelius', 'Roman Emperor and Stoic philosopher.');

INSERT INTO books (author_id, title, isbn, published_year) VALUES 
(1, 'The 48 Laws of Power', '978-0140280197', 1998),
(2, 'Meditations', '978-0140449334', 2002);

INSERT INTO comments (book_id, user_name, comment_text, rating) VALUES 
(1, 'SystemAdmin', 'Essential reading for understanding social dynamics.', 5),
(2, 'StoicLearner', 'A timeless guide to self-discipline.', 5);