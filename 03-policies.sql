-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================
-- Sicurezza semplice e verificata
-- ============================================

-- ============================================
-- ABILITA RLS
-- ============================================
ALTER TABLE turni ENABLE ROW LEVEL SECURITY;
ALTER TABLE iscrizioni ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;

-- ============================================
-- POLICIES: TURNI
-- ============================================

-- Tutti possono LEGGERE turni attivi (utenti pubblici)
CREATE POLICY "Turni attivi leggibili da tutti"
ON turni FOR SELECT
TO anon, authenticated
USING (attivo = true);

-- Solo admin possono gestire turni
CREATE POLICY "Admin possono gestire turni"
ON turni FOR ALL
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- ============================================
-- POLICIES: ISCRIZIONI
-- ============================================

-- Nessuno può scrivere direttamente (solo via RPC)
CREATE POLICY "Nessuna scrittura diretta iscrizioni"
ON iscrizioni FOR INSERT
TO anon, authenticated
WITH CHECK (false);

-- Admin possono leggere tutte le iscrizioni
CREATE POLICY "Admin leggono tutte iscrizioni"
ON iscrizioni FOR SELECT
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- Admin possono aggiornare iscrizioni
CREATE POLICY "Admin aggiornano iscrizioni"
ON iscrizioni FOR UPDATE
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- ============================================
-- POLICIES: EMAIL QUEUE
-- ============================================

-- Solo sistema può accedere alla coda email
CREATE POLICY "Solo sistema accede email queue"
ON email_queue FOR ALL
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'service_role' OR
  auth.jwt() ->> 'role' = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

-- ============================================
-- GRANT PERMESSI PER FUNZIONI RPC
-- ============================================

-- Funzioni pubbliche (callable da anon)
GRANT EXECUTE ON FUNCTION crea_iscrizione TO anon, authenticated;

-- Funzioni admin
GRANT EXECUTE ON FUNCTION cancella_iscrizione TO authenticated;
GRANT EXECUTE ON FUNCTION promuovi_iscrizione TO authenticated;
GRANT EXECUTE ON FUNCTION get_turno_stats TO authenticated;
GRANT EXECUTE ON FUNCTION promuovi_da_lista_attesa TO authenticated;
GRANT EXECUTE ON FUNCTION riordina_lista_attesa TO authenticated;

-- ============================================
-- VERIFICA CONFIGURAZIONE
-- ============================================

-- Query di test per verificare RLS
DO $$
BEGIN
  -- Verifica RLS abilitato
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename IN ('turni', 'iscrizioni', 'email_queue')
    AND rowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS non abilitato correttamente';
  END IF;
  
  RAISE NOTICE 'RLS configurato correttamente';
END $$;

-- ============================================
-- HELPER: Reset completo sistema (SOLO DEV)
-- ============================================
CREATE OR REPLACE FUNCTION reset_sistema_dev()
RETURNS void AS $$
BEGIN
  -- ATTENZIONE: Usa solo in sviluppo!
  DELETE FROM email_queue;
  DELETE FROM iscrizioni;
  UPDATE turni SET posti_occupati = 0;
  
  RAISE NOTICE 'Sistema resettato - SOLO SVILUPPO';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION reset_sistema_dev IS 'Reset completo sistema - SOLO SVILUPPO';

-- ============================================
-- DOCUMENTA POLICIES
-- ============================================
COMMENT ON POLICY "Turni attivi leggibili da tutti" ON turni 
  IS 'Utenti pubblici vedono solo turni attivi';
COMMENT ON POLICY "Admin possono gestire turni" ON turni 
  IS 'Admin hanno accesso completo ai turni';
COMMENT ON POLICY "Nessuna scrittura diretta iscrizioni" ON iscrizioni 
  IS 'Blocca INSERT diretti, forza uso di crea_iscrizione()';
COMMENT ON POLICY "Admin leggono tutte iscrizioni" ON iscrizioni 
  IS 'Admin vedono tutte le iscrizioni per gestione';
