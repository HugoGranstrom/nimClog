import std / [strutils, sugar, macros, tables, hashes]
import ./nimClog/types
export types, tables

var currentId*: int
proc getNewId*(): int {.gcsafe.} =
  # this is not gcsafe!
  result = currentId
  inc currentId

proc `$`*(obj: ClogObject): string =
  $obj[]

proc hash*(obj: ClogObject): Hash =
  hash(obj.id)

template createElement*(elTag: string, parent: ClogObject, content: string = "", attributes: seq[(string, string)] = newSeq[(string, string)]()): ClogObject =
  let result = ClogObject(id: $getNewId(), tag: elTag)
  elements[result.id] = result
  var attributeString: string 
  for attr in attributes:
    attributeString &= " $1=\"$2\"" % [attr[0], attr[1]]
    if attr[0].toLower == "type":
      result.tagType = attr[1]
  await ws.send(toJson(DiffObject(id: result.id, kind: newElement, parentId: parent.id, newEl: "<$2 $3>$1</$2>" % [content, elTag, attributeString])))
  result

template removeElement*(obj: ClogObject) =
  elements.del(obj.id)
  # TODO: remove all event handlers assiciated with it
  await ws.send(toJson(DiffObject(id: obj.id, kind: removeElement)))

template setProperty*(obj: ClogObject, property, newValue: string) =
  await send(ws, toJson(DiffObject(id: obj.id, kind: propertyChange, prop: property, value: newValue, isCss: false)))

template setCss*(obj: ClogObject, property, newValue: string) =
  await send(ws, toJson(DiffObject(id: obj.id, kind: propertyChange, prop: property, value: newValue, isCss: true)))

template getProperty*(obj: ClogObject, property: string): string =
  await ws.send(toJson(DiffObject(id: obj.id, kind: propertyRead, prop: property, isCss: false)))
  # Here we just have to pray that the client doesn't send any messages before it sends the query results!
  let result = await ws.receiveStrPacket() 
  result

template addCss*(cssLink: string) =
  discard createElement("link", head, attributes = @[("rel", "stylesheet"), ("href", cssLink)])

template createDiv*(parent: ClogObject, content: string = ""): ClogObject =
  createElement("div", parent, content)

template createLink*(parent: ClogObject, content: string, link: string): ClogObject =
  let result = createElement("a", parent, content, @[("href", link)])
  result
   
template createButton*(parent: ClogObject, content: string): ClogObject =
  let result = createElement("button", parent, content)
  result

template createLabel*(parent: ClogObject, content: string): ClogObject =
  createElement("label", parent, content)

template createInput*(parent: ClogObject, content: string): ClogObject =
  createElement("input", parent, content)

template setText*(obj: ClogObject, newText: string) =
  obj.setProperty("innerHTML", newText)

template getText*(obj: ClogObject): string =
  obj.getProperty("innerHTML")

template setValue*(obj: ClogObject, newValue: string) =
  obj.setProperty("value", newValue)

template getValue*(obj: ClogObject): string =
  obj.getProperty("value")

template setColor*(obj: ClogObject, newText: string) =
  obj.setCss("color", newText)

template setVisible*(obj: ClogObject, visible: bool) =
  obj.setCss("display", if visible: "block" else: "none")

template createEvent*(obj: ClogObject, eventName: string, handler: EventProc)=
  let eventEnum = parseEnum[ClogEventKind](eventName)
  let eventId = "E:" & $obj.id & "-" & $getNewId() & ":" & eventName 
  eventHandlers[eventId] = handler
  await ws.send(toJson(DiffObject(id: obj.id, kind: addEvent, eventId: eventId, event: eventEnum)))


template bindVariableToValue*(variable: untyped, obj: ClogObject) =
  obj.createEvent("change",
    proc (self: ClogObject, event: ClogEvent) {.async.} =
      if obj.tagType != "checkbox":
        variable = event.value
      else:
        variable = event.checked
  )

template bindVariableToValue*(variable: untyped, obj: ClogObject, conv: untyped) = #conv: proc (raw: string): T) = 
  obj.createEvent("change",
    proc (self: ClogObject, event: ClogEvent) {.async.} =
      if obj.tagType != "checkbox":
        variable = conv(event.value)
      else:
        variable = conv(event.checked)
  )

template executeJs*(code: string) =
  await ws.send(toJson(DiffObject(kind: executeJavascript, jsCode: code)))

proc idFromEventString*(eventString: string): string =
  eventString.split(":")[1]


proc extractAttributes(body: NimNode): seq[(NimNode, NimNode)] =
  body.expectKind(nnkCall)
  for x in body:
    if x.kind == nnkExprEqExpr:
      x[0].expectKind({nnkIdent, nnkAccQuoted})
      let first =
        if x[0].eqIdent("type"):
          newLit"type"
        else:
          x[0].strVal.newLit
      let sec = x[1]
      result.add (first,
        quote do:
          $(`sec`)
      )


proc buildHtmlInternal(parent, call: NimNode, injectedNames: var seq[NimNode], varName: NimNode = nil): NimNode =
  case call.kind:
  of nnkCall:
    let tag = if call[0].strVal.toLower == "tdiv": newlit"div" else: call[0].strVal.newlit
    let varName =
      if varName.isNil:
        let newVar = genSym(nskVar, "clogObj")
        injectedNames.add newVar
        newVar
      else:
        varName
    let attributes = extractAttributes(call)
    var attributesNode = nnkBracket.newTree()
    var text: NimNode = nil
    for (key, val) in attributes:
      if key.strVal.toLower == "text":
        # capture the text value and pass it as content!
        text = val
      else:
        attributesNode.add quote do: (`key`, `val`)
    attributesNode = nnkPrefix.newTree(bindSym"@", attributesNode)
    if text.isNil:
      text = newLit""
    var elementCall: NimNode
    if attributesNode[1].len > 0:
      elementCall = quote do:
        createElement(`tag`, `parent`, content=`text`, attributes=`attributesNode`)
    else:
      elementCall = quote do:
        createElement(`tag`, `parent`, content=`text`)
    result = newStmtList()
    result.add quote do:
      `varName` = `elementCall`
    if call.len > attributes.len + 1: # if there is a body
      for child in call[^1]:
        result.add buildHtmlInternal(varName, child, injectedNames)
  of nnkInfix:
    doAssert call[0].eqIdent("as"), "Other infix than 'as' was found!"
    let varName = call[2]
    varName.expectKind(nnkIdent)
    injectedNames.add varName
    var newBody = call[1]
    if call.len == 4: # if there is a body
      newBody.add call[3]
    result = buildHtmlInternal(parent, newBody, injectedNames, varName=varName)
  of nnkCommand:
    discard # bindTo var conv
    doAssert call[0].eqIdent("bindTo"), "Only bindTo is allowed as command! $1 was given!" % [call[0].strVal]
    var args: seq[NimNode]
    args.add call[1]
    args.add parent
    if call.len > 2:
      args.add call[2]
    result = newCall("bindVariableToValue", args) 
  of nnkProcDef:
    let event = call[0].strVal.newLit
    let procBody = call[6]
    let self = ident"self"
    let eventIdent = ident"event"
    result = quote do:
      createEvent(`parent`, `event`, 
        proc (`self`: ClogObject, `eventIdent`: ClogEvent): Future[void] {.async.} =
          `procBody`
      )
  else:
    doAssert false, "Kind $1 not supported in buildHtml at the moment: $2" % [$call.kind, call.repr] 

macro buildHtml*(parent: ClogObject, body: untyped) =
  body.expectKind(nnkStmtList)
  result = newStmtList()
  var injectedNames: seq[NimNode]
  for x in body: 
    result.add buildHtmlInternal(parent, x, injectedNames)
  if injectedNames.len > 0:
    var varsec = nnkVarSection.newTree()
    varsec.add nnkIdentDefs.newTree()
    for name in injectedNames:
      varsec[0].add name
    varsec[0].add ident"ClogObject"
    varsec[0].add newEmptyNode()
    result = newStmtList(varsec, result)
  echo result.repr


template startNimClog*(code: untyped) =
  proc mainClog(req: Request) {.async, gcsafe.} =
    try:
      var ws {.inject.} = await newWebSocket(req)
      var eventHandlers {.inject.}: Table[string, EventProc] 
      var elements {.inject.}: Table[string, ClogObject]
      let body {.inject.} = ClogObject(id: "body")
      let head {.inject.} = ClogObject(id: "head")
      elements["body"] = body
      code
      while ws.readyState == Open:
        let packet = await ws.receiveStrPacket()
        try:
          let event = packet.fromJson(ClogEvent)
          if event.eventId in eventHandlers:
            await eventHandlers[event.eventId](elements[event.objectId], event)
        except JsonError:
          echo "Couldn't parse message: ", packet
    except WebSocketError:
      echo "Socket closed: ", getCurrentExceptionMsg()
  var server = newAsyncHttpServer()
  waitFor server.serve(Port(9001), mainClog)
