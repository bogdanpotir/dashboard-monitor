Option Explicit

Public ProssimoAggiornamento As Date
Public AutoAggiornamentoAttivo As Boolean

' ============================================================
' MACRO MANUALE
' Esegui questa da ALT + F8: EsportaDatiDashboard
' Alla fine mostra un messaggio di feedback.
' ============================================================
Public Sub EsportaDatiDashboard()
    EsportaDatiDashboardCore True
End Sub

' ============================================================
' MACRO PRINCIPALE
' Se MostraMessaggio = True mostra feedback finale.
' Se MostraMessaggio = False lavora in silenzio per aggiornamento automatico.
' ============================================================
Private Sub EsportaDatiDashboardCore(ByVal MostraMessaggio As Boolean)

    Dim wsC As Worksheet, wsP As Worksheet, wsT As Worksheet, wsLog As Worksheet
    Dim percorsoReport As String, percorsoColli As String
    Dim cartellaOut As String, nomeJson As String, percorsoJson As String
    Dim foglioReport As String, foglioColli As String
    Dim cellaEff As String, cellaMedia As String, cellaMediaMensilePK As String
    Dim rigaIni As Long, rigaFin As Long
    Dim colOra As String, colMedia As String
    Dim wbReport As Workbook, wbColli As Workbook
    Dim reportAperto As Boolean, colliAperto As Boolean
    Dim efficienza As Variant, mediaGiornaliera As Variant, mediaMensilePK As Variant
    Dim jsonTrend As String, json As String
    Dim stato As String
    Dim numeroPuntiTrend As Long

    On Error GoTo GestioneErrore

    Set wsC = ThisWorkbook.Worksheets("CONFIG")
    Set wsP = ThisWorkbook.Worksheets("ANTEPRIMA_DATI")
    Set wsT = ThisWorkbook.Worksheets("TREND_ORARIO")
    Set wsLog = ThisWorkbook.Worksheets("LOG")

    percorsoReport = PulisciPercorso(CStr(wsC.Range("B2").Value))
    percorsoColli = PulisciPercorso(CStr(wsC.Range("B3").Value))
    cartellaOut = PulisciPercorso(CStr(wsC.Range("B4").Value))
    nomeJson = Trim(CStr(wsC.Range("B5").Value))

    cellaEff = Trim(CStr(wsC.Range("B6").Value))
    cellaMedia = Trim(CStr(wsC.Range("B7").Value))
    rigaIni = CLng(wsC.Range("B8").Value)
    rigaFin = CLng(wsC.Range("B9").Value)
    colOra = Trim(CStr(wsC.Range("B10").Value))
    colMedia = Trim(CStr(wsC.Range("B11").Value))

    ' Nuovo dato: Media mensile PK dal Report Tecnico.
    ' Se CONFIG!B13 è vuota, usa P35 come valore predefinito.
    cellaMediaMensilePK = Trim(CStr(wsC.Range("B13").Value))
    If cellaMediaMensilePK = "" Then cellaMediaMensilePK = "P35"

    If nomeJson = "" Then nomeJson = "dati.json"
    If cartellaOut = "" Then cartellaOut = ThisWorkbook.Path
    If cartellaOut = "" Then Err.Raise vbObjectError + 100, , "Salva prima il file centrale oppure indica una cartella output in CONFIG!B4."

    CreaCartellaSeManca cartellaOut

    percorsoJson = cartellaOut & Application.PathSeparator & nomeJson

    If percorsoReport = "" Or Dir(percorsoReport) = "" Then
        Err.Raise vbObjectError + 101, , "File Report Tecnico non trovato. Controlla CONFIG!B2."
    End If

    If percorsoColli = "" Or Dir(percorsoColli) = "" Then
        Err.Raise vbObjectError + 102, , "File Colli Giornalieri non trovato. Controlla CONFIG!B3."
    End If

    If cellaEff = "" Then Err.Raise vbObjectError + 103, , "Cella efficienza mancante. Controlla CONFIG!B6."
    If cellaMedia = "" Then Err.Raise vbObjectError + 104, , "Cella media giornaliera mancante. Controlla CONFIG!B7."
    If cellaMediaMensilePK = "" Then Err.Raise vbObjectError + 108, , "Cella media mensile PK mancante. Controlla CONFIG!B13."
    If rigaIni <= 0 Or rigaFin <= 0 Or rigaFin < rigaIni Then Err.Raise vbObjectError + 105, , "Righe trend orario non valide. Controlla CONFIG!B8 e CONFIG!B9."
    If colOra = "" Then Err.Raise vbObjectError + 106, , "Colonna ora mancante. Controlla CONFIG!B10."
    If colMedia = "" Then Err.Raise vbObjectError + 107, , "Colonna media oraria mancante. Controlla CONFIG!B11."

    foglioColli = Format(Date, "dd-mm-yyyy")
    foglioReport = NomeMeseItaliano(Date) & " " & Year(Date)

    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.DisplayAlerts = False

    Set wbReport = ApriWorkbookSolaLettura(percorsoReport, reportAperto)
    Set wbColli = ApriWorkbookSolaLettura(percorsoColli, colliAperto)

    efficienza = LeggiCellaDaFoglio(wbReport, foglioReport, cellaEff)
    mediaMensilePK = LeggiCellaDaFoglio(wbReport, foglioReport, cellaMediaMensilePK)
    mediaGiornaliera = LeggiCellaDaFoglio(wbColli, foglioColli, cellaMedia)

    efficienza = NormalizzaEfficienza(efficienza)

    jsonTrend = CreaTrendJson(wbColli, foglioColli, colOra, colMedia, rigaIni, rigaFin, wsT, numeroPuntiTrend)

    wsP.Range("B2").Value = efficienza
    wsP.Range("B3").Value = mediaGiornaliera
    wsP.Range("B4").Value = foglioReport
    wsP.Range("B5").Value = foglioColli
    wsP.Range("B6").Value = Now
    wsP.Range("B7").Value = percorsoJson
    wsP.Range("B8").Value = mediaMensilePK

    json = "{" & vbCrLf & _
           "  ""efficienza_mensile"": " & JsonNumber(efficienza) & "," & vbCrLf & _
           "  ""media_giornaliera"": " & JsonNumber(mediaGiornaliera) & "," & vbCrLf & _
           "  ""media_mensile_pk"": " & JsonNumber(mediaMensilePK) & "," & vbCrLf & _
           "  ""foglio_report"": " & JsonString(foglioReport) & "," & vbCrLf & _
           "  ""foglio_colli"": " & JsonString(foglioColli) & "," & vbCrLf & _
           "  ""ultimo_aggiornamento"": " & JsonString(Format(Now, "dd/mm/yyyy hh:nn:ss")) & "," & vbCrLf & _
           "  ""trend_orario"": " & jsonTrend & vbCrLf & _
           "}"

    SalvaTestoUtf8 percorsoJson, json

    stato = "OK - JSON creato"
    ScriviLog wsLog, stato, percorsoJson

Uscita:
    On Error Resume Next

    If Not wbReport Is Nothing Then
        If reportAperto = False Then wbReport.Close SaveChanges:=False
    End If

    If Not wbColli Is Nothing Then
        If colliAperto = False Then wbColli.Close SaveChanges:=False
    End If

    Application.DisplayAlerts = True
    Application.EnableEvents = True
    Application.ScreenUpdating = True

    On Error GoTo 0

    If MostraMessaggio Then
        If Left(stato, 6) = "ERRORE" Then
            MsgBox "Esportazione NON completata." & vbCrLf & vbCrLf & _
                   stato, vbExclamation, "Dashboard Monitor"
        Else
            MsgBox "Esportazione completata correttamente." & vbCrLf & vbCrLf & _
                   "File creato/aggiornato:" & vbCrLf & percorsoJson & vbCrLf & vbCrLf & _
                   "Foglio Report: " & foglioReport & vbCrLf & _
                   "Efficienza mensile: " & ValorePerMessaggio(efficienza) & vbCrLf & _
                   "Media mensile PK: " & ValorePerMessaggio(mediaMensilePK) & vbCrLf & vbCrLf & _
                   "Foglio Colli: " & foglioColli & vbCrLf & _
                   "Media giornaliera: " & ValorePerMessaggio(mediaGiornaliera) & vbCrLf & _
                   "Punti trend orario esportati: " & numeroPuntiTrend, _
                   vbInformation, "Dashboard Monitor"
        End If
    End If

    Exit Sub

GestioneErrore:
    stato = "ERRORE: " & Err.Description

    On Error Resume Next
    If Not wsLog Is Nothing Then ScriviLog wsLog, stato, ""
    If Not wsP Is Nothing Then wsP.Range("B6").Value = stato
    On Error GoTo 0

    Resume Uscita

End Sub

' ============================================================
' APERTURA FILE SORGENTI
' ============================================================
Private Function ApriWorkbookSolaLettura(ByVal percorso As String, ByRef giaAperto As Boolean) As Workbook

    Dim wb As Workbook
    Dim nomeFile As String

    nomeFile = Dir(percorso)
    giaAperto = False

    For Each wb In Application.Workbooks
        If LCase(wb.Name) = LCase(nomeFile) Then
            Set ApriWorkbookSolaLettura = wb
            giaAperto = True
            Exit Function
        End If
    Next wb

    Set ApriWorkbookSolaLettura = Workbooks.Open(Filename:=percorso, ReadOnly:=True, UpdateLinks:=0)

End Function

' ============================================================
' LETTURA CELLA DA FOGLIO
' ============================================================
Private Function LeggiCellaDaFoglio(ByVal wb As Workbook, ByVal nomeFoglio As String, ByVal indirizzoCella As String) As Variant

    Dim ws As Worksheet

    On Error Resume Next
    Set ws = wb.Worksheets(nomeFoglio)
    On Error GoTo 0

    If ws Is Nothing Then
        Err.Raise vbObjectError + 201, , "Foglio '" & nomeFoglio & "' non trovato nel file '" & wb.Name & "'."
    End If

    LeggiCellaDaFoglio = ws.Range(indirizzoCella).Value

End Function

' ============================================================
' CREAZIONE TREND JSON
' ============================================================
Private Function CreaTrendJson(ByVal wb As Workbook, _
                               ByVal nomeFoglio As String, _
                               ByVal colOra As String, _
                               ByVal colMedia As String, _
                               ByVal rigaIni As Long, _
                               ByVal rigaFin As Long, _
                               ByVal wsTrend As Worksheet, _
                               ByRef numeroPuntiTrend As Long) As String

    Dim ws As Worksheet
    Dim r As Long, outRow As Long
    Dim oraVal As Variant, mediaVal As Variant
    Dim parti As Collection

    Set parti = New Collection
    numeroPuntiTrend = 0

    wsTrend.Range("A2:D200").ClearContents
    wsTrend.Range("A1:D1").Value = Array("Ora", "Media", "Foglio", "Aggiornato")

    On Error Resume Next
    Set ws = wb.Worksheets(nomeFoglio)
    On Error GoTo 0

    If ws Is Nothing Then
        Err.Raise vbObjectError + 202, , "Foglio '" & nomeFoglio & "' non trovato nel file '" & wb.Name & "'."
    End If

    outRow = 2

    For r = rigaIni To rigaFin

        oraVal = ws.Range(colOra & r).Value
        mediaVal = ws.Range(colMedia & r).Value

        If Trim(CStr(oraVal)) <> "" And IsNumeric(mediaVal) Then

            parti.Add "{""ora"":" & JsonString(OraToText(oraVal)) & ",""media"":" & JsonNumber(mediaVal) & "}"

            wsTrend.Cells(outRow, 1).Value = OraToText(oraVal)
            wsTrend.Cells(outRow, 2).Value = mediaVal
            wsTrend.Cells(outRow, 3).Value = nomeFoglio
            wsTrend.Cells(outRow, 4).Value = Now

            outRow = outRow + 1
            numeroPuntiTrend = numeroPuntiTrend + 1

        End If

    Next r

    If parti.Count = 0 Then
        CreaTrendJson = "[]"
    Else
        CreaTrendJson = "[" & JoinCollection(parti, ",") & "]"
    End If

End Function

' ============================================================
' UTILITY
' ============================================================
Private Function JoinCollection(ByVal col As Collection, ByVal separatore As String) As String

    Dim i As Long
    Dim s As String

    For i = 1 To col.Count
        If i > 1 Then s = s & separatore
        s = s & CStr(col.Item(i))
    Next i

    JoinCollection = s

End Function

Private Function NomeMeseItaliano(ByVal d As Date) As String

    Dim mesi As Variant

    mesi = Array("Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", _
                 "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre")

    NomeMeseItaliano = mesi(Month(d) - 1)

End Function

Private Function NormalizzaEfficienza(ByVal v As Variant) As Variant

    If IsError(v) Then
        NormalizzaEfficienza = v
    ElseIf IsNumeric(v) Then
        If CDbl(v) > 0 And CDbl(v) <= 2 Then
            NormalizzaEfficienza = CDbl(v) * 100
        Else
            NormalizzaEfficienza = CDbl(v)
        End If
    Else
        NormalizzaEfficienza = v
    End If

End Function

Private Function OraToText(ByVal v As Variant) As String

    On Error GoTo TestoNormale

    If IsDate(v) Then
        OraToText = Format(CDate(v), "hh:nn")
    ElseIf IsNumeric(v) Then
        If CDbl(v) >= 0 And CDbl(v) < 1 Then
            OraToText = Format(CDbl(v), "hh:nn")
        ElseIf CDbl(v) >= 0 And CDbl(v) <= 24 Then
            OraToText = Format(TimeSerial(CLng(CDbl(v)), 0, 0), "hh:nn")
        Else
            OraToText = CStr(v)
        End If
    Else
        OraToText = CStr(v)
    End If

    Exit Function

TestoNormale:
    OraToText = CStr(v)

End Function

' ============================================================
' JSON CORRETTO
' Questa funzione evita valori non validi tipo 0.
' ============================================================
Private Function JsonNumber(ByVal v As Variant) As String

    Dim d As Double
    Dim s As String

    If IsError(v) Then
        JsonNumber = "null"
    ElseIf Trim(CStr(v)) = "" Then
        JsonNumber = "null"
    ElseIf Not IsNumeric(v) Then
        JsonNumber = "null"
    Else
        d = CDbl(v)
        s = Trim(Str(d)) ' Str usa il punto come separatore decimale

        If Right(s, 1) = "." Then
            s = Left(s, Len(s) - 1)
        End If

        If Left(s, 1) = "." Then
            s = "0" & s
        End If

        If Left(s, 2) = "-." Then
            s = "-0" & Mid(s, 2)
        End If

        JsonNumber = s
    End If

End Function

Private Function JsonString(ByVal s As String) As String

    s = Replace(s, "\", "\\")
    s = Replace(s, Chr(34), "\" & Chr(34))
    s = Replace(s, vbCrLf, "\n")
    s = Replace(s, vbCr, "\n")
    s = Replace(s, vbLf, "\n")

    JsonString = Chr(34) & s & Chr(34)

End Function

Private Function PulisciPercorso(ByVal s As String) As String

    PulisciPercorso = Replace(Trim(s), Chr(34), "")

End Function

Private Sub SalvaTestoUtf8(ByVal percorso As String, ByVal testo As String)

    Dim stream As Object

    Set stream = CreateObject("ADODB.Stream")

    stream.Type = 2
    stream.Charset = "utf-8"
    stream.Open
    stream.WriteText testo
    stream.SaveToFile percorso, 2
    stream.Close

End Sub

Private Sub ScriviLog(ByVal wsLog As Worksheet, ByVal stato As String, ByVal dettaglio As String)

    Dim r As Long

    r = wsLog.Cells(wsLog.Rows.Count, 1).End(xlUp).Row + 1
    If r < 2 Then r = 2

    wsLog.Cells(r, 1).Value = Now
    wsLog.Cells(r, 2).Value = stato
    wsLog.Cells(r, 3).Value = dettaglio
    wsLog.Cells(r, 4).Value = Environ("Username")

End Sub

Private Function ValorePerMessaggio(ByVal v As Variant) As String

    If IsError(v) Then
        ValorePerMessaggio = "ERRORE"
    ElseIf IsNumeric(v) Then
        ValorePerMessaggio = Replace(Format(CDbl(v), "0.00"), ".", ",")
    ElseIf Trim(CStr(v)) = "" Then
        ValorePerMessaggio = "vuoto"
    Else
        ValorePerMessaggio = CStr(v)
    End If

End Function

' ============================================================
' CREA CARTELLA OUTPUT SE NON ESISTE
' Supporta anche percorsi con più sottocartelle.
' ============================================================
Private Sub CreaCartellaSeManca(ByVal percorsoCartella As String)

    Dim parti As Variant
    Dim i As Long
    Dim percorsoProgressivo As String

    percorsoCartella = PulisciPercorso(percorsoCartella)

    If percorsoCartella = "" Then Exit Sub
    If Dir(percorsoCartella, vbDirectory) <> "" Then Exit Sub

    parti = Split(percorsoCartella, "\")

    percorsoProgressivo = parti(0)

    For i = 1 To UBound(parti)
        percorsoProgressivo = percorsoProgressivo & "\" & parti(i)

        If Dir(percorsoProgressivo, vbDirectory) = "" Then
            MkDir percorsoProgressivo
        End If
    Next i

End Sub

' ============================================================
' AGGIORNAMENTO AUTOMATICO
' ============================================================
Public Sub AvviaAggiornamentoAutomatico()

    AutoAggiornamentoAttivo = True
    EsportaDatiDashboardCore False
    PianificaProssimoAggiornamento

End Sub

Public Sub PianificaProssimoAggiornamento()

    Dim minuti As Long

    If AutoAggiornamentoAttivo = False Then Exit Sub

    On Error Resume Next
    minuti = CLng(ThisWorkbook.Worksheets("CONFIG").Range("B12").Value)
    On Error GoTo 0

    If minuti <= 0 Then minuti = 10

    ProssimoAggiornamento = Now + TimeSerial(0, minuti, 0)

    Application.OnTime EarliestTime:=ProssimoAggiornamento, _
                       Procedure:="EseguiAggiornamentoAutomatico", _
                       Schedule:=True

End Sub

Public Sub EseguiAggiornamentoAutomatico()

    If AutoAggiornamentoAttivo = False Then Exit Sub

    EsportaDatiDashboardCore False
    PianificaProssimoAggiornamento

End Sub

Public Sub FermaAggiornamentoAutomatico()

    On Error Resume Next

    AutoAggiornamentoAttivo = False

    Application.OnTime EarliestTime:=ProssimoAggiornamento, _
                       Procedure:="EseguiAggiornamentoAutomatico", _
                       Schedule:=False

    On Error GoTo 0

End Sub
