require 'socket'
require "em-websocket"
require "json"
module WebSocketChatServer

# A wrapper class for em-websocket (https://github.com/igrigorik/em-websocket) implementing a custom chat server protocol. 

class ChatServer
	# An array of string containing the banned usernames. 
	attr_accessor :banned_usernames

	# The max number of allowed client connections. 
	attr_accessor :max_connections
	
	# An array of ChatUser objects representing the admins of the chat.
	attr_reader :admins
	
	# A hash containing the connected users. The key contains of the user's username and the value is a ChatUser object.
	attr_reader :connected_users
	
	# The host address.
	attr_reader :host 
	
	# The socket port to be used.
	attr_reader :port

	# The class initializer
	# ==== args
	# * +:server+ (Required) - The host of the chat server to run on.
	# * +:port+ (Required) - The port of the server.
	# * +:max_connections+ (Optional) - The max client connections allowed. If not passed, the default is 100.
	# * +:secure+ (Optional) - In case of using Secure Servers, pass true as allowed by em-websocket (https://github.com/igrigorik/em-websocket#secure-server).
	# * +:tls-options+ (Optional) - The TLS options as allowed by em-websocket (https://github.com/igrigorik/em-websocket#secure-server). 
	# * +:secure_proxy+ (Optional) - When ruinng behind a SSL proxy (https://github.com/igrigorik/em-websocket#running-behind-an-ssl-proxyterminator-like-stunnel).
	# * +:admins+ (Optional) - In order to have admins (for banning users). Pass an array of ChatUser objects to this key. The ChatUser object contains of username and password attributes. The username must consist of at least 3 alphanumeric characters. The password must at least consist of 6 alphanumeric characters. 
	# * +:allowed_origin (Optional) - Allow connections only from the passed URI. The URI should be the domain and/or port (depending on the server setup), in which your application is operating. 
	def initialize(args = {:host => "0.0.0.0", :port => 8080})
		@server_started = false
		raise ArgumentError, "The :host parameter is required" unless args.has_key?(:host)
		raise ArgumentError, "The :port parameter is required" unless args.has_key?(:port)
		raise ArgumentError, "The port value is not valid" unless valid_port?( args[:port])

		@origin = ""
		@origin = args[:allowed_origin] if args.has_key?(:allowed_origin)

		@max_connections = args[:max_connections].to_s.to_i
		@max_connections = 100 if @max_connections <= 1
		@host = args[:host]
		@port = args[:port]
		@server_started = false
		@admins = []
		@banned_usernames = []
		@connected_users = Hash.new
		
		@server_options = Hash.new
		@server_options[:host] = @host
		@server_options[:port] = @port.to_i
		@server_options[:secure] = args[:secure] if args.has_key?(:secure)
		@server_options[:tls_options] = args[:tls_options] if args.has_key?(:tls_options)
		@server_options[:secure_proxy] = args[:secure_proxy] if args.has_key?(:secure_proxy)


		if args.has_key?(:admins)
			if args[:admins].class == Array
				args[:admins].each { |chat_user|
					if chat_user.class == ChatUser
						raise RuntimeError, "The admin's username has to be at least 3 alphanumeric characters, and the password at least 6 alphanumeric characters" unless user_credentials_valid?(chat_user.username, chat_user.password)
						@admins << chat_user unless @admins.include?(chat_user)
					end
				}
			end
		end
	end

	# To start the server, call this method. It will return true if successful, false if it is already started. Otherwise, RuntimeError will be raised on errors. If giving a <b>block</b>, A hash <b>{command: "...", data: "...", information: "..."}</b> is yield. 
	def start_server()
		return false if @server_started

		begin
			Thread.new {run_server() do |response|
				yield response if block_given?
			end
		}
	rescue Exception => e
		@server_started = false
		raise RuntimeError, e.message
	end

	until @server_started
		next
	end

	@server_started
end

	# To stop the server, call this method. True if the server is stopped, false if it is already stopped. Otherwise, RuntimeError is raised on errors. 
	def stop_server()
		return false unless @server_started
		@server_started = false
		@connected_users.clear if @connected_users.count > 0
		begin
			EM::WebSocket.stop()	
		rescue Exception => e
			raise RuntimeError, e.message 
		end
		true
	end

	# Returns true if the server is started, otherwise false. 
	def started?()
		@server_started
	end

	private
	# This method will fire the eventmachine and the containing em-socket. 
	def run_server()
		@server_started = true

		EM.run do
			EM::WebSocket.run(@server_options) do |ws|
				ws.onopen { |handshake|
					begin
						unless @origin.empty?
							if @origin != handshake.origin
								ws.close
								break
							end
						end

						response = nil
						if (@connected_users.count + 1) > @max_connections
							response = create_response_json("failed_connection", nil, "The max connections limit is reached.")
							yield response if block_given?
							ws.send(response)
							ws.close
							break
						end

						username = handshake.query["username"]
						password = handshake.query["password"]
						client_ip = Socket.unpack_sockaddr_in(ws.get_peername)[1]
						user = ChatUser.new({:username => username, :password => password, :ip => client_ip})

						if username.nil? || password.nil?
							response = create_response_json("failed_connection", nil, "The username & password have to be passed in the query string.")
							yield response if block_given?
							ws.send(response)
							ws.close
							break
						end 

						if user_credentials_valid?(username, password) == false 
							response = create_response_json("failed_connection", nil, "Invalid user creadentials. The username has to be at least 3 alphanumeric characters, and the password at least 6 alphanumeric characters.")
							yield response if block_given?
							ws.send(response)
							ws.close
							break
						end

						if user_banned?(user)
							response = create_response_json("failed_connection", nil, "The user is banned")
							yield response if block_given?
							ws.send(response)
							ws.close
							break
						end

						number_of_tries = 0
						while user_exists?(user)
							number_of_tries = number_of_tries + 1
							user.username = user.username + Random.rand(1..@max_connections).to_s

							if number_of_tries > 30 
								response = create_response_json("failed_connection", nil, "The username exists already.")
								yield response if block_given?
								ws.send(response)
								ws.close
								break
							end
						end

						number_of_tries = 0
						while admin_credentials_invalid?(user.username, user.password)
							number_of_tries = number_of_tries + 1
							user.username = user.username + Random.rand(1..@max_connections).to_s

							if number_of_tries > 30 
								response = create_response_json("failed_connection", nil, "The username exists already.")
								yield response if block_given?
								ws.send(response)
								ws.close
								break
							end
						end
						
						user.connection = ws

						response = create_response_json("successful_connection", connected_users_to_array, "Connection accepted")
						yield response if block_given?
						ws.send(response)

						@connected_users[user.username] = user
						response = create_response_json("new_connection", user.username, "A new user is connected.")
						yield response if block_given?
						broadcast_message(response)
					end while false
				}
				ws.onmessage { |msg|
					json_data = nil
					command = ""
					data = ""
					user = nil
					begin
						user = get_user_by_connection(ws)

						if user.nil?
							ws.close
							break
						end

						begin
							json_data = JSON.parse(msg)
							command = json_data["command"]
							data = json_data["data"]
						rescue
							break
						end

						case command
						when "chat_message"
							break if data == ""
							response = create_response_json("chat_message", {"from_user" => user.username, "message" => data}, "A chat message.")
							yield response if block_given?
							broadcast_message(response)
							break

						when "ban_user"
							break if data == ""
							unless user_admin?(user)
								response = create_response_json("ban_user", false, "Only an admin can ban a user.")
								yield response if block_given?
								ws.send(response)
								break
							end

							user_to_ban = get_user_by_username(data)
							if user_to_ban.nil?
								response = create_response_json("ban_user", false, "The user to ban did not exist.")
								yield response if block_given?
								ws.send(response)
								break
							end

							if user_admin?(user_to_ban)
								response = create_response_json("ban_user", false, "An admin user can not be banned.")
								yield response if block_given?
								ws.send(response)
								break
							end

							@banned_usernames << user_to_ban.username
							response = create_response_json("ban_user", true, "The user #{user_to_ban.username} has been banned.")
							yield response if block_given?
							ws.send(response)
							user_to_ban.connection.close
							break

						when "private_message"
							break unless data.is_a? Hash
							break if data["to_user"].nil?
							break if data["message"].nil?

							user_to_receive = get_user_by_username(data["to_user"])
							break if user_to_receive.nil?

							response = create_response_json("private_message", {"from_user" => user.username, "message" => data["message"]}, "A private message.")
							yield response if block_given?
							user_to_receive.connection.send(response)
							break

						else
							ws.send(create_response_json("system_information", "Unknown command", "Please make sure that you are sending the right command."))
							ws.close
							break
						end
					end while false
				}
				ws.onclose {
					begin
						break unless @server_started
						deleted = nil
						@connected_users.values.each do |u|
							if u.connection == ws
								name = u.username
								deleted =  @connected_users.delete(name)
								response = create_response_json("user_disconnected", deleted.username, "The user is diconnected.")
								yield response if block_given?
								broadcast_message(response)
								break unless deleted.nil?
							end
						end
					end while false
				}
				ws.onerror { |e|

					unless e.kind_of?(EM::WebSocket::WebSocketError)
						ws.close
					end

				}
			end
		end
	end

	# This method is used privately. It will check if the passwed username belongs to an admin and that the password matches. 
	def admin_credentials_invalid?(username = "", password = "")
		@admins.each do |admin|
			return true if admin.username == username && admin.password != password
		end

		false
	end

	# This method is used privately to check if the username and password are valid. The username has to be at least 3 alphanumeric characters and the password 6 alphanumeric characters. 
	# It returns true if the credentials are valid, otherwise false. 
	def user_credentials_valid?(username = "", password = "")
		return false if /\A\p{Alnum}{3,}\Z/.match(username).nil?
		return false if /\A\p{Alnum}{6,}\Z/.match(password).nil?

		true
	end

	# Returns true if the port number is valid. 
	def valid_port?(value)
		return false if /\A[0-9]{1,6}\Z/.match(value).nil?
		true
	end

	# Returns true if the user is banned. 
	def user_banned?(user)
		if user.class == ChatUser 
			return @banned_usernames.include?(user.username)
		end

		@banned_usernames.include?(user)
	end

	# Returns true if the username is already added to the connected users. 
	def user_exists?(user)
		@connected_users.include?(user.username)
	end

	# Returns true is the user is admin. 
	def user_admin?(user)
		@admins.include?(user)
	end

	# Sends text/json to the connected clients. 
	def broadcast_message(message)
		return false if @connected_users.count == 0

		@connected_users.values.each do |u|
			begin
				u.connection.send(message) unless u.connection.nil?
			rescue
				next
			end
		end
	end

	# Returns the ChatUser object bound to the socket connection. 
	def get_user_by_connection(connection)
		return nil if @connected_users.count == 0
		@connected_users.values.each do |user|
			return user if user.connection == connection
		end

		nil
	end

	# Returns the ChatUser object by the username. 
	def get_user_by_username(username)
		@connected_users[username]
	end

	# Creates the json object to be sent to the clients.
	def create_response_json(command = "", data = nil, message = "")
		{"command" => command, "data" => data, "information" => message}.to_json
	end

	def connected_users_to_array()
		usernames = []
		@connected_users.values.each do |u|
			usernames << u.username
		end

		usernames
	end

end


class ChatUser
	attr_accessor :username, :password, :connection, :ip
	def initialize(args = {})
		raise RuntimeError, "The username is not given" unless args.has_key?(:username)
		raise RuntimeError, "The password is not given" unless args.has_key?(:password)

		@connection = nil
		@connection = args[:connection] if args.has_key?(:connection)
		@ip = args[:ip] if args.has_key?(:ip)
		@username = args[:username]
		@password = args[:password]
	end

	def admin?()
		@is_admin
	end

	def ==(object)
		return false unless object.class == ChatUser
		return username == object.username
	end

	def to_json(options = {})
		{"user" => @username}.to_json
	end

end

end


