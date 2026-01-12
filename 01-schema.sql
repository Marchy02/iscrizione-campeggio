-- ============================================
-- SCHEMA DATABASE CORRETTO - Sistema Campeggi v2.1
-- ============================================
-- Fix: Rimossi default su parametri funzioni
-- Fix: Campi form corretti come da requisiti
-- ============================================

-- Drop existing
DROP TABLE IF EXISTS iscrizioni CASCADE;
DROP TABLE IF EXISTS turni CASCADE;
DROP TABLE IF EXISTS email_queue CASCADE;
DROP FUNCTION IF EXISTS crea_iscrizione CASCADE;
DROP FUNCTION IF EXISTS cancella_iscrizione CASCADE;
DROP FUNCTION IF EXISTS promuovi_iscrizione CASCADE;
DROP FUNCTION IF EXISTS get_turno_stats CASCADE;
DROP FUNCTION IF EXISTS promuovi_da_lista_attesa CASCADE;
DROP FUNCTION IF EXISTS riordina_lista_attesa CASCADE;

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

CREATE INDEX idx_turni_attivo ON turni(attivo);

-- ============================================
-- TABELLA ISCRIZIONI (con campi corretti)
-- ============================================
CREATE TABLE iscrizioni (
  id BIGSERIAL PRIMARY KEY,
  turno_id BIGINT NOT NULL REFERENCES turni(id) ON DELETE CASCADE,
  
  -- Dati partecipante (obbligatori)
  nome TEXT NOT NULL,
  cognome TEXT NOT NULL,
  data_nascita DATE NOT NULL,
  luogo_nascita TEXT NOT NULL,
  
  -- Residenza (obbligatori)
  indirizzo TEXT NOT NULL,
  citta TEXT NOT NULL,
  
  -- Maggiorenne
  e_maggiorenne BOOLEAN NOT NULL,
  
  -- Dati genitore/tutore (se minorenne)
  nome_genitore TEXT,
  cognome_genitore TEXT,
  
  -- Contatti (obbligatori)
  email TEXT NOT NULL,
  telefono TEXT NOT NULL,
  
  -- Dati sanitari
  ha_allergie BOOLEAN NOT NULL DEFAULT false,
  descrizione_allergie TEXT,
  ha_medicinali BOOLEAN NOT NULL DEFAULT false,
  descrizione_medicinali TEXT,
  
  -- Consenso GDPR (obbligatorio)
  consenso_gdpr BOOLEAN NOT NULL,
  
  -- Status e posizione
  status TEXT NOT NULL DEFAULT 'WAITING_LIST' 
    CHECK (status IN ('CONFIRMED', 'WAITING_LIST', 'CANCELLED')),
  posizione_lista INTEGER,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT check_consenso_obbligatorio CHECK (consenso_gdpr = true),
  CONSTRAINT check_dati_genitore CHECK (
    (e_maggiorenne = false AND nome_genitore IS NOT NULL AND cognome_genitore IS NOT NULL) OR
    (e_maggiorenne = true)
  ),
  CONSTRAINT check_allergie CHECK (
    (ha_allergie = true AND descrizione_allergie IS NOT NULL) OR
    (ha_allergie = false)
  ),
  CONSTRAINT check_medicinali CHECK (
    (ha_medicinali = true AND descrizione_medicinali IS NOT NULL) OR
    (ha_medicinali = false)
  ),
  CONSTRAINT check_posizione_lista CHECK (
    (status = 'WAITING_LIST' AND posizione_lista IS NOT NULL) OR
    (status != 'WAITING_LIST' AND posizione_lista IS NULL)
  )
);

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
-- TRIGGER: Aggiorna timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_turni_updated_at
  BEFORE UPDATE ON turni
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_iscrizioni_updated_at
  BEFORE UPDATE ON iscrizioni
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============================================
-- TRIGGER: Ricalcola posti occupati
-- ============================================
CREATE OR REPLACE FUNCTION ricalcola_posti_occupati()
RETURNS TRIGGER AS $$
BEGIN
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
  SELECT posti_totali - posti_occupati INTO v_posti_disponibili
  FROM turni
  WHERE id = p_turno_id;
  
  IF v_posti_disponibili <= 0 THEN
    RETURN;
  END IF;
  
  SELECT i.id, i.email, i.nome, i.cognome
  INTO v_iscrizione
  FROM iscrizioni i
  WHERE i.turno_id = p_turno_id
    AND i.status = 'WAITING_LIST'
  ORDER BY i.posizione_lista
  LIMIT 1;
  
  IF FOUND THEN
    UPDATE iscrizioni
    SET status = 'CONFIRMED',
        posizione_lista = NULL
    WHERE id = v_iscrizione.id;
    
    INSERT INTO email_queue (iscrizione_id, email_to, email_type)
    VALUES (v_iscrizione.id, v_iscrizione.email, 'PROMOZIONE');
    
    PERFORM riordina_lista_attesa(p_turno_id);
    
    RETURN QUERY SELECT v_iscrizione.id, v_iscrizione.email, v_iscrizione.nome, v_iscrizione.cognome;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- INSERISCI DATI DI ESEMPIO
-- ============================================
INSERT INTO turni (nome, luogo, data_inizio, data_fine, posti_totali, attivo) VALUES
  ('Turno Bambini 6-10 anni', 'Rifugio Monte Baldo', '2025-06-15', '2025-06-22', 30, true),
  ('Turno Ragazzi 11-14 anni', 'Rifugio Monte Baldo', '2025-06-29', '2025-07-06', 30, true),
  ('Turno Adolescenti 15-17 anni', 'Rifugio Monte Baldo', '2025-07-13', '2025-07-20', 30, true);
