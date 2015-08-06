$(function(){
	var ws = null;
	showLoginForm();
	hideChatComponents();
	$("#login-form").on("submit", function(e){
		e.preventDefault();

		var username = $("#username").val();
		var password = $("#password").val();

		if(/^[a-zA-Z0-9]{3,}/i.test(username) === false){
			alert("The username must be at least 3 alphnumeric characters.");
			return;
		}

		if(/^[a-zA-Z0-9]{6,}/i.test(password) === false){
			alert("The password must be at least 3 alphnumeric characters.");
			return;
		}

		startChatting(username, password);	
	});


});


function startChatting(username, password){

	var Socket = "MozWebSocket" in window ? MozWebSocket : WebSocket;
	var socket = new Socket("ws://localhost:8080?username=" + username + "&password=" + password );

	socket.onmessage = function(event) 
	{ 

		var data = JSON.parse(event.data);
		switch(data.command){
			case "failed_connection":
			alert(data.information);
			location.reload();
			break;

			case "successful_connection":
			if(data.data !== null){
				for(i = 0; i < data.data.length; i++){
					$("#users-list").append("<span class='label label-primary' id="+data.data[i]+">"+ data.data[i]+"<br></span>");
				}
			}
			break;

			case "new_connection":
			$("#users-list").append("<span class='label label-primary' id="+data.data+">"+data.data+"<br></span>");
			break;

			case "user_disconnected":
			displayChatText("<span class='label label-info'>" + data.data + " has disconnected</span><br>");
			$('#'+data.data).remove();
			break;

			case "private_message":
			displayChatText("<span class='label label-primary'>Private message from " + data.data.from_user + "</span>: " + data.data.message + "<br>");
			break;

			case "chat_message":
			displayChatText("<span class='label label-primary'>" + data.data.from_user + "</span>: " + data.data.message + "<br>");
			break;

			case "ban_user":
			displayChatText("<span class='label label-info'>" + data.information + "<br>");
			break;

			case "system_information":
			displayChatText("<span class='label label-danger'>" + data.data.data + "<br>");
			break;

			default:
			break;
		}




	};
	socket.onclose = function(event) {
		location.reload();
	};
	socket.onopen = function() {
		hideLoginForm();
		showChatComponents();

		$(document).on("keyup", "#chat-text", function(event){
			if(event.keyCode == 13){
				var message = $("#chat-text").val();
				if(message === "") return;
				$("#chat-text").val("");

				var words = message.split(" ");
				if((words.length > 1) && (words[0] === "ban_user")){
					socket.send(JSON.stringify({command: "ban_user", data: words[1]}));
					return;
				}

				if((words.length > 2) && (words[0] === "private_message")){
					var str = "";
					for(i = 2; i < words.length; i++){
						str = str + words[i] + " ";
					}
					socket.send(JSON.stringify({command: "private_message", data: {to_user: words[1], message: str}}));
					return;
				}
				sendChatMessage(socket, message);
			}
		});
		displayChatText("<h5><span class='alert-success'>Connected. to send a private message type (private_message USERNAME MESSAGE). To ban a user when you are logged in as admin, type (ban_user USERNAME)</span><br></h5>");
	};
}


function sendChatMessage(socket, message){
	socket.send(JSON.stringify({command: "chat_message", data: message}));
}

function hideChatComponents(){
	$("#chat-components").hide();
}

function showChatComponents(){
	$("#chat-components").show();
	$("#chat-text").focus();
}

function hideLoginForm(){
	$("#login-div").hide();
}

function showLoginForm(){
	$("#login-div").show();
}

function displayChatText(text){
	$("#chat-log").append(text);
	$("#chat-log").animate({ scrollTop: $("#chat-log")[0].scrollHeight}, 1000);
}