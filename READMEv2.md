q# 🏕️ Sistema Gestione Campeggi Estivi - Versione 2.0 RIGENERATA

## 🎯 Cosa è cambiato nella versione 2.0

Questa è una **rigenerazione completa** del sistema con architettura solida che risolve tutti i problemi della versione precedente:

### ✅ Problemi Risolti

1. **Iscrizioni Atomiche**: Ora le iscrizioni sono gestite tramite funzione RPC che garantisce atomicità
2. **Lista d'Attesa Affidabile**: Gestione automatica tramite trigger PostgreSQL
3. **Conteggio Posti Preciso**: Trigger automatici aggiornano i contatori in tempo reale
4. **Sicurezza RLS Corretta**: Policy semplificate e testate
5. **Email Asincrone**: Sistema separato che non blocca le iscrizioni
6. **Promozioni Automatiche**: Quando un posto si libera, il primo in lista viene promosso automaticamente

### 🏗️ Architettura Nuova

```
┌─────────────────────────────────────────────┐
│           FRONTEND (HTML/CSS/JS)            │
│  - Nessuna logica business                  │
│  - Solo chiamate RPC autorizzate            │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│         SUPABASE (PostgreSQL)               │
│  ┌────────────────────────────────────────┐ │
│  │  TABELLE                               │ │
│  │  - turni (con contatori automatici)   │ │
│  │  - iscrizioni (con trigger)           │ │
│  │  - email_queue (asincrona)            │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │  FUNZIONI RPC                          │ │
│  │  - crea_iscrizione() atomica           │ │
│  │  - cancella_iscrizione()               │ │
│  │  - promuovi_iscrizione()               │ │
│  │  - get_turno_stats()                   │ │
│  └────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────┐ │
│  │  TRIGGER AUTOMATICI                    │ │
│  │  - Ricalcola posti occupati            │ │
│  │  - Riordina lista d'attesa             │ │
│  │  - Promozione automatica               │ │
│  └────────────────────────────────────────┘ │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│      EDGE FUNCTION (Email Asincrone)        │
│  - Invia email senza bloccare iscrizioni    │
│  - Retry automatico se fallisce             │
└─────────────────────────────────────────────┘
```

---

## 📋 PREREQUISITI

- Account GitHub (gratuito)
- Account Supabase (gratuito)
- Account Resend.com (gratuito, opzionale per email)
- Editor di testo (VS Code consigliato)

---

## 🚀 STEP 1: SETUP SUPABASE

### 1.1 Crea Progetto

1. Vai su https://supabase.com
2. Clicca "Start your project"
3. Crea nuovo progetto:
   - Nome: `campeggi-parrocchia-v2`
   - Database Password: **SALVALA!**
   - Region: Scegli la più vicina
4. Attendi creazione (2-3 minuti)

### 1.2 Crea Database

Vai su **SQL Editor** in Supabase e esegui **nell'ordine**:

1. `backend/01-schema.sql` - Crea tabelle e trigger
2. `backend/02-functions.sql` - Crea funzioni RPC
3. `backend/03-policies.sql` - Configura sicurezza
4. `backend/04-seed.sql` - Inserisce dati esempio

**IMPORTANTE**: Esegui i file **uno alla volta** nell'ordine indicato.

### 1.3 Ottieni Credenziali

Vai su **Settings > API** e copia:

- `Project URL` → Esempio: `https://xxxxx.supabase.co`
- `anon/public key` → Chiave lunga che inizia con `eyJ...`

### 1.4 Crea Utente Admin

1. Vai su **Authentication > Users**
2. Clicca **Add user** → **Create new user**
3. Inserisci:
   - Email: `admin@tuaparrocchia.it`
   - Password: (scegli password sicura)
   - Auto Confirm User: ✓ Attivato
4. Clicca su **Create user**
5. Clicca sull'utente appena creato
6. Scorri fino a **Raw User Meta Data**
7. Inserisci:
   ```json
   {
     "role": "admin"
   }
   ```
8. Salva

---

## 📂 STEP 2: CONFIGURA FRONTEND

### 2.1 Aggiorna Credenziali

Apri questi file e sostituisci le credenziali:

**File da modificare:**
- `frontend/app.js`
- `frontend/turno.html` (dentro lo script)
- `frontend/admin.html` (dentro lo script)

**Sostituisci:**
```javascript
const SUPABASE_URL = 'https://TUO_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'TUA_ANON_KEY_QUI';
```

### 2.2 Struttura File

Verifica di avere questa struttura:

```
campeggi-v2/
├── frontend/
│   ├── index.html
│   ├── turno.html
│   ├── admin.html
│   ├── app.js
│   └── styles.css
├── backend/
│   ├── 01-schema.sql
│   ├── 02-functions.sql
│   ├── 03-policies.sql
│   └── 04-seed.sql
├── edge-functions/
│   └── send-email.ts
└── README.md
```

---

## 🌐 STEP 3: DEPLOY SU GITHUB PAGES

### 3.1 Crea Repository

1. Vai su https://github.com/new
2. Nome: `campeggi-parrocchia-v2`
3. Pubblico
4. Non inizializzare con README

### 3.2 Upload File

**Opzione A: Via Web**
- Trascina i file dalla cartella `frontend/` su GitHub

**Opzione B: Via Git**
```bash
cd frontend
git init
git add .
git commit -m "Initial commit v2.0"
git branch -M main
git remote add origin https://github.com/TUO-USERNAME/campeggi-parrocchia-v2.git
git push -u origin main
```

### 3.3 Attiva GitHub Pages

1. Repository → **Settings** → **Pages**
2. Source: `main` branch, `/root` folder
3. Salva

Sito disponibile a: `https://TUO-USERNAME.github.io/campeggi-parrocchia-v2/`

---

## ✅ STEP 4: TEST COMPLETO

### Test 1: Homepage
1. Vai su `https://TUO-USERNAME.github.io/campeggi-parrocchia-v2/`
2. Verifica che i turni vengano caricati
3. Controlla console browser (F12) per errori

### Test 2: Iscrizione
1. Clicca "Iscriviti ora" su un turno
2. Compila form completo
3. Invia
4. Verifica messaggio di conferma

### Test 3: Verifica Database
```sql
-- In Supabase SQL Editor
SELECT * FROM turni;
SELECT * FROM iscrizioni ORDER BY created_at DESC;
SELECT * FROM email_queue ORDER BY created_at DESC;
```

### Test 4: Admin Panel
1. Vai su `...github.io/campeggi-parrocchia-v2/admin.html`
2. Login con email/password admin
3. Seleziona turno
4. Verifica liste e statistiche

### Test 5: Lista d'Attesa
1. Iscriviti finché i posti non si esauriscono
2. Prossima iscrizione dovrebbe finire in lista d'attesa
3. In admin, cancella un'iscrizione confermata
4. Verifica che il primo in lista viene promosso automaticamente

---

## 📧 STEP 5: EMAIL AUTOMATICHE (OPZIONALE)

### 5.1 Setup Resend

1. Vai su https://resend.com/signup
2. Verifica email
3. Vai su **API Keys**
4. Crea nuova chiave → **Full access**
5. Copia la chiave (inizia con `re_...`)

### 5.2 Deploy Edge Function

**Da terminale:**
```bash
# Installa Supabase CLI
npm install -g supabase

# Login
supabase login

# Link al progetto
supabase link --project-ref TUO_PROJECT_ID

# Deploy funzione
supabase functions deploy send-email
```

### 5.3 Configura Secret

```bash
supabase secrets set RESEND_API_KEY=re_tua_chiave_qui
```

### 5.4 Verifica Email Domain

1. In Resend, vai su **Domains**
2. Aggiungi il tuo dominio
3. Configura DNS records
4. Oppure usa il dominio test `onboarding.resend.dev`

### 5.5 Test Email

```sql
-- In Supabase SQL Editor, inserisci email di test
INSERT INTO email_queue (iscrizione_id, email_to, email_type, status)
VALUES (1, 'tua@email.com', 'CONFERMA', 'PENDING');
```

Poi chiama manualmente la funzione:
```javascript
// In console browser su admin panel
await supabase.functions.invoke('send-email', {
  body: {
    to: 'tua@email.com',
    type: 'CONFERMA',
    data: {
      nome: 'Test',
      cognome: 'Test',
      turno_nome: 'Turno Test',
      date: '15 giugno - 22 giugno 2025',
      luogo: 'Rifugio Monte Baldo'
    }
  }
});
```

---

## 🔧 TROUBLESHOOTING

### Problema: Turni non caricano

**Causa**: URL o chiave Supabase errate

**Soluzione**:
1. Verifica credenziali in `app.js`, `turno.html`, `admin.html`
2. Controlla console browser (F12)
3. Verifica che tabella `turni` abbia dati:
   ```sql
   SELECT * FROM turni WHERE attivo = true;
   ```

### Problema: Login admin fallisce

**Causa**: Utente non ha role admin

**Soluzione**:
1. Supabase → Authentication → Users
2. Clicca utente admin
3. Raw User Meta Data:
   ```json
   {
     "role": "admin"
   }
   ```
4. Salva e riprova

### Problema: Iscrizioni falliscono

**Causa**: Policy RLS bloccano inserimenti

**Soluzione**:
1. Esegui di nuovo `backend/03-policies.sql`
2. Verifica che funzione RPC sia eseguibile:
   ```sql
   GRANT EXECUTE ON FUNCTION crea_iscrizione TO anon, authenticated;
   ```

### Problema: Conteggio posti errato

**Causa**: Trigger non attivi

**Soluzione**:
1. Verifica trigger:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname LIKE 'trigger_ricalcola%';
   ```
2. Se assenti, esegui di nuovo `backend/01-schema.sql`
3. Ricalcola manualmente:
   ```sql
   UPDATE turni SET posti_occupati = (
     SELECT COUNT(*) FROM iscrizioni 
     WHERE turno_id = turni.id AND status = 'CONFIRMED'
   );
   ```

### Problema: Lista d'attesa disordinata

**Causa**: Posizioni non riordinate

**Soluzione**:
```sql
-- Per ogni turno
SELECT riordina_lista_attesa(1);
SELECT riordina_lista_attesa(2);
SELECT riordina_lista_attesa(3);
```

### Problema: Email non inviate

**Verifica**:
1. Edge Function deployata correttamente
2. Secret RESEND_API_KEY configurato
3. Dominio verificato in Resend
4. Controlla coda:
   ```sql
   SELECT * FROM email_queue WHERE status = 'FAILED';
   ```

---

## 📊 QUERY UTILI

### Statistiche Generali

```sql
SELECT 
  t.nome,
  COUNT(CASE WHEN i.status = 'CONFIRMED' THEN 1 END) as confermati,
  COUNT(CASE WHEN i.status = 'WAITING_LIST' THEN 1 END) as lista_attesa,
  t.posti_totali - t.posti_occupati as posti_liberi
FROM turni t
LEFT JOIN iscrizioni i ON i.turno_id = t.id
GROUP BY t.id, t.nome, t.posti_totali, t.posti_occupati
ORDER BY t.data_inizio;
```

### Export Excel

```sql
SELECT 
  i.nome,
  i.cognome,
  i.data_nascita,
  i.email,
  i.telefono,
  i.citta,
  t.nome as turno,
  i.status,
  i.posizione_lista,
  i.allergie,
  i.contatto_emergenza_nome,
  i.contatto_emergenza_telefono,
  i.created_at
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
WHERE i.status IN ('CONFIRMED', 'WAITING_LIST')
ORDER BY t.id, i.status, i.posizione_lista, i.created_at;
```

### Reset Sistema (SOLO SVILUPPO!)

```sql
-- ATTENZIONE: Cancella tutti i dati!
SELECT reset_sistema_dev();
```

---

## 🔒 SICUREZZA

### Best Practices

1. **Non condividere mai**:
   - Database password
   - Service role key
   - Resend API key

2. **Backup Regolari**:
   ```sql
   -- Export iscrizioni
   COPY (SELECT * FROM iscrizioni) TO '/tmp/iscrizioni_backup.csv' CSV HEADER;
   ```

3. **RLS sempre attivo**:
   ```sql
   -- Verifica RLS attivo
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE schemaname = 'public';
   ```

4. **Monitora accessi**:
   - Supabase → Authentication → Policies → Logs

---

## 📱 PERSONALIZZAZIONE

### Colori

In `frontend/styles.css`:

```css
/* Cambia colori principali */
.header, .btn-primary {
  background: linear-gradient(135deg, #TUO_COLORE_1, #TUO_COLORE_2);
}
```

### Font

```html
<!-- In <head> di ogni HTML -->
<link href="https://fonts.googleapis.com/css2?family=TUO_FONT&display=swap" rel="stylesheet">
```

```css
body {
  font-family: 'TUO_FONT', sans-serif;
}
```

### Dati Contatto

Cerca e sostituisci in tutti gli HTML:
- `campeggi@parrocchia.it`
- `0123 456789`
- `Parrocchia San Giuseppe`

---

## 🎯 DIFFERENZE CHIAVE VS VERSIONE 1.0

| Aspetto | v1.0 (Vecchia) | v2.0 (Nuova) |
|---------|----------------|--------------|
| **Inserimento** | INSERT diretto | Funzione RPC atomica |
| **Conteggio posti** | Manuale frontend | Trigger automatico |
| **Lista attesa** | Gestione manuale | Automatica con trigger |
| **Sicurezza** | RLS complessa | RLS semplificata |
| **Email** | Bloccante | Asincrona con queue |
| **Promozioni** | Manuali | Automatiche |
| **Race condition** | Possibili | Impossibili |
| **Errori** | Frequenti | Rarissimi |

---

## 🚀 PROSSIMI PASSI

Dopo il setup base funzionante, puoi aggiungere:

1. **Pagamenti Online**: Stripe/PayPal
2. **Upload Documenti**: Certificati medici
3. **SMS Notifiche**: Twilio
4. **Dashboard Analytics**: Grafici statistiche
5. **Export PDF**: Moduli iscrizione
6. **Multi-lingua**: Inglese/altre lingue

---

## 📞 SUPPORTO

### Documentazione Ufficiale

- Supabase: https://supabase.com/docs
- GitHub Pages: https://docs.github.com/pages
- Resend: https://resend.com/docs

### Debug

1. **Console browser** (F12): Errori JavaScript
2. **Supabase Logs**: Errori database
3. **Network tab**: Chiamate API fallite

---

## ✅ CHECKLIST FINALE

Prima di andare in produzione:

- [ ] Database creato e popolato
- [ ] Credenziali aggiornate in tutti i file
- [ ] Admin user creato con role corretto
- [ ] GitHub Pages attivo
- [ ] Test iscrizione completo funzionante
- [ ] Test lista d'attesa funzionante
- [ ] Test promozione automatica funzionante
- [ ] Admin panel accessibile
- [ ] Email configurate (opzionale)
- [ ] Dati di contatto aggiornati
- [ ] Backup database fatto
- [ ] Test su mobile
- [ ] Test cancellazione iscrizione

---

## 🎓 CONCLUSIONI

Questa versione 2.0 è **production-ready** e risolve tutti i problemi critici:

✅ **Niente più iscrizioni perse**
✅ **Conteggi sempre precisi**
✅ **Lista d'attesa affidabile**
✅ **Sicurezza garantita**
✅ **Email asincrone**

Il sistema è ora **stabile, sicuro e scalabile**.

---

**Versione**: 2.0
**Data**: Gennaio 2025
**Autore**: Sistema rigenerato
**Tempo Setup Stimato**: 45-60 minuti

Buon lavoro! 🏕️
