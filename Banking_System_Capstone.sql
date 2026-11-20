-- =====================================================================
--  CAPSTONE PROJECT : Banking and Financial Transaction Management System
--  Course           : Database Management Systems (DBMS)
--  Student          : Varun Kumar (Roll No. 2501410058)
--  University       : K.R. Mangalam University, B.Tech CSE (Cyber Security)
--  RDBMS            : MySQL 8.x / MariaDB 10.5+
-- =====================================================================

DROP DATABASE IF EXISTS bank_db;
CREATE DATABASE bank_db CHARACTER SET utf8mb4;
USE bank_db;

-- =====================================================================
-- SECTION 1 : DDL  (schema with integrity constraints)
-- =====================================================================

CREATE TABLE branch (
    branch_id    INT AUTO_INCREMENT PRIMARY KEY,
    branch_name  VARCHAR(60)  NOT NULL,
    ifsc_code    CHAR(11)     NOT NULL UNIQUE,          -- candidate key
    city         VARCHAR(40)  NOT NULL
);

CREATE TABLE employee (
    emp_id       INT AUTO_INCREMENT PRIMARY KEY,
    emp_name     VARCHAR(60)  NOT NULL,
    designation  VARCHAR(40)  NOT NULL,
    branch_id    INT          NOT NULL,
    manager_id   INT          NULL,                     -- self-referencing FK
    CONSTRAINT fk_emp_branch  FOREIGN KEY (branch_id)  REFERENCES branch(branch_id),
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employee(emp_id)
);

CREATE TABLE customer (
    customer_id  INT AUTO_INCREMENT PRIMARY KEY,
    first_name   VARCHAR(40)  NOT NULL,
    last_name    VARCHAR(40)  NOT NULL,
    dob          DATE         NOT NULL,
    gender       CHAR(1)      NOT NULL,
    email        VARCHAR(80)  NOT NULL UNIQUE,          -- candidate key
    phone        CHAR(10)     NOT NULL UNIQUE,          -- candidate key
    pan_no       CHAR(10)     NOT NULL UNIQUE,          -- candidate key
    city         VARCHAR(40)  NOT NULL,
    kyc_status   VARCHAR(10)  NOT NULL DEFAULT 'PENDING',
    created_at   DATE         NOT NULL,
    CONSTRAINT chk_cust_gender CHECK (gender IN ('M','F','O')),
    CONSTRAINT chk_cust_kyc    CHECK (kyc_status IN ('PENDING','VERIFIED','REJECTED')),
    CONSTRAINT chk_cust_phone  CHECK (phone REGEXP '^[6-9][0-9]{9}$')
);

CREATE TABLE account (
    account_id   INT AUTO_INCREMENT PRIMARY KEY,
    account_no   CHAR(12)      NOT NULL UNIQUE,         -- candidate key
    customer_id  INT           NOT NULL,
    branch_id    INT           NOT NULL,
    account_type VARCHAR(10)   NOT NULL DEFAULT 'SAVINGS',
    balance      DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    interest_rate DECIMAL(4,2) NOT NULL DEFAULT 3.50,
    status       VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    open_date    DATE          NOT NULL,
    CONSTRAINT fk_acc_cust   FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_acc_branch FOREIGN KEY (branch_id)   REFERENCES branch(branch_id),
    CONSTRAINT chk_acc_type    CHECK (account_type IN ('SAVINGS','CURRENT')),
    CONSTRAINT chk_acc_balance CHECK (balance >= 0),    -- no overdraft on savings
    CONSTRAINT chk_acc_status  CHECK (status IN ('ACTIVE','DORMANT','CLOSED'))
);

CREATE TABLE loan (
    loan_id          INT AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT           NOT NULL,
    branch_id        INT           NOT NULL,
    loan_type        VARCHAR(15)   NOT NULL,
    principal        DECIMAL(14,2) NOT NULL,
    interest_rate    DECIMAL(4,2)  NOT NULL,
    tenure_months    INT           NOT NULL,
    application_date DATE          NOT NULL,
    status           VARCHAR(10)   NOT NULL DEFAULT 'PENDING',
    CONSTRAINT fk_loan_cust   FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_loan_branch FOREIGN KEY (branch_id)   REFERENCES branch(branch_id),
    CONSTRAINT chk_loan_type   CHECK (loan_type IN ('HOME','EDUCATION','PERSONAL','VEHICLE')),
    CONSTRAINT chk_loan_amt    CHECK (principal > 0),
    CONSTRAINT chk_loan_rate   CHECK (interest_rate BETWEEN 1 AND 30),
    CONSTRAINT chk_loan_tenure CHECK (tenure_months BETWEEN 6 AND 360),
    CONSTRAINT chk_loan_status CHECK (status IN ('PENDING','APPROVED','REJECTED','CLOSED'))
);

CREATE TABLE loan_payment (
    payment_id   INT AUTO_INCREMENT PRIMARY KEY,
    loan_id      INT           NOT NULL,
    payment_date DATE          NOT NULL,
    amount       DECIMAL(12,2) NOT NULL,
    CONSTRAINT fk_pay_loan FOREIGN KEY (loan_id) REFERENCES loan(loan_id),
    CONSTRAINT chk_pay_amt CHECK (amount > 0)
);

CREATE TABLE fund_transfer (
    transfer_id     INT AUTO_INCREMENT PRIMARY KEY,
    from_account_id INT           NOT NULL,
    to_account_id   INT           NOT NULL,
    amount          DECIMAL(12,2) NOT NULL,
    transfer_date   DATETIME      NOT NULL,
    status          VARCHAR(10)   NOT NULL DEFAULT 'COMPLETED',
    CONSTRAINT fk_tr_from FOREIGN KEY (from_account_id) REFERENCES account(account_id),
    CONSTRAINT fk_tr_to   FOREIGN KEY (to_account_id)   REFERENCES account(account_id),
    CONSTRAINT chk_tr_amt  CHECK (amount > 0),
    CONSTRAINT chk_tr_diff CHECK (from_account_id <> to_account_id),
    CONSTRAINT chk_tr_stat CHECK (status IN ('COMPLETED','FAILED','PENDING'))
);

CREATE TABLE transactions (
    txn_id      BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id  INT           NOT NULL,
    txn_type    VARCHAR(15)   NOT NULL,
    amount      DECIMAL(12,2) NOT NULL,
    txn_date    DATETIME      NOT NULL,
    description VARCHAR(80),
    transfer_id INT           NULL,
    CONSTRAINT fk_txn_acc FOREIGN KEY (account_id)  REFERENCES account(account_id),
    CONSTRAINT fk_txn_tr  FOREIGN KEY (transfer_id) REFERENCES fund_transfer(transfer_id),
    CONSTRAINT chk_txn_type CHECK (txn_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER_IN','TRANSFER_OUT')),
    CONSTRAINT chk_txn_amt  CHECK (amount > 0)
);

-- ---------------------------------------------------------------------
-- Trigger: keeps account.balance in sync with every transaction.
-- A withdrawal that would overdraw the account violates chk_acc_balance
-- and the whole statement is rolled back.
-- ---------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER trg_txn_after_insert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.txn_type IN ('DEPOSIT','TRANSFER_IN') THEN
        UPDATE account SET balance = balance + NEW.amount WHERE account_id = NEW.account_id;
    ELSE
        UPDATE account SET balance = balance - NEW.amount WHERE account_id = NEW.account_id;
    END IF;
END//
DELIMITER ;

-- DDL: ALTER / indexes ------------------------------------------------
ALTER TABLE customer ADD COLUMN address VARCHAR(120) NULL AFTER city;      -- ALTER ADD
ALTER TABLE customer MODIFY COLUMN address VARCHAR(150) NULL;               -- ALTER MODIFY
ALTER TABLE customer DROP COLUMN address;                                   -- ALTER DROP

CREATE INDEX idx_txn_account_date ON transactions (account_id, txn_date);
CREATE INDEX idx_txn_date         ON transactions (txn_date);
CREATE INDEX idx_account_customer ON account (customer_id);
CREATE INDEX idx_loan_cust_status ON loan (customer_id, status);
CREATE INDEX idx_customer_name    ON customer (last_name, first_name);

-- =====================================================================
-- SECTION 2 : DML  (sample data)
-- =====================================================================

INSERT INTO branch (branch_name, ifsc_code, city) VALUES
('Main Branch Gurugram',  'KRMB0000001', 'Gurugram'),
('Sector 21 Delhi',       'KRMB0000002', 'Delhi'),
('Noida Sector 62',       'KRMB0000003', 'Noida');

INSERT INTO employee (emp_name, designation, branch_id, manager_id) VALUES
('Rakesh Sharma',  'Regional Manager', 1, NULL),
('Sunita Verma',   'Branch Manager',   1, 1),
('Anil Kapoor',    'Branch Manager',   2, 1),
('Meera Nair',     'Branch Manager',   3, 1),
('Rohit Jain',     'Loan Officer',     1, 2),
('Pooja Singh',    'Cashier',          1, 2),
('Imran Khan',     'Loan Officer',     2, 3),
('Kavita Rao',     'Cashier',          3, 4);

INSERT INTO customer (first_name,last_name,dob,gender,email,phone,pan_no,city,kyc_status,created_at) VALUES
('Aarav',  'Sharma',  '1990-04-12','M','aarav.sharma@mail.com',  '9810000001','ABCPS1001A','Gurugram','VERIFIED','2025-12-20'),
('Priya',  'Verma',   '1994-08-23','F','priya.verma@mail.com',   '9810000002','ABCPV1002B','Gurugram','VERIFIED','2025-12-21'),
('Rahul',  'Mehta',   '1985-01-30','M','rahul.mehta@mail.com',   '9810000003','ABCPM1003C','Delhi',   'VERIFIED','2025-12-22'),
('Sneha',  'Gupta',   '1998-11-05','F','sneha.gupta@mail.com',   '9810000004','ABCPG1004D','Delhi',   'VERIFIED','2025-12-23'),
('Vikram', 'Singh',   '1982-06-17','M','vikram.singh@mail.com',  '9810000005','ABCPS1005E','Noida',   'VERIFIED','2025-12-24'),
('Ananya', 'Iyer',    '1996-02-14','F','ananya.iyer@mail.com',   '9810000006','ABCPI1006F','Noida',   'VERIFIED','2025-12-26'),
('Karan',  'Malhotra','1979-09-09','M','karan.malhotra@mail.com','9810000007','ABCPM1007G','Gurugram','VERIFIED','2025-12-27'),
('Neha',   'Joshi',   '1992-12-01','F','neha.joshi@mail.com',    '9810000008','ABCPJ1008H','Delhi',   'VERIFIED','2025-12-28'),
('Rohan',  'Kapoor',  '2000-03-19','M','rohan.kapoor@mail.com',  '9810000009','ABCPK1009J','Noida',   'VERIFIED','2025-12-29'),
('Divya',  'Reddy',   '1988-07-27','F','divya.reddy@mail.com',   '9810000010','ABCPR1010K','Gurugram','VERIFIED','2025-12-30'),
('Manish', 'Tiwari',  '1975-10-10','M','manish.tiwari@mail.com', '9810000011','ABCPT1011L','Gurugram','VERIFIED','2025-12-31'),
('Isha',   'Bansal',  '2001-05-22','F','isha.bansal@mail.com',   '9810000012','ABCPB1012M','Noida',   'PENDING', '2026-01-01');

INSERT INTO account (account_no, customer_id, branch_id, account_type, interest_rate, status, open_date) VALUES
('501000000001', 1, 1,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000002', 2, 1,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000003', 3, 2,'SAVINGS',4.00,'ACTIVE', '2026-01-02'),
('501000000004', 4, 2,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000005', 5, 3,'SAVINGS',4.00,'ACTIVE', '2026-01-02'),
('501000000006', 6, 3,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000007', 7, 1,'SAVINGS',4.00,'ACTIVE', '2026-01-02'),
('501000000008', 8, 2,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000009', 9, 3,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000010',10, 1,'SAVINGS',4.00,'ACTIVE', '2026-01-02'),
('501000000011', 1, 2,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000012',11, 1,'SAVINGS',3.50,'ACTIVE', '2026-01-02'),
('501000000013',12, 3,'SAVINGS',3.50,'DORMANT','2026-01-02');

INSERT INTO loan (customer_id,branch_id,loan_type,principal,interest_rate,tenure_months,application_date,status) VALUES
(1, 1,'HOME',     2500000.00, 8.50, 240,'2026-01-10','APPROVED'),
(3, 2,'VEHICLE',   600000.00, 9.25,  60,'2026-01-15','APPROVED'),
(5, 3,'PERSONAL',  300000.00,12.00,  36,'2026-02-05','APPROVED'),
(7, 1,'EDUCATION', 800000.00, 7.75,  84,'2026-02-12','APPROVED'),
(4, 2,'PERSONAL',  150000.00,13.50,  24,'2026-03-01','REJECTED'),
(9, 3,'EDUCATION', 500000.00, 7.75,  60,'2026-04-18','PENDING'),
(10,1,'VEHICLE',   450000.00, 9.25,  48,'2026-02-20','APPROVED'),
(2, 1,'PERSONAL',  100000.00,12.50,  12,'2026-01-20','CLOSED');

INSERT INTO loan_payment (loan_id,payment_date,amount) VALUES
(1,'2026-02-10',21700.00),(1,'2026-03-10',21700.00),(1,'2026-04-10',21700.00),(1,'2026-05-10',21700.00),
(2,'2026-02-15',12500.00),(2,'2026-03-15',12500.00),(2,'2026-04-15',12500.00),
(3,'2026-03-05', 9950.00),(3,'2026-04-05', 9950.00),
(4,'2026-03-12',12400.00),(4,'2026-04-12',12400.00),(4,'2026-05-12',12400.00),
(7,'2026-03-20',11200.00),(7,'2026-04-20',11200.00),
(8,'2026-02-20', 8900.00),(8,'2026-03-20', 8900.00),(8,'2026-04-20', 8900.00),(8,'2026-05-20', 8900.00),
(8,'2026-06-20', 8900.00),(8,'2026-07-20', 8900.00),(8,'2026-08-20', 8900.00),(8,'2026-09-20', 8900.00),
(8,'2026-10-20', 8900.00),(8,'2026-11-20', 8900.00),(8,'2026-12-20', 8900.00),(8,'2027-01-20', 8900.00);


-- Transaction ledger (191 rows) and fund transfers (18 rows)
INSERT INTO fund_transfer (transfer_id, from_account_id, to_account_id, amount, transfer_date, status) VALUES
(1,12,2,15000.00,'2026-01-04 12:06:00','COMPLETED'),
(2,7,11,15000.00,'2026-01-10 13:49:00','COMPLETED'),
(3,10,2,10000.00,'2026-01-27 11:57:00','COMPLETED'),
(4,1,3,10000.00,'2026-02-03 15:56:00','COMPLETED'),
(5,9,2,15000.00,'2026-02-08 16:09:00','COMPLETED'),
(6,7,5,15000.00,'2026-02-15 14:20:00','COMPLETED'),
(7,2,7,8000.00,'2026-03-10 14:27:00','COMPLETED'),
(8,8,2,10000.00,'2026-03-13 16:36:00','COMPLETED'),
(9,10,7,15000.00,'2026-03-16 16:19:00','COMPLETED'),
(10,7,8,3000.00,'2026-04-08 10:24:00','COMPLETED'),
(11,10,12,3000.00,'2026-04-09 14:49:00','COMPLETED'),
(12,8,7,8000.00,'2026-04-10 10:04:00','COMPLETED'),
(13,1,8,3000.00,'2026-05-09 15:24:00','COMPLETED'),
(14,8,3,8000.00,'2026-05-15 12:10:00','COMPLETED'),
(15,1,2,3000.00,'2026-05-23 15:55:00','COMPLETED'),
(16,4,3,15000.00,'2026-06-09 11:09:00','COMPLETED'),
(17,11,3,5000.00,'2026-06-10 14:36:00','COMPLETED'),
(18,11,8,10000.00,'2026-06-15 17:24:00','COMPLETED');

-- Balance is maintained automatically by trigger trg_txn_after_insert
INSERT INTO transactions (account_id, txn_type, amount, txn_date, description, transfer_id) VALUES
(1,'DEPOSIT',150000.00,'2026-01-02 10:01:00','Opening deposit',NULL),
(2,'DEPOSIT',85000.00,'2026-01-02 10:02:00','Opening deposit',NULL),
(3,'DEPOSIT',240000.00,'2026-01-02 10:03:00','Opening deposit',NULL),
(4,'DEPOSIT',60000.00,'2026-01-02 10:04:00','Opening deposit',NULL),
(5,'DEPOSIT',120000.00,'2026-01-02 10:05:00','Opening deposit',NULL),
(6,'DEPOSIT',45000.00,'2026-01-02 10:06:00','Opening deposit',NULL),
(7,'DEPOSIT',310000.00,'2026-01-02 10:07:00','Opening deposit',NULL),
(8,'DEPOSIT',98000.00,'2026-01-02 10:08:00','Opening deposit',NULL),
(9,'DEPOSIT',72000.00,'2026-01-02 10:09:00','Opening deposit',NULL),
(10,'DEPOSIT',185000.00,'2026-01-02 10:10:00','Opening deposit',NULL),
(11,'DEPOSIT',50000.00,'2026-01-02 10:11:00','Opening deposit',NULL),
(12,'DEPOSIT',64000.00,'2026-01-02 10:12:00','Opening deposit',NULL),
(13,'DEPOSIT',30000.00,'2026-01-02 10:13:00','Opening deposit',NULL),
(8,'WITHDRAWAL',2000.00,'2026-01-04 09:13:00','UPI debit',NULL),
(12,'TRANSFER_OUT',15000.00,'2026-01-04 12:06:00','Transfer to A/C 002',1),
(2,'TRANSFER_IN',15000.00,'2026-01-04 12:06:00','Transfer from A/C 012',1),
(13,'WITHDRAWAL',2000.00,'2026-01-05 17:25:00','Bill payment',NULL),
(6,'WITHDRAWAL',10000.00,'2026-01-07 12:29:00','ATM withdrawal',NULL),
(3,'WITHDRAWAL',7500.00,'2026-01-08 10:10:00','Bill payment',NULL),
(1,'DEPOSIT',2000.00,'2026-01-09 12:28:00','Cheque deposit',NULL),
(2,'WITHDRAWAL',3500.00,'2026-01-09 16:35:00','Cash withdrawal',NULL),
(6,'WITHDRAWAL',7500.00,'2026-01-09 16:39:00','ATM withdrawal',NULL),
(4,'DEPOSIT',10000.00,'2026-01-10 13:43:00','Salary credit',NULL),
(7,'TRANSFER_OUT',15000.00,'2026-01-10 13:49:00','Transfer to A/C 011',2),
(11,'TRANSFER_IN',15000.00,'2026-01-10 13:49:00','Transfer from A/C 007',2),
(2,'WITHDRAWAL',3500.00,'2026-01-12 09:31:00','UPI debit',NULL),
(3,'DEPOSIT',5000.00,'2026-01-12 13:19:00','Cash deposit',NULL),
(7,'WITHDRAWAL',20000.00,'2026-01-13 13:45:00','ATM withdrawal',NULL),
(13,'DEPOSIT',7500.00,'2026-01-13 15:08:00','UPI credit',NULL),
(10,'DEPOSIT',5000.00,'2026-01-14 11:13:00','UPI credit',NULL),
(1,'WITHDRAWAL',10000.00,'2026-01-15 13:28:00','Bill payment',NULL),
(4,'DEPOSIT',5000.00,'2026-01-17 11:46:00','Cheque deposit',NULL),
(7,'DEPOSIT',3500.00,'2026-01-18 11:02:00','Cheque deposit',NULL),
(5,'WITHDRAWAL',10000.00,'2026-01-18 14:37:00','UPI debit',NULL),
(9,'WITHDRAWAL',20000.00,'2026-01-20 14:20:00','Cash withdrawal',NULL),
(8,'DEPOSIT',3500.00,'2026-01-21 09:31:00','Salary credit',NULL),
(6,'DEPOSIT',5000.00,'2026-01-22 10:31:00','Salary credit',NULL),
(13,'WITHDRAWAL',20000.00,'2026-01-22 15:05:00','ATM withdrawal',NULL),
(2,'WITHDRAWAL',12000.00,'2026-01-24 09:06:00','ATM withdrawal',NULL),
(11,'WITHDRAWAL',15000.00,'2026-01-24 10:47:00','Cash withdrawal',NULL),
(12,'DEPOSIT',2000.00,'2026-01-27 11:36:00','Salary credit',NULL),
(10,'TRANSFER_OUT',10000.00,'2026-01-27 11:57:00','Transfer to A/C 002',3),
(2,'TRANSFER_IN',10000.00,'2026-01-27 11:57:00','Transfer from A/C 010',3),
(11,'WITHDRAWAL',5000.00,'2026-01-27 12:49:00','ATM withdrawal',NULL),
(12,'DEPOSIT',12000.00,'2026-01-27 15:23:00','Cash deposit',NULL),
(1,'TRANSFER_OUT',10000.00,'2026-02-03 15:56:00','Transfer to A/C 003',4),
(3,'TRANSFER_IN',10000.00,'2026-02-03 15:56:00','Transfer from A/C 001',4),
(6,'WITHDRAWAL',25000.00,'2026-02-03 17:52:00','UPI debit',NULL),
(1,'WITHDRAWAL',25000.00,'2026-02-04 09:10:00','UPI debit',NULL),
(2,'DEPOSIT',3500.00,'2026-02-07 10:08:00','UPI credit',NULL),
(4,'WITHDRAWAL',5000.00,'2026-02-07 10:47:00','Cash withdrawal',NULL),
(7,'WITHDRAWAL',5000.00,'2026-02-08 14:38:00','Bill payment',NULL),
(9,'TRANSFER_OUT',15000.00,'2026-02-08 16:09:00','Transfer to A/C 002',5),
(2,'TRANSFER_IN',15000.00,'2026-02-08 16:09:00','Transfer from A/C 009',5),
(5,'DEPOSIT',12000.00,'2026-02-10 12:50:00','Cash deposit',NULL),
(12,'DEPOSIT',20000.00,'2026-02-10 17:47:00','Salary credit',NULL),
(11,'WITHDRAWAL',7500.00,'2026-02-11 15:10:00','Bill payment',NULL),
(1,'DEPOSIT',25000.00,'2026-02-12 13:07:00','UPI credit',NULL),
(11,'WITHDRAWAL',7500.00,'2026-02-14 11:12:00','ATM withdrawal',NULL),
(4,'DEPOSIT',15000.00,'2026-02-14 14:00:00','UPI credit',NULL),
(7,'TRANSFER_OUT',15000.00,'2026-02-15 14:20:00','Transfer to A/C 005',6),
(5,'TRANSFER_IN',15000.00,'2026-02-15 14:20:00','Transfer from A/C 007',6),
(1,'DEPOSIT',20000.00,'2026-02-16 09:51:00','UPI credit',NULL),
(3,'WITHDRAWAL',12000.00,'2026-02-16 11:58:00','UPI debit',NULL),
(9,'WITHDRAWAL',20000.00,'2026-02-16 15:59:00','Bill payment',NULL),
(12,'WITHDRAWAL',3500.00,'2026-02-17 16:17:00','Bill payment',NULL),
(2,'WITHDRAWAL',3500.00,'2026-02-18 14:23:00','ATM withdrawal',NULL),
(6,'WITHDRAWAL',5000.00,'2026-02-18 16:10:00','ATM withdrawal',NULL),
(10,'DEPOSIT',12000.00,'2026-02-19 10:05:00','Cash deposit',NULL),
(5,'DEPOSIT',25000.00,'2026-02-19 12:30:00','Cheque deposit',NULL),
(11,'WITHDRAWAL',25000.00,'2026-02-23 11:28:00','UPI debit',NULL),
(8,'DEPOSIT',7500.00,'2026-02-24 16:43:00','Cash deposit',NULL),
(9,'WITHDRAWAL',3500.00,'2026-02-25 13:43:00','Cash withdrawal',NULL),
(3,'DEPOSIT',20000.00,'2026-02-26 13:35:00','Cheque deposit',NULL),
(7,'WITHDRAWAL',2000.00,'2026-03-03 16:14:00','UPI debit',NULL),
(1,'WITHDRAWAL',2000.00,'2026-03-04 17:11:00','Bill payment',NULL),
(9,'WITHDRAWAL',12000.00,'2026-03-05 13:43:00','ATM withdrawal',NULL),
(3,'DEPOSIT',25000.00,'2026-03-06 11:47:00','Cheque deposit',NULL),
(4,'WITHDRAWAL',10000.00,'2026-03-07 10:25:00','UPI debit',NULL),
(1,'WITHDRAWAL',10000.00,'2026-03-07 13:10:00','ATM withdrawal',NULL),
(10,'DEPOSIT',2000.00,'2026-03-07 14:04:00','Cash deposit',NULL),
(2,'WITHDRAWAL',2000.00,'2026-03-07 16:28:00','Cash withdrawal',NULL),
(2,'WITHDRAWAL',7500.00,'2026-03-10 09:53:00','Bill payment',NULL),
(2,'TRANSFER_OUT',8000.00,'2026-03-10 14:27:00','Transfer to A/C 007',7),
(7,'TRANSFER_IN',8000.00,'2026-03-10 14:27:00','Transfer from A/C 002',7),
(3,'DEPOSIT',15000.00,'2026-03-10 17:42:00','UPI credit',NULL),
(11,'DEPOSIT',10000.00,'2026-03-11 09:06:00','UPI credit',NULL),
(4,'WITHDRAWAL',12000.00,'2026-03-11 11:20:00','Cash withdrawal',NULL),
(3,'DEPOSIT',12000.00,'2026-03-13 10:23:00','Salary credit',NULL),
(8,'TRANSFER_OUT',10000.00,'2026-03-13 16:36:00','Transfer to A/C 002',8),
(2,'TRANSFER_IN',10000.00,'2026-03-13 16:36:00','Transfer from A/C 008',8),
(8,'DEPOSIT',7500.00,'2026-03-14 09:24:00','Cheque deposit',NULL),
(5,'WITHDRAWAL',15000.00,'2026-03-15 09:13:00','UPI debit',NULL),
(6,'DEPOSIT',20000.00,'2026-03-15 09:49:00','Cash deposit',NULL),
(10,'TRANSFER_OUT',15000.00,'2026-03-16 16:19:00','Transfer to A/C 007',9),
(7,'TRANSFER_IN',15000.00,'2026-03-16 16:19:00','Transfer from A/C 010',9),
(10,'WITHDRAWAL',7500.00,'2026-03-17 17:52:00','Bill payment',NULL),
(5,'WITHDRAWAL',5000.00,'2026-03-22 13:00:00','Cash withdrawal',NULL),
(2,'DEPOSIT',12000.00,'2026-03-24 16:57:00','Cash deposit',NULL),
(7,'WITHDRAWAL',20000.00,'2026-03-25 09:28:00','Cash withdrawal',NULL),
(12,'DEPOSIT',10000.00,'2026-03-26 10:52:00','Cash deposit',NULL),
(7,'TRANSFER_OUT',3000.00,'2026-04-08 10:24:00','Transfer to A/C 008',10),
(8,'TRANSFER_IN',3000.00,'2026-04-08 10:24:00','Transfer from A/C 007',10),
(5,'DEPOSIT',20000.00,'2026-04-08 14:08:00','Salary credit',NULL),
(3,'WITHDRAWAL',20000.00,'2026-04-09 10:29:00','Cash withdrawal',NULL),
(10,'TRANSFER_OUT',3000.00,'2026-04-09 14:49:00','Transfer to A/C 012',11),
(12,'TRANSFER_IN',3000.00,'2026-04-09 14:49:00','Transfer from A/C 010',11),
(8,'TRANSFER_OUT',8000.00,'2026-04-10 10:04:00','Transfer to A/C 007',12),
(7,'TRANSFER_IN',8000.00,'2026-04-10 10:04:00','Transfer from A/C 008',12),
(4,'DEPOSIT',20000.00,'2026-04-10 13:08:00','Salary credit',NULL),
(5,'DEPOSIT',12000.00,'2026-04-11 10:26:00','Cash deposit',NULL),
(7,'WITHDRAWAL',15000.00,'2026-04-11 13:43:00','UPI debit',NULL),
(9,'DEPOSIT',10000.00,'2026-04-11 16:16:00','UPI credit',NULL),
(11,'DEPOSIT',15000.00,'2026-04-12 10:37:00','UPI credit',NULL),
(10,'WITHDRAWAL',2000.00,'2026-04-12 13:05:00','Bill payment',NULL),
(6,'WITHDRAWAL',2000.00,'2026-04-12 15:27:00','Bill payment',NULL),
(6,'WITHDRAWAL',5000.00,'2026-04-13 15:02:00','ATM withdrawal',NULL),
(6,'DEPOSIT',25000.00,'2026-04-14 16:03:00','Salary credit',NULL),
(1,'WITHDRAWAL',15000.00,'2026-04-17 11:46:00','UPI debit',NULL),
(1,'WITHDRAWAL',7500.00,'2026-04-17 11:48:00','Cash withdrawal',NULL),
(2,'WITHDRAWAL',7500.00,'2026-04-17 12:58:00','Bill payment',NULL),
(4,'DEPOSIT',15000.00,'2026-04-19 13:54:00','Cheque deposit',NULL),
(12,'DEPOSIT',20000.00,'2026-04-19 14:41:00','Cheque deposit',NULL),
(8,'WITHDRAWAL',25000.00,'2026-04-19 15:17:00','Bill payment',NULL),
(2,'DEPOSIT',2000.00,'2026-04-20 13:47:00','UPI credit',NULL),
(8,'WITHDRAWAL',10000.00,'2026-04-21 14:29:00','Cash withdrawal',NULL),
(7,'WITHDRAWAL',7500.00,'2026-04-23 15:21:00','UPI debit',NULL),
(5,'WITHDRAWAL',2000.00,'2026-04-24 15:43:00','ATM withdrawal',NULL),
(9,'DEPOSIT',15000.00,'2026-04-26 13:08:00','Cheque deposit',NULL),
(3,'WITHDRAWAL',15000.00,'2026-04-27 15:30:00','Bill payment',NULL),
(2,'WITHDRAWAL',25000.00,'2026-05-03 14:14:00','UPI debit',NULL),
(6,'WITHDRAWAL',5000.00,'2026-05-04 13:27:00','Cash withdrawal',NULL),
(10,'WITHDRAWAL',25000.00,'2026-05-05 13:08:00','ATM withdrawal',NULL),
(1,'DEPOSIT',15000.00,'2026-05-05 14:09:00','Salary credit',NULL),
(1,'DEPOSIT',15000.00,'2026-05-07 17:50:00','Salary credit',NULL),
(11,'DEPOSIT',3500.00,'2026-05-08 10:06:00','Cheque deposit',NULL),
(7,'WITHDRAWAL',2000.00,'2026-05-08 14:41:00','Cash withdrawal',NULL),
(3,'WITHDRAWAL',25000.00,'2026-05-09 12:54:00','UPI debit',NULL),
(1,'TRANSFER_OUT',3000.00,'2026-05-09 15:24:00','Transfer to A/C 008',13),
(8,'TRANSFER_IN',3000.00,'2026-05-09 15:24:00','Transfer from A/C 001',13),
(9,'WITHDRAWAL',15000.00,'2026-05-10 11:01:00','Cash withdrawal',NULL),
(9,'DEPOSIT',20000.00,'2026-05-10 16:28:00','UPI credit',NULL),
(7,'WITHDRAWAL',15000.00,'2026-05-11 14:46:00','UPI debit',NULL),
(4,'DEPOSIT',25000.00,'2026-05-13 15:34:00','Cash deposit',NULL),
(6,'DEPOSIT',2000.00,'2026-05-13 17:55:00','Cash deposit',NULL),
(5,'WITHDRAWAL',15000.00,'2026-05-14 10:00:00','Cash withdrawal',NULL),
(12,'WITHDRAWAL',15000.00,'2026-05-14 11:03:00','Cash withdrawal',NULL),
(12,'DEPOSIT',2000.00,'2026-05-15 09:12:00','Salary credit',NULL),
(8,'TRANSFER_OUT',8000.00,'2026-05-15 12:10:00','Transfer to A/C 003',14),
(3,'TRANSFER_IN',8000.00,'2026-05-15 12:10:00','Transfer from A/C 008',14),
(3,'WITHDRAWAL',12000.00,'2026-05-16 12:06:00','ATM withdrawal',NULL),
(8,'WITHDRAWAL',25000.00,'2026-05-17 11:44:00','Cash withdrawal',NULL),
(1,'WITHDRAWAL',3500.00,'2026-05-19 13:19:00','UPI debit',NULL),
(10,'DEPOSIT',10000.00,'2026-05-19 14:48:00','Salary credit',NULL),
(12,'WITHDRAWAL',7500.00,'2026-05-20 10:04:00','UPI debit',NULL),
(5,'WITHDRAWAL',10000.00,'2026-05-23 11:40:00','UPI debit',NULL),
(2,'WITHDRAWAL',25000.00,'2026-05-23 13:04:00','UPI debit',NULL),
(1,'TRANSFER_OUT',3000.00,'2026-05-23 15:55:00','Transfer to A/C 002',15),
(2,'TRANSFER_IN',3000.00,'2026-05-23 15:55:00','Transfer from A/C 001',15),
(4,'DEPOSIT',20000.00,'2026-05-24 12:24:00','Cash deposit',NULL),
(5,'DEPOSIT',7500.00,'2026-05-24 14:52:00','UPI credit',NULL),
(8,'WITHDRAWAL',5000.00,'2026-05-25 14:35:00','Bill payment',NULL),
(11,'DEPOSIT',5000.00,'2026-05-25 15:50:00','Salary credit',NULL),
(9,'WITHDRAWAL',25000.00,'2026-05-26 16:18:00','Cash withdrawal',NULL),
(3,'WITHDRAWAL',7500.00,'2026-06-03 10:00:00','Bill payment',NULL),
(1,'WITHDRAWAL',25000.00,'2026-06-03 16:11:00','UPI debit',NULL),
(1,'WITHDRAWAL',20000.00,'2026-06-05 10:17:00','Cash withdrawal',NULL),
(4,'DEPOSIT',25000.00,'2026-06-05 11:31:00','Salary credit',NULL),
(5,'WITHDRAWAL',3500.00,'2026-06-07 13:11:00','UPI debit',NULL),
(10,'WITHDRAWAL',7500.00,'2026-06-08 14:51:00','UPI debit',NULL),
(4,'TRANSFER_OUT',15000.00,'2026-06-09 11:09:00','Transfer to A/C 003',16),
(3,'TRANSFER_IN',15000.00,'2026-06-09 11:09:00','Transfer from A/C 004',16),
(11,'TRANSFER_OUT',5000.00,'2026-06-10 14:36:00','Transfer to A/C 003',17),
(3,'TRANSFER_IN',5000.00,'2026-06-10 14:36:00','Transfer from A/C 011',17),
(4,'DEPOSIT',15000.00,'2026-06-10 17:32:00','UPI credit',NULL),
(8,'DEPOSIT',5000.00,'2026-06-12 17:40:00','Salary credit',NULL),
(12,'DEPOSIT',3500.00,'2026-06-14 11:24:00','UPI credit',NULL),
(2,'DEPOSIT',20000.00,'2026-06-14 14:34:00','Cash deposit',NULL),
(7,'DEPOSIT',7500.00,'2026-06-15 16:14:00','UPI credit',NULL),
(11,'TRANSFER_OUT',10000.00,'2026-06-15 17:24:00','Transfer to A/C 008',18),
(8,'TRANSFER_IN',10000.00,'2026-06-15 17:24:00','Transfer from A/C 011',18),
(12,'DEPOSIT',15000.00,'2026-06-16 12:13:00','Cheque deposit',NULL),
(11,'WITHDRAWAL',12000.00,'2026-06-16 14:54:00','Bill payment',NULL),
(11,'DEPOSIT',15000.00,'2026-06-21 10:28:00','Salary credit',NULL),
(3,'WITHDRAWAL',5000.00,'2026-06-21 14:34:00','UPI debit',NULL),
(5,'WITHDRAWAL',12000.00,'2026-06-21 15:47:00','Cash withdrawal',NULL),
(6,'WITHDRAWAL',25000.00,'2026-06-21 16:16:00','UPI debit',NULL),
(9,'DEPOSIT',7500.00,'2026-06-22 16:37:00','Salary credit',NULL),
(5,'WITHDRAWAL',25000.00,'2026-06-24 13:40:00','Cash withdrawal',NULL),
(2,'WITHDRAWAL',15000.00,'2026-06-25 17:38:00','Bill payment',NULL),
(3,'WITHDRAWAL',25000.00,'2026-06-27 16:24:00','Bill payment',NULL);

-- Reconciliation check: stored balance must equal the sum of the ledger
SELECT a.account_id, a.balance AS stored_balance,
       SUM(CASE WHEN t.txn_type IN ('DEPOSIT','TRANSFER_IN') THEN t.amount ELSE -t.amount END) AS ledger_balance
FROM account a JOIN transactions t ON t.account_id = a.account_id
GROUP BY a.account_id, a.balance
HAVING stored_balance <> ledger_balance;      -- expected: 0 rows


-- =====================================================================
-- SECTION 3 : VIEWS
-- =====================================================================

-- [V1] View: customer balances
-- Total balance and number of accounts for every customer.
CREATE OR REPLACE VIEW vw_customer_balances AS
SELECT c.customer_id,
       CONCAT(c.first_name,' ',c.last_name) AS customer_name,
       c.city,
       COUNT(a.account_id)  AS no_of_accounts,
       COALESCE(SUM(a.balance),0) AS total_balance
FROM customer c
LEFT JOIN account a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.city;

SELECT * FROM vw_customer_balances ORDER BY total_balance DESC;

-- [V2] View: loan summary
-- Loan-wise repayment summary (payments made vs principal).
CREATE OR REPLACE VIEW vw_loan_summary AS
SELECT l.loan_id,
       CONCAT(c.first_name,' ',c.last_name) AS customer_name,
       l.loan_type, l.principal, l.interest_rate, l.tenure_months, l.status,
       COUNT(p.payment_id)               AS emis_paid,
       COALESCE(SUM(p.amount),0)         AS total_paid,
       ROUND(COALESCE(SUM(p.amount),0) * 100 / l.principal, 2) AS paid_pct_of_principal
FROM loan l
JOIN customer c ON c.customer_id = l.customer_id
LEFT JOIN loan_payment p ON p.loan_id = l.loan_id
GROUP BY l.loan_id, c.first_name, c.last_name, l.loan_type, l.principal,
         l.interest_rate, l.tenure_months, l.status;

SELECT * FROM vw_loan_summary ORDER BY loan_id;

-- [V3] View: monthly transaction summary
-- Month-wise deposits, withdrawals and net cash flow for the whole bank.
CREATE OR REPLACE VIEW vw_monthly_txn_summary AS
SELECT DATE_FORMAT(txn_date,'%Y-%m') AS txn_month,
       COUNT(*) AS no_of_txns,
       SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN')      THEN amount ELSE 0 END) AS total_credits,
       SUM(CASE WHEN txn_type IN ('WITHDRAWAL','TRANSFER_OUT')  THEN amount ELSE 0 END) AS total_debits
FROM transactions
GROUP BY DATE_FORMAT(txn_date,'%Y-%m');

SELECT * FROM vw_monthly_txn_summary ORDER BY txn_month;


-- =====================================================================
-- SECTION 4 : JOINS
-- =====================================================================

-- [Q1] Account statement with running balance (JOIN + CTE + window function)
-- Generates the statement of account 501000000001 for Jan-Mar 2026. The running balance is computed over the full history and filtered afterwards.
WITH ledger AS (
    SELECT t.txn_id, t.txn_date, t.txn_type, t.description, t.amount,
           SUM(CASE WHEN t.txn_type IN ('DEPOSIT','TRANSFER_IN') THEN t.amount ELSE -t.amount END)
               OVER (PARTITION BY t.account_id ORDER BY t.txn_date, t.txn_id) AS running_balance
    FROM transactions t
    JOIN account a ON a.account_id = t.account_id
    WHERE a.account_no = '501000000001'
)
SELECT txn_date, txn_type, description, amount, running_balance
FROM ledger
WHERE txn_date >= '2026-01-01' AND txn_date < '2026-04-01'
ORDER BY txn_date, txn_id;

-- [Q2] INNER JOIN - customers, accounts and branches
-- Lists every account with its holder and branch.
SELECT a.account_no, CONCAT(c.first_name,' ',c.last_name) AS holder,
       b.branch_name, a.account_type, a.balance
FROM account a
INNER JOIN customer c ON c.customer_id = a.customer_id
INNER JOIN branch   b ON b.branch_id   = a.branch_id
ORDER BY a.account_id;

-- [Q3] LEFT OUTER JOIN - customers with no loan
-- Customers who have never applied for a loan (cross-sell targets).
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer_name, c.city
FROM customer c
LEFT JOIN loan l ON l.customer_id = c.customer_id
WHERE l.loan_id IS NULL
ORDER BY c.customer_id;

-- [Q4] RIGHT OUTER JOIN - loans per branch
-- Shows every branch even if it has no approved loans.
SELECT b.branch_name,
       COUNT(l.loan_id)                  AS approved_loans,
       COALESCE(SUM(l.principal),0)      AS total_sanctioned
FROM loan l
RIGHT JOIN branch b ON b.branch_id = l.branch_id AND l.status = 'APPROVED'
GROUP BY b.branch_id, b.branch_name
ORDER BY total_sanctioned DESC;

-- [Q5] SELF JOIN - employee and reporting manager
-- Employee hierarchy using the self-referencing foreign key manager_id.
SELECT e.emp_name AS employee, e.designation,
       COALESCE(m.emp_name,'-- (top of hierarchy)') AS reports_to
FROM employee e
LEFT JOIN employee m ON m.emp_id = e.manager_id
ORDER BY e.emp_id;

-- [Q6] GROUP BY / HAVING - branch-wise deposits
-- Branches whose customers hold more than Rs 3,00,000 in total.
SELECT b.branch_name, COUNT(a.account_id) AS accounts, SUM(a.balance) AS total_deposits,
       ROUND(AVG(a.balance),2) AS avg_balance
FROM branch b JOIN account a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
HAVING SUM(a.balance) > 300000
ORDER BY total_deposits DESC;


-- =====================================================================
-- SECTION 5 : SUBQUERIES
-- =====================================================================

-- [Q7] Nested subquery - above-average balances
-- Accounts holding more than the bank-wide average balance.
SELECT account_no, customer_id, balance
FROM account
WHERE balance > (SELECT AVG(balance) FROM account)
ORDER BY balance DESC;

-- [Q8] Correlated subquery - unusually large transactions
-- Day-to-day transactions (opening deposits excluded) that are more than 1.5 times the average day-to-day transaction of the same account.
SELECT t.txn_id, t.account_id, t.txn_type, t.amount, DATE(t.txn_date) AS txn_date
FROM transactions t
WHERE t.description <> 'Opening deposit'
  AND t.amount > 1.5 * (SELECT AVG(t2.amount)
                        FROM transactions t2
                        WHERE t2.account_id = t.account_id
                          AND t2.description <> 'Opening deposit')
ORDER BY t.amount DESC
LIMIT 10;

-- [Q9] IN / EXISTS subqueries
-- Customers with an approved loan and a withdrawal of Rs 20,000 or more.
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer_name
FROM customer c
WHERE c.customer_id IN (SELECT customer_id FROM loan WHERE status = 'APPROVED')
  AND EXISTS (SELECT 1
              FROM account a JOIN transactions t ON t.account_id = a.account_id
              WHERE a.customer_id = c.customer_id
                AND t.txn_type = 'WITHDRAWAL' AND t.amount >= 20000)
ORDER BY c.customer_id;


-- =====================================================================
-- SECTION 6 : SET OPERATIONS
-- =====================================================================

-- [Q10] UNION
-- Customers who either hold an approved loan or have a total balance above Rs 1,50,000 (duplicates removed).
SELECT customer_id FROM loan WHERE status = 'APPROVED'
UNION
SELECT customer_id FROM account GROUP BY customer_id HAVING SUM(balance) > 150000
ORDER BY customer_id;

-- [Q11] INTERSECT
-- Customers who hold an approved loan AND have a total balance above Rs 1,50,000.
SELECT customer_id FROM loan WHERE status = 'APPROVED'
INTERSECT
SELECT customer_id FROM account GROUP BY customer_id HAVING SUM(balance) > 150000
ORDER BY customer_id;

-- [Q12] EXCEPT (MINUS)
-- Customers who hold an account but have never applied for any loan.
SELECT customer_id FROM account
EXCEPT
SELECT customer_id FROM loan
ORDER BY customer_id;


-- =====================================================================
-- SECTION 7 : WINDOW FUNCTIONS
-- =====================================================================

-- [Q13] Monthly transaction analysis (LAG, running total)
-- Month-wise net cash flow, month-on-month change and cumulative net flow for the bank.
SELECT txn_month, total_credits, total_debits,
       total_credits - total_debits                                         AS net_flow,
       (total_credits - total_debits)
         - LAG(total_credits - total_debits) OVER (ORDER BY txn_month)      AS change_vs_prev_month,
       SUM(total_credits - total_debits) OVER (ORDER BY txn_month)          AS cumulative_net_flow
FROM vw_monthly_txn_summary
ORDER BY txn_month;

-- [Q14] RANK, DENSE_RANK and NTILE - customer ranking
-- Ranks customers by total balance and splits them into 4 quartiles.
SELECT customer_name, total_balance,
       RANK()       OVER (ORDER BY total_balance DESC) AS balance_rank,
       DENSE_RANK() OVER (ORDER BY total_balance DESC) AS dense_rank_no,
       NTILE(4)     OVER (ORDER BY total_balance DESC) AS quartile
FROM vw_customer_balances
ORDER BY balance_rank;

-- [Q15] ROW_NUMBER with PARTITION BY - largest withdrawal each month
-- Top withdrawal in every month, with the account that made it.
SELECT txn_month, account_no, amount
FROM (
    SELECT DATE_FORMAT(t.txn_date,'%Y-%m') AS txn_month, a.account_no, t.amount,
           ROW_NUMBER() OVER (PARTITION BY DATE_FORMAT(t.txn_date,'%Y-%m')
                              ORDER BY t.amount DESC, t.txn_id) AS rn
    FROM transactions t JOIN account a ON a.account_id = t.account_id
    WHERE t.txn_type = 'WITHDRAWAL'
) x
WHERE rn = 1
ORDER BY txn_month;

-- [Q16] Moving average of monthly debits (frame clause)
-- 3-month moving average of total debits.
SELECT txn_month, total_debits,
       ROUND(AVG(total_debits) OVER (ORDER BY txn_month
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS moving_avg_3m
FROM vw_monthly_txn_summary
ORDER BY txn_month;


-- =====================================================================
-- SECTION 8 : CTES
-- =====================================================================

-- [Q17] Multiple CTEs - accounts with falling balances
-- Accounts whose net flow was negative in at least 3 of the 6 months.
WITH monthly AS (
    SELECT account_id, DATE_FORMAT(txn_date,'%Y-%m') AS m,
           SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount ELSE -amount END) AS net
    FROM transactions
    GROUP BY account_id, DATE_FORMAT(txn_date,'%Y-%m')
),
negative_months AS (
    SELECT account_id, COUNT(*) AS neg_months
    FROM monthly WHERE net < 0
    GROUP BY account_id
)
SELECT a.account_no, n.neg_months, a.balance
FROM negative_months n JOIN account a ON a.account_id = n.account_id
WHERE n.neg_months >= 3
ORDER BY n.neg_months DESC, a.account_no;

-- [Q18] Recursive CTE - loan amortisation schedule
-- First 6 months of the amortisation schedule for the personal loan (loan_id 3).
WITH RECURSIVE params AS (
    SELECT principal AS p, interest_rate / 1200 AS r, tenure_months AS n
    FROM loan WHERE loan_id = 3
),
emi AS (
    SELECT p, r, n, p * r * POW(1+r, n) / (POW(1+r, n) - 1) AS emi FROM params
),
schedule (month_no, opening_balance, interest, principal_paid, closing_balance) AS (
    SELECT 1, p, p * r, emi - p * r, p - (emi - p * r) FROM emi
    UNION ALL
    SELECT s.month_no + 1, s.closing_balance, s.closing_balance * e.r,
           e.emi - s.closing_balance * e.r,
           s.closing_balance - (e.emi - s.closing_balance * e.r)
    FROM schedule s CROSS JOIN emi e
    WHERE s.month_no < 6
)
SELECT month_no,
       ROUND(opening_balance,2) AS opening_balance,
       ROUND(interest,2)        AS interest,
       ROUND(principal_paid,2)  AS principal_paid,
       ROUND(closing_balance,2) AS closing_balance
FROM schedule;

-- [Q19] Suspicious activity detection (AML style)
-- Accounts with 2 or more debits of Rs 15,000+ inside the same calendar month.
WITH big_withdrawals AS (
    SELECT account_id, DATE_FORMAT(txn_date,'%Y-%m') AS m, COUNT(*) AS cnt, SUM(amount) AS total
    FROM transactions
    WHERE txn_type IN ('WITHDRAWAL','TRANSFER_OUT') AND amount >= 15000
    GROUP BY account_id, DATE_FORMAT(txn_date,'%Y-%m')
)
SELECT a.account_no, b.m AS month, b.cnt, b.total
FROM big_withdrawals b JOIN account a ON a.account_id = b.account_id
WHERE b.cnt >= 2
ORDER BY b.cnt DESC, b.total DESC;


-- =====================================================================
-- SECTION 9 : INDEXING
-- =====================================================================

-- [X1] Index usage verified with EXPLAIN
-- Confirms the composite index idx_txn_account_date is used for statement queries.
EXPLAIN SELECT txn_id, txn_date, amount
FROM transactions
WHERE account_id = 1 AND txn_date BETWEEN '2026-03-01' AND '2026-03-31';

SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = 'bank_db' AND table_name = 'transactions'
GROUP BY index_name;


-- =====================================================================
-- SECTION 10 : STORED PROCEDURE
-- =====================================================================

-- [P1] Fund transfer procedure (atomic, with TCL)
-- Transfers money between two accounts as one atomic unit: validation, debit, credit and rollback on error.
DROP PROCEDURE IF EXISTS sp_fund_transfer;
DELIMITER //
CREATE PROCEDURE sp_fund_transfer(IN p_from CHAR(12), IN p_to CHAR(12), IN p_amount DECIMAL(12,2))
BEGIN
    DECLARE v_from INT; DECLARE v_to INT; DECLARE v_tid INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'FAILED - transaction rolled back (insufficient balance or invalid data)' AS result;
    END;

    SELECT account_id INTO v_from FROM account WHERE account_no = p_from AND status = 'ACTIVE';
    SELECT account_id INTO v_to   FROM account WHERE account_no = p_to   AND status = 'ACTIVE';

    START TRANSACTION;
        INSERT INTO fund_transfer (from_account_id,to_account_id,amount,transfer_date,status)
        VALUES (v_from, v_to, p_amount, NOW(), 'COMPLETED');
        SET v_tid = LAST_INSERT_ID();
        INSERT INTO transactions (account_id,txn_type,amount,txn_date,description,transfer_id)
        VALUES (v_from,'TRANSFER_OUT',p_amount,NOW(),CONCAT('Transfer to ',p_to),v_tid);
        INSERT INTO transactions (account_id,txn_type,amount,txn_date,description,transfer_id)
        VALUES (v_to,'TRANSFER_IN',p_amount,NOW(),CONCAT('Transfer from ',p_from),v_tid);
    COMMIT;
    SELECT 'SUCCESS - transfer committed' AS result;
END//
DELIMITER ;

SELECT account_no, balance FROM account WHERE account_no IN ('501000000003','501000000005');
CALL sp_fund_transfer('501000000003','501000000005',25000.00);
SELECT account_no, balance FROM account WHERE account_no IN ('501000000003','501000000005');

-- [P2] Failed transfer (insufficient funds) is rolled back
-- Attempts to move Rs 5,00,000 from an account that has far less - nothing must change.
CALL sp_fund_transfer('501000000006','501000000001',500000.00);
SELECT account_no, balance FROM account WHERE account_no IN ('501000000006','501000000001');
SELECT COUNT(*) AS failed_transfer_rows_left FROM fund_transfer WHERE amount = 500000.00;


-- =====================================================================
-- SECTION 11 : DML
-- =====================================================================

-- [D1] INSERT, UPDATE and DELETE
-- Adds a customer, updates the KYC status and deletes the record again.
INSERT INTO customer (first_name,last_name,dob,gender,email,phone,pan_no,city,created_at)
VALUES ('Test','User','1999-01-01','M','test.user@mail.com','9899999999','TESTU9999Z','Delhi','2026-06-30');

UPDATE customer SET kyc_status = 'VERIFIED' WHERE email = 'test.user@mail.com';
SELECT customer_id, first_name, last_name, kyc_status FROM customer WHERE email = 'test.user@mail.com';

DELETE FROM customer WHERE email = 'test.user@mail.com';
SELECT COUNT(*) AS rows_after_delete FROM customer WHERE email = 'test.user@mail.com';


-- =====================================================================
-- SECTION 12 : TCL
-- =====================================================================

-- [T1] START TRANSACTION, SAVEPOINT, ROLLBACK TO, COMMIT
-- Interest-rate revision with a partial rollback to a savepoint.
START TRANSACTION;
    UPDATE account SET interest_rate = 4.25 WHERE branch_id = 1;     -- step 1
    SAVEPOINT after_branch1;
    UPDATE account SET interest_rate = 9.99 WHERE branch_id = 2;     -- step 2 (mistake)
    SELECT branch_id, MIN(interest_rate) AS min_rate, MAX(interest_rate) AS max_rate FROM account GROUP BY branch_id;
    ROLLBACK TO SAVEPOINT after_branch1;                             -- undo only step 2
COMMIT;                                                              -- make step 1 permanent
SELECT branch_id, MIN(interest_rate) AS min_rate, MAX(interest_rate) AS max_rate FROM account GROUP BY branch_id;


-- =====================================================================
-- SECTION 13 : DCL
-- =====================================================================

-- [C1] CREATE USER, GRANT, REVOKE
-- Role-based access: teller can record transactions, auditor can only read views.
CREATE USER IF NOT EXISTS 'bank_teller'@'localhost'  IDENTIFIED BY 'Teller@123';
CREATE USER IF NOT EXISTS 'bank_auditor'@'localhost' IDENTIFIED BY 'Audit@123';

GRANT SELECT, INSERT ON bank_db.transactions TO 'bank_teller'@'localhost';
GRANT SELECT ON bank_db.account  TO 'bank_teller'@'localhost';
GRANT SELECT ON bank_db.vw_customer_balances  TO 'bank_auditor'@'localhost';
GRANT SELECT ON bank_db.vw_loan_summary       TO 'bank_auditor'@'localhost';
GRANT SELECT ON bank_db.vw_monthly_txn_summary TO 'bank_auditor'@'localhost';

SHOW GRANTS FOR 'bank_teller'@'localhost';
REVOKE INSERT ON bank_db.transactions FROM 'bank_teller'@'localhost';
SHOW GRANTS FOR 'bank_teller'@'localhost';

DROP USER 'bank_teller'@'localhost';
DROP USER 'bank_auditor'@'localhost';


-- =====================================================================
-- SECTION 14 : INTEGRITY TESTS
-- =====================================================================

-- [E1] Overdraft is rejected
-- Withdrawal larger than the balance must fail (CHECK balance >= 0 via trigger).
-- EXPECTED RESULT: the statement below is REJECTED. Un-comment it to test.
-- INSERT INTO transactions (account_id,txn_type,amount,txn_date,description)
-- VALUES (6,'WITHDRAWAL',999999.00,NOW(),'Overdraft attempt');
-- ERROR 4025 (23000) at line 1: CONSTRAINT `chk_acc_balance` failed for `bank_db`.`account`

-- [E2] Negative amount is rejected
-- Amount must be greater than zero.
-- EXPECTED RESULT: the statement below is REJECTED. Un-comment it to test.
-- INSERT INTO transactions (account_id,txn_type,amount,txn_date,description)
-- VALUES (1,'DEPOSIT',-500.00,NOW(),'Negative deposit');
-- ERROR 4025 (23000) at line 1: CONSTRAINT `chk_txn_amt` failed for `bank_db`.`transactions`

-- [E3] Duplicate e-mail is rejected
-- E-mail is a candidate key (UNIQUE).
-- EXPECTED RESULT: the statement below is REJECTED. Un-comment it to test.
-- INSERT INTO customer (first_name,last_name,dob,gender,email,phone,pan_no,city,created_at)
-- VALUES ('Dup','Mail','1990-01-01','M','aarav.sharma@mail.com','9877777777','DUPMA7777Q','Delhi','2026-06-30');
-- ERROR 1062 (23000) at line 1: Duplicate entry 'aarav.sharma@mail.com' for key 'email'

-- [E4] Invalid phone number is rejected
-- Phone must be 10 digits starting with 6-9.
-- EXPECTED RESULT: the statement below is REJECTED. Un-comment it to test.
-- INSERT INTO customer (first_name,last_name,dob,gender,email,phone,pan_no,city,created_at)
-- VALUES ('Bad','Phone','1990-01-01','M','bad.phone@mail.com','1234567890','BADPH1234X','Delhi','2026-06-30');
-- ERROR 4025 (23000) at line 1: CONSTRAINT `chk_cust_phone` failed for `bank_db`.`customer`

-- [E5] Foreign-key violation is rejected
-- An account cannot be opened for a non-existent customer.
-- EXPECTED RESULT: the statement below is REJECTED. Un-comment it to test.
-- INSERT INTO account (account_no,customer_id,branch_id,open_date)
-- VALUES ('501000000099',999,1,'2026-06-30');
-- ERROR 1452 (23000) at line 1: Cannot add or update a child row: a foreign key constraint fails (`bank_db`.`account`, CONSTRAINT `fk_acc_cust` FOREIGN KEY (`customer_id`) REFERENCES `customer` (`customer_id`))

-- [E6] Self-transfer is rejected
-- from_account_id must differ from to_account_id.
-- EXPECTED RESULT: the statement below is REJECTED. Un-comment it to test.
-- INSERT INTO fund_transfer (from_account_id,to_account_id,amount,transfer_date)
-- VALUES (1,1,1000.00,NOW());
-- ERROR 4025 (23000) at line 1: CONSTRAINT `chk_tr_diff` failed for `bank_db`.`fund_transfer`
