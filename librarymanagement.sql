/*
  Library Management System Database
  Purpose: Manages books, members, borrowing records, and fines for a public library
  Retention Policy:
  - Borrowing records archived after 5 years
  - Fines kept for 7 years for tax purposes
*/

-- Set default storage engine and character set for all tables
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET NAMES utf8mb4;

-- Create Authors table
CREATE TABLE Authors (
    author_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE,
    nationality VARCHAR(50),
    UNIQUE (first_name, last_name, birth_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Stores author information';

-- Create Publishers table
CREATE TABLE Publishers (
    publisher_id INT PRIMARY KEY AUTO_INCREMENT,
    publisher_name VARCHAR(100) NOT NULL UNIQUE,
    address VARCHAR(200),
    phone VARCHAR(20),
    email VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Stores publisher information';

-- Create Categories table
CREATE TABLE Categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Stores book categories/genres';

-- Create Books table with branch_id and ISBN validation
CREATE TABLE Books (
    book_id INT PRIMARY KEY AUTO_INCREMENT,
    isbn VARCHAR(13) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    publisher_id INT,
    publication_year YEAR,
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,
    branch_id INT NOT NULL,
    FOREIGN KEY (publisher_id) REFERENCES Publishers(publisher_id),
    CHECK (available_copies <= total_copies),
    CHECK (isbn REGEXP '^[0-9]{12}[0-9X]$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Stores book information';
CREATE INDEX idx_books_title ON Books(title);

-- Create Book_Copies table for individual copy management
CREATE TABLE Book_Copies (
    copy_id INT PRIMARY KEY AUTO_INCREMENT,
    book_id INT NOT NULL,
    status ENUM('AVAILABLE', 'LOST', 'MAINTENANCE') DEFAULT 'AVAILABLE',
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Tracks individual book copies';

-- Create Book_Authors (M-M relationship between Books and Authors)
CREATE TABLE Book_Authors (
    book_id INT,
    author_id INT,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES Authors(author_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Maps books to their authors';

-- Create Book_Categories (M-M relationship between Books and Categories)
CREATE TABLE Book_Categories (
    book_id INT,
    category_id INT,
    PRIMARY KEY (book_id, category_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Maps books to their categories';

-- Create Members table with email validation and password hash
CREATE TABLE Members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    join_date DATE NOT NULL,
    address VARCHAR(200),
    membership_status ENUM('ACTIVE', 'SUSPENDED', 'EXPIRED') DEFAULT 'ACTIVE',
    password_hash VARCHAR(255) NOT NULL COMMENT 'BCrypt hash',
    CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Stores library member information';
CREATE INDEX idx_members_email ON Members(email);

-- Create Membership_Audit table for tracking status changes
CREATE TABLE Membership_Audit (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT,
    old_status ENUM('ACTIVE', 'SUSPENDED', 'EXPIRED'),
    new_status ENUM('ACTIVE', 'SUSPENDED', 'EXPIRED'),
    change_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES Members(member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Tracks membership status changes';

-- Create Borrowings table (removed fine_amount for normalization)
CREATE TABLE Borrowings (
    borrowing_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT,
    book_id INT,
    borrow_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id),
    CHECK (due_date > borrow_date),
    CHECK (return_date IS NULL OR return_date >= borrow_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Tracks book borrowing records';
CREATE INDEX idx_borrow_dates ON Borrowings(due_date, return_date);

-- Create Fines table
CREATE TABLE Fines (
    fine_id INT PRIMARY KEY AUTO_INCREMENT,
    borrowing_id INT,
    member_id INT,
    amount DECIMAL(10,2) NOT NULL,
    issue_date DATE NOT NULL,
    payment_date DATE,
    status ENUM('PENDING', 'PAID', 'WAIVED') DEFAULT 'PENDING',
    FOREIGN KEY (borrowing_id) REFERENCES Borrowings(borrowing_id),
    FOREIGN KEY (member_id) REFERENCES Members(member_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Manages fine records';

-- Create Reservations table
CREATE TABLE Reservations (
    reservation_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT,
    book_id INT,
    reservation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('PENDING', 'FULFILLED', 'CANCELLED'),
    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT = 'Manages book reservations';

-- Partition Borrowings table for performance
ALTER TABLE Borrowings 
PARTITION BY RANGE (YEAR(borrow_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026)
);

-- Stored Procedure for Borrowing
DELIMITER //
CREATE PROCEDURE BorrowBook(
    IN p_member_id INT,
    IN p_book_id INT,
    IN p_borrow_date DATE,
    IN p_due_date DATE
)
BEGIN
    START TRANSACTION;
    INSERT INTO Borrowings (member_id, book_id, borrow_date, due_date)
    VALUES (p_member_id, p_book_id, p_borrow_date, p_due_date);
    UPDATE Books SET available_copies = available_copies - 1
    WHERE book_id = p_book_id AND available_copies > 0;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No available copies';
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Trigger for Overdue Fines
DELIMITER //
CREATE TRIGGER trg_after_borrowing_insert
AFTER INSERT ON Borrowings
FOR EACH ROW
BEGIN
    IF NEW.due_date < CURDATE() THEN
        INSERT INTO Fines (borrowing_id, member_id, amount, issue_date)
        VALUES (NEW.borrowing_id, NEW.member_id, 5.00, CURDATE());
    END IF;
END //
DELIMITER ;

-- View for Popular Books
CREATE VIEW Popular_Books AS
SELECT b.title, COUNT(br.borrowing_id) AS times_borrowed
FROM Books b
JOIN Borrowings br USING (book_id)
GROUP BY b.book_id
ORDER BY times_borrowed DESC
LIMIT 10;

-- Sample Data for Testing
INSERT INTO Members (first_name, last_name, email, join_date, membership_status, password_hash)
VALUES ('kevo', 'johnte', 'john@lib.com', '2023-01-01', 'ACTIVE', '$2a$10$examplehash');