import std / [tables]
export tables

type
  ClogObject* = ref object # To make this thread-safe to read, use SharedPtr[ClogObject] and remove ref
    id*: string
    tag*: string 
    tagType*: string # if type attribute is supplied it will be assigned here
    objects*: Table[string, ClogObject]

  DiffKind* = enum
    noChange
    propertyChange
    propertyRead
    newElement
    addEvent
    executeJavascript
    removeElement
  DiffObject* = object
    case kind*: DiffKind
    of noChange:
      discard
    of propertyChange, propertyRead:
      prop*: string
      value*: string
      isCss*: bool # if css, treat prop as css-prop
    of newElement:
      newEl*: string
      parentId*: string
    of addEvent:
      event*: ClogEventKind # TODO: make this an enum
      eventId*: string # The string sent when an event has occured
    of removeElement:
      discard
    of executeJavascript:
      jsCode*: string
    id*: string
  
  ClogEventKind* = enum
    click
    change

  ClogEvent* = object
    eventId*: string
    objectId*: string
    case kind*: ClogEventKind
    of click:
      discard
    of change:
      value*: string
      checked*: string
    
when not defined(js):
  import std / [asyncdispatch]
  export asyncdispatch
  type
    EventProc* = proc (self: ClogObject, event: ClogEvent): Future[void]
