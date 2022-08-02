import std / [tables, sugar, random, times]
import ws, asyncdispatch, asynchttpserver
import jsony
import ../src/nimClog

# Username to update proc
var users: Table[string, proc (sender, msg: string): Future[void]]

startNimClog:
  var username: string
  
  buildHtml(body):
    tdiv() as signInDiv:
      label(text = "Username:")
      input() as usernameInput
      button(text = "Login"):
        proc click() =
          # Do some simple validation
          let user = usernameInput.getValue()
          if user == "":
            executeJs("alert('No username choosen!')")
          elif user in users:
            executeJs("alert('Username already taken!')")
          else:
            username = user
            signInDiv.setVisible(false)
            loggedInDiv.setVisible(true)
            users[username] = 
              proc (sender, msg: string) {.async.} =
                buildHtml(messageBox):
                  span(text = sender & ": " & msg)
                  br()

    tdiv() as loggedInDiv:
      tdiv() as messageBox
      tdiv():
        input() as chatInput
        button(text = "Send"):
          proc click() =
            let msg = chatInput.getValue()
            chatInput.setValue("")
            if msg.len > 0:
              await users[username]("Me", msg)
              for user in users.keys():
                if user != username:
                  await users[user](username, msg)

  setVisible(loggedInDiv, false)

