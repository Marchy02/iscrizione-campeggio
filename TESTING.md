# ✅ CHECKLIST TEST SISTEMA CAMPEGGI v2.0

## 🎯 Obiettivo
Questa checklist garantisce che tutte le funzionalità critiche del sistema siano operative prima del lancio in produzione.

---

## 📋 FASE 1: SETUP INIZIALE

### Database
- [ ] Tabella `turni` creata correttamente
- [ ] Tabella `iscrizioni` creata correttamente
- [ ] Tabella `email_queue` creata correttamente
- [ ] Trigger `trigger_ricalcola_posti_*` attivi
- [ ] Funzione `crea_iscrizione` eseguibile
- [ ] Funzione `cancella_iscrizione` eseguibile
- [ ] Funzione `promuovi_iscrizione` eseguibile
- [ ] Funzione `get_turno_stats` eseguibile
- [ ] RLS abilitato su tutte le tabelle
- [ ] Policy "Turni attivi leggibili da tutti" attiva
- [ ] Policy "Nessuna scrittura diretta iscrizioni" attiva
- [ ] Dati seed (3 turni) inseriti

**Test SQL:**
```sql
-- Verifica tabelle
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('turni', 'iscrizioni', 'email_queue');

-- Verifica turni
SELECT * FROM turni WHERE attivo = true;

-- Verifica trigger
SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trigger_ricalcola%';

-- Verifica RLS
SELECT tablename, rowsecurity FROM pg_tables 
WHERE schemaname = 'public';
```

### Utente Admin
- [ ] Utente admin creato in Authentication
- [ ] Email confermata
- [ ] `user_metadata.role = "admin"` impostato
- [ ] Login funzionante

**Test:**
1. Vai su admin.html
2. Login con credenziali admin
3. Verifica accesso pannello

### Frontend
- [ ] `SUPABASE_URL` aggiornato in tutti i file
- [ ] `SUPABASE_ANON_KEY` aggiornato in tutti i file
- [ ] File caricati su GitHub
- [ ] GitHub Pages attivo
- [ ] Sito accessibile da browser

---

## 📋 FASE 2: TEST FUNZIONALI

### Test 1: Caricamento Turni (Homepage)

**Obiettivo:** Verificare che i turni vengano visualizzati correttamente

**Passi:**
1. [ ] Apri homepage (index.html)
2. [ ] Verifica che appaia "Caricamento turni..."
3. [ ] Verifica che i 3 turni vengano visualizzati
4. [ ] Verifica date formattate correttamente in italiano
5. [ ] Verifica posti disponibili mostrati
6. [ ] Verifica stile grafico corretto

**Risultato Atteso:**
- 3 card turni visibili
- Date formato "15 giugno 2025"
- Posti "30 posti disponibili"
- Nessun errore in console (F12)

**Errori Comuni:**
- "Failed to fetch": URL Supabase errato
- Turni vuoti: Esegui `backend/04-seed.sql`

---

### Test 2: Iscrizione Confermata (Posto Disponibile)

**Obiettivo:** Verificare iscrizione atomica con posto disponibile

**Passi:**
1. [ ] Click "Iscriviti ora" su primo turno
2. [ ] Verifica caricamento info turno
3. [ ] Compila form completo:
   - Nome: Mario
   - Cognome: Rossi
   - Data nascita: 15/03/2015
   - Sesso: M
   - Email: mario.rossi@test.com
   - Telefono: 333-1234567
   - Indirizzo: Via Roma 1
   - Città: Verona
   - CAP: 37100
   - Contatto emergenza: Paolo Rossi
   - Tel emergenza: 333-7654321
   - ✓ Consenso privacy
4. [ ] Click "Conferma Iscrizione"
5. [ ] Verifica modal "Iscrizione Confermata"
6. [ ] Verifica messaggio "Il tuo posto è confermato"

**Verifica Database:**
```sql
-- Deve esserci 1 iscrizione CONFIRMED
SELECT * FROM iscrizioni WHERE email = 'mario.rossi@test.com';

-- Posti occupati deve essere 1
SELECT posti_occupati FROM turni WHERE id = 1;

-- Email in coda
SELECT * FROM email_queue WHERE email_to = 'mario.rossi@test.com';
```

**Risultato Atteso:**
- Modal conferma visibile
- Status = 'CONFIRMED'
- posizione_lista = NULL
- posti_occupati = 1
- Email in coda con type = 'CONFERMA'

---

### Test 3: Riempimento Turno

**Obiettivo:** Verificare conteggio posti automatico

**Passi:**
1. [ ] Ripeti iscrizioni fino a raggiungere 30 posti
   (Usa email diverse: test1@test.com, test2@test.com, ecc.)
2. [ ] Dopo ogni iscrizione verifica contatore homepage
3. [ ] All'iscrizione 30 verifica messaggio "Posti esauriti"

**Verifica Database:**
```sql
-- Deve essere esattamente 30
SELECT posti_occupati FROM turni WHERE id = 1;

-- Devono esserci 30 CONFIRMED
SELECT COUNT(*) FROM iscrizioni WHERE turno_id = 1 AND status = 'CONFIRMED';
```

**Risultato Atteso:**
- Contatore homepage aggiornato dopo ogni iscrizione
- Alla 30esima: "Posti esauriti"
- posti_occupati = 30
- Nessun posto oltre i 30

---

### Test 4: Lista d'Attesa

**Obiettivo:** Verificare gestione automatica lista d'attesa

**Passi:**
1. [ ] Iscrivi quando posti = 30 (esauriti)
2. [ ] Compila form con email: attesa1@test.com
3. [ ] Verifica modal "Inserito in Lista d'Attesa"
4. [ ] Verifica "Posizione in lista: 1"
5. [ ] Ripeti con attesa2@test.com
6. [ ] Verifica "Posizione in lista: 2"

**Verifica Database:**
```sql
-- Lista ordinata per posizione
SELECT 
  nome, 
  cognome, 
  email, 
  posizione_lista 
FROM iscrizioni 
WHERE turno_id = 1 AND status = 'WAITING_LIST'
ORDER BY posizione_lista;
```

**Risultato Atteso:**
- Primo: posizione_lista = 1
- Secondo: posizione_lista = 2
- Status = 'WAITING_LIST'
- Email type = 'LISTA_ATTESA'
- Ordine cronologico rispettato

---

### Test 5: Promozione Automatica

**Obiettivo:** Verificare promozione automatica da lista d'attesa

**Passi:**
1. [ ] Login admin panel
2. [ ] Seleziona turno con lista d'attesa
3. [ ] Verifica statistiche (30 confermati, 2 in attesa)
4. [ ] Cancella UNA iscrizione confermata
5. [ ] Verifica alert "Promosso dalla lista: ..."
6. [ ] Verifica statistiche aggiornate (30 confermati, 1 in attesa)

**Verifica Database:**
```sql
-- Primo in lista deve essere stato promosso
SELECT 
  email,
  status,
  posizione_lista
FROM iscrizioni
WHERE email = 'attesa1@test.com';

-- Secondo deve essere salito a posizione 1
SELECT 
  email,
  status,
  posizione_lista
FROM iscrizioni
WHERE email = 'attesa2@test.com';

-- Email promozione inviata
SELECT * FROM email_queue 
WHERE email_to = 'attesa1@test.com' 
AND email_type = 'PROMOZIONE';
```

**Risultato Atteso:**
- attesa1@test.com: status = CONFIRMED, posizione_lista = NULL
- attesa2@test.com: status = WAITING_LIST, posizione_lista = 1
- Email promozione in coda
- Contatori aggiornati automaticamente

---

### Test 6: Admin Panel - Visualizzazione

**Obiettivo:** Verificare funzionalità pannello admin

**Passi:**
1. [ ] Login admin.html
2. [ ] Verifica caricamento turni nel select
3. [ ] Seleziona turno 1
4. [ ] Verifica statistiche:
   - Posti Totali: 30
   - Confermati: 30
   - Lista d'Attesa: 1
   - Posti Disponibili: 0
5. [ ] Verifica tab "Confermati" mostra 30 iscrizioni
6. [ ] Verifica tab "Lista d'Attesa" mostra 1 iscrizione
7. [ ] Verifica badge "Pos. 1" in lista attesa

**Risultato Atteso:**
- Tutti i dati visibili correttamente
- Statistiche precise
- Liste complete
- Nessun errore console

---

### Test 7: Admin Panel - Promozione Manuale

**Obiettivo:** Verificare promozione manuale da admin

**Prerequisiti:** Avere almeno 1 persona in lista d'attesa

**Passi:**
1. [ ] Admin panel → Lista d'Attesa
2. [ ] Click "✓ Promuovi" su prima persona
3. [ ] Conferma alert
4. [ ] Verifica messaggio "Iscrizione promossa"
5. [ ] Verifica persona spostata in tab "Confermati"
6. [ ] Verifica statistiche aggiornate

**Verifica Database:**
```sql
SELECT status, posizione_lista 
FROM iscrizioni 
WHERE id = [ID_PROMOSSO];
```

**Risultato Atteso:**
- Status = CONFIRMED
- posizione_lista = NULL
- Email promozione in coda
- Liste aggiornate

---

### Test 8: Admin Panel - Cancellazione

**Obiettivo:** Verificare cancellazione iscrizione

**Passi:**
1. [ ] Admin panel → Confermati
2. [ ] Click "✗ Cancella" su un'iscrizione
3. [ ] Conferma alert
4. [ ] Se c'è lista d'attesa, verifica alert promozione
5. [ ] Verifica iscrizione rimossa da lista
6. [ ] Verifica statistiche aggiornate

**Verifica Database:**
```sql
-- Status deve essere CANCELLED
SELECT status FROM iscrizioni WHERE id = [ID_CANCELLATO];

-- Contatore aggiornato
SELECT posti_occupati FROM turni WHERE id = 1;
```

**Risultato Atteso:**
- Iscrizione marcata CANCELLED (non eliminata)
- Se lista d'attesa presente: promozione automatica
- Contatori aggiornati
- Liste aggiornate

---

### Test 9: Validazioni Form

**Obiettivo:** Verificare validazioni lato client

**Passi:**
1. [ ] Prova invio form vuoto → errori HTML5
2. [ ] Email formato errato → errore HTML5
3. [ ] CAP non 5 cifre → errore HTML5
4. [ ] Privacy non spuntata → errore "consenso obbligatorio"
5. [ ] Tutti campi corretti → iscrizione OK

**Risultato Atteso:**
- Browser blocca invio se campi invalidi
- Messaggi errore chiari
- Nessuna iscrizione salvata con dati incompleti

---

### Test 10: Race Condition

**Obiettivo:** Verificare che non ci siano race condition

**Setup:** Turno con 1 posto disponibile

**Passi:**
1. [ ] Apri 2 browser/tab diverse
2. [ ] In entrambe compila form iscrizione simultaneamente
3. [ ] Invia contemporaneamente (entro 1 secondo)
4. [ ] Verifica che solo 1 venga confermata
5. [ ] L'altra deve finire in lista d'attesa

**Verifica Database:**
```sql
-- Deve essere max 30, non 31!
SELECT posti_occupati FROM turni WHERE id = 1;

SELECT COUNT(*) FROM iscrizioni 
WHERE turno_id = 1 AND status = 'CONFIRMED';
```

**Risultato Atteso:**
- posti_occupati = 30 (mai 31)
- 1 CONFIRMED, 1 WAITING_LIST
- Nessun superamento limite

---

### Test 11: Responsive Mobile

**Obiettivo:** Verificare usabilità mobile

**Passi:**
1. [ ] Apri sito da smartphone (o DevTools mobile)
2. [ ] Verifica homepage leggibile
3. [ ] Verifica card turni responsive
4. [ ] Compila form da mobile
5. [ ] Verifica admin panel mobile
6. [ ] Test orientamento landscape/portrait

**Risultato Atteso:**
- Tutto leggibile senza zoom
- Form compilabile agevolmente
- Pulsanti cliccabili facilmente
- Nessun overflow orizzontale

---

### Test 12: Browser Compatibility

**Obiettivo:** Verificare compatibilità browser

**Browsers da testare:**
- [ ] Chrome/Edge (desktop)
- [ ] Firefox (desktop)
- [ ] Safari (desktop)
- [ ] Chrome Mobile (Android)
- [ ] Safari Mobile (iOS)

**Per ogni browser:**
1. Homepage carica
2. Iscrizione funziona
3. Admin panel funziona
4. Nessun errore console

---

### Test 13: Email (Opzionale)

**Prerequisiti:** Edge Function deployata, Resend configurato

**Passi:**
1. [ ] Iscrizione confermata → verifica email ricevuta
2. [ ] Iscrizione in lista → verifica email ricevuta
3. [ ] Promozione da lista → verifica email ricevuta
4. [ ] Verifica template HTML corretto
5. [ ] Verifica link e contatti nell'email

**Verifica Database:**
```sql
-- Email devono avere status SENT
SELECT * FROM email_queue WHERE status = 'SENT';
```

**Risultato Atteso:**
- Email ricevute in casella
- Template formattato correttamente
- Dati corretti nell'email

---

## 📋 FASE 3: TEST INTEGRITÀ

### Test Integrità Database

```sql
-- 1. Nessun posto oltre il massimo
SELECT * FROM turni WHERE posti_occupati > posti_totali;
-- Risultato: 0 righe

-- 2. Conteggio corretto
SELECT 
  t.id,
  t.posti_occupati,
  COUNT(i.id) as reale
FROM turni t
LEFT JOIN iscrizioni i ON i.turno_id = t.id AND i.status = 'CONFIRMED'
GROUP BY t.id, t.posti_occupati
HAVING t.posti_occupati != COUNT(i.id);
-- Risultato: 0 righe

-- 3. Posizioni lista consecutive
SELECT 
  turno_id,
  array_agg(posizione_lista ORDER BY posizione_lista)
FROM iscrizioni
WHERE status = 'WAITING_LIST'
GROUP BY turno_id;
-- Risultato: [1,2,3,...] senza buchi

-- 4. Nessun orphan
SELECT COUNT(*) FROM iscrizioni 
WHERE turno_id NOT IN (SELECT id FROM turni);
-- Risultato: 0

-- 5. Privacy sempre true
SELECT COUNT(*) FROM iscrizioni WHERE consenso_privacy = false;
-- Risultato: 0
```

**Tutti i test devono passare!**

---

## 📋 FASE 4: TEST PERFORMANCE

### Load Test Basico

**Obiettivo:** Verificare sistema sotto carico leggero

**Setup:**
1. Installa Artillery: `npm install -g artillery`
2. Crea file `load-test.yml`:
```yaml
config:
  target: 'https://TUO-USERNAME.github.io'
  phases:
    - duration: 60
      arrivalRate: 5
scenarios:
  - flow:
      - get:
          url: "/campeggi-parrocchia-v2/index.html"
```

**Esecuzione:**
```bash
artillery run load-test.yml
```

**Risultato Atteso:**
- Response time < 2s
- Error rate < 1%
- Nessun timeout

---

## 📋 FASE 5: CHECKLIST PRODUZIONE

Prima di comunicare il sito agli utenti:

### Configurazione
- [ ] Tutte le credenziali aggiornate
- [ ] Dati contatto parrocchia corretti
- [ ] Email "from" configurata (se email attive)
- [ ] Domini verificati (se email attive)

### Dati
- [ ] Turni reali inseriti (non seed)
- [ ] Date corrette
- [ ] Posti corretti
- [ ] Luoghi corretti
- [ ] Descrizioni corrette

### Sicurezza
- [ ] Password admin forte
- [ ] Database password mai condivisa
- [ ] Service role key mai esposta
- [ ] HTTPS attivo su GitHub Pages

### Backup
- [ ] Backup database eseguito
- [ ] Credenziali salvate in luogo sicuro
- [ ] Documentazione salvata

### Comunicazione
- [ ] URL finale testato
- [ ] Email supporto funzionante
- [ ] Telefono supporto verificato
- [ ] Materiale informativo pronto

### Monitoraggio
- [ ] Piano per check quotidiani
- [ ] Responsabile identificato
- [ ] Procedura emergenza definita

---

## 🎯 CRITERI SUPERAMENTO

Il sistema è **pronto per produzione** se:

✅ Tutti i test funzionali (1-13) passano
✅ Tutti i test integrità (Fase 3) passano
✅ Load test accettabile (Fase 4)
✅ Checklist produzione completata (Fase 5)
✅ Nessun errore critico in console browser
✅ Nessun errore in Supabase logs

---

## ⚠️ ERRORI BLOCCANTI

Non andare in produzione se:

❌ Iscrizioni vanno perse
❌ Posti superano il massimo
❌ Lista d'attesa disordinata
❌ Promozione automatica non funziona
❌ Admin panel non accessibile
❌ Race condition permettono overbooking
❌ Database inconsistente

---

## 📞 SUPPORTO

Se qualche test fallisce:

1. Controlla console browser (F12)
2. Controlla Supabase logs
3. Esegui query debug in `backend/query-utili.sql`
4. Verifica credenziali aggiornate
5. Ri-esegui SQL nell'ordine corretto

---

**Versione Checklist**: 2.0
**Data**: Gennaio 2025
**Tempo Stimato Test**: 2-3 ore

Buon testing! 🧪
