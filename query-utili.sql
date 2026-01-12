-- ============================================
-- QUERY UTILI - Sistema Campeggi v2.0
-- ============================================
-- Query per monitoraggio, debug e manutenzione
-- ============================================

-- ========================================
-- MONITORAGGIO GENERALE
-- ========================================

-- Vista completa stato turni
SELECT 
  t.id,
  t.nome,
  t.data_inizio,
  t.data_fine,
  t.posti_totali,
  t.posti_occupati,
  t.posti_totali - t.posti_occupati as posti_disponibili,
  COUNT(CASE WHEN i.status = 'CONFIRMED' THEN 1 END) as count_confermati,
  COUNT(CASE WHEN i.status = 'WAITING_LIST' THEN 1 END) as count_lista_attesa,
  COUNT(CASE WHEN i.status = 'CANCELLED' THEN 1 END) as count_cancellati
FROM turni t
LEFT JOIN iscrizioni i ON i.turno_id = t.id
WHERE t.attivo = true
GROUP BY t.id
ORDER BY t.data_inizio;

-- Verifica consistenza contatori
-- (posti_occupati deve essere uguale a count iscrizioni confermate)
SELECT 
  t.id,
  t.nome,
  t.posti_occupati as contatore_tabella,
  COUNT(i.id) as conteggio_reale,
  CASE 
    WHEN t.posti_occupati = COUNT(i.id) THEN '✅ OK'
    ELSE '⚠️ ERRORE CONTEGGIO'
  END as stato
FROM turni t
LEFT JOIN iscrizioni i ON i.turno_id = t.id AND i.status = 'CONFIRMED'
GROUP BY t.id, t.nome, t.posti_occupati;

-- ========================================
-- ISCRIZIONI
-- ========================================

-- Ultime 20 iscrizioni
SELECT 
  i.id,
  i.nome,
  i.cognome,
  i.email,
  t.nome as turno,
  i.status,
  i.posizione_lista,
  i.created_at
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
ORDER BY i.created_at DESC
LIMIT 20;

-- Iscrizioni per turno e status
SELECT 
  t.nome as turno,
  i.status,
  COUNT(*) as totale,
  MIN(i.created_at) as prima_iscrizione,
  MAX(i.created_at) as ultima_iscrizione
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
GROUP BY t.nome, i.status
ORDER BY t.nome, i.status;

-- Liste d'attesa complete (ordinate per posizione)
SELECT 
  t.nome as turno,
  i.posizione_lista,
  i.nome,
  i.cognome,
  i.email,
  i.telefono,
  i.created_at
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
WHERE i.status = 'WAITING_LIST'
ORDER BY t.id, i.posizione_lista;

-- Verifica integrità lista d'attesa
-- (posizioni devono essere consecutive: 1,2,3,4... senza buchi)
SELECT 
  t.id,
  t.nome,
  array_agg(i.posizione_lista ORDER BY i.posizione_lista) as posizioni,
  CASE 
    WHEN array_agg(i.posizione_lista ORDER BY i.posizione_lista) = 
         array(SELECT generate_series(1, COUNT(*)) FROM iscrizioni WHERE turno_id = t.id AND status = 'WAITING_LIST')
    THEN '✅ Lista OK'
    ELSE '⚠️ Posizioni non consecutive'
  END as stato
FROM turni t
LEFT JOIN iscrizioni i ON i.turno_id = t.id AND i.status = 'WAITING_LIST'
WHERE EXISTS (SELECT 1 FROM iscrizioni WHERE turno_id = t.id AND status = 'WAITING_LIST')
GROUP BY t.id, t.nome;

-- ========================================
-- EMAIL
-- ========================================

-- Stato coda email
SELECT 
  status,
  email_type,
  COUNT(*) as totale,
  MIN(created_at) as prima,
  MAX(created_at) as ultima
FROM email_queue
GROUP BY status, email_type
ORDER BY status, email_type;

-- Email fallite (per debugging)
SELECT 
  eq.id,
  eq.email_to,
  eq.email_type,
  eq.attempts,
  eq.last_error,
  eq.created_at,
  i.nome,
  i.cognome
FROM email_queue eq
JOIN iscrizioni i ON i.id = eq.iscrizione_id
WHERE eq.status = 'FAILED'
ORDER BY eq.created_at DESC;

-- Email in attesa di invio
SELECT 
  eq.id,
  eq.email_to,
  eq.email_type,
  eq.created_at,
  i.nome,
  i.cognome,
  t.nome as turno
FROM email_queue eq
JOIN iscrizioni i ON i.id = eq.iscrizione_id
JOIN turni t ON t.id = i.turno_id
WHERE eq.status = 'PENDING'
ORDER BY eq.created_at;

-- ========================================
-- EXPORT DATI
-- ========================================

-- Export completo per Excel/Google Sheets
SELECT 
  -- Turno
  t.nome as "Turno",
  t.data_inizio as "Data Inizio",
  t.data_fine as "Data Fine",
  t.luogo as "Luogo",
  
  -- Partecipante
  i.nome as "Nome",
  i.cognome as "Cognome",
  i.data_nascita as "Data Nascita",
  i.sesso as "Sesso",
  
  -- Contatti
  i.email as "Email",
  i.telefono as "Telefono",
  i.indirizzo as "Indirizzo",
  i.citta as "Città",
  i.cap as "CAP",
  
  -- Status
  i.status as "Status",
  i.posizione_lista as "Pos. Lista",
  
  -- Medici
  i.allergie as "Allergie",
  i.farmaci as "Farmaci",
  i.note_mediche as "Note Mediche",
  
  -- Emergenza
  i.contatto_emergenza_nome as "Contatto Emergenza Nome",
  i.contatto_emergenza_telefono as "Contatto Emergenza Tel",
  
  -- Consensi
  i.consenso_privacy as "Privacy",
  i.consenso_immagini as "Immagini",
  
  -- Date
  i.created_at as "Data Iscrizione"
  
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
WHERE i.status IN ('CONFIRMED', 'WAITING_LIST')
ORDER BY t.data_inizio, i.status, i.posizione_lista, i.created_at;

-- Export solo confermati
SELECT 
  t.nome as "Turno",
  i.nome as "Nome",
  i.cognome as "Cognome",
  i.data_nascita as "Nato il",
  i.email as "Email",
  i.telefono as "Telefono",
  i.allergie as "Allergie",
  i.contatto_emergenza_nome as "Contatto Emergenza",
  i.contatto_emergenza_telefono as "Tel Emergenza"
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
WHERE i.status = 'CONFIRMED'
ORDER BY t.data_inizio, i.cognome, i.nome;

-- ========================================
-- STATISTICHE AVANZATE
-- ========================================

-- Andamento iscrizioni nel tempo
SELECT 
  DATE(created_at) as data,
  COUNT(*) as iscrizioni_giorno,
  COUNT(*) FILTER (WHERE status = 'CONFIRMED') as confermate,
  COUNT(*) FILTER (WHERE status = 'WAITING_LIST') as lista_attesa
FROM iscrizioni
GROUP BY DATE(created_at)
ORDER BY data DESC;

-- Città più rappresentate
SELECT 
  citta,
  COUNT(*) as totale,
  COUNT(*) FILTER (WHERE status = 'CONFIRMED') as confermati
FROM iscrizioni
GROUP BY citta
ORDER BY totale DESC
LIMIT 10;

-- Distribuzione età (per turno)
SELECT 
  t.nome as turno,
  COUNT(*) as totale,
  AVG(EXTRACT(YEAR FROM AGE(i.data_nascita))) as eta_media,
  MIN(EXTRACT(YEAR FROM AGE(i.data_nascita))) as eta_min,
  MAX(EXTRACT(YEAR FROM AGE(i.data_nascita))) as eta_max
FROM iscrizioni i
JOIN turni t ON t.id = i.turno_id
WHERE i.status = 'CONFIRMED'
GROUP BY t.id, t.nome
ORDER BY t.data_inizio;

-- ========================================
-- MANUTENZIONE
-- ========================================

-- Ricalcola tutti i contatori posti
UPDATE turni
SET posti_occupati = (
  SELECT COUNT(*)
  FROM iscrizioni
  WHERE turno_id = turni.id
    AND status = 'CONFIRMED'
);

-- Riordina tutte le liste d'attesa
DO $$
DECLARE
  turno RECORD;
BEGIN
  FOR turno IN SELECT id FROM turni WHERE attivo = true LOOP
    PERFORM riordina_lista_attesa(turno.id);
  END LOOP;
END $$;

-- Pulizia email vecchie (più di 30 giorni)
DELETE FROM email_queue
WHERE status = 'SENT'
  AND sent_at < NOW() - INTERVAL '30 days';

-- ========================================
-- VERIFICA INTEGRITÀ SISTEMA
-- ========================================

-- Verifica constraint database
SELECT 
  conname as constraint_name,
  conrelid::regclass as table_name,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid IN ('turni'::regclass, 'iscrizioni'::regclass, 'email_queue'::regclass)
ORDER BY conrelid, conname;

-- Verifica trigger attivi
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled,
  pg_get_triggerdef(oid) as definition
FROM pg_trigger
WHERE tgrelid IN ('turni'::regclass, 'iscrizioni'::regclass)
  AND NOT tgisinternal
ORDER BY tgrelid, tgname;

-- Verifica RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ========================================
-- BACKUP E RESTORE
-- ========================================

-- Backup completo (esegui da psql)
-- \copy (SELECT * FROM turni) TO 'backup_turni.csv' CSV HEADER
-- \copy (SELECT * FROM iscrizioni) TO 'backup_iscrizioni.csv' CSV HEADER
-- \copy (SELECT * FROM email_queue) TO 'backup_email.csv' CSV HEADER

-- Restore (esegui da psql dopo TRUNCATE)
-- \copy turni FROM 'backup_turni.csv' CSV HEADER
-- \copy iscrizioni FROM 'backup_iscrizioni.csv' CSV HEADER
-- \copy email_queue FROM 'backup_email.csv' CSV HEADER

-- ========================================
-- TEST E DEBUG
-- ========================================

-- Test funzione crea_iscrizione
SELECT crea_iscrizione(
  p_turno_id := 1,
  p_nome := 'Test',
  p_cognome := 'Sistema',
  p_data_nascita := '2010-01-01',
  p_sesso := 'M',
  p_email := 'test@example.com',
  p_telefono := '333-1234567',
  p_indirizzo := 'Via Test 1',
  p_citta := 'Testville',
  p_cap := '12345',
  p_contatto_emergenza_nome := 'Emergenza Test',
  p_contatto_emergenza_telefono := '333-7654321',
  p_consenso_privacy := true,
  p_consenso_immagini := false
);

-- Test promozione da lista
SELECT * FROM promuovi_da_lista_attesa(1);

-- Test statistiche
SELECT * FROM get_turno_stats(1);

-- ========================================
-- RESET SISTEMA (SOLO SVILUPPO!)
-- ========================================

-- ATTENZIONE: Questa query cancella TUTTI i dati!
-- Usa SOLO in ambiente di sviluppo
/*
SELECT reset_sistema_dev();
*/

-- ========================================
-- NOTE FINALI
-- ========================================

/*
Queste query sono organizzate per uso:
1. MONITORAGGIO: Per controlli quotidiani
2. EXPORT: Per creare report Excel
3. MANUTENZIONE: Per pulizia e ottimizzazione
4. DEBUG: Per risolvere problemi

Suggerimenti:
- Esegui query monitoraggio giornalmente
- Fai backup settimanali
- Pulisci email vecchie mensilmente
- Verifica integrità prima di eventi importanti
*/
