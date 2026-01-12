-- ============================================
-- DATI DI ESEMPIO - Sistema Campeggi
-- ============================================
-- Per testing e sviluppo
-- ============================================

-- ============================================
-- INSERISCI TURNI DI ESEMPIO
-- ============================================
INSERT INTO turni (nome, luogo, data_inizio, data_fine, posti_totali, attivo) VALUES
  ('Turno Bambini 6-10 anni', 'Rifugio Monte Baldo', '2025-06-15', '2025-06-22', 30, true),
  ('Turno Ragazzi 11-14 anni', 'Rifugio Monte Baldo', '2025-06-29', '2025-07-06', 30, true),
  ('Turno Adolescenti 15-17 anni', 'Rifugio Monte Baldo', '2025-07-13', '2025-07-20', 30, true);

-- ============================================
-- NOTA: Le iscrizioni vengono create solo via RPC
-- ============================================
-- Per testare iscrizioni, usa la funzione crea_iscrizione()
-- Non inserire mai direttamente in tabella iscrizioni

-- Esempio chiamata RPC per test:
/*
SELECT crea_iscrizione(
  p_turno_id := 1,
  p_nome := 'Mario',
  p_cognome := 'Rossi',
  p_data_nascita := '2015-03-15',
  p_sesso := 'M',
  p_email := 'mario.rossi@example.com',
  p_telefono := '333-1234567',
  p_indirizzo := 'Via Roma 1',
  p_citta := 'Verona',
  p_cap := '37100',
  p_allergie := NULL,
  p_farmaci := NULL,
  p_note_mediche := NULL,
  p_contatto_emergenza_nome := 'Paolo Rossi',
  p_contatto_emergenza_telefono := '333-7654321',
  p_consenso_privacy := true,
  p_consenso_immagini := true
);
*/

-- ============================================
-- QUERY UTILI PER VERIFICA
-- ============================================

-- Verifica turni caricati
-- SELECT * FROM turni ORDER BY data_inizio;

-- Verifica conteggio posti (dovrebbe essere 0 inizialmente)
-- SELECT nome, posti_totali, posti_occupati, posti_totali - posti_occupati as disponibili
-- FROM turni ORDER BY data_inizio;

-- Verifica iscrizioni per turno
-- SELECT t.nome as turno, i.status, COUNT(*) as totale
-- FROM iscrizioni i
-- JOIN turni t ON t.id = i.turno_id
-- GROUP BY t.nome, i.status
-- ORDER BY t.nome, i.status;

-- Verifica lista d'attesa ordinata
-- SELECT t.nome as turno, i.nome, i.cognome, i.posizione_lista, i.created_at
-- FROM iscrizioni i
-- JOIN turni t ON t.id = i.turno_id
-- WHERE i.status = 'WAITING_LIST'
-- ORDER BY i.turno_id, i.posizione_lista;

-- Verifica email in coda
-- SELECT eq.*, i.nome, i.cognome
-- FROM email_queue eq
-- JOIN iscrizioni i ON i.id = eq.iscrizione_id
-- WHERE eq.status = 'PENDING'
-- ORDER BY eq.created_at;
