# Prism: Go Client

Here is an example on how to use Prism via the built-in PHP client:

> **NOTE**: The built-in PHP client is still not 100% finished - it is still in development!



```php
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

```