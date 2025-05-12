# week-8-DBMS-assignment
Library Management System Database
Description
The Library Management System Database is a robust SQL-based solution designed for public libraries to manage books, members, borrowing records, fines, and reservations. It supports multi-branch operations, includes security features like password hashing, and provides performance optimizations such as indexing and table partitioning. Key features include:

Book and copy management with ISBN validation
Member management with email validation and audit trails
Borrowing and reservation systems
Fine tracking with automated overdue triggers
Reporting via views (e.g., popular books)

Setup and Installation

Prerequisites:

MySQL 8.0+ installed
Git for cloning the repository
(Optional) MySQL Workbench or DBeaver for ERD visualization


Clone the Repository:
git clone https://github.com/your-username/library-management-system.git
cd library-management-system


Create the Database:
CREATE DATABASE library_db;


Import the SQL Schema:
mysql -u your_username -p library_db < sql/library_schema.sql

Alternatively, import sql/library_schema.sql using a GUI tool like MySQL Workbench.

Configure Database Connection:Create a .env file in the root directory:
DB_HOST=localhost
DB_USER=library_admin
DB_PASS=your_secure_password
DB_NAME=library_db


Test the Setup:Run the sample data included in library_schema.sql:
SELECT * FROM Members;

Or test the borrowing procedure:
CALL BorrowBook(1, 1, '2025-01-01', '2025-01-15');



Entity-Relationship Diagram (ERD)
The ERD visualizes the database structure, including tables, relationships, and constraints. You can find it in docs/erd.png.

Note: The ERD can be generated using MySQL Workbench or tools like DBeaver by importing the schema and using their diagramming features.
Additional Notes

Performance: The schema includes indexes, partitioning, and stored procedures for optimal performance. Configure my.cnf for connection pooling:[mysqld]
max_connections = 200
thread_cache_size = 10


Testing: Stress test with:mysqlslap --concurrency=100 --iterations=10 --query="CALL BorrowBook(1,1,'2025-01-01','2025-01-15')" -u your_username -p


Backup Strategy: Enable binary logging and schedule daily snapshots.
Version Control: Use tools like Flyway or Liquibase for schema migrations.

