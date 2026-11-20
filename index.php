<?php
$config = require __DIR__ . '/config.php';

$dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['database']};charset={$config['charset']}";

try {
    $pdo = new PDO($dsn, $config['username'], $config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException $e) {
    die("<div style='font-family:Arial;padding:30px'><h2>Database connection failed</h2>
    <p>Check XAMPP MySQL/MariaDB, port 3307, database <b>bank_db</b>, and config.php.</p>
    <pre>" . htmlspecialchars($e->getMessage()) . "</pre></div>");
}

$page = $_GET['page'] ?? 'dashboard';
$message = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'transfer') {
    $from = trim($_POST['from_account'] ?? '');
    $to = trim($_POST['to_account'] ?? '');
    $amount = (float)($_POST['amount'] ?? 0);

    if ($from === $to || $amount <= 0) {
        $error = 'Enter two different accounts and a valid amount.';
    } else {
        try {
            $stmt = $pdo->prepare("CALL sp_fund_transfer(?, ?, ?)");
            $stmt->execute([$from, $to, $amount]);
            $result = $stmt->fetch();
            $stmt->closeCursor();
            $message = $result['result'] ?? 'Transfer completed.';
        } catch (PDOException $e) {
            $error = 'Transfer failed: ' . $e->getMessage();
        }
    }
}

function money($n) {
    return '₹' . number_format((float)$n, 2);
}

function countRows($pdo, $table) {
    return (int)$pdo->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();
}

$totalCustomers = countRows($pdo, 'customer');
$totalAccounts = countRows($pdo, 'account');
$totalLoans = countRows($pdo, 'loan');
$totalTransactions = countRows($pdo, 'transactions');

$totalBalance = (float)$pdo->query("SELECT COALESCE(SUM(balance),0) FROM account")->fetchColumn();

$accounts = $pdo->query("
    SELECT a.account_no, CONCAT(c.first_name,' ',c.last_name) AS customer_name,
           b.branch_name, a.account_type, a.balance, a.status
    FROM account a
    JOIN customer c ON c.customer_id=a.customer_id
    JOIN branch b ON b.branch_id=a.branch_id
    ORDER BY a.account_id
")->fetchAll();

$customers = $pdo->query("
    SELECT customer_id, CONCAT(first_name,' ',last_name) AS customer_name,
           email, phone, city, kyc_status
    FROM customer ORDER BY customer_id
")->fetchAll();

$transactions = $pdo->query("
    SELECT t.txn_id, a.account_no,
           CONCAT(c.first_name,' ',c.last_name) AS customer_name,
           t.txn_type, t.amount, t.txn_date, t.description
    FROM transactions t
    JOIN account a ON a.account_id=t.account_id
    JOIN customer c ON c.customer_id=a.customer_id
    ORDER BY t.txn_date DESC, t.txn_id DESC
    LIMIT 25
")->fetchAll();

$loans = $pdo->query("
    SELECT l.loan_id, CONCAT(c.first_name,' ',c.last_name) AS customer_name,
           l.loan_type, l.principal, l.interest_rate,
           l.tenure_months, l.status
    FROM loan l
    JOIN customer c ON c.customer_id=l.customer_id
    ORDER BY l.loan_id
")->fetchAll();

$branches = $pdo->query("
    SELECT branch_name, city, ifsc_code,
           (SELECT COUNT(*) FROM account a WHERE a.branch_id=b.branch_id) AS accounts
    FROM branch b ORDER BY branch_id
")->fetchAll();

$recent = array_slice($transactions, 0, 8);
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BankSphere - Banking Management System</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div class="layout">
    <aside class="sidebar">
        <div class="brand">🏦 BankSphere</div>
        <div class="sub">Banking & Financial Transaction Management</div>
        <nav>
            <a class="<?= $page==='dashboard'?'active':'' ?>" href="?page=dashboard">Dashboard</a>
            <a class="<?= $page==='customers'?'active':'' ?>" href="?page=customers">Customers</a>
            <a class="<?= $page==='accounts'?'active':'' ?>" href="?page=accounts">Accounts</a>
            <a class="<?= $page==='transactions'?'active':'' ?>" href="?page=transactions">Transactions</a>
            <a class="<?= $page==='loans'?'active':'' ?>" href="?page=loans">Loans</a>
            <a class="<?= $page==='transfer'?'active':'' ?>" href="?page=transfer">Fund Transfer</a>
            <a class="<?= $page==='branches'?'active':'' ?>" href="?page=branches">Branches</a>
        </nav>
        <div class="side-note">Uses the original <b>bank_db</b> database and its existing tables, views and transfer procedure.</div>
    </aside>

    <main class="main">
        <header>
            <div>
                <h1><?= htmlspecialchars(ucfirst($page)) ?></h1>
                <p>Simple frontend for your original DBMS capstone database.</p>
            </div>
            <span class="status">● Database Connected</span>
        </header>

        <?php if ($message): ?><div class="alert success"><?= htmlspecialchars($message) ?></div><?php endif; ?>
        <?php if ($error): ?><div class="alert error"><?= htmlspecialchars($error) ?></div><?php endif; ?>

        <?php if ($page === 'dashboard'): ?>
            <section class="cards">
                <div class="card"><span>Customers</span><strong><?= $totalCustomers ?></strong></div>
                <div class="card"><span>Accounts</span><strong><?= $totalAccounts ?></strong></div>
                <div class="card"><span>Total Balance</span><strong><?= money($totalBalance) ?></strong></div>
                <div class="card"><span>Loans</span><strong><?= $totalLoans ?></strong></div>
            </section>

            <div class="grid2">
                <section class="panel">
                    <h2>Recent Transactions</h2>
                    <div class="table-wrap"><table>
                        <tr><th>Date</th><th>Account</th><th>Type</th><th>Amount</th></tr>
                        <?php foreach ($recent as $r): ?>
                        <tr>
                            <td><?= htmlspecialchars($r['txn_date']) ?></td>
                            <td><?= htmlspecialchars($r['account_no']) ?></td>
                            <td><span class="badge"><?= htmlspecialchars($r['txn_type']) ?></span></td>
                            <td><?= money($r['amount']) ?></td>
                        </tr>
                        <?php endforeach; ?>
                    </table></div>
                </section>
                <section class="panel">
                    <h2>Bank Summary</h2>
                    <div class="summary">
                        <div><span>Transactions</span><b><?= $totalTransactions ?></b></div>
                        <div><span>Branches</span><b><?= count($branches) ?></b></div>
                        <div><span>Active Accounts</span><b><?= count(array_filter($accounts, fn($a)=>$a['status']==='ACTIVE')) ?></b></div>
                        <div><span>Approved Loans</span><b><?= count(array_filter($loans, fn($l)=>$l['status']==='APPROVED')) ?></b></div>
                    </div>
                </section>
            </div>

        <?php elseif ($page === 'customers'): ?>
            <section class="panel"><h2>Customer Details</h2><div class="table-wrap"><table>
                <tr><th>ID</th><th>Name</th><th>Email</th><th>Phone</th><th>City</th><th>KYC</th></tr>
                <?php foreach ($customers as $c): ?>
                <tr><td><?= $c['customer_id'] ?></td><td><?= htmlspecialchars($c['customer_name']) ?></td>
                <td><?= htmlspecialchars($c['email']) ?></td><td><?= htmlspecialchars($c['phone']) ?></td>
                <td><?= htmlspecialchars($c['city']) ?></td><td><span class="badge"><?= $c['kyc_status'] ?></span></td></tr>
                <?php endforeach; ?>
            </table></div></section>

        <?php elseif ($page === 'accounts'): ?>
            <section class="panel"><h2>Accounts</h2><div class="table-wrap"><table>
                <tr><th>Account No.</th><th>Customer</th><th>Branch</th><th>Type</th><th>Balance</th><th>Status</th></tr>
                <?php foreach ($accounts as $a): ?>
                <tr><td><?= htmlspecialchars($a['account_no']) ?></td><td><?= htmlspecialchars($a['customer_name']) ?></td>
                <td><?= htmlspecialchars($a['branch_name']) ?></td><td><?= $a['account_type'] ?></td>
                <td class="amount"><?= money($a['balance']) ?></td><td><span class="badge"><?= $a['status'] ?></span></td></tr>
                <?php endforeach; ?>
            </table></div></section>

        <?php elseif ($page === 'transactions'): ?>
            <section class="panel"><h2>Latest 25 Transactions</h2><div class="table-wrap"><table>
                <tr><th>ID</th><th>Date</th><th>Account</th><th>Customer</th><th>Type</th><th>Amount</th><th>Description</th></tr>
                <?php foreach ($transactions as $t): ?>
                <tr><td><?= $t['txn_id'] ?></td><td><?= htmlspecialchars($t['txn_date']) ?></td>
                <td><?= htmlspecialchars($t['account_no']) ?></td><td><?= htmlspecialchars($t['customer_name']) ?></td>
                <td><span class="badge"><?= $t['txn_type'] ?></span></td><td><?= money($t['amount']) ?></td>
                <td><?= htmlspecialchars($t['description'] ?? '') ?></td></tr>
                <?php endforeach; ?>
            </table></div></section>

        <?php elseif ($page === 'loans'): ?>
            <section class="panel"><h2>Loans</h2><div class="table-wrap"><table>
                <tr><th>ID</th><th>Customer</th><th>Type</th><th>Principal</th><th>Interest</th><th>Tenure</th><th>Status</th></tr>
                <?php foreach ($loans as $l): ?>
                <tr><td><?= $l['loan_id'] ?></td><td><?= htmlspecialchars($l['customer_name']) ?></td>
                <td><?= $l['loan_type'] ?></td><td><?= money($l['principal']) ?></td>
                <td><?= $l['interest_rate'] ?>%</td><td><?= $l['tenure_months'] ?> months</td>
                <td><span class="badge"><?= $l['status'] ?></span></td></tr>
                <?php endforeach; ?>
            </table></div></section>

        <?php elseif ($page === 'transfer'): ?>
            <section class="panel form-panel">
                <h2>Transfer Money</h2>
                <p>This uses the original stored procedure <b>sp_fund_transfer</b>.</p>
                <form method="post">
                    <input type="hidden" name="action" value="transfer">
                    <label>From Account</label>
                    <select name="from_account" required>
                        <option value="">Select account</option>
                        <?php foreach ($accounts as $a): if ($a['status']==='ACTIVE'): ?>
                            <option value="<?= htmlspecialchars($a['account_no']) ?>"><?= htmlspecialchars($a['account_no']) ?> — <?= htmlspecialchars($a['customer_name']) ?> — <?= money($a['balance']) ?></option>
                        <?php endif; endforeach; ?>
                    </select>
                    <label>To Account</label>
                    <select name="to_account" required>
                        <option value="">Select account</option>
                        <?php foreach ($accounts as $a): if ($a['status']==='ACTIVE'): ?>
                            <option value="<?= htmlspecialchars($a['account_no']) ?>"><?= htmlspecialchars($a['account_no']) ?> — <?= htmlspecialchars($a['customer_name']) ?></option>
                        <?php endif; endforeach; ?>
                    </select>
                    <label>Amount (₹)</label>
                    <input type="number" name="amount" min="1" step="0.01" required>
                    <button type="submit">Transfer Money</button>
                </form>
            </section>

        <?php elseif ($page === 'branches'): ?>
            <section class="panel"><h2>Branches</h2><div class="table-wrap"><table>
                <tr><th>Branch</th><th>City</th><th>IFSC</th><th>Accounts</th></tr>
                <?php foreach ($branches as $b): ?>
                <tr><td><?= htmlspecialchars($b['branch_name']) ?></td><td><?= htmlspecialchars($b['city']) ?></td>
                <td><?= htmlspecialchars($b['ifsc_code']) ?></td><td><?= $b['accounts'] ?></td></tr>
                <?php endforeach; ?>
            </table></div></section>
        <?php endif; ?>

        <footer>BankSphere • K.R. Mangalam University • DBMS Capstone</footer>
    </main>
</div>
</body>
</html>
