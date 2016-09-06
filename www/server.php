<?php
    require_once('wp-config.php');

    // Create connection
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
    // Check connection
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }

    $sql = "SHOW VARIABLES WHERE Variable_name = 'hostname'";
    $result = $conn->query($sql);
    $data = $result->fetch_assoc();

?>
<h1>Server Connection Information</h1>
<ul>
    <li>
        Web Server: <?=$_SERVER['SERVER_ADDR'];?>
    </li>
    <li>
        DB Hostname: <?=$data['Value'];?>
    </li>
</ul>