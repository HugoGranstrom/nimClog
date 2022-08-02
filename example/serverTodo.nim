import std / [tables, sugar, random, times]
import ws, asyncdispatch, asynchttpserver
import jsony
import ../src/nimClog

startNimClog:
  var items: seq[ClogObject]
  var texts: Table[ClogObject, string]
  var checks: Table[ClogObject, bool]


  proc removeItem(item: ClogObject) {.async.} =
    for i in countdown(items.high, 0):
      if items[i] == item:
        items.delete(i)
    texts.del(item)
    checks.del(item)
    removeElement(item) 

  proc addTodo(ul: ClogObject, text: string) {.async.} =
    buildHtml(ul):
      li() as listItem:
        tdiv() as staticDiv: # Normal view
          input(`type` = "checkbox") as checkbox:
            bindTo checks[listItem], (raw: string) => raw == "true"
          span(text = text, style = "margin: 5px") as todolabel
          button(text = "edit"):
            proc click(self, event) =
              staticDiv.setVisible(false)
              editDiv.setVisible(true)
              editInput.setValue(texts[listItem]) 
          button(text = "remove"):
            proc click(self, event) =
              await removeItem(listItem)

        tdiv() as editDiv: # Edit view 
          input() as editInput
          button(text = "Save"):
            proc click() =
              let newValue = editInput.getValue()
              todolabel.setText(newValue)
              texts[listItem] = newValue 
              editDiv.setVisible(false)
              staticDiv.setVisible(true)
    editDiv.setVisible(false)
    listItem.objects["label"] = todolabel # save it so we can access the label outside this function
    items.add listItem  
    texts[listItem] = text
    checks[listItem] = false

  var inputField: string
  var dateField: DateTime
  buildHtml(body):
    tdiv(): # Tabs
      span(text = "Tabs: ")
      button(text = "Todo"):
        proc click() =
          todoAppDiv.setVisible(true)
          datepickerDiv.setvisible(false)
      button(text = "Date Picker"):
        proc click() =
          todoAppDiv.setVisible(false)
          datepickerDiv.setvisible(true)

    tdiv() as todoAppDiv: # Todo app
      h1(text = "TODO APP")
      button(text = "Remove random"):
        proc click () =
          if items.len > 0:
            let i = rand(items.high)
            let item = items[i]
            await removeItem(item)
      button(text = "Remove all checked"):
        proc click () =
          var removeList: seq[ClogObject]
          for item in items:
            if checks[item]:
              removeList.add item
          for item in removeList:
            await removeItem(item)

      tdiv(style = "margin-top: 5px"):
        input(placeholder = "Write a TODO here...") as inputElement
        button(text = "Add"):
          proc click(self: ClogObject, event: ClogEvent) =
            await todolist.addTodo(inputField)
            inputElement.setValue("")
            inputField = "" 
      ul(style = "list-style: none; padding-left: 0px") as todolist

    tdiv() as datepickerDiv: # Date picker
      h1(text = "Date Picker")
      input(`type` = "date") as datepicker:
        bindTo dateField, (raw: string) => (if raw.len > 0: parse(raw, "yyyy-MM-dd") else: DateTime()) 
        proc change() =
          dateText.setText("What the server sees: " & $dateField)
      p(text = "What the server sees: ") as dateText
      button(text = "Click this and look at the nim terminal to see what value it has stored"):
        proc click() =
          echo dateField 

  datepickerDiv.setVisible(false) # hide the second tab
  bindVariableToValue(inputField, inputElement) # manual binding if you don't use `bindTo`
  
