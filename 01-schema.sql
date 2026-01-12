-- ============================================
-- SCHEMA DATABASE - Sistema Campeggi
-- ============================================
-- Versione: 2.0
-- Autore: Sistema rigenerato
-- Data: Gennaio 2025
-- ============================================

-- Drop existing tables (se esistono)
DROP TABLE IF EXISTS iscrizioni CASCADE;
DROP TABLE IF EXISTS turni CASCADE;
DROP TABLE IF EXISTS email_queue CASCADE;

-- ============================================
-- TABELLA TURNI
-- ============================================
CREATE TABLE turni (
  id BIGSERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  luogo TEXT NOT NULL,
  data_inizio DATE NOT NULL,
  data_fine DATE NOT NULL,
  posti_totali INTEGER NOT NULL DEFAULT 30,
  posti_occupati INTEGER NOT NULL DEFAULT 0,
  attivo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT check_posti_positivi CHECK (posti_totali > 0),
  CONSTRAINT check_posti_occupati CHECK (posti_occupati >= 0),
  CONSTRAINT check_posti_max CHECK (posti_occupati <= posti_totali),
  CONSTRAINT check_date_valide CHECK (data_fine > data_inizio)
);

-- Indice per query frequenti
CREATE INDEX idx_turni_attivo ON turni(attivo);

-- ============================================
-- TABELLA ISCRIZIONI
-- ============================================
CREATE TABLE iscrizioni (
  id BIGSERIAL PRIMARY KEY,
  turno_id BIGINT NOT NULL REFERENCES turni(id) ON DELETE CASCADE,
  
  -- Dati partecipante
  nome TEXT NOT NULL,
  cognome TEXT NOT NULL,
  data_nascita DATE NOT NULL,
  sesso TEXT NOT NULL CHECK (sesso IN ('M', 'F')),
  
  -- Contatti
  email TEXT NOT NULL,
  telefono TEXT NOT NULL,
  indirizzo TEXT NOT NULL,
  citta TEXT NOT NULL,
  cap TEXT NOT NULL,
  
  -- Dati medici
  allergie TEXT,
  farmaci TEXT,
  note_mediche TEXT,
  
  -- Contatti emergenza
  contatto_emergenza_nome TEXT NOT NULL,
  contatto_emergenza_telefono TEXT NOT NULL,
  
  -- Status e posizione
  status TEXT NOT NULL DEFAULT 'WAITING_LIST' 
    CHECK (status IN ('CONFIRMED', 'WAITING_LIST', 'CANCELLED')),
  posizione_lista INTEGER,
  
  -- Consensi GDPR
  consenso_privacy BOOLEAN NOT NULL DEFAULT false,
  consenso_immagini BOOLEAN NOT NULL DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT check_consenso_obbligatorio CHECK (consenso_privacy = true),
  CONSTRAINT check_posizione_lista CHECK (
    (status = 'WAITING_LIST' AND posizione_lista IS NOT NULL) OR
    (status != 'WAITING_LIST' AND posizione_lista IS NULL)
  )
);

-- Indici per performance
CREATE INDEX idx_iscrizioni_turno ON iscrizioni(turno_id);
CREATE INDEX idx_iscrizioni_status ON iscrizioni(status);
CREATE INDEX idx_iscrizioni_lista ON iscrizioni(turno_id, status, posizione_lista) 
  WHERE status = 'WAITING_LIST';
CREATE INDEX idx_iscrizioni_email ON iscrizioni(email);

-- ============================================
-- TABELLA EMAIL QUEUE
-- ============================================
CREATE TABLE email_queue (
  id BIGSERIAL PRIMARY KEY,
  iscrizione_id BIGINT NOT NULL REFERENCES iscrizioni(id) ON DELETE CASCADE,
  email_to TEXT NOT NULL,
  email_type TEXT NOT NULL CHECK (email_type IN ('CONFERMA', 'LISTA_ATTESA', 'PROMOZIONE')),
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ
);

CREATE INDEX idx_email_queue_status ON email_queue(status);
CREATE INDEX idx_email_queue_pending ON email_queue(created_at) WHERE status = 'PENDING';

-- ============================================
-- FUNZIONE: Aggiorna timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger per turni
CREATE TRIGGER trigger_turni_updated_at
  BEFORE UPDATE ON turni
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Trigger per iscrizioni
CREATE TRIGGER trigger_iscrizioni_updated_at
  BEFORE UPDATE ON iscrizioni
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============================================
-- FUNZIONE: Ricalcola posti occupati
-- ============================================
CREATE OR REPLACE FUNCTION ricalcola_posti_occupati()
RETURNS TRIGGER AS $$
BEGIN
  -- Ricalcola il conteggio effettivo
  UPDATE turni
  SET posti_occupati = (
    SELECT COUNT(*)
    FROM iscrizioni
    WHERE turno_id = COALESCE(NEW.turno_id, OLD.turno_id)
      AND status = 'CONFIRMED'
  )
  WHERE id = COALESCE(NEW.turno_id, OLD.turno_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger per aggiornamento automatico posti
CREATE TRIGGER trigger_ricalcola_posti_insert
  AFTER INSERT ON iscrizioni
  FOR EACH ROW
  EXECUTE FUNCTION ricalcola_posti_occupati();

CREATE TRIGGER trigger_ricalcola_posti_update
  AFTER UPDATE ON iscrizioni
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.turno_id IS DISTINCT FROM NEW.turno_id)
  EXECUTE FUNCTION ricalcola_posti_occupati();

CREATE TRIGGER trigger_ricalcola_posti_delete
  AFTER DELETE ON iscrizioni
  FOR EACH ROW
  EXECUTE FUNCTION ricalcola_posti_occupati();

-- ============================================
-- FUNZIONE: Riordina lista d'attesa
-- ============================================
CREATE OR REPLACE FUNCTION riordina_lista_attesa(p_turno_id BIGINT)
RETURNS void AS $$
BEGIN
  -- Riassegna posizioni in ordine cronologico
  WITH lista_ordinata AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) as nuova_posizione
    FROM iscrizioni
    WHERE turno_id = p_turno_id
      AND status = 'WAITING_LIST'
  )
  UPDATE iscrizioni i
  SET posizione_lista = lo.nuova_posizione
  FROM lista_ordinata lo
  WHERE i.id = lo.id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNZIONE: Promuovi da lista d'attesa
-- ============================================
CREATE OR REPLACE FUNCTION promuovi_da_lista_attesa(p_turno_id BIGINT)
RETURNS TABLE(iscrizione_id BIGINT, email TEXT, nome TEXT, cognome TEXT) AS $$
DECLARE
  v_posti_disponibili INTEGER;
  v_iscrizione RECORD;
BEGIN
  -- Verifica posti disponibili
  SELECT posti_totali - posti_occupati INTO v_posti_disponibili
  FROM turni
  WHERE id = p_turno_id;
  
  -- Se non ci sono posti, esci
  IF v_posti_disponibili <= 0 THEN
    RETURN;
  END IF;
  
  -- Prendi la prima persona in lista d'attesa
  SELECT i.id, i.email, i.nome, i.cognome
  INTO v_iscrizione
  FROM iscrizioni i
  WHERE i.turno_id = p_turno_id
    AND i.status = 'WAITING_LIST'
  ORDER BY i.posizione_lista
  LIMIT 1;
  
  -- Se trovata, promuovi
  IF FOUND THEN
    UPDATE iscrizioni
    SET status = 'CONFIRMED',
        posizione_lista = NULL
    WHERE id = v_iscrizione.id;
    
    -- Accoda email di promozione
    INSERT INTO email_queue (iscrizione_id, email_to, email_type)
    VALUES (v_iscrizione.id, v_iscrizione.email, 'PROMOZIONE');
    
    -- Riordina lista
    PERFORM riordina_lista_attesa(p_turno_id);
    
    -- Ritorna dati promosso
    RETURN QUERY SELECT v_iscrizione.id, v_iscrizione.email, v_iscrizione.nome, v_iscrizione.cognome;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTI DOCUMENTAZIONE
-- ============================================
COMMENT ON TABLE turni IS 'Tabella turni campeggio con conteggio automatico posti';
COMMENT ON TABLE iscrizioni IS 'Iscrizioni con gestione atomica stato e lista attesa';
COMMENT ON TABLE email_queue IS 'Coda email asincrone con retry logic';
COMMENT ON FUNCTION ricalcola_posti_occupati() IS 'Trigger automatico per conteggio posti aggiornato';
COMMENT ON FUNCTION riordina_lista_attesa(BIGINT) IS 'Riordina posizioni lista attesa in ordine cronologico';
COMMENT ON FUNCTION promuovi_da_lista_attesa(BIGINT) IS 'Promuove automaticamente prima persona in lista';
