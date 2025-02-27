defprotocol Net.Proto do
  def start(opts)

  def send_message(conn, message)

  def receive_message(conn)
end
