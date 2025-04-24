<?php
// schedule.php
session_start();
if (!isset($_SESSION['userid'])) {
    header("Location: index.php");
    exit();
}
require_once 'config.php';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Train Schedule Lookup</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <h2>Train Schedule Lookup</h2>
  <p><a href="user_page.php">← Dashboard</a></p>

  <form method="post">
    <label>From Station:</label>
    <input type="text" name="from" required>

    <label>To Station:</label>
    <input type="text" name="to" required>

    <button type="submit" name="lookup">Lookup</button>
  </form>

  <?php
  if (isset($_POST['lookup'])) {
    $from = $_POST['from'];
    $to   = $_POST['to'];

    $sql = "
      SELECT
        t.trainid,
        t.train_name,
        s1.departure_time AS depart,
        s2.arrival_time   AS arrive
      FROM route_stops s1
      JOIN routes      r  ON r.routeid = s1.routeid
      JOIN trains      t  ON t.trainid = r.trainid
      JOIN route_stops s2 ON s2.routeid = r.routeid
                         AND s2.stop_order > s1.stop_order
     WHERE s1.station_name = ?
       AND s2.station_name = ?
     GROUP BY t.trainid
    ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('ss', $from, $to);
    $stmt->execute();
    $res = $stmt->get_result();

    if ($res->num_rows) {
      echo "<table>
              <tr>
                <th>ID</th><th>Name</th><th>Depart</th><th>Arrive</th>
              </tr>";
      while ($r = $res->fetch_assoc()) {
        echo "<tr>
                <td>{$r['trainid']}</td>
                <td>".htmlspecialchars($r['train_name'])."</td>
                <td>{$r['depart']}</td>
                <td>{$r['arrive']}</td>
              </tr>";
      }
      echo "</table>";
    } else {
      echo "<p>No matching trains for that route.</p>";
    }
  }
  ?>
</body>
</html>
