-- ============================================
-- FUNZIONI RPC - Sistema Campeggi
-- ============================================
-- Funzioni chiamabili dal frontend via supabase.rpc()
-- ============================================

-- ============================================
-- FUNZIONE RPC: Nuova iscrizione atomica
-- ============================================
CREATE OR REPLACE FUNCTION crea_iscrizione(
  p_turno_id BIGINT,
  p_nome TEXT,
  p_cognome TEXT,
  p_data_nascita DATE,
  p_sesso TEXT,
  p_email TEXT,
  p_telefono TEXT,
  p_indirizzo TEXT,
  p_citta TEXT,
  p_cap TEXT,
  p_allergie TEXT DEFAULT NULL,
  p_farmaci TEXT DEFAULT NULL,
  p_note_mediche TEXT DEFAULT NULL,
  p_contatto_emergenza_nome TEXT,
  p_contatto_emergenza_telefono TEXT,
  p_consenso_privacy BOOLEAN,
  p_consenso_immagini BOOLEAN DEFAULT false
)
RETURNS JSON AS $$
DECLARE
  v_turno RECORD;
  v_posti_disponibili INTEGER;
  v_status TEXT;
  v_posizione_lista INTEGER;
  v_iscrizione_id BIGINT;
  v_email_type TEXT;
BEGIN
  -- Validazioni input
  IF p_consenso_privacy IS NOT TRUE THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Il consenso privacy è obbligatorio'
    );
  END IF;
  
  IF p_turno_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ID turno non valido'
    );
  END IF;
  
  -- Verifica turno esiste ed è attivo
  SELECT * INTO v_turno
  FROM turni
  WHERE id = p_turno_id AND attivo = true
  FOR UPDATE; -- Lock per evitare race condition
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Turno non trovato o non attivo'
    );
  END IF;
  
  -- Calcola posti disponibili
  v_posti_disponibili := v_turno.posti_totali - v_turno.posti_occupati;
  
  -- Determina status
  IF v_posti_disponibili > 0 THEN
    v_status := 'CONFIRMED';
    v_posizione_lista := NULL;
    v_email_type := 'CONFERMA';
  ELSE
    v_status := 'WAITING_LIST';
    -- Calcola prossima posizione in lista
    SELECT COALESCE(MAX(posizione_lista), 0) + 1
    INTO v_posizione_lista
    FROM iscrizioni
    WHERE turno_id = p_turno_id AND status = 'WAITING_LIST';
    v_email_type := 'LISTA_ATTESA';
  END IF;
  
  -- Inserisci iscrizione
  INSERT INTO iscrizioni (
    turno_id,
    nome,
    cognome,
    data_nascita,
    sesso,
    email,
    telefono,
    indirizzo,
    citta,
    cap,
    allergie,
    farmaci,
    note_mediche,
    contatto_emergenza_nome,
    contatto_emergenza_telefono,
    status,
    posizione_lista,
    consenso_privacy,
    consenso_immagini
  ) VALUES (
    p_turno_id,
    TRIM(p_nome),
    TRIM(p_cognome),
    p_data_nascita,
    p_sesso,
    LOWER(TRIM(p_email)),
    TRIM(p_telefono),
    TRIM(p_indirizzo),
    TRIM(p_citta),
    TRIM(p_cap),
    NULLIF(TRIM(p_allergie), ''),
    NULLIF(TRIM(p_farmaci), ''),
    NULLIF(TRIM(p_note_mediche), ''),
    TRIM(p_contatto_emergenza_nome),
    TRIM(p_contatto_emergenza_telefono),
    v_status,
    v_posizione_lista,
    p_consenso_privacy,
    p_consenso_immagini
  ) RETURNING id INTO v_iscrizione_id;
  
  -- Accoda email
  INSERT INTO email_queue (iscrizione_id, email_to, email_type)
  VALUES (v_iscrizione_id, LOWER(TRIM(p_email)), v_email_type);
  
  -- Ritorna risultato
  RETURN json_build_object(
    'success', true,
    'iscrizione_id', v_iscrizione_id,
    'status', v_status,
    'posizione_lista', v_posizione_lista,
    'turno_nome', v_turno.nome,
    'turno_luogo', v_turno.luogo,
    'data_inizio', v_turno.data_inizio,
    'data_fine', v_turno.data_fine
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNZIONE RPC: Cancella iscrizione (ADMIN)
-- ============================================
CREATE OR REPLACE FUNCTION cancella_iscrizione(p_iscrizione_id BIGINT)
RETURNS JSON AS $$
DECLARE
  v_iscrizione RECORD;
  v_promosso RECORD;
BEGIN
  -- Recupera iscrizione
  SELECT * INTO v_iscrizione
  FROM iscrizioni
  WHERE id = p_iscrizione_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Iscrizione non trovata');
  END IF;
  
  -- Se era confermata, prova a promuovere dalla lista
  IF v_iscrizione.status = 'CONFIRMED' THEN
    -- Marca come cancellata
    UPDATE iscrizioni
    SET status = 'CANCELLED'
    WHERE id = p_iscrizione_id;
    
    -- Promuovi dalla lista
    SELECT * INTO v_promosso
    FROM promuovi_da_lista_attesa(v_iscrizione.turno_id)
    LIMIT 1;
    
    IF FOUND THEN
      RETURN json_build_object(
        'success', true,
        'promosso', json_build_object(
          'id', v_promosso.iscrizione_id,
          'nome', v_promosso.nome,
          'cognome', v_promosso.cognome,
          'email', v_promosso.email
        )
      );
    END IF;
  ELSE
    -- Marca come cancellata
    UPDATE iscrizioni
    SET status = 'CANCELLED',
        posizione_lista = NULL
    WHERE id = p_iscrizione_id;
    
    -- Riordina lista
    PERFORM riordina_lista_attesa(v_iscrizione.turno_id);
  END IF;
  
  RETURN json_build_object('success', true, 'promosso', NULL);
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNZIONE RPC: Promuovi manualmente (ADMIN)
-- ============================================
CREATE OR REPLACE FUNCTION promuovi_iscrizione(p_iscrizione_id BIGINT)
RETURNS JSON AS $$
DECLARE
  v_iscrizione RECORD;
  v_posti_disponibili INTEGER;
BEGIN
  -- Recupera iscrizione
  SELECT i.*, t.posti_totali - t.posti_occupati as posti_liberi
  INTO v_iscrizione
  FROM iscrizioni i
  JOIN turni t ON t.id = i.turno_id
  WHERE i.id = p_iscrizione_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Iscrizione non trovata');
  END IF;
  
  IF v_iscrizione.status != 'WAITING_LIST' THEN
    RETURN json_build_object('success', false, 'error', 'Iscrizione non in lista d''attesa');
  END IF;
  
  IF v_iscrizione.posti_liberi <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Nessun posto disponibile');
  END IF;
  
  -- Promuovi
  UPDATE iscrizioni
  SET status = 'CONFIRMED',
      posizione_lista = NULL
  WHERE id = p_iscrizione_id;
  
  -- Accoda email
  INSERT INTO email_queue (iscrizione_id, email_to, email_type)
  VALUES (p_iscrizione_id, v_iscrizione.email, 'PROMOZIONE');
  
  -- Riordina lista
  PERFORM riordina_lista_attesa(v_iscrizione.turno_id);
  
  RETURN json_build_object('success', true);
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNZIONE RPC: Ottieni statistiche turno (ADMIN)
-- ============================================
CREATE OR REPLACE FUNCTION get_turno_stats(p_turno_id BIGINT)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'confermati', COUNT(*) FILTER (WHERE status = 'CONFIRMED'),
    'lista_attesa', COUNT(*) FILTER (WHERE status = 'WAITING_LIST'),
    'cancellati', COUNT(*) FILTER (WHERE status = 'CANCELLED'),
    'posti_totali', (SELECT posti_totali FROM turni WHERE id = p_turno_id),
    'posti_occupati', (SELECT posti_occupati FROM turni WHERE id = p_turno_id),
    'posti_disponibili', (SELECT posti_totali - posti_occupati FROM turni WHERE id = p_turno_id)
  ) INTO v_result
  FROM iscrizioni
  WHERE turno_id = p_turno_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- COMMENTI DOCUMENTAZIONE
-- ============================================
COMMENT ON FUNCTION crea_iscrizione IS 'Crea iscrizione atomica con gestione automatica status e lista attesa';
COMMENT ON FUNCTION cancella_iscrizione IS 'Cancella iscrizione e promuove automaticamente dalla lista [ADMIN]';
COMMENT ON FUNCTION promuovi_iscrizione IS 'Promuove manualmente iscrizione dalla lista attesa [ADMIN]';
COMMENT ON FUNCTION get_turno_stats IS 'Ritorna statistiche turno per dashboard admin';
