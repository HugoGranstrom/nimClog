# nimClog - A [CLOG](https://github.com/rabbibotton/clog) inspired HTML-over-Websocket Proof of concept in Nim

In traditional web development you have the frontend separate from the backend, for example the frontend written in Karax and the backend in Prolouge. 
What CLOG does is that it runs the majority of the logic on the server and uses a thin client which's only purpose is to send events to the server and to perform commands the server sends.
This means one only has to have a single codebase, namely the server. (Though to be fair, Nim doesn't really suffer that much from this as the frontend and backend can share the codebase thanks to
Nim's ability to compile to Javascript). 
This is a proof of concept of this idea but it has many rough edges and is hacky in many ways. So don't use this for anything serious, more like something fun to play around with. My main motivation with this is to inspire others to take inspiration from this and
develop a proper HTML-over-Websocket library in Nim. I have neither the time nor knowledge to succeed with that.  

## Example
In `example/` there are examples with a TODO (how imaginative) and a Date picker and a second one with a simple chat app. You can run them by cloning the repo and installing the dependencies.
Then you have to start a http server in `example/client` for example using `nimhttpd example/client`. After that you can open a second terminal window and run
`nimble runTodo` or `nimble runChat` to build the client and start the Websocket server. Going to [localhost:1337](localhost:1337) should show you the chosen demo then. 

## Usage
The easiest way to start at the moment is to clone the repo and modify `example/server.nim`, removing all content inside `startNimClog`.
The content of `startNimClog` is what will be run when we connect to the server.
The easiest way to get started is with the Karax-inspired `buildHtml` macro:
```nim
startNimClog:
    # body is predefined and represents the body of the nimClog app 
    buildHtml(body):
        tdiv():
            button(text = "Click me!")
            p(text = "Count: 0")
```
This creates a `<div>` with a button and paragraph inside. It is worth noting that contrary to Karax's `builtHtml`,
nimClog doesn't return anything but instead appends the the first argument. So in this case the `div` with the button and 
paragraph is added to the body. Now let's add some functionality to the button. When we press it we want to increase the count
in the paragraph. So to do that we have to be able to reference the paragraph. That can be done using `p() as pCount`. We can then
access and modify properties of the paragraph through the variable `pCount`:
```nim
startNimClog:
    var counter: int
    buildHtml(body):
        tdiv():
            button(text = "Click me!"):
                proc click(self: ClogObject, event: ClogEvent) {.async} =
                    inc counter
                    pCount.setText("Count: " & $counter)
            p(text = "Count: 0") as pCount
```
We created a variable `counter` to keep track of the current count and we created an `click` event-handler. `click` and `change` are the
supported events at the moment. `self` is the object representing the button on the server and `event` contains some
data from the event if applicable. `click` has no data but `change` has `event.value` and `event.checked`. 
The text of the paragraph is then set with `pCount.setText()` to send the new text to the frontend. 

### Binding to input elements
If you have an input element:
```nim
startNimClog:
    buildHtml(body):
        input(placeholder = "Type something...") 
```
You can bind its value to a variable using `bindTo` like this:
```nim
startNimClog:
    var inputValue: string
    buildHtml(body):
        input(placeholder = "Type something..."):
            bindTo inputValue
```
Now whenever the input is changed on the client-side, it will send it to the server and update `inputValue`.
You can also supply a conversion function as a second argument if you want to convert the value to something other than a string:
```nim
import sugar
startNimClog:
    var checked: bool
    buildHtml(body):
        input(`type` = "checkbox"):
            bindTo checked, (raw: string) => raw == "true" 
```
Note that you can pass arbitrary attributes to the tag when creating it like for example `placeholder = "Type something`.
These are just forwarded to the html. `text = "some text"` is the only exception as it puts the text between the tags: `<tag>text</tag>`.



## Suggested improvements
- Use multithreading so that events don't run on the main thread blocking it.
- Make it more general, right now it is hardcoded for asynchttpserver.


