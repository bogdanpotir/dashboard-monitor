AGGIORNAMENTO DASHBOARD - MEDIA MENSILE PK

File da caricare/sostituire su GitHub:
- index.html
- style.css
- app.js

NON sostituire dati.json con questi file.
Il file dati.json deve essere rigenerato dal file Excel centrale dopo aver aggiornato il VBA.

Modifica VBA richiesta:
- il JSON ora deve contenere anche:
  "media_mensile_pk": <valore>
- il valore viene letto dal Report Tecnico, foglio del mese corrente, cella P35.

Nel foglio CONFIG del generatore puoi aggiungere:
A13 = Cella media mensile PK
B13 = P35

Se B13 resta vuota, il VBA aggiornato usa comunque P35 come valore predefinito.

Dopo aver aggiornato il VBA:
1. Esegui EsportaDatiDashboard.
2. Controlla che dati.json contenga media_mensile_pk.
3. Carica il nuovo dati.json su GitHub.
4. Carica anche i 3 file dashboard aggiornati.
5. Apri la dashboard e premi CTRL+F5.
