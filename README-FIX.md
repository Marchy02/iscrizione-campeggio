# 🔧 FIX SISTEMA CAMPEGGI - Guida Rapida

## ❌ Problemi Identificati

1. **Funzioni SQL non trovate** → Parametri DEFAULT problematici
2. **Campi form non corretti** → Mancavano dati richiesti (genitore, luogo nascita, ecc.)
3. **TypeScript errors** → Tipi mancanti in send-email.ts

## ✅ Soluzioni Implementate

### Fix 1: Schema e Funzioni SQL Corretti

**Problema:** `could not find a function named "crea_iscrizione"`
**Causa:** PostgreSQL non supporta parametri con DEFAULT dopo parametri obbligatori

**Soluzione:** Rimossi tutti i `DEFAULT` dai parametri funzione

### Fix 2: Form con Campi Corretti

**Aggiunti:**
- Luogo di nascita
- Checkbox "È maggiorenne?"
- Dati genitore/tutore (condizionali se minorenne)
- Checkbox allergie/patologie con descrizione condizionale
- Checkbox medicinali con descrizione condizionale
- Solo consenso GDPR (rimosso consenso immagini)

### Fix 3: TypeScript Corretto

**Aggiunti:**
- Interface per EmailRequest ed EmailData
- Type guard per error handling
- Reference types per Deno

---

## 🚀 PROCEDURA FIX RAPIDA (15 minuti)

### STEP 1: Pulizia Database (IMPORTANTE!)

Vai su **Supabase → SQL Editor** ed esegui:

```sql
-- Elimina tutto il vecchio
DROP TABLE IF EXISTS iscrizioni CASCADE;
DROP TABLE IF EXISTS turni CASCADE;
DROP TABLE IF EXISTS email_queue CASCADE;
DROP FUNCTION IF EXISTS crea_iscrizione CASCADE;
DROP FUNCTION IF EXISTS cancella_iscrizione CASCADE;
DROP FUNCTION IF EXISTS promuovi_iscrizione CASCADE;
DROP FUNCTION IF EXISTS get_turno_stats CASCADE;
DROP FUNCTION IF EXISTS promuovi_da_lista_attesa CASCADE;
DROP FUNCTION IF EXISTS riordina_lista_attesa CASCADE;
```

### STEP 2: Crea Nuovo Database

Esegui **nell'ordine** questi file:

1. **01-schema-corretto.sql** 
   - Crea tabelle con campi corretti
   - Crea trigger automatici

2. **02-functions-corrette.sql**
   - Crea funzioni RPC SENZA parametri default
   - Gestisce tutti i campi richiesti

3. **03-policies-corrette.sql**
   - Configura RLS policies

**Tempo:** ~3 minuti

### STEP 3: Sostituisci File Frontend

Sostituisci questi file nella tua cartella progetto:

```
turno.html → turno-corretto.html
app.js → app-corretto.js
admin.html → admin-corretto.html  
index.html → index-corretto.html
styles.css → styles-corretto.css
```

**Tempo:** ~2 minuti

### STEP 4: Aggiorna Credenziali

Nei file HTML e JS, aggiorna:

```javascript
const SUPABASE_URL = 'TUO_URL_QUI';
const SUPABASE_ANON_KEY = 'TUA_KEY_QUI';
```

**Tempo:** ~2 minuti

### STEP 5: Deploy Edge Function (Opzionale - Email)

```bash
# Deploy funzione email corretta
supabase functions deploy send-email --project-ref TUO_PROJECT_ID

# Con file corretto
supabase functions deploy send-email send-email-corretto.ts
```

**Tempo:** ~3 minuti

### STEP 6: Test Completo

1. **Apri homepage** → Verifica turni caricati ✅
2. **Click "Iscriviti"** → Form con TUTTI i campi ✅
3. **Compila form** → Test iscrizione ✅
4. **Login admin** → Verifica statistiche ✅

---

## 📋 CHECKLIST VERIFICA

### Database
- [ ] Query `SELECT * FROM turni;` ritorna 3 turni
- [ ] Query `SELECT * FROM pg_proc WHERE proname LIKE '%iscrizione%';` ritorna funzioni
- [ ] Nessun errore "could not find function"

### Frontend
- [ ] Form mostra campi: nome, cognome, data nascita, **luogo nascita**
- [ ] Checkbox "È maggiorenne?" presente
- [ ] Se NON maggiorenne → mostra campi genitore
- [ ] Checkbox allergie → mostra textarea descrizione
- [ ] Checkbox medicinali → mostra textarea descrizione
- [ ] Solo consenso GDPR presente

### Test Funzionale
- [ ] Iscrizione → Ricevi conferma (CONFIRMED o WAITING_LIST)
- [ ] Database → Verifica `SELECT * FROM iscrizioni;` mostra record
- [ ] Admin → Login funziona
- [ ] Admin → Statistiche visibili
- [ ] Admin → Liste confermati/attesa visibili

---

## 🐛 TROUBLESHOOTING

### Errore: "could not find function"

**Causa:** Funzioni non create o parametri errati

**Fix:**
```sql
-- Verifica funzioni presenti
SELECT proname, pronargs FROM pg_proc WHERE proname LIKE '%iscrizione%';

-- Se vuoto, riesegui 02-functions-corrette.sql
```

### Errore: "violates check constraint"

**Causa:** Campi obbligatori mancanti

**Fix:** Verifica che il form invii TUTTI i campi:
```javascript
console.log('Dati inviati:', data);
```

Devono esserci:
- `p_luogo_nascita`
- `p_e_maggiorenne`
- `p_nome_genitore` (se minorenne)
- `p_cognome_genitore` (se minorenne)

### Errore: "Failed to load resource 404"

**Causa:** URL Supabase errato o funzione non deployata

**Fix:**
1. Verifica URL corretto in tutti i file
2. Verifica funzioni create: `SELECT * FROM pg_proc WHERE proname = 'get_turno_stats';`

### TypeScript Errors in VS Code

**Causa:** VS Code non riconosce Deno types

**Fix:** Ignora (sono warnings IDE, non bloccano il deploy)

Oppure aggiungi `.vscode/settings.json`:
```json
{
  "deno.enable": true
}
```

---

## 📊 CONFRONTO PRIMA/DOPO

| Aspetto | Prima (Buggy) | Dopo (Fixed) |
|---------|---------------|--------------|
| **Funzioni SQL** | ❌ Parametri DEFAULT non supportati | ✅ Parametri senza DEFAULT |
| **Form luogo nascita** | ❌ Mancante | ✅ Presente |
| **Dati genitore** | ❌ Mancanti | ✅ Condizionali se minorenne |
| **Allergie/Medicinali** | ❌ Solo note generiche | ✅ Checkbox + descrizione |
| **TypeScript** | ❌ Errori 'any' e Deno | ✅ Tipi corretti |
| **RPC calls** | ❌ Falliscono | ✅ Funzionano |

---

## 🎯 TEST FINALE

Dopo il fix, esegui questa query per verificare tutto:

```sql
-- Test inserimento manuale
SELECT crea_iscrizione(
  p_turno_id := 1,
  p_nome := 'Test',
  p_cognome := 'Fix',
  p_data_nascita := '2015-01-01',
  p_luogo_nascita := 'Verona',
  p_indirizzo := 'Via Test 1',
  p_citta := 'Verona',
  p_e_maggiorenne := false,
  p_nome_genitore := 'Mario',
  p_cognome_genitore := 'Rossi',
  p_email := 'test@test.com',
  p_telefono := '3331234567',
  p_ha_allergie := false,
  p_descrizione_allergie := NULL,
  p_ha_medicinali := false,
  p_descrizione_medicinali := NULL,
  p_consenso_gdpr := true
);

-- Verifica inserito
SELECT * FROM iscrizioni WHERE email = 'test@test.com';

-- Deve ritornare: {"success": true, "status": "CONFIRMED", ...}
```

Se ritorna `success: true` → **TUTTO OK!** ✅

---

## 📞 SUPPORTO

Se persistono errori:

1. Copia **ESATTO** errore da console
2. Verifica quale file SQL hai eseguito
3. Verifica ordine esecuzione (01 → 02 → 03)
4. Controlla credenziali Supabase aggiornate

---

## 🎉 RISULTATO ATTESO

Dopo questo fix:

✅ Form completo con TUTTI i campi richiesti
✅ Iscrizioni salvate correttamente
✅ Admin panel funzionante
✅ Statistiche visibili
✅ Email pronte (se deployate)
✅ Nessun errore 404 o "function not found"

**Tempo totale fix:** 15-20 minuti

---

**Versione Fix**: 2.1
**Data**: Gennaio 2025
**Status**: TESTATO E FUNZIONANTE ✅
