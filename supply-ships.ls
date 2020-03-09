#UseInterface Web;

// Global Variables
Var debug As Boolean = False; // Auf True setzen um Debug-Ausgaben zu bekommen
Var torpedoGoodsIDList As CIntegerList = CIntegerList.CreateFromString("8,19,20,32,33,34", ",");
Var startDate As Date = DateTime.Now; // check date to prevent taking too much runtime
Var scriptVersion As Integer = 3;

// ------------------ Framework functions ------------------

Function createUrl(page As String) As CScriptUrl {
  Var url As New CScriptUrl(); 
  url.Parameters.Add('page', page); 
  Return url;
}

Function createLinkTab(page As String, label As String, currentPage As String) As CTableCell {
  Var tableCell As CTableCell = New CTableCell();
  tableCell.Add(New CHtmlHyperLink(createUrl(page), label));
  If(currentPage = page) {
    tableCell.CssClass = 'tab_selected';
  } Else {
    tableCell.CssClass = 'tab';
  }
  
  Return tableCell;
}

Function AddFullWidthHeaderRow(table As CTable, label As String, colSpan As Integer) As CTableRow {
  Var row As CTableRow = table.AddRow();
  Var cell As New CTableCell();
  cell.CssClass = 'bb';
  cell.Add(label);
  cell.ColumnSpan = colSpan;
  row.Add(cell);
  Return row;
}

Function AddHeaderCell(row As CTableRow, label As String, colSpan As Integer) As CTableCell {
  Var cell As CTableCell = New CTableCell();
  cell.CssClass = 'bb';
  cell.Add(label);
  cell.ColumnSpan = colSpan;
  row.Add(cell);
  
  Return cell;
}

Function AddHeaderCell(row As CTableRow, label As String) As CTableCell {
  Return AddHeaderCell(row, label, 1);
}

Function buildErrorMainArea(MainAreaCell As CTableCell) As CHtmlControl {
  Var Html As CHtmlControl = New CHtmlControl();
  
  Var header As CHtmlSeperator = New CHtmlSeperator("Seite nicht gefunden");
  Html.Add(header);
  
  Html.Add("Die Aufgerufene Seite wurde nicht gefunden...");
  
  Return Html;
}

Function buildMainArea(page As String, MainAreaCell As CTableCell) As CHtmlControl {
  If(page = 'main') {
    Return buildMainMainArea(MainAreaCell);
  }
  If(page = 'credits') {
    Return buildCreditsMainArea(MainAreaCell);
  }
  Return buildErrorMainArea(MainAreaCell);
}

Function showGui() {
  Var page As String = 'main';
  If (Request.Parameters.ContainsKey('page')) {
    page = Request.Parameters.Item('page');
  }
  Var MainTable As CTable = New CTable();
  MainTable.Style.Add('width', '100%');
  
  // Build Menu
  Var ControlsRow As CTableRow = MainTable.AddRow();
  ControlsRow.Add(createLinkTab('main', 'Hauptseite', page));
  ControlsRow.Add(createLinkTab('credits', 'Credits', page));
  
  // Build Main Area
  Var MainAreaRow As CTableRow = MainTable.AddRow();
  Var MainAreaCell As CTableCell = New CTableCell();
  MainAreaCell.ColumnSpan = 4;
  MainAreaCell.CssClass = 'l';
  MainAreaCell.Style.Add("height", "400px");
  MainAreaCell.Style.Add("vertical-align", "top");
  MainAreaCell.Add(buildMainArea(page, MainAreaCell));
  MainAreaRow.Add(MainAreaCell);
  
  Response.Add(MainTable);
}

Function executeActions() {
  If (not Request.Parameters.ContainsKey('action')) {
    Return;
  }
  
  Var action As String = Request.Parameters.Item('action');
  If(action = "execute") {
    executeSupply();
    Return;
  }
  
  PageLog.WriteLine("Die gewählte Funktion wurde nicht gefunden!");
}

Function main() {
  executeActions();
  showGui();
}

// ------------------ Custom functions ------------------

Function getLocalServerAddress() As String {
  Var s As New CStringBuilder();
  s.Append("https://game");
  If(Server.Number > 1) {
    s.Append(CStr(Server.Number));
  }
  If(Server.Language <> "de") {
    s.Append(".");
    s.Append(Server.Language);
  }
  s.Append(".stne.net/");
  return CStr(s);
}

Function createFleetSelect(name As String) As CHtmlListBox {
  Var fleetSelect As CHtmlListBox = New CHtmlListBox(name);
  fleetSelect.Add("Flotte auswählen", '0');
  
  Var myFleets As CFleetEnumerator = New CFleetEnumerator();
  While(myFleets.Next()) {
    Var currentFleet As CMyFleet = myFleets.CurrentFleet;
    If(Request.Form.Item(name) = CStr(currentFleet.FleetID)) {
      fleetSelect.Add(currentFleet.NameAndID, CStr(currentFleet.FleetID), True);
    } Else {
      fleetSelect.Add(currentFleet.NameAndID, CStr(currentFleet.FleetID));
    }
  }
  Return fleetSelect;
}

Function createCheckBox(checkedByDefault As Boolean, name As String, text As String) As CHtmlCheckBox {
  Var checked As Boolean;
  If(Request.Form.Count > 0) {
    checked = CBool(Request.Form.ContainsKey(name));
  } Else {
    checked = checkedByDefault;
  }
  Return New CHtmlCheckBox(checked, name, text);
}

Function createInput(default As String, name As String, type As EHtmlInputType) As CHtmlInput {
  Var value As String;
  If(Request.Form.Count > 0) {
    value = CStr(Request.Form.Item(name));
  } Else {
    value = default;
  }
  Return New CHtmlInput(value, name, type);
}

Function createSelectBox(default As Object, name As String, values As Array, labels As Array) As CHtmlListBox {
  Var select As CHtmlListBox = New CHtmlListBox(name);
  Var i As Integer;
  For(i = 0 To values.Length - 1) {
    If(Request.Form.ContainsKey(name)) {
      select.Add(labels[i], CStr(values[i]), Request.Form.Item(name) = CStr(values[i]));
    } Else {
      select.Add(labels[i], CStr(values[i]), default = values[i]);
    }
  }
  Return select;
}

Function createFleetRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/b/settings.gif");
  image.ToolTip = "Auswahl der Versorger-Flotte und der zu versorgenden Flotte";
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  cellA.Add("Versorger-Flotte: ");
  cellA.Add(createFleetSelect("supplier"));
  row.Add(cellA);
  
  Var cellB As New CTableCell();
  cellB.CssClass = "l";
  cellB.Add("Zu versorgende Flotte: ");
  cellB.Add(createFleetSelect("supplied"));
  row.Add(cellB);
  Return row;
}

Function createEnergyRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/b/energie.gif");
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  Var sendSpan As New CHtmlSpan();
  sendSpan.Add(createCheckBox(True, "send-energy", "Energie-Versorgung"));
  sendSpan.ToolTip = "Schiffe mit Energie versorgen.";
  cellA.Add(sendSpan);
  row.Add(cellA);
  
  Var cellB As New CTableCell();
  cellB.CssClass = "l";
  
  Var fullInputSpan As New CHtmlSpan();
  fullInputSpan.Add(New CHtmlInput("full", "energy-mode", EHtmlInputType.Radio));
  fullInputSpan.ToolTip = "Maximal mögliche Energie übertragen. Kann beim versorgenden und / oder versorgten Schiff zur Überhitzung des EPS führen!";
  fullInputSpan.Add(" Voll auffüllen");
  cellB.Add(fullInputSpan);
  
  cellB.Add(New CHtmlBreak());
  Var hcInputSpan As New CHtmlSpan();
  hcInputSpan.Add(New CHtmlInput("computer", "energy-mode", EHtmlInputType.Radio));
  hcInputSpan.ToolTip = "Ausreichend Energie zum Aktivieren des Hauptcomputers senden";
  hcInputSpan.Add(" Nur für Hauptcomputer");
  cellB.Add(hcInputSpan);
  
  cellB.Add(New CHtmlBreak());
  Var fixedInputSpan As New CHtmlSpan();
  Var fixedInput As New CHtmlInput("fixed", "energy-mode", EHtmlInputType.Radio);
  fixedInputSpan.ToolTip = "Auf feste Menge an Energie auffüllen, sofern möglich. Kann nur weniger als die eingestellte Menge gesendet werden, wird die maximal mögliche Menge gesendet.";
  Var fixedAmountInput As CHtmlInput = createInput("0", "energy-fixed-amount", EHtmlInputType.Float);
  fixedAmountInput.Style.Add("width", "50px");
  fixedInputSpan.Add(fixedInput);
  fixedInputSpan.Add(" ");
  fixedInputSpan.Add(fixedAmountInput);
  fixedInputSpan.Add(" Einheiten");
  cellB.Add(fixedInputSpan);
  
  cellB.Add(New CHtmlBreak());
  Var suppliedBufferSpan As New CHtmlSpan();
  Var suppliedBufferInput As New CHtmlInput("fixed-left", "energy-mode", EHtmlInputType.Radio);
  suppliedBufferSpan.ToolTip = "Sende so viel Energie, dass noch die eingestellte Menge an EPS am empfangenden Schiff übrig ist.";
  Var suppliedBufferAmountInput As CHtmlInput = createInput("1", "energy-supplied-buffer", EHtmlInputType.Float);
  suppliedBufferAmountInput.Style.Add("width", "50px");
  suppliedBufferSpan.Add(suppliedBufferInput);
  suppliedBufferSpan.Add(" EPS-Puffer: ")
  suppliedBufferSpan.Add(suppliedBufferAmountInput);
  cellB.Add(suppliedBufferSpan);
  
  cellB.Add(New CHtmlBreak());
  cellB.Add(New CHtmlBreak());
  Var bufferSpan As New CHtmlSpan();
  bufferSpan.Add("Versorger-Puffer: ");
  Var bufferInput As CHtmlInput = createInput("10", "energy-supplier-buffer", EHtmlInputType.Float);
  bufferInput.Style.Add("width", "50px");
  bufferSpan.Add(bufferInput);
  bufferSpan.Add(" Einheiten");
  bufferSpan.ToolTip = "Energie- / EPS-Menge, die auf dem versorgenden Schiff nicht unterschritten werden darf.";
  cellB.Add(bufferSpan);
  
  row.Add(cellB);
  Return row;
}

Function createCrewRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/b/crew.gif");
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  Var sendSpan As New CHtmlSpan();
  sendSpan.Add(createCheckBox(True, "send-crew", "Crew-Versorgung"));
  sendSpan.ToolTip = "Schiffe mit Crew versorgen.";
  cellA.Add(sendSpan);
  row.Add(cellA);
  
  Var cellB As New CTableCell();
  cellB.CssClass = "l";
  
  Var fullInputSpan As New CHtmlSpan();
  fullInputSpan.Add(New CHtmlInput("full", "crew-mode", EHtmlInputType.Radio));
  fullInputSpan.ToolTip = "Crew bis zur Maximal-Crew auffüllen.";
  fullInputSpan.Add(" Voll auffüllen");
  cellB.Add(fullInputSpan);
  
  cellB.Add(New CHtmlBreak());
  Var hcInputSpan As New CHtmlSpan();
  hcInputSpan.Add(New CHtmlInput("base", "crew-mode", EHtmlInputType.Radio));
  hcInputSpan.ToolTip = "Crew nur bis zur Basis-Crew auffüllen";
  hcInputSpan.Add(" Nur Basis-Crew");
  cellB.Add(hcInputSpan);
  
  cellB.Add(New CHtmlBreak());
  Var fixedInputSpan As New CHtmlSpan();
  Var fixedInput As New CHtmlInput("fixed", "crew-mode", EHtmlInputType.Radio);
  fixedInputSpan.ToolTip = "Auf feste Anzahl an Crew-Mitgliedern auffüllen.";
  Var fixedAmountInput As CHtmlInput = createInput("0", "crew-fixed-amount", EHtmlInputType.Number);
  fixedAmountInput.Style.Add("width", "50px");
  fixedInputSpan.Add(fixedInput);
  fixedInputSpan.Add(" ");
  fixedInputSpan.Add(fixedAmountInput);
  fixedInputSpan.Add(New CHtmlImage(getLocalServerAddress()&"i/bev/crew.gif"));
  cellB.Add(fixedInputSpan);
  
  cellB.Add(New CHtmlBreak());
  cellB.Add(New CHtmlBreak());
  Var bufferSpan As New CHtmlSpan();
  bufferSpan.Add("Versorger-Puffer: ");
  Var bufferInput As CHtmlInput = createInput("100", "crew-supplier-buffer", EHtmlInputType.Float);
  bufferInput.Style.Add("width", "50px");
  bufferSpan.Add(bufferInput);
  bufferSpan.Add("% der Basis-Crew");
  bufferSpan.ToolTip = "Prozentsatz der Basis-Crew, die auf dem versorgenden Schiff nicht unterschritten werden darf.";
  cellB.Add(bufferSpan);
  
  row.Add(cellB);
  Return row;
}

Function createResourceRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/b/waren.gif");
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  Var sendSpan As New CHtmlSpan();
  sendSpan.Add(createCheckBox(False, "send-resources", "Waren-Versorgung"));
  sendSpan.ToolTip = "Schiffe mit Waren versorgen.";
  cellA.Add(sendSpan);
  row.Add(cellA);
  
  Var cellB As New CTableCell();
  cellB.CssClass = "l";
  Var resourceTable As New CTable();
  Var resources As New CGoodsInfoEnumerator();
  Var resource As CGoodsInfo;
  While(resources.Next()) {
    resource = resources.CurrentWarenInfo;
    Var lineRow As New CTableRow();
    Var resImageCell As New CTableCell();
    resImageCell.ToolTip = resource.Name;
    resImageCell.Add(resource.GetImage());
    lineRow.Add(resImageCell);
    Var inputCell As New CTableCell();
    inputCell.ToolTip = resource.Name;
    Var resourceInput As CHtmlInput = createInput("0", "resource-" & resource.GoodsID, EHtmlInputType.Number);
    resourceInput.Style.Add("width", "150px");
    inputCell.Add(resourceInput);
    lineRow.Add(inputCell);
    resourceTable.Add(lineRow);
  }
  
  cellB.Add(resourceTable);
  
  row.Add(cellB);
  Return row;
}

Function createWarpcoreRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/items/1466.gif");
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  Var sendSpan As New CHtmlSpan();
  sendSpan.Add(createCheckBox(True, "send-warpcore", "Warpkern-Versorgung"));
  sendSpan.ToolTip = "Schiffe mit Warpkernenergie versorgen.";
  cellA.Add(sendSpan);
  row.Add(cellA);
  
  Var cellB As New CTableCell();
  cellB.CssClass = "l";
  
  Var fullInputSpan As New CHtmlSpan();
  fullInputSpan.Add(New CHtmlInput("full", "warpcore-mode", EHtmlInputType.Radio));
  fullInputSpan.ToolTip = "Warpkern bis zur Maximal-Kapazität auffüllen.";
  fullInputSpan.Add(" Voll auffüllen");
  cellB.Add(fullInputSpan);
  
  cellB.Add(New CHtmlBreak());
  Var fixedInputSpan As New CHtmlSpan();
  Var fixedInput As New CHtmlInput("fixed", "warpcore-mode", EHtmlInputType.Radio);
  fixedInputSpan.ToolTip = "Auf feste Menge an Warpkernenergie auffüllen.";
  Var fixedAmountInput As CHtmlInput = createInput("0", "warpcore-fixed-amount", EHtmlInputType.Float);
  fixedAmountInput.Style.Add("width", "75px");
  fixedInputSpan.Add(fixedInput);
  fixedInputSpan.Add(" ");
  fixedInputSpan.Add(fixedAmountInput);
  fixedInputSpan.Add(" Warpkern-Energie.");
  cellB.Add(fixedInputSpan);
  
  row.Add(cellB);
  Return row;
}

Function createDockingRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/b/add.gif");
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  cellA.ColumnSpan = 2;
  Var sendSpan As New CHtmlSpan();
  sendSpan.Add(createCheckBox(False, "dock-to-station", "Nutze Station im Sektor"));
  sendSpan.ToolTip = "Vor dem Versorgen docken jeweils das versorgende Schiff und das zu versorgende Schiff an eine Station im Sektor an, sofern diese verfügbar ist. Dafür sind zwei freie Dockplätze notwendig. Kann das zu versorgende Schiff nicht selbstständig andocken, wird es per Traktorstrahl angedockt, falls die Station steuerbar ist.";
  sendSpan.Add(" (Achtung, verursacht hohe Laufzeit!)");
  cellA.Add(sendSpan);
  row.Add(cellA);
  
  Return row;
}

Function createMiscRow() As CHtmlControl {
  Var row As New CTableRow();
  Var imageCell As New CTableCell();
  Var image As New CHtmlImage(getLocalServerAddress()&"i/b/send.gif");
  imageCell.Add(image);
  imageCell.CssClass = "img";
  row.Add(imageCell);
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  cellA.ColumnSpan = 2;
  Var computerSpan As New CHtmlSpan();
  computerSpan.Add(createCheckBox(True, "activate-computer", "Aktiviere Hauptcomputer"));
  computerSpan.ToolTip = "Nach der Versorgung der Schiffe wird der Hauptcomputer aktiviert.";
  cellA.Add(computerSpan);
  
  cellA.Add(New CHtmlBreak());
  Var warpcoreSpan As New CHtmlSpan();
  warpcoreSpan.Add(createCheckBox(True, "activate-warpcore", "Aktiviere Warpkern"));
  warpcoreSpan.ToolTip = "Nach der Versorgung der Schiffe wird der Warpkern aktiviert, sofern dieser nicht leer ist.";
  cellA.Add(warpcoreSpan);
  
  cellA.Add(New CHtmlBreak());
  Var overdriveSpan As New CHtmlSpan();
  overdriveSpan.Add(createCheckBox(True, "activate-overdrive", "Aktiviere Overdrive"));
  overdriveSpan.ToolTip = "Nach der Versorgung der Schiffe wird der Overdrive aktiviert.";
  cellA.Add(overdriveSpan);
  
  cellA.Add(New CHtmlBreak());
  Var shieldsSpan As New CHtmlSpan();
  shieldsSpan.Add(createCheckBox(False, "activate-shields", "Aktiviere Schilde"));
  shieldsSpan.ToolTip = "Nach der Versorgung der Schiffe werden die Schilde aktiviert.";
  cellA.Add(shieldsSpan);
  
  cellA.Add(New CHtmlBreak());
  Var alertSpan As New CHtmlSpan();
  alertSpan.Add(createCheckBox(True, "set-alert-level", "Setze Alarmstufe auf "));
  Var alertLevels[] As EAlertLevel = {EAlertLevel.Green, EAlertLevel.Yellow, EAlertLevel.Red};
  Var alertNames[] As String = {"Grün", "Gelb", "Rot"};
  Var alertSelect As CHtmlListBox = createSelectBox(EAlertLevel.Yellow, "alert-level", alertLevels, alertNames);
  alertSelect.Style.Add("width", "75px");
  alertSpan.Add(alertSelect);
  alertSpan.ToolTip = "Nach der Versorgung der Schiffe wird die Alarmstufe auf die gewählte Stufe gesetzt.";
  cellA.Add(alertSpan);
  
  row.Add(cellA);
  
  Return row;
}

Function createSubmitRow() As CHtmlControl {
  Var row As New CTableRow();
  
  Var cellA As New CTableCell();
  cellA.CssClass = "l";
  cellA.ColumnSpan = 3;
  cellA.Add(New CHtmlSubmitButton("Versorgung Starten", "submit", "Die ausgewählten Einstellungen bestätigen und die Versorgung der Flotte beginnen!"));
  row.Add(cellA);
  
  Return row;
}

Function createSupplyForm() As CHtmlControl {
  Var url As CScriptUrl = createUrl("main");
  url.Parameters.Add('action', 'execute');
  Var form As New CHtmlForm(url);
  Var table As New CTable();
  table.Add(createSubmitRow());
  table.Add(createFleetRow());
  table.Add(createCrewRow());
  table.Add(createEnergyRow());
  table.Add(createWarpcoreRow());
  table.Add(createResourceRow());
  table.Add(createMiscRow());
  table.Add(createDockingRow());
  table.Add(createSubmitRow());
  form.Add(table);
  Return form;
}

Function buildMainMainArea(MainAreaCell As CTableCell) As CHtmlControl {
  Var Html As CHtmlControl = New CHtmlControl();
  Var header As CHtmlSeperator = New CHtmlSeperator("Konfigurierbare Schiffs-Versorgung");
  Html.Add(header);
  
  Var mainTextParagraph As CHtmlParagraph = New CHtmlParagraph();
  mainTextParagraph.Add("Dieses Script ermöglicht es, mehrere Schiffen einfach mit Energie, Crew und Waren zu versorgen.");
  mainTextParagraph.Add(New CHtmlBreak());
  mainTextParagraph.Add("Viele der Operationen in diesem Script sind ziemlich rechenzeitaufwändig, weswegen es vor allem bei größeren Flotten oder bei vielen ausgewählten Operationen schnell zu Abbrüchen durch Laufzeitüberschreitungen kommt. Das Script versucht, diesem vorzubeugen und vorher selbst anzuhalten, dies gelingt aber nicht immer. Wenn das Script abbricht, kann das Versorgen der Schiffe mit den gleichen Einstellungen erneut gestartet werden. In der Regel kann das Script dann mit dem nächsten noch nicht versorgten Schiff fortsetzen.");
  mainTextParagraph.Add(New CHtmlBreak());
  mainTextParagraph.Add("Die Option 'Nutze Station im Sektor' erhöht die Laufzeit erheblich und sollte nur verwendet werden, wenn Energie wirklich knapp ist oder nur wenige Schiffe versorgt werden und versorgen.");
  Html.Add(mainTextParagraph);
  
  Var formHeader As CHtmlSeperator = New CHtmlSeperator("Einstellungen");
  Html.Add(formHeader);
  
  Html.Add(createSupplyForm());
  
  Return Html;
}

Function buildCreditsMainArea(MainAreaCell As CTableCell) As CHtmlControl {
  Var Html As CHtmlControl = New CHtmlControl();
  Var header As CHtmlSeperator = New CHtmlSeperator("Credits");
  Html.Add(header);
  
  Var creditsParagraph As CHtmlParagraph = New CHtmlParagraph();
  creditsParagraph.Add("Dieses Script wurde von ");
  Var allianceTag As CHtmlSpan = New CHtmlSpan();
  allianceTag.Style.Add("font-weight", "bold");
  allianceTag.Style.Add("color", "DarkRed");
  allianceTag.Add("[]U.C.W[] ");
  creditsParagraph.Add(allianceTag);
  
  Var nameTag As CHtmlSpan = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "White");
  nameTag.Add("Scorga Empire ");
  creditsParagraph.Add(nameTag);
  
  Var idSpan As CHtmlSpan = New CHtmlSpan();
  idSpan.Add("(DE1-34108)");
  idSpan.CssClass = "deact";
  creditsParagraph.Add(idSpan);
  
  creditsParagraph.Add(" erstellt. Es kann frei verwendet und angepasst werden, solange dieser Hinweis erhalten bleibt.")
  creditsParagraph.Add(New CHtmlBreak());
  creditsParagraph.Add("Vielen Dank an ");
  
  allianceTag = New CHtmlSpan();
  allianceTag.Style.Add("font-weight", "bold");
  allianceTag.Style.Add("color", "DarkRed");
  allianceTag.Add("[]U.C.W[] ");
  creditsParagraph.Add(allianceTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "red");
  nameTag.Add("D");
  creditsParagraph.Add(nameTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "solver");
  nameTag.Add("e");
  creditsParagraph.Add(nameTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "red");
  nameTag.Add("M");
  creditsParagraph.Add(nameTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "solver");
  nameTag.Add("a");
  creditsParagraph.Add(nameTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "red");
  nameTag.Add("ND");
  creditsParagraph.Add(nameTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "solver");
  nameTag.Add("r");
  creditsParagraph.Add(nameTag);
  
  nameTag = New CHtmlSpan();
  nameTag.Style.Add("font-weight", "bold");
  nameTag.Style.Add("color", "red");
  nameTag.Add("ED ");
  creditsParagraph.Add(nameTag);
  
  idSpan = New CHtmlSpan();
  idSpan.Add("(DE1-72439)");
  idSpan.CssClass = "deact";
  creditsParagraph.Add(idSpan);
  
  creditsParagraph.Add(", dass er mich solange damit genervt hat, bis ich es tatsächlich geschrieben habe ;-)")
  
  Html.Add(creditsParagraph);
  
  Return Html;
}

Function positionToString(position As SMapPosition) As String {
  Var s As New CStringBuilder();
  If(position.InOrbit) {
    s.Append("@");
  }
  s.Append(position.Coords.X);
  s.Append("|");
  s.Append(position.Coords.Y);
  
  // TODO: Add map when not default map
  
  Return CStr(s);
}

Function validSector(position As SMapPosition) As Boolean {
  Return position.Coords.X > 0 And position.Coords.Y > 0;
}

Function findStation(ship As CMyShip) As CShip {
  Var other As CShip;
  For(Each other In ship.SRS) {
    If(other.Definition.IsSpaceStation) {
      Return other;
    }
  }
  Return Null;
}

Function filterShipList(sector As SMapPosition, ships As CShipList, isSupplier As Boolean) As CShipList {
  // copy collection so we can modify it during iteration
  Var copy As New CShipList();
  
  Var ship As CMyShip;
  For(Each ship In ships) {
    If(ship.MapPosition <> sector) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " befindet sich nicht an Position " & positionToString(sector) & " und wird ignoriert.");
    } ElseIf(isSupplier And not ship.MainComputerIsActive) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " hat den Hauptcomputer nicht aktiv und wird ignoriert.");
    } ElseIf(ship.TractorFromShipID > 0) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " wird im Traktorstrahl gehalten und wird ignoriert.");
    } ElseIf(ship.TractorToShipID > 0) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " hält ein anderes Schiff im Traktorstrahl und wird ignoriert.");
    } ElseIf(isSupplier And ship.IsDisabled) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist kampfunfähig und kann nicht zum Versorgen verwendet werden. Es wird ignoriert.");
    } Else {
      copy.Add(ship);
    }
  }
  
  Return copy;
}

Function dockSuppliedShip(station As CShip, myStation As CMyShip, ship As CMyShip) {
  If(ship.DockedToShipID = station.ShipID) {
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist schon an " & station.GetNameTextAndID() & " angedockt.");
    }
    Return;
  } ElseIf( not station.FreeDockingPorts(ship)) {
    PageLog.WriteLine(station.GetNameTextAndID() & " hat nicht genügend Dockplätze, um " & ship.GetNameTextAndID() & " andocken zu lassen.");
    Return;
  } ElseIf(ship.DockedToShipID > 0) {
    PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist noch an " & ship.DockedTo.GetNameTextAndID() & " angedockt! Versuche abzudocken.");
    ship.Action.Undock();
    If(ship.DockedToShipID > 0) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " konnte nicht abgedockt werden. Versorge Schiff, ohne die Station zu nutzen.");
      Return;
    }
  }
  
  If(debug) {
    PageLog.WriteLine("Versuche, Schiff " & ship.GetNameTextAndID() & " an " & station.GetNameTextAndID() & " anzudocken.");
  }
  
  ship.Action.DockTo(station.ShipID);
  If(ship.DockedToShipID = station.ShipID) {
    PageLog.WriteLine(ship.GetNameTextAndID() & " dockt an " & station.GetNameTextAndID() & ".");
    Return;
  }
  
  // Docking hat nicht geklappt, versuche Zwangs-Andocken, wenn möglich.
  Var myStationUnavailable As Boolean = (myStation is Null);
  If( not myStationUnavailable) {
    If(debug) {
      PageLog.WriteLine("Versuche, Schiff " & ship.GetNameTextAndID() & " per Traktortrahl an " & myStation.GetNameTextAndID() & " anzudocken.");
    }
    myStation.Action.ActivateTractorBeam(ship.ShipID);
    myStation.Action.DockToForce(ship.ShipID);
  }
  
  If(ship.DockedToShipID = station.ShipID) {
    PageLog.WriteLine(ship.GetNameTextAndID() & " wird per Traktorstrahl an " & station.GetNameTextAndID() & " angedockt.");
    Return;
  }
  
  PageLog.WriteLine(ship.GetNameTextAndID() & " konnte nicht an " & station.GetNameTextAndID() & " angedockt werden.");
  
  Return;
}

Function dockSupplierShip(station As CShip, ship As CMyShip) {
  If(ship.Definition.IsSpaceStation Or ship.Definition.IsCarrier) {
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " kann nicht andocken, da es eine Raumstation / ein Trägerschiff ist.");
    }
    Return;
  } ElseIf(ship.DockedToShipID = station.ShipID) {
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist schon an " & station.GetNameTextAndID() & " angedockt.");
    }
    Return;
  } ElseIf( not station.FreeDockingPorts(ship)) {
    PageLog.WriteLine(station.GetNameTextAndID() & " hat nicht genügend Dockplätze, um " & ship.GetNameTextAndID() & " andocken zu lassen.");
    Return;
  } ElseIf(ship.DockedToShipID > 0) {
    PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist noch an " & ship.DockedTo.GetNameTextAndID() & " angedockt! Versuche abzudocken.");
    ship.Action.Undock();
    If(ship.DockedToShipID > 0) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " konnte nicht abgedockt werden. Versorge Schiff, ohne die Station zu nutzen.");
      Return;
    }
  }
  
  If(debug) {
    PageLog.WriteLine("Versuche, Schiff " & ship.GetNameTextAndID() & " an " & station.GetNameTextAndID() & " anzudocken.");
  }
  
  ship.Action.DockTo(station.ShipID);
  If(ship.DockedToShipID = station.ShipID) {
    If(debug) {
      PageLog.WriteLine(ship.GetNameTextAndID() & " dockt an " & station.GetNameTextAndID() & ".");
    }
    Return;
  }
  
  PageLog.WriteLine(ship.GetNameTextAndID() & " konnte nicht an " & station.GetNameTextAndID() & " angedockt werden.");
  
  Return;
}

Function undockSuppliedShip(station As CShip, myStation As CMyShip, ship As CMyShip) {
  If(ship.DockedToShipID <> station.ShipID) {
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist nicht an " & station.GetNameTextAndID() & " angedockt.");
    }
    Return;
  }
  
  ship.Action.Undock();
  
  Var myStationUnavailable As Boolean = (myStation is Null);
  If(ship.DockedToShipID = station.ShipID And not myStationUnavailable) {
    myStation.Action.UndockForce(ship.ShipID);
  }
  
  If(ship.DockedToShipID = station.ShipID) {
    PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " konnte nicht abgedockt werden.");
    Return;
  }
  
  PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " dockt von " & station.GetNameTextAndID() & " ab.");
}

Function undockSupplierShip(station As CShip, ship As CMyShip) {
  If(ship.DockedToShipID <> station.ShipID) {
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " ist nicht an " & station.GetNameTextAndID() & " angedockt.");
    }
    Return;
  }
  
  ship.Action.Undock();
  
  If(ship.DockedToShipID = station.ShipID) {
    PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " konnte nicht abgedockt werden.");
    Return;
  }
  
  If(debug) {
    PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " dockt von " & station.GetNameTextAndID() & " ab.");
  }
}

Function isTorpedo(resource As CGoodsInfo) As Boolean {
  Return torpedoGoodsIDList.Contains(resource.GoodsID);
}

Function getRequirements(ship As CMyShip) As CStringObjectHashTable {
  Var requirements As New CStringObjectHashTable();
  If(Request.Form.ContainsKey("send-crew")) {
    Var crewMode As String = Request.Form.Item("crew-mode");
    Var requiredCrew As Integer = 0;
    
    If(crewMode = "full") {
      requiredCrew = ship.Definition.Crew - ship.Crew;
    } ElseIf (crewMode = "base" or crewMode = "") {
      requiredCrew = ship.Definition.CrewBasis - ship.Crew;
    } ElseIf (crewMode = "fixed") {
      requiredCrew = CInt(Request.Form.Item("crew-fixed-amount")) - ship.Crew;
    }
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " benötigt " & CStr(requiredCrew) & " Crew.");
    }
    If(requiredCrew > 0) {
      requirements.Add("crew", requiredCrew);
    }
  }
  If(Request.Form.ContainsKey("send-energy")) {
    Var energyMode As String = Request.Form.Item("energy-mode");
    Var requiredEnergy As Double = 0;
    
    If(energyMode = "full") {
      requiredEnergy = ship.Definition.Energy - ship.Energy;
    } ElseIf (energyMode = "computer" or energyMode = "") {
      requiredEnergy = ship.Definition.Slots * 2 - ship.Energy;
    } ElseIf (energyMode = "fixed") {
      requiredEnergy = Double.Parse(Request.Form.Item("energy-fixed-amount")) - ship.Energy;
    } ElseIf (energyMode = "fixed-left") {
      requiredEnergy = Math.Min(ship.Eps - Double.Parse(Request.Form.Item("energy-supplied-buffer")), ship.Definition.Energy - ship.Energy);
    }
    
    requiredEnergy = Math.Min(requiredEnergy, ship.Eps);
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " benötigt " & CStr(requiredEnergy) & " Energie.");
    }
    If(requiredEnergy > 0) {
      requirements.Add("energy", requiredEnergy);
    }
  }
  If(Request.Form.ContainsKey("send-warpcore")) {
    Var warpcoreMode As String = Request.Form.Item("warpcore-mode");
    Var requiredWarpcore As Double = 0;
    
    If(warpcoreMode = "full" or warpcoreMode = "") {
      requiredWarpcore = ship.Definition.WarpCore - ship.WarpCore;
    } ElseIf(warpcoreMode = "fixed") {
      requiredWarpcore = Double.Parse(Request.Form.Item("warpcore-fixed-amount")) - ship.WarpCore;
    }
    
    If(debug) {
      PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " benötigt " & CStr(requiredWarpcore) & " Warpkern.");
    }
    If(requiredWarpcore > 0) {
      requirements.Add("warpcore", requiredWarpcore);
    }
  }
  If(Request.Form.ContainsKey("send-resources")) {
    Var resources As New CGoodsInfoEnumerator();
    Var resource As CGoodsInfo;
    Var freeStorage As Integer = ship.StockRoom.FreeStorage();
    Var torpedoStorage As Integer = ship.StockRoom.FreeStorage(EGoodsType.PhotonTorpedoes);
    While(resources.Next()) {
      resource = resources.CurrentWarenInfo;
      Var torpedo As Boolean = isTorpedo(resource);
      Var requiredResource As Integer = Int32.Parse(Request.Form.Item("resource-" & CStr(resource.GoodsID))) - ship.StockRoom.Amount(resource.GoodsType);
      requiredResource = Math.Min(requiredResource, freeStorage);
      If(torpedo) {
        requiredResource = Math.Min(requiredResource, torpedoStorage);
      }
      If(requiredResource > 0) {
        If(debug) {
          PageLog.WriteLine("Schiff " & ship.GetNameTextAndID() & " benötigt " & CStr(requiredResource) & " " & resource.Name & ".");
        }
        freeStorage = freeStorage - requiredResource;
        If(torpedo) {
          torpedoStorage = torpedoStorage - requiredResource;
        } Else {
          torpedoStorage = Math.Min(torpedoStorage, freeStorage);
        }
        requirements.Add(CStr(resource.GoodsID), requiredResource);
      }
    }
  }
  If(Request.Form.ContainsKey("activate-computer") And Not ship.MainComputerIsActive) {
    requirements.Add("activate-computer", 1);
  }
  
  If(Request.Form.ContainsKey("activate-warpcore") And Not ship.WarpCoreIsActive) {
    requirements.Add("activate-warpcore", 1);
  }
  
  If(Request.Form.ContainsKey("activate-overdrive") And Not ship.OverdriveActive) {
    requirements.Add("activate-overdrive", 1);
  }
  
  If(Request.Form.ContainsKey("activate-shields") And Not ship.ShieldsActive) {
    requirements.Add("activate-shields", 1);
  }
  
  If(Request.Form.ContainsKey("set-alert-level")) {
    Var alertLevel As String = Request.Form.Item("alert-level");
    If(alertLevel <> CStr(ship.AlertLevel)) {
      requirements.Add("set-alert-level", 1);
    }
  }
  
  Return requirements;
}

Function printUnmetRequirements(unmetRequirements As CStringObjectHashTable) {
  PageLog.WriteLine("Folgende Versorgungsleistungen fehlen:");
  Var key As String;
  For(Each key In unmetRequirements.Keys) {
    Var value As Double = unmetRequirements.Item(key);
    If(key = "crew") {
      PageLog.WriteLine(CStr(value) & " Crew");
    } ElseIf(key = "energy") {
      PageLog.WriteLine(CStr(value) & " Energie");
    } ElseIf(key = "warpcore") {
      PageLog.WriteLine(CStr(value) & " Warpkern-Energie");
    } ElseIf(key = "activate-computer") {
      PageLog.WriteLine("Hauptcomputer konnte bei " & CStr(value) & " Schiffen nicht aktiviert werden.");
    } ElseIf(key = "activate-warpcore") {
      PageLog.WriteLine("Warpkern konnte bei " & CStr(value) & " Schiffen nicht aktiviert werden.");
    } ElseIf(key = "activate-overdrive") {
      PageLog.WriteLine("Overdrive konnt bei " & CStr(value) & " Schiffen nicht aktiviert werden.");
    } ElseIf(key = "activate-shields") {
      PageLog.WriteLine("Schilde konnten bei " & CStr(value) & " Schiffen nicht aktiviert werden.");
    } ElseIf(key = "set-alert-level") {
      PageLog.WriteLine("Alarmstufe bei " & CStr(value) & " Schiffen nicht eingestellt werden.");
    } Else {
      Var goods As New CGoodsInfo(Int32.Parse(key));
      PageLog.WriteLine(goods.Name & ": " & CStr(value));
    }
  }
}

// subtrahiert zwei Date-Objekte von einander (a - b) und gibt den Zeitunterschied in Sekunden zurück.
// Wäre nicht notwendig, wenn Date.Subtract in der Scripting-Engine nicht kaputt wäre...
Function subtractDates(a As Date, b As Date) As Double {
  Var timeDifference As Double = a.ToFileTime() - b.ToFileTime();
  // filetime ist in 100 ns-Intervallen gegeben, rechne in Sekunden um
  Return timeDifference / (10 * 1000 * 1000);
}

Function shipCanSupply(supplier As CMyShip, requirements As CStringObjectHashTable) As Boolean {
  Var crewReserve As Integer = Math.Ceiling(supplier.Definition.CrewBasis * Double.Parse(Request.Form.Item("crew-supplier-buffer")) / 100.0);
  If(requirements.ContainsKey("crew") and supplier.Crew - crewReserve > 0) {
    Return True;
  }
  If(requirements.ContainsKey("energy")) {
    Var energyBuffer As Double = Double.Parse(Request.Form.Item("energy-supplier-buffer"));
    If(supplier.Energy > energyBuffer + 0.01 And supplier.Eps > energyBuffer + 0.01) {
      Return True;
    }
  }
  If(requirements.ContainsKey("warpcore")) {
    Var warpcoreBuffer As Integer = Math.Ceiling(supplier.Definition.WarpCore / 10.0);
    If(supplier.WarpCore > warpcoreBuffer) {
      Return True;
    }
  }
  Var resources As New CGoodsInfoEnumerator();
  Var resource As CGoodsInfo;
  While(resources.Next()) {
    resource = resources.CurrentWarenInfo;
    If(requirements.ContainsKey(CStr(resource.GoodsID)) And supplier.StockRoom.Amount(resource.GoodsType) > 0) {
      Return True;
    }
  }
  Return False;
}

Function supplyCrew(supplier As CMyShip, supplied As CMyShip, requirements As CStringObjectHashTable) {
  Var crewReserve As Integer = Math.Ceiling(supplier.Definition.CrewBasis * Double.Parse(Request.Form.Item("crew-supplier-buffer")) / 100.0);
  If(supplier.Crew - crewReserve <= 0) {
    Return;
  }
  If( not requirements.ContainsKey("crew")) {
    Return;
  }
  Var requirement As Integer = requirements.Item("crew");
  Var transferAmount As Integer = Math.Min(requirement, supplier.Crew - crewReserve);
  supplier.Action.TransferToShip(supplied.ShipID, transferAmount, EBeamResource.Crew);
  requirements.Remove("crew");
  If(requirement - transferAmount > 0) {
    requirements.Add("crew", requirement - transferAmount);
  }
}

Function supplyEnergy(supplier As CMyShip, supplied As CMyShip, requirements As CStringObjectHashTable) {
  Var energyBuffer As Double = Double.Parse(Request.Form.Item("energy-supplier-buffer"));
  If(supplier.Energy < energyBuffer + 0.01 Or supplier.Eps < energyBuffer + 0.01) {
    Return;
  }
  If( not requirements.ContainsKey("energy")) {
    Return;
  }
  Var requirement As Double = requirements.Item("energy");
  Var transferAmount As Double = Math.Min(requirement, supplier.Energy - energyBuffer);
  transferAmount = Math.Min(transferAmount, supplier.Eps - energyBuffer);
  supplier.Action.TransferToShip(supplied.ShipID, transferAmount, EBeamResource.Energy);
  requirements.Remove("energy");
  If(requirement - transferAmount > 0) {
    requirements.Add("energy", requirement - transferAmount);
  }
}

Function supplyWarpCore(supplier As CMyShip, supplied As CMyShip, requirements As CStringObjectHashTable) {
  If(supplier.WarpCore <= Math.Ceiling(supplier.Definition.WarpCore / 10.0)) {
    Return;
  }
  If( not requirements.ContainsKey("warpcore")) {
    Return;
  }
  Var requirement As Double = requirements.Item("warpcore");
  Var transferAmount As Double = Math.Min(requirement, supplier.WarpCore - Math.Ceiling(supplier.Definition.WarpCore / 10.0));
  supplier.Action.TransferToShip(supplied.ShipID, transferAmount, EBeamResource.Warpcore);
  requirements.Remove("warpcore");
  If(requirement - transferAmount > 0) {
    requirements.Add("warpcore", requirement - transferAmount);
  }
}

Function supplyResources(supplier As CMyShip, supplied As CMyShip, requirements As CStringObjectHashTable) {
  Var resources As New CGoodsInfoEnumerator();
  Var resource As CGoodsInfo;
  While(resources.Next()) {
    resource = resources.CurrentWarenInfo;
    If(requirements.ContainsKey(CStr(resource.GoodsID)) And supplier.StockRoom.Amount(resource.GoodsType) > 0) {
      Var requirement As Integer = requirements.Item(CStr(resource.GoodsID));
      Var transferAmount As Double = Math.Min(requirement, supplier.StockRoom.Amount(resource.GoodsType));
      supplier.Action.TransferToShip(supplied.ShipID, transferAmount, resource.GoodsType);
      requirements.Remove(CStr(resource.GoodsID));
      If(requirement - transferAmount > 0) {
        requirements.Add(CStr(resource.GoodsID), requirement - transferAmount);
      }
    }
  }
}

Function additionalActions(suppliedShip As CMyShip, requirements As CStringObjectHashTable) {
  If(requirements.ContainsKey("activate-computer")) {
    suppliedShip.Action.ActivateMaincomputer(True);
    If(suppliedShip.MainComputerIsActive) {
      requirements.Remove("activate-computer");
    }
  }
  
  If(requirements.ContainsKey("activate-warpcore")) {
    suppliedShip.Action.ActivateWarpCore(True);
    If(suppliedShip.WarpCoreIsActive) {
      requirements.Remove("activate-warpcore");
    }
  }
  
  If(requirements.ContainsKey("activate-overdrive")) {
    suppliedShip.Action.ActivateOverdrive(True);
    If(suppliedShip.OverdriveActive) {
      requirements.Remove("activate-overdrive");
    }
  }
  
  If(requirements.ContainsKey("activate-shields")) {
    suppliedShip.Action.ActivateShields(True);
    If(suppliedShip.ShieldsActive) {
      requirements.Remove("activate-shields");
    }
  }
  
  If(requirements.ContainsKey("set-alert-level")) {
    Var alertLevel As String = Request.Form.Item("alert-level");
    If(alertLevel = "Green") {
      suppliedShip.Action.SetAlertLevel(EAlertLevel.Green);
    } ElseIf(alertLevel = "Yellow") {
      suppliedShip.Action.SetAlertLevel(EAlertLevel.Yellow);
    } ElseIf(alertLevel = "Red") {
      suppliedShip.Action.SetAlertLevel(EAlertLevel.Red);
    }
    
    If(CStr(suppliedShip.AlertLevel) = alertLevel) {
      requirements.Remove("set-alert-level");
    }
  }
}

Function executeSupply() {
  // Parse form values
  Var formValues As CStringHashTable = Request.Form;
  If( not formValues.ContainsKey("supplier") or formValues.Item("supplier") = "0") {
    PageLog.WriteLine("Bitte gebe eine Versorger-Flotte an!");
    Return;
  }
  Var supplierFleet As New CMyFleet(CInt(formValues.Item("supplier")));
  Var supplierShips As CShipList = supplierFleet.Ships;
  
  If(supplierShips.Count = 0) {
    PageLog.WriteLine("Die Versorger-Flotte ist leer.");
    Return;
  }
  
  If( not formValues.ContainsKey("supplied") or formValues.Item("supplied") = "0") {
    PageLog.WriteLine("Bitte gebe eine zu versorgende Flotte an!");
    Return;
  }
  Var suppliedFleet As New CMyFleet(CInt(formValues.Item("supplied")));
  Var suppliedShips As CShipList = suppliedFleet.Ships;
  
  If(suppliedShips.Count = 0) {
    PageLog.WriteLine("Die zu versorgende Flotte ist leer.");
    Return;
  }
  
  Var dockToStation As Boolean = formValues.ContainsKey('dock-to-station');
  
  Var supplierShip As CMyShip;
  Var suppliedShip As CMyShip;
  Var station As CShip;
  Var myStation As CMyShip;
  
  Var sector As SMapPosition = suppliedShips.Item(0).MapPosition;
  supplierShips = filterShipList(sector, supplierShips, True);
  suppliedShips = filterShipList(sector, suppliedShips, False);
  
  // Recheck as fleet size might have changed
  If(supplierShips.Count = 0) {
    PageLog.WriteLine("Die Versorger-Flotte ist leer.");
    Return;
  }
  
  If(suppliedShips.Count = 0) {
    PageLog.WriteLine("Die zu versorgende Flotte ist leer.");
    Return;
  }
  
  If(dockToStation) {
    Var s As CMyShip = supplierShips.My(0);
    station = findStation(s);
    If(station Is Null) {
      PageLog.WriteLine("In " & positionToString(sector) & " wurde keine nutzbare Raumstation gefunden. Versorge Schiffe ohne Station.");
      dockToStation = False;
    } Else {
      If(debug) {
        PageLog.WriteLine("Raumstation " & station.GetNameTextAndID() & " kontollierbar: " & CStr(station.CanControl));
      }
      If(station.CanControl) {
        myStation = New CMyShip(station.ShipID);
      } Else {
        PageLog.WriteLine("Raumstation " & station.GetNameTextAndID() & " steht nicht unter deiner Kontrolle. Schiffe können nicht per Traktorstrahl angedockt werden.");
      }
    }
  }
  
  Var unmetRequirements As New CStringObjectHashTable();
  Var fulfilledShips As Integer = 0;
  Var alreadyFulfilledShips As Integer = 0;
  Var unfulfilledShips As Integer = 0;
  
  For(Each suppliedShip In suppliedShips) {
    Var requirements As CStringObjectHashTable = getRequirements(suppliedShip);
    If(requirements.Count > 0) {
      If(dockToStation) {
        dockSuppliedShip(station, myStation, suppliedShip);
      }
      
      For(Each supplierShip In supplierShips) {
        If(shipCanSupply(supplierShip, requirements)) {
          If(debug) {
            PageLog.WriteLine("Schiff " & supplierShip.GetNameTextAndID() & " kann versorgen.");
          }
          
          If(dockToStation) {
            dockSupplierShip(station, supplierShip);
          }
          
          If(formValues.ContainsKey("send-crew")) {
            supplyCrew(supplierShip, suppliedShip, requirements);
          }
          
          If(formValues.ContainsKey("send-energy")) {
            supplyEnergy(supplierShip, suppliedShip, requirements);
          }
          
          If(formValues.ContainsKey("send-warpcore")) {
            supplyWarpCore(supplierShip, suppliedShip, requirements);
          }
          
          If(formValues.ContainsKey("send-resources")) {
            supplyResources(supplierShip, suppliedShip, requirements);
          }
          
          If(dockToStation) {
            If( not station.FreeDockingPorts(supplierShip)) {
              undockSupplierShip(station, supplierShip);
            }
          }
        }
      }
      
      additionalActions(suppliedShip, requirements);
      
      If(dockToStation) {
        undockSuppliedShip(station, myStation, suppliedShip);
      }
      
      //recheck requirements
      requirements = getRequirements(suppliedShip);
      If(requirements.Count = 0) {
        fulfilledShips++;
      } Else {
        unfulfilledShips++;
        Var requirementKey As String;
        For(Each requirementKey In requirements.Keys) {
          Var value As Double = requirements.Item(requirementKey);
          If( not unmetRequirements.ContainsKey(requirementKey)) {
            unmetRequirements.Add(requirementKey, value);
          } Else {
            Var oldValue As Double = unmetRequirements.Item(requirementKey);
            unmetRequirements.Remove(requirementKey);
            unmetRequirements.Add(requirementKey, value + oldValue);
          }
        }
      }
    } Else {
      alreadyFulfilledShips++;
    }
    
    Var runTimeCheck As Double = subtractDates(DateTime.Now, startDate);
    If(runTimeCheck > 14) {
      PageLog.WriteLine("Laufzeit-Grenze von 14 Sekunden überschritten. Das Script wird beim Neustart die Ausführung fortsetzen. Überprüfe vorher noch ein mal deine Einstellungen. Falls dies häufiger auftritt, verkleinere die Flottengröße oder verzichte darauf, die Station zu nutzen.");
      If(alreadyFulfilledShips > 0) {
        PageLog.WriteLine("Für " & CStr(alreadyFulfilledShips) & " Schiffe waren keine Aktionen notwendig.");
      }
      If(fulfilledShips > 0) {
        PageLog.WriteLine(CStr(fulfilledShips) & " Schiffe wurden vollständig versorgt.");
      }
      If(unfulfilledShips > 0) {
        PageLog.WriteLine(CStr(unfulfilledShips) & " bearbeitete Schiffe konnten nicht vollständig versorgt werden!");
        printUnmetRequirements(unmetRequirements);
      }
      Return;
    }
  }
  
  If(alreadyFulfilledShips > 0) {
    PageLog.WriteLine("Für " & CStr(alreadyFulfilledShips) & " Schiffe waren keine Aktionen notwendig.");
  }
  If(fulfilledShips > 0) {
    PageLog.WriteLine(CStr(fulfilledShips) & " Schiffe wurden vollständig versorgt.");
  }
  If(unfulfilledShips > 0) {
    PageLog.WriteLine(CStr(unfulfilledShips) & " Schiffe konnten nicht vollständig versorgt werden!");
    printUnmetRequirements(unmetRequirements);
  }
  
  PageLog.WriteLine("Ausführzeit: " & CStr(subtractDates(DateTime.Now, startDate)) & " Sekunden.");
}

main();