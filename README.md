# WebSocketChatServer

A wrapper class for em-websocket (https://github.com/igrigorik/em-websocket) implementing a custom chat server protocol.


![alt tag](http://abulewis.com/ws/wscs.png)

## Installation

Type this in the console:

```
$ gem install web_socket_chat_server
```

## Documentation
For better understanding, check the docs at http://abulewis.com/ws/doc/WebSocketChatServer/ChatServer.html
## Usage

An example on how to run the server:

```ruby
require "web_socket_chat_server.rb"

admin1 = WebSocketChatServer::ChatUser.new(:username => "admin", :password => "secret")
admin2 = WebSocketChatServer::ChatUser.new(:username => "admin2", :password => "secret2")
admins = []
admins << admin1
admins << admin2

chat = WebSocketChatServer::ChatServer.new(:host=> "0.0.0.0", :port => "8080", :admins => admins)

chat.start_server do |response|
puts response
end

['TERM', 'INT'].each do |signal|
trap(signal){ 
chat.stop_server()
}
end

puts "Running..........."
wait = gets
```

The code above creates an array consisting of two admins (ChatUser objects) and passes them to initialize(). The server will listen on IP 0.0.0.0 and the port 8080 (Required parameters). 

By running the code above, you do not need to do any other things. The class takes care of the of itself by handling the connections and the logic of the server’s custom protocol. You still though have the opportunity to print out the commands generated by the server by passing a block to the start_server() function as it has been done above.

On the client side, use the HTML WebSocket API to connect to the server. An example on a fully working Chat client will be attached to this repo (CHAT_CLIENT_EXAMPLE). 

To explain how to connect to the server briefly:

You have to pass the query parameters username & password to the socket client when connecting. 

On successful connection, you can send a JSON hash of the format {command: ”…”, data: ”…}

### Available client commands are:
```
{command: ”chat_message”, data: ”your message”}

{command: ”private_message”, data: {to_user:  ”chuck_norris”, message: ”Private message”}}

{command: ”ban_user”, data: ”chuck_norris”}
```

The server will respond with a JSON hash of the format {command: ”…”, data: ”…”, information: ”…”}

### Available server responses are:
```
{command: ”failed_connection”, data: nil, information: ”Some details”}

{command: ”successful_connection”, data: array_of_connected_users, information: ”Some details”}

{command: ”new_connection”, data: username, information: ”A new connected user”}

{command: ”chat_message”, data: {from_user: ”chuck_norris”, message: ”The message”}, information: ”Some details.”}

{command: ”ban_user”, data: boolean, information: ”Some details.”}

{command: ”private_message”, data: {from_user: ”chuck_norris”, message: ”The message”}, information: ”Some details.”}

{command: ”system_information”, data: ”Issue”, information: ”Some details.”}

{command: ”user_disconnected”, data: ”username”, information: ”Some details.”}
```

### Want to write the client in JS?
Use the demo attached to this repository or check this out http://abulewis.com/blog/writing-a-wrapper-websocket-client-class-in-js/
