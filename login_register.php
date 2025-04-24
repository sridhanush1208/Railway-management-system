<?php
// login_register.php
session_start();
require_once 'config.php';

if (isset($_POST['register'])) {
    $name  = $conn->real_escape_string($_POST['name']);
    $email = $conn->real_escape_string($_POST['email']);
    $pass  = password_hash($_POST['password'], PASSWORD_DEFAULT);
    $role  = $conn->real_escape_string($_POST['role']);

    $check = $conn->query("SELECT 1 FROM users WHERE email='$email'");
    if ($check->num_rows) {
        $_SESSION['register_error']  = 'Email is already registered!';
        $_SESSION['active_form']     = 'register';
    } else {
        $conn->query(
            "INSERT INTO users (name, email, password, role)
             VALUES ('$name','$email','$pass','$role')"
        );
    }
    header("Location: index.php");
    exit();
}

if (isset($_POST['login'])) {
    $email = $conn->real_escape_string($_POST['email']);
    $pass  = $_POST['password'];

    $res = $conn->query("SELECT * FROM users WHERE email='$email'");
    if ($res->num_rows) {
        $user = $res->fetch_assoc();
        if (password_verify($pass, $user['password'])) {
            $_SESSION['name']   = $user['name'];
            $_SESSION['email']  = $user['email'];
            $_SESSION['userid'] = $user['userid'];

            if ($user['role'] === 'user') {
                header("Location: user_page.php");
                exit();
            }
        }
    }
    $_SESSION['login_error']  = 'Incorrect email or password';
    $_SESSION['active_form']  = 'login';
    header("Location: index.php");
    exit();
}
?>
