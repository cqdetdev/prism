const socket = await Bun.connect({
    hostname: "localhost",
    port: 6969,
  
    socket: {
      data(socket, data) {
        console.log(data.toString());
      },
      open(socket) {
        socket.write("Hello, world!\n");
      },
      close(socket) {},
      drain(socket) {},
      error(socket, error) {},
  
      // client-specific handlers
      connectError(socket, error) {}, // connection failed
      end(socket) {}, // connection closed by server
      timeout(socket) {}, // connection timed out
    },
  });