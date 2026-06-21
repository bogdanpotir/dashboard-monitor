AGGIORNAMENTO DASHBOARD - TARGET MEDIA 110

Carica su GitHub questi 3 file:
- index.html
- style.css
- app.js

Modifiche incluse:
1. Il riquadro Media giornaliera cambia colore in base al target 110.
   - 110 = colore base simile al riquadro Efficienza
   - -10% o meno = rosso pieno
   - +10% o più = verde pieno
   - valori intermedi = gradiente progressivo

2. Accanto alla Media giornaliera viene mostrato lo scostamento percentuale rispetto a 110.
   Formula: (media - 110) / 110.

3. Il grafico include una linea target a 110.

4. La linea del grafico e i punti sono colorati secondo la stessa logica:
   sotto 110 tende al rosso, intorno a 110 tende al colore base, sopra 110 tende al verde.

5. Le ore future a zero continuano a essere escluse dal grafico.

Dopo il commit su GitHub, attendi 1-3 minuti e premi CTRL + F5 sulla pagina.
