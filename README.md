# 🏕️ Sistema Gestione Campeggi Estivi - Guida Setup Completa

## 📋 PREREQUISITI

- Account GitHub (gratuito)
- Account Supabase (gratuito)
- Account Resend.com (opzionale, per email automatiche)
- Editor di testo (VS Code consigliato)

---

## 🚀 STEP 1: SETUP SUPABASE

### 1.1 Crea Progetto

1. Vai su https://supabase.com  
2. Clicca "Start your project"  
3. Crea un nuovo progetto:
   - Nome: `campeggi-parrocchia`
   - Database Password: **SALVALA IN MODO SICURO** 
   - Region: Scegli la più vicina  
4. Attendi la creazione (2–3 minuti)

### 1.2 Crea Database

1. Supabase → **SQL Editor**
2. **New query**
3. Incolla `backend/schema.sql`
4. **Run**
5. Ripeti con `backend/policies.sql`

### 1.3 Ottieni Credenziali

Supabase → **Settings > API**

- Project URL  
- anon/public key  

### 1.4 Crea Utente Admin

Supabase → Authentication → Users → Add user

Raw User Meta Data:

```json
{
  "role": "admin"
}
```

---

## 📂 STEP 2: PREPARAZIONE CODICE

### Struttura

```
campeggi-parrocchia/
├── index.html
├── turno.html
├── admin.html
├── styles.css
├── app.js
├── admin.js
└── README.md
```

### Configurazione Supabase

`app.js`, `admin.js`, `turno.html`:

```javascript
const SUPABASE_URL = 'https://TUOPROGETTO.supabase.co';
const SUPABASE_ANON_KEY = 'CHIAVE';
```

---

## 🌐 STEP 3: DEPLOY SU GITHUB PAGES

### Repository

Nome: `campeggi-parrocchia`  
Pubblico

### Upload

Via web o Git:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/TUO-USERNAME/campeggi-parrocchia.git
git push -u origin main
```

### GitHub Pages

Settings → Pages → main / root

---

## ✅ STEP 4: TEST

Homepage  
Iscrizione  
Admin panel  
Lista d’attesa

---

## 📧 STEP 5: EMAIL AUTOMATICHE (OPZIONALE)

Resend → API Key

Supabase → Edge Functions → `send-email`

Secret:

```
RESEND_API_KEY
```

Invocazione frontend:

```javascript
await supabase.functions.invoke('send-email', {
  body: {
    to: formData.email,
    subject: formData.status === 'CONFIRMED'
      ? 'Iscrizione confermata!'
      : 'Inserito in lista d\'attesa',
    type: formData.status === 'CONFIRMED' ? 'CONFERMA' : 'LISTA_ATTESA',
    data: {
      nome: formData.nome,
      cognome: formData.cognome,
      turno_nome: turnoData.nome,
      date: `${dataInizio} - ${dataFine}`,
      luogo: turnoData.luogo,
      posizione: formData.posizione_lista
    }
  }
});
```

---

## 🔧 TROUBLESHOOTING

### Turni non caricano
- Console browser
- URL e KEY corretti
- Tabelle presenti

### Login admin
- User presente
- `{"role":"admin"}`
- Password
- RLS

### Failed to fetch
- Policies
- Esegui `policies.sql`
- Permessi anon

### Contatore

```sql
SELECT * FROM pg_trigger WHERE tgname='trigger_update_posti';
```

### Lista attesa

```sql
SELECT * FROM iscrizioni
WHERE turno_id=1 AND status='WAITING_LIST'
ORDER BY posizione_lista;
```

---

## 🔒 SICUREZZA

- Password DB mai condivisa  
- Service role mai frontend  
- RLS attive  

Backup:

```sql
SELECT * FROM iscrizioni;
SELECT * FROM turni;
```

---

## 📊 MONITORAGGIO

Free tier:

- 50k richieste/mese
- 500MB DB
- 1GB storage

---

## 🎨 PERSONALIZZAZIONE

Colori:

```css
body { background-color:#FFF8E7; }
.header,.btn-primary { background:linear-gradient(135deg,#FFA726,#FF9800); }
.btn-secondary { background:#FFB74D; }
body { color:#5D4037; }
```

Font:

```css
body { font-family:'Nunito',sans-serif; }
```

---

## 📱 RESPONSIVE

- Mobile < 480px
- Tablet 480–768px
- Desktop > 768px

---

## 🔄 AGGIORNAMENTI

Nuovo turno → Supabase table `turni`

Posti:

```sql
UPDATE turni SET posti_totali=40 WHERE id=1;
```

Export Excel:

```sql
SELECT i.nome,i.cognome,i.data_nascita,i.email,i.telefono,
t.nome,i.status,i.created_at
FROM iscrizioni i
JOIN turni t ON i.turno_id=t.id
ORDER BY t.id,i.created_at;
```

---

## 📞 SUPPORTO

- Supabase docs
- GitHub Pages docs
- Resend docs

---

## ✅ CHECKLIST PRE-LANCIO

Database  
Tabelle  
RLS  
Admin  
Turni  
GitHub Pages  
Form  
Admin panel  
Backup  

---

## 🎯 FLUSSO OPERATIVO

Admin:
- Login
- Gestione iscrizioni
- Export
- Log

Utenti:
- Scelta turno
- Iscrizione
- Conferma

---

## 💾 BACKUP

```sql
COPY (SELECT * FROM iscrizioni) TO '/tmp/iscrizioni.csv' CSV HEADER;
COPY (SELECT * FROM turni) TO '/tmp/turni.csv' CSV HEADER;
```

Restore:

```sql
COPY iscrizioni FROM '/tmp/iscrizioni.csv' CSV HEADER;
COPY turni FROM '/tmp/turni.csv' CSV HEADER;
```

---

## 🚀 ESTENSIONI FUTURE

Pagamenti, PDF, SMS, Upload documenti, Dashboard, Multilingua

---

## 📜 LICENZA E CREDITI

Supabase – GitHub Pages – Resend – PostgreSQL – Vanilla JS

---

## 🎓 NOTE FINALI

Sistema gratuito, sicuro, mobile-friendly, scalabile.

Ultima modifica: Gennaio 2025

---

# FILE AGGIUNTIVO: .gitignore

```gitignore
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db
*.log
npm-debug.log*
.env
.env.local
config.local.js
*.backup
*.bak
```

---

# RIEPILOGO FILE

Frontend:

- index.html  
- turno.html  
- admin.html  
- styles.css  
- app.js  
- admin.js  

Backend:

- schema.sql  
- policies.sql  
- edge-functions/send-email.js  

Documentazione:

- README.md  
- .gitignore  

---

# PROSSIMI PASSI

1. Copia i file
2. Configura Supabase
3. Carica su GitHub Pages
4. Testa

Tempo: ~30 minuti

---

# QUICK START

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/USERNAME/campeggi-parrocchia.git
git push -u origin main
```

Aggiorna:

- SUPABASE_URL
- SUPABASE_ANON_KEY

---

Sistema completo, production-ready.

Frontend ✅  
Backend Supabase ✅  
Lista attesa ✅  
Admin panel ✅  
Email opzionali ✅  

Buon lavoro 🏕️
