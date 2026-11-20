# SimpleBankSphere - Original Database

This is a simplified PHP frontend for the ORIGINAL `bank_db` database from `Banking_System_Capstone.sql`.

## Important
The database schema and sample data are NOT replaced by a new simplified database.
This project connects directly to the original:
- customer
- account
- branch
- employee
- loan
- loan_payment
- fund_transfer
- transactions
- original views
- original stored procedure `sp_fund_transfer`

## XAMPP setup

1. Start Apache and MySQL in XAMPP.
2. Your MySQL/MariaDB is configured for port `3307`.
3. Import the original `Banking_System_Capstone.sql` into MariaDB:
   `mysql -u root -p bank_db < "C:\xampp\htdocs\bank-capstone-website\Banking_System_Capstone.sql"`
4. Copy this folder into:
   `C:\xampp\htdocs\`
5. Make sure `config.php` contains the correct MySQL password.
6. Open:
   `http://localhost/SimpleBankSphere_OriginalDB/`

Current XAMPP credentials used in this setup:
- Host: 127.0.0.1
- Port: 3307
- Database: bank_db
- Username: root
- Password: root123

If your password changes, edit only `config.php`.

## Features
- Dashboard
- Customer list
- Account list and balances
- Latest transactions
- Loan list
- Branch list
- Fund transfer using the original stored procedure

No Composer, Node.js, npm, or separate framework is required.
