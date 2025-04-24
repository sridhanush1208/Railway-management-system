<?php
// queries.php
session_start();
if (!isset($_SESSION['userid'])) {
    header("Location: index.php");
    exit();
}
require_once 'config.php';

function render_table($res) {
    if (!$res || !$res->num_rows) return;
    echo "<table><tr>";
    foreach ($res->fetch_fields() as $f) {
        echo "<th>{$f->name}</th>";
    }
    echo "</tr>";
    $res->data_seek(0);
    while ($row = $res->fetch_assoc()) {
        echo "<tr>";
        foreach ($row as $c) {
            echo "<td>".htmlspecialchars($c)."</td>";
        }
        echo "</tr>";
    }
    echo "</table>";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Ad-hoc Queries</title>
  <link rel="stylesheet" href="style.css">
  <script src="script.js"></script>
</head>
<body>
  <h2>Predefined & Custom Queries</h2>
  <p><a href="user_page.php">← Dashboard</a></p>

  <label>Choose Query:</label>
  <select id="queryType" onchange="showQueryForm()">
    <option value="">--Select--</option>
    <option value="pnr_status">PNR Status</option>
    <option value="schedule_train">Train Schedule</option>
    <option value="available_seats">Available Seats</option>
    <option value="passengers_train">Passengers on Train</option>
    <option value="waitlist_train">Waiting List</option>
    <option value="total_refund_train">Total Refund</option>
    <option value="revenue_period">Revenue in Period</option>
    <option value="cancellation_records">All Refund Records</option>
    <option value="busiest_route">Busiest Route</option>
    <option value="itemized_bill">Itemized Bill</option>
    <option value="custom_sql">Custom SQL</option>
  </select>

  <!-- Query-specific forms -->
  <div id="form_pnr_status" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_pnr" placeholder="PNR" required>
      <button name="run_q" value="pnr_status">Run</button>
    </form>
  </div>

  <div id="form_schedule_train" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_trainid" placeholder="Train ID" required>
      <button name="run_q" value="schedule_train">Run</button>
    </form>
  </div>

  <div id="form_available_seats" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_trainid2" placeholder="Train ID" required>
      <select name="q_class" required>
        <option value="sleeper">Sleeper</option>
        <option value="3ac">3AC</option>
        <option value="2ac">2AC</option>
        <option value="firstclass">First Class</option>
      </select>
      <button name="run_q" value="available_seats">Run</button>
    </form>
  </div>

  <div id="form_passengers_train" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_trainid3" placeholder="Train ID" required>
      <button name="run_q" value="passengers_train">Run</button>
    </form>
  </div>

  <div id="form_waitlist_train" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_trainid4" placeholder="Train ID" required>
      <button name="run_q" value="waitlist_train">Run</button>
    </form>
  </div>

  <div id="form_total_refund_train" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_trainid5" placeholder="Train ID" required>
      <button name="run_q" value="total_refund_train">Run</button>
    </form>
  </div>

  <div id="form_revenue_period" class="queryForm" style="display:none;">
    <form method="post">
      <input type="date" name="q_from" required>
      <input type="date" name="q_to" required>
      <button name="run_q" value="revenue_period">Run</button>
    </form>
  </div>

  <div id="form_cancellation_records" class="queryForm" style="display:none;">
    <form method="post">
      <button name="run_q" value="cancellation_records">Run</button>
    </form>
  </div>

  <div id="form_busiest_route" class="queryForm" style="display:none;">
    <form method="post">
      <button name="run_q" value="busiest_route">Run</button>
    </form>
  </div>

  <div id="form_itemized_bill" class="queryForm" style="display:none;">
    <form method="post">
      <input name="q_pnr2" placeholder="PNR" required>
      <button name="run_q" value="itemized_bill">Run</button>
    </form>
  </div>

  <div id="form_custom_sql" class="queryForm" style="display:none;">
    <form method="post">
      <textarea name="q_custom" rows="4" style="width:100%" placeholder="SELECT ..."></textarea>
      <button name="run_q" value="custom_sql">Run</button>
    </form>
  </div>

  <hr>

  <?php
  if (isset($_POST['run_q'])) {
    switch ($_POST['run_q']) {
      case 'pnr_status':
        $pnr = $conn->real_escape_string($_POST['q_pnr']);
        $sql = "
          SELECT 'Confirmed' AS category, pnr, trainid, class, from_station, to_station, status, amount
            FROM tickets WHERE pnr='$pnr'
          UNION ALL
          SELECT 'RAC', pnr, trainid, class, from_station, to_station, status, amount
            FROM rac WHERE pnr='$pnr'
          UNION ALL
          SELECT 'Waiting', pnr, trainid, class, from_station, to_station, status, amount
            FROM waiting_list WHERE pnr='$pnr'
        ";
        render_table($conn->query($sql));
        break;

      case 'schedule_train':
        $tid = (int)$_POST['q_trainid'];
        $sql = "
          SELECT
            rs.stop_order,
            rs.station_name AS station,
            rs.departure_time,
            rs.arrival_time
          FROM routes r
          JOIN route_stops rs ON rs.routeid = r.routeid
          WHERE r.trainid = $tid
          ORDER BY rs.stop_order
        ";
        render_table($conn->query($sql));
        break;

      case 'available_seats':
        $tid = (int)$_POST['q_trainid2'];
        $cl  = $conn->real_escape_string($_POST['q_class']);
        $col = "available_{$cl}";
        render_table($conn->query("
          SELECT $col AS available_seats
            FROM seats
           WHERE trainid = $tid
        "));
        break;

      case 'passengers_train':
        $tid = (int)$_POST['q_trainid3'];
        render_table($conn->query("
          SELECT * FROM passengers WHERE trainid = $tid
        "));
        break;

      case 'waitlist_train':
        $tid = (int)$_POST['q_trainid4'];
        render_table($conn->query("
          SELECT * FROM waiting_list WHERE trainid = $tid
        "));
        break;

      case 'total_refund_train':
        $tid = (int)$_POST['q_trainid5'];
        render_table($conn->query("
          SELECT SUM(refund_amount) AS total_refund
            FROM refund WHERE trainid = $tid
        "));
        break;

      case 'revenue_period':
        $from = $conn->real_escape_string($_POST['q_from']);
        $to   = $conn->real_escape_string($_POST['q_to']);
        render_table($conn->query("
          SELECT SUM(amount) AS total_revenue
            FROM payment
           WHERE payment_date BETWEEN '$from' AND '$to'
        "));
        break;

      case 'cancellation_records':
        render_table($conn->query("SELECT * FROM refund"));
        break;

        case 'busiest_route':
            $sql = "
              SELECT
                pcount.trainid,
                rstr.route,
                pcount.passenger_count
              FROM (
                -- 1) count passengers per train
                SELECT trainid, COUNT(*) AS passenger_count
                  FROM passengers
                 GROUP BY trainid
              ) AS pcount
              JOIN routes r
                ON r.trainid = pcount.trainid
              JOIN (
                -- 2) build the ordered route string
                SELECT
                  routeid,
                  GROUP_CONCAT(station_name ORDER BY stop_order SEPARATOR '→') AS route
                FROM route_stops
                GROUP BY routeid
              ) AS rstr
                ON rstr.routeid = r.routeid
              ORDER BY pcount.passenger_count DESC
              LIMIT 1
            ";
            render_table($conn->query($sql));
            break;
        

      case 'itemized_bill':
        $pnr = $conn->real_escape_string($_POST['q_pnr2']);
        render_table($conn->query("
          SELECT
            t.pnr, t.trainid, t.class,
            t.from_station, t.to_station,
            t.amount   AS ticket_charge,
            p.payment_status, p.payment_date,
            IFNULL(r.refund_amount,0) AS refund_amount
          FROM tickets t
          JOIN payment p ON p.pnr    = t.pnr
          LEFT JOIN refund  r ON r.pnr = t.pnr
          WHERE t.pnr = '$pnr'
        "));
        break;

      case 'custom_sql':
        $sql = trim($_POST['q_custom']);
        if (stripos($sql, 'SELECT') === 0) {
          render_table($conn->query($sql));
        } else {
          echo "<p class='error-message'>Only SELECT queries are allowed.</p>";
        }
        break;
    }
  }
  ?>
</body>
</html>
