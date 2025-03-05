<?php declare(strict_types=1);

require "./PrismClient.php";

$client = new PrismClient("127.0.0.1", 6969);
$client->sendLoginRequest("default_service", "default_token",
    function ($message) {
        echo "Success Login: $message\n";
    },
    function ($error) {
        echo "Error: $error\n";
    }
);
$client->sendUpdateRequest("test", "1", "kills", true,
    function ($message) {
        echo "Success Update: $message\n";
    },
    function ($error) {
        echo "Error: $error\n";
    }
);

$client->loop();

$client->close();
