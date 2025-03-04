<?php

require 'vendor/autoload.php';
require 'Login.php';
require 'Update.php';
require 'DataPacket.php';

const IV_LENGTH = 12;
const TAG_LENGTH = 16;

final class PacketType {
    public const DATA = 1;
    public const ACK = 2;
    public const NACK = 3;
}

class Security {
    private static $key = "secret-auth-key-123=============";

    public static function encryptData($plaintext) {
        $iv = random_bytes(IV_LENGTH);
        $tag = "";
        $ciphertext = openssl_encrypt($plaintext, "aes-256-gcm", self::$key, OPENSSL_RAW_DATA, $iv, $tag, "", TAG_LENGTH);
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
    }

    public function loop() {
        while (true) {
            $buffer = "";
            $from = "";
            $port = 0;
            @socket_recvfrom($this->socket, $buffer, 1024, 64, $from, $port);
            usleep(100000);
        }
    }

    public function sendLoginRequest($service, $token, callable $resolve, callable $reject) {
        $loginPacket = new Login();
        $loginPacket->setService($service);
        $loginPacket->setToken($token);
        
        $data = $loginPacket->serializeToString();
        [$iv, $ciphertext, $tag] = Security::encryptData($data);

        $seq = random_int(0, 0xffffffff);
        $header = str_repeat("\0", 9);
        $header = $this->pack($header, "C", 1, 0);
        $header = $this->pack($header, "N", $seq, 1);
        $checksum = crc32($header . $data);
        $header = $this->pack($header, "N", $checksum, 5);

        $packet = $header . $iv . $ciphertext . $tag;

        $this->pendingAcks[$seq] = [$resolve, $reject];

        socket_sendto($this->socket, $packet, strlen($packet), 0, $this->host, $this->port);

        $this->waitForAck($seq);
    }

    public function sendUpdateRequest($name, $value, $type, bool $persistRedis, callable $resolve, callable $reject) {
        $update = new Update([
            "name" => $name,
            "value" => $value,
            "type" => $type,
            // "persist_redis" => $persistRedis
        ]);
        $dataPacket = new DataPacket([
            "type" => 4,
            "update" => $update,
        ]);

        $data = $dataPacket->serializeToString();
        [$iv, $ciphertext, $tag] = Security::encryptData($data);

        $seq = random_int(0, 0xffffffff);
        $header = str_repeat("\0", 9);
        $header = $this->pack($header, "C", PacketType::DATA, 0);
        $header = $this->pack($header, "N", $seq, 1);
        $checksum = crc32($header . $data);
        $header = $this->pack($header, "N", $checksum, 5);

        $packet = $header . $iv . $ciphertext . $tag;

        $this->pendingAcks[$seq] = [$resolve, $reject];

        socket_sendto($this->socket, $packet, strlen($packet), 0, $this->host, $this->port);

        $this->waitForAck($seq);
    }

    private function waitForAck($seq) {
        while (true) {
            $buffer = "";
            $from = "";
            $port = 0;

            $recv = @socket_recvfrom($this->socket, $buffer, 1024, 0, $from, $port);
            if ($recv !== false) {
                if (strlen($buffer) < IV_LENGTH + TAG_LENGTH + 9) {
                    $data = unpack("C*", $buffer);
                    if ($data[1] == PacketType::ACK) {
                        $this->handleAckPacket($data);
                        return;
                    }
                } else {
                    $iv = substr($buffer, 0, IV_LENGTH);
                    $ciphertext = substr($buffer, IV_LENGTH, strlen($buffer) - TAG_LENGTH - IV_LENGTH);
                    $tag = substr($buffer, strlen($buffer) - TAG_LENGTH);

                    if (strlen($iv) !== IV_LENGTH || strlen($tag) !== TAG_LENGTH) {
                        echo "Invalid IV or tag length\n";
                        continue;
                    }

                    $dec = Security::decryptData($iv, $ciphertext, $tag);
                    if ($dec === false) {
                        echo "Failed to decrypt data\n";
                        continue;
                    }
                    $data = unpack("C*", $dec);
                    if ($data[1] == PacketType::DATA) {
                        $this->handleDataPacket($data, $from);
                    }
                }
            } else {
                usleep(100000);
            }
        }

        if (isset($this->pendingAcks[$seq])) {
            [$resolve, $reject] = $this->pendingAcks[$seq];
            unset($this->pendingAcks[$seq]);
            $reject("No ACK received for seqNum: $seq");
        }
    }

    private function handleDataPacket($buffer, $from) {
        $toStr = pack("C*", ...$buffer);
        $seq = unpack("N", substr($toStr, 1, 4))[1];
        $checksum = unpack("N", substr($toStr, 5, 4))[1];
        $data = substr($toStr, 9);

        if ($checksum !== crc32($data)) {
            echo "Invalid checksum\n";
            return;
        }

        $ackPacket = str_repeat("\0", 5);
        $ackPacket = $this->pack($ackPacket, "C", PacketType::ACK, 0);
        $ackPacket = $this->pack($ackPacket, "N", $seq, 1);
        socket_sendto($this->socket, $ackPacket, strlen($ackPacket), 0, $from, $this->port);
    }

    private function handleAckPacket(array $buffer) {
        $toStr = pack("C*", ...$buffer);
        $seq = unpack("N", substr($toStr, 1, 4))[1];

        if (isset($this->pendingAcks[$seq])) {
            [$resolve, $reject] = $this->pendingAcks[$seq];
            unset($this->pendingAcks[$seq]);
            $resolve("ACK received for seqNum: $seq");
        } else {
            echo "Received ACK for unknown seqNum: $seq\n";
        }
    }

    public function close() {
        socket_close($this->socket);
    }

    public function pack($buffer, $format, $data, $offset = 0): string {
        $packedData = pack($format, $data);
        return substr_replace($buffer, $packedData, $offset, strlen($packedData));
    }
}

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
