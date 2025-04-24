<?php
// refund.php
session_start();
if (!isset($_SESSION['userid'])) header("Location: index.php");
require_once 'config.php';
$uid = $_SESSION['userid'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>My Refunds</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <h2>Refund History</h2>
  <p><a href="user_page.php">← Dashboard</a></p>

<?php
$sql = "
  SELECT r.pnr, r.trainid, r.refund_amount, r.created_at
    FROM refund r
   WHERE r.userid = ?
";
$stmt = $conn->prepare($sql);
$stmt->bind_param('i', $uid);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows) {
    echo "<table>
            <tr>
              <th>PNR</th><th>Train</th><th>Amount</th><th>Date</th>
            </tr>";
    while ($r = $res->fetch_assoc()) {
        echo "<tr>
                <td>{$r['pnr']}</td>
                <td>{$r['trainid']}</td>
                <td>₹{$r['refund_amount']}</td>
                <td>{$r['created_at']}</td>
              </tr>";
    }
    echo "</table>";
} else {
    echo "<p>No refunds found.</p>";
}
?>
</body>
</html>
