<?php
// cancellation.php
session_start();
if (!isset($_SESSION['userid'])) header("Location: index.php");
require_once 'config.php';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Cancel Ticket</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <h2>Cancel Reservation</h2>
  <p><a href="user_page.php">← Dashboard</a></p>

  <form method="post">
    <label>PNR to Cancel:</label>
    <input type="text" name="pnr" required>
    <button type="submit" name="cancel">Cancel Ticket</button>
  </form>

<?php
if (isset($_POST['cancel'])) {
    $pnr = $_POST['pnr'];
    $stmt = $conn->prepare("CALL cancel_ticket(?)");
    $stmt->bind_param('s', $pnr);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($row = $res->fetch_assoc()) {
        echo "<p>{$row['Result']}</p>";
    } else {
        echo "<p class='error-message'>Cancellation failed. Check PNR.</p>";
    }
}
?>
</body>
</html>
