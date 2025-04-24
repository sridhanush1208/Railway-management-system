<?php
// ticket.php
session_start();
if (!isset($_SESSION['userid'])) header("Location: index.php");
require_once 'config.php';
$uid = $_SESSION['userid'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>My Tickets</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <h2>My Reservations</h2>
  <p><a href="user_page.php">← Dashboard</a></p>

<?php
$sql = "
  SELECT 'Confirmed' AS category, pnr, trainid, class, from_station, to_station, status, amount, seat_no AS seat, coach_no AS coach
    FROM tickets WHERE userid=?
  UNION ALL
  SELECT 'RAC', pnr, trainid, class, from_station, to_station, status, amount, rac_no, NULL
    FROM rac WHERE userid=?
  UNION ALL
  SELECT 'Waiting', pnr, trainid, class, from_station, to_station, status, amount, waiting_list_no, NULL
    FROM waiting_list WHERE userid=?
";
$stmt = $conn->prepare($sql);
$stmt->bind_param('iii', $uid, $uid, $uid);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows) {
    echo "<table>
            <tr>
              <th>Cat</th><th>PNR</th><th>Train</th><th>Class</th>
              <th>From</th><th>To</th><th>Status</th><th>Amt</th>
              <th>Seat</th><th>Coach</th>
            </tr>";
    while ($r = $res->fetch_assoc()) {
        echo "<tr>
                <td>{$r['category']}</td>
                <td>{$r['pnr']}</td>
                <td>{$r['trainid']}</td>
                <td>{$r['class']}</td>
                <td>{$r['from_station']}</td>
                <td>{$r['to_station']}</td>
                <td>{$r['status']}</td>
                <td>{$r['amount']}</td>
                <td>".($r['seat'] ?? '—')."</td>
                <td>".($r['coach'] ?? '—')."</td>
              </tr>";
    }
    echo "</table>";
} else {
    echo "<p>No reservations found.</p>";
}
?>
</body>
</html>
