<?php
// booking.php
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
  <title>Book Ticket</title>
  <link rel="stylesheet" href="style.css">
  <script src="script.js"></script>
</head>
<body>
  <h2>Ticket Booking</h2>
  <p>
    <a href="user_page.php">← Dashboard</a> |
    <a href="logout.php">Logout</a>
  </p>

  <?php
  // STEP 1: Show search form
  if (!isset($_POST['search']) && !isset($_POST['book_train']) && !isset($_POST['confirm_booking'])):
  ?>
    <form method="post">
      <label>From Station:</label>
      <input type="text" name="from" required>

      <label>To Station:</label>
      <input type="text" name="to" required>

      <label>Journey Date:</label>
      <input type="date" name="date" required>

      <button type="submit" name="search">Search Trains</button>
    </form>
  <?php
  endif;

  // STEP 2: Display matching trains
  if (isset($_POST['search'])) {
    $from = $_POST['from'];
    $to   = $_POST['to'];
    $date = $_POST['date'];

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
      echo "<h3>Trains on {$date}</h3>
            <form method='post'>
              <input type='hidden' name='from' value='".htmlspecialchars($from)."'>
              <input type='hidden' name='to'   value='".htmlspecialchars($to)."'>
              <input type='hidden' name='date' value='{$date}'>
              <table>
                <tr>
                  <th>ID</th><th>Name</th><th>Depart</th><th>Arrive</th><th>Book</th>
                </tr>";
      while ($r = $res->fetch_assoc()) {
        echo "<tr>
                <td>{$r['trainid']}</td>
                <td>".htmlspecialchars($r['train_name'])."</td>
                <td>{$r['depart']}</td>
                <td>{$r['arrive']}</td>
                <td>
                  <button type='submit'
                          name='book_train'
                          value='{$r['trainid']}'>
                    Select
                  </button>
                </td>
              </tr>";
      }
      echo "  </table>
            </form>";
    } else {
      echo "<p>No trains found from <b>".htmlspecialchars($from)."</b> to <b>".htmlspecialchars($to)."</b> on {$date}.</p>";
    }
  }

  // STEP 3: Passenger & payment form
  if (isset($_POST['book_train'])):
    $trainid = (int)$_POST['book_train'];
    $from    = $_POST['from'];
    $to      = $_POST['to'];
    $date    = $_POST['date'];
  ?>
    <h3>Passenger Details & Payment</h3>
    <form method="post">
      <input type="hidden" name="trainid" value="<?= $trainid ?>">
      <input type="hidden" name="from"    value="<?= htmlspecialchars($from) ?>">
      <input type="hidden" name="to"      value="<?= htmlspecialchars($to) ?>">
      <input type="hidden" name="date"    value="<?= $date ?>">

      <label>Class:</label>
      <select name="p_class" required>
        <option value="sleeper">Sleeper</option>
        <option value="3ac">3AC</option>
        <option value="2ac">2AC</option>
        <option value="firstclass">First Class</option>
      </select>

      <label>Passenger Name:</label>
      <input type="text" name="p_name" required>

      <label>Email:</label>
      <input type="email" name="p_email"
             value="<?= htmlspecialchars($_SESSION['email']) ?>"
             readonly>

      <label>Concession:</label>
      <select name="p_concession" required>
        <option value="none">None</option>
        <option value="student">Student (20% off)</option>
        <option value="senior citizen">Senior (40% off)</option>
        <option value="disabled">Disabled (60% off)</option>
      </select>

      <button type="submit" name="confirm_booking">
        Confirm &amp; Book
      </button>
    </form>
  <?php
  endif;

  // STEP 4: Execute booking stored procedure
  if (isset($_POST['confirm_booking'])) {
    $userid  = $_SESSION['userid'];
    $trainid = (int)$_POST['trainid'];
    $class   = $_POST['p_class'];
    $from    = $_POST['from'];
    $to      = $_POST['to'];
    $pname   = $_POST['p_name'];
    $pemail  = $_POST['p_email'];
    $con     = $_POST['p_concession'];

    $stmt = $conn->prepare("CALL book_ticket(?,?,?,?,?,?,?,?)");
    $stmt->bind_param(
      'iissssss',
      $userid, $trainid, $class, $from, $to,
      $pname, $pemail, $con
    );
    $stmt->execute();
    $res = $stmt->get_result();
    if ($row = $res->fetch_assoc()) {
      echo "<h3>Booking Successful!</h3>
            <p>PNR: <b>{$row['BookingPNR']}</b><br>
            Amount Paid: ₹{$row['Amount']}</p>";
    } else {
      echo "<p class='error-message'>Booking failed. Please try again.</p>";
    }
  }
  ?>
</body>
</html>
