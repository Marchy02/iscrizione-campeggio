-- ============================================
-- ROW LEVEL SECURITY POLICIES CORRETTE
-- ============================================

ALTER TABLE turni ENABLE ROW LEVEL SECURITY;
ALTER TABLE iscrizioni ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;

-- ============================================
-- POLICIES: TURNI
-- ============================================

CREATE POLICY "Turni attivi leggibili da tutti"
ON turni FOR SELECT
TO anon, authenticated
USING (attivo = true);

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

CREATE POLICY "Nessuna scrittura diretta iscrizioni"
ON iscrizioni FOR INSERT
TO anon, authenticated
WITH CHECK (false);

CREATE POLICY "Admin leggono tutte iscrizioni"
ON iscrizioni FOR SELECT
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);

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

CREATE POLICY "Solo sistema accede email queue"
ON email_queue FOR ALL
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'service_role' OR
  auth.jwt() ->> 'role' = 'admin' OR
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);
