<?php
// user_page.php
session_start();
if (!isset($_SESSION['email'])) {
    header("Location: index.php");
    exit();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>User Dashboard</title>
  <link rel="stylesheet" href="style.css">
  <style>
    .dashboard { margin:30px auto; max-width:800px; text-align:center; }
    .dashboard a {
      display:block; margin:10px auto;
      padding:12px; width:300px;
      background:#7494ec; color:#fff;
      text-decoration:none; border-radius:6px;
    }
    .dashboard a:hover { background:#6884d3; }
    h1 span { color:#7494ec; }
  </style>
</head>
<body>
  <div class="box">
    <h1>Welcome, <span><?= htmlspecialchars($_SESSION['name']) ?></span></h1>
    <div class="dashboard">
      <a href="booking.php">Ticket Booking</a>
      <a href="schedule.php">Train Schedule</a>
      <a href="pnr_status.php">PNR Status</a>
      <a href="ticket.php">My Tickets</a>
      <a href="cancellation.php">Cancellation</a>
      <a href="refund.php">Refunds</a>
      <a href="queries.php">Queries</a>
      <a href="logout.php">Logout</a>
    </div>
  </div>
</body>
</html>
