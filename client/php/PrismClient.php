<?php

require 'vendor/autoload.php';
require './proto/Login.php';

class Security {
    private static $key = "secret-auth-key-123=============";

    public static function encryptData($plaintext) {
        $iv = random_bytes(12);
        $tag = "";
        $ciphertext = openssl_encrypt($plaintext, "aes-256-gcm", self::$key, OPENSSL_RAW_DATA, $iv, $tag, "", 16);
        return [$iv, $ciphertext, $tag];
    }

    public static function decryptData($iv, $ciphertext, $tag) {
        return openssl_decrypt($ciphertext, "aes-256-gcm", self::$key, OPENSSL_RAW_DATA, $iv, $tag);
    }
}

class PrismClient {
    private $socket;
    private $host;
    private $port;
    private $pendingAcks;

    public function __construct($host, $port) {
        $this->host = $host;
        $this->port = $port;
        $this->pendingAcks = [];

        $this->socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
        socket_set_option($this->socket, SOL_SOCKET, SO_RCVTIMEO, ["sec" => 2, "usec" => 0]);
    }

    public function sendLoginRequest($service, $token) {
        $loginPacket = new Login();
        $loginPacket->setService($service);
        $loginPacket->setToken($token);
        
        $data = $loginPacket->serializeToString();
        [$iv, $ciphertext, $tag] = Security::encryptData($data);

        $seq = random_int(0, 0xffffffff);
        $header = $this->pack("C", 1, 0) . $this->pack("N", 1000, 1);
        $checksum = crc32($header . $data);
        $header .= $this->pack("N", $checksum, 5);


        $packet = $header . $iv . $ciphertext . $tag;
        $this->pendingAcks[$seq] = true;

        socket_sendto($this->socket, $packet, strlen($packet), 0, $this->host, $this->port);

        $this->waitForAck($seq);
    }

    private function waitForAck($seq) {
        $buffer = "";
        $from = "";
        $port = 0;

        while (socket_recvfrom($this->socket, $buffer, 1024, 0, $from, $port) !== false) {
            if (strlen($buffer) < 5) {
                continue;
            }

            $type = ord($buffer[0]);
            $recvSeq = unpack("N", substr($buffer, 1, 4))[1];

            if ($type == 1 && isset($this->pendingAcks[$recvSeq])) { // ACK Packet Type: 1
                unset($this->pendingAcks[$recvSeq]);
                echo "Received ACK for seqNum: $recvSeq\n";
                return;
            }
        }

        echo "No ACK received for seqNum: $seq\n";
    }

    public function close() {
        socket_close($this->socket);
    }

    public function pack($format, $data, $offset = 0) {
        $packed = str_repeat("\0", $offset);

        if (is_array($data)) {
            $buffer = pack($format, ...$data);
        } else {
            $buffer = pack($format, $data);
        }

        return $packed . $buffer;
    }
}

$client = new PrismClient("127.0.0.1", 6969); // Replace with correct port
$client->sendLoginRequest("default_service", "default_token");
$client->close();
