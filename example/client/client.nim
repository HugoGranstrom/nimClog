import std / [jsffi, dom, tables, sugar]
import jsony
import nimClog/types

type
  WebSocket = ref object 
  MessageEvent* {.importjs.} = object of Event
    data: cstring

proc newWebSocket(address: cstring): WebSocket {.importjs: "(new WebSocket(#))".}
proc send(ws: WebSocket, data: cstring) {.importjs: "#.send(#)".}
proc close(ws: WebSocket) {.importjs: "#.close()".}
proc onEvent(el: Element, event: cstring, handler: proc (e: Event)) {.importjs: "#.addEventListener(#, #)".}
proc onOpen(ws: WebSocket, handler: proc (e: Event)) {.importjs: "#.addEventListener('open', #)".}
proc onMessage(ws: WebSocket, handler: proc (e: MessageEvent)) {.importjs: "#.addEventListener('message', #)".}
proc eval(code: cstring) {.importjs: "eval(#)".}

# Shoudl we exportc these?
var elements: Table[cstring, Element]

let body = getElementById("clog-body")
let head = document.head
elements["body"] = body
elements["head"] = head
var domParser = newDomParser()

let ws = newWebSocket("ws://localhost:9001")

ws.onOpen proc (e: Event) =
  discard

ws.onMessage proc (e: MessageEvent) =
  echo "Received: ", e.data
  let x = ($e.data).fromJson(DiffObject)
  let id = x.id.cstring
  case x.kind
  of propertyChange:
    let el = elements[id]
    if x.isCss:
      el.style.setProperty(x.prop.cstring, x.value.cstring)
    else:
      cast[JsObject](el)[x.prop.cstring] = x.value.cstring
  of propertyRead:
    let el = elements[id]
    var answer: cstring
    if x.isCss:
      answer = el.style.getPropertyValue(x.prop.cstring)
    else:
      answer = cast[JsObject](el)[x.prop.cstring].to(cstring)
    ws.send(answer)
  of newElement:
    echo "Starting to add!"
    let parent = elements[x.parentId.cstring]
    let newEl = 
      if parent == head:
        domParser.parseFromString(x.newEl.cstring, "text/html").head.children[0].Element
      else:
        domParser.parseFromString(x.newEl.cstring, "text/html").body.children[0].Element

    echo "After parser!"
    echo "Adding this doc: ", newEl[]
    parent.appendChild(newEl)
    elements[id] = newEl
  of addEvent:
    let eventObj = ClogEvent(eventId: x.eventId, objectId: x.id, kind: x.event)
    case x.event
    of ClogEventKind.click:
      elements[id].onEvent(($x.event).cstring, (e: Event) => ws.send(toJson(eventObj).cstring))
    of ClogEventKind.change:
      proc callback(e: Event) =
        var event = eventObj
        event.value = $elements[id].value
        event.checked = $elements[id].checked
        ws.send(toJson(event).cstring)
      elements[id].onEvent(($x.event).cstring, callBack) 
  of executeJavascript:
    eval(x.jsCode.cstring)
  of removeElement:
    elements[id].remove() # remove from dom
    elements.del(id) # remove from table
  of noChange:
    discard



