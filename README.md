<img height="128" alt="image" src="./assets/logo.jpg" align="right">

# Prism

A simple, fast, and distributed data broker for clustered server use.

## Purpose

The typical problem with distributed servers is encountering the three main issues:
- The server typically has to rely on a central DB server (which adds latency to farther regions)
- A server that does use distributed DBs needs to handle synchronization between the DBs (which is hard to do correctly)
- Database mutations and queries are typically slow and asynchronous operations are difficult to implement correctly

Thus, the solution is to use a broker to extract all the database logic. However, we want a distributed broker
so that we are able to limit latency but also have some way to handle synchronization between the brokers.

## Architecture

![Architecture](/assets/diagram.png)

## Features/Development

- `Net.Server` - central server to handle all UDP traffic
- `Net.Manager` - central manager to handle all connections
- `Net.Conn` - connection struct to store connection info
- `Net.Packet` - Protobuf packets to handle all the different packet types
- `Net.Cluster` - functions to connect to other nodes and broadcast updates (via OTP)
- `Net.Reliablity` - enforces reliablity on all packets as well as handling retries
- `Net.Security` - utilizes AES to encrypt and decrypt incoming packets


## Current Status

- [x] Basic UDP server
- [x] Basic packet handling
- [x] Basic cluster connection
- [x] Finish packet layer
- [x] Add service authentication
- [x] Implemented security via AES encryption
- [ ] Add database connection and redis connection
- [x] Add proper regional handling
- [ ] Find a way to combat synchronization issues (few will arise because of Cluster implementation)
- [x] Add better logging