-- ============================================
-- FUNZIONI RPC CORRETTE - Sistema Campeggi v2.1
-- ============================================
-- Fix: NESSUN parametro con DEFAULT
-- Fix: Parametri nullable gestiti con COALESCE
-- ============================================

-- ============================================
-- FUNZIONE RPC: Nuova iscrizione atomica
-- ============================================
CREATE OR REPLACE FUNCTION crea_iscrizione(
  -- Parametri SENZA DEFAULT (tutti obbligatori o nullable)
  p_turno_id BIGINT,
  p_nome TEXT,
  p_cognome TEXT,
  p_data_nascita DATE,
  p_luogo_nascita TEXT,
  p_indirizzo TEXT,
  p_citta TEXT,
  p_e_maggiorenne BOOLEAN,
  p_nome_genitore TEXT,
  p_cognome_genitore TEXT,
  p_email TEXT,
  p_telefono TEXT,
  p_ha_allergie BOOLEAN,
  p_descrizione_allergie TEXT,
  p_ha_medicinali BOOLEAN,
  p_descrizione_medicinali TEXT,
  p_consenso_gdpr BOOLEAN
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
  -- Validazione consenso GDPR
  IF p_consenso_gdpr IS NOT TRUE THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Il consenso GDPR è obbligatorio'
    );
  END IF;
  
  -- Validazione turno
  IF p_turno_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ID turno non valido'
    );
  END IF;
  
  -- Validazione dati genitore se minorenne
  IF p_e_maggiorenne = false AND (p_nome_genitore IS NULL OR p_cognome_genitore IS NULL) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Dati genitore obbligatori per minorenni'
    );
  END IF;
  
  -- Validazione allergie
  IF p_ha_allergie = true AND (p_descrizione_allergie IS NULL OR TRIM(p_descrizione_allergie) = '') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Descrizione allergie obbligatoria se presenti'
    );
  END IF;
  
  -- Validazione medicinali
  IF p_ha_medicinali = true AND (p_descrizione_medicinali IS NULL OR TRIM(p_descrizione_medicinali) = '') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Descrizione medicinali obbligatoria se presenti'
    );
  END IF;
  
  -- Verifica turno esiste ed è attivo (con lock)
  SELECT * INTO v_turno
  FROM turni
  WHERE id = p_turno_id AND attivo = true
  FOR UPDATE;
  
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
    luogo_nascita,
    indirizzo,
    citta,
    e_maggiorenne,
    nome_genitore,
    cognome_genitore,
    email,
    telefono,
    ha_allergie,
    descrizione_allergie,
    ha_medicinali,
    descrizione_medicinali,
    consenso_gdpr,
    status,
    posizione_lista
  ) VALUES (
    p_turno_id,
    TRIM(p_nome),
    TRIM(p_cognome),
    p_data_nascita,
    TRIM(p_luogo_nascita),
    TRIM(p_indirizzo),
    TRIM(p_citta),
    p_e_maggiorenne,
    CASE WHEN p_e_maggiorenne = false THEN TRIM(p_nome_genitore) ELSE NULL END,
    CASE WHEN p_e_maggiorenne = false THEN TRIM(p_cognome_genitore) ELSE NULL END,
    LOWER(TRIM(p_email)),
    TRIM(p_telefono),
    COALESCE(p_ha_allergie, false),
    CASE WHEN COALESCE(p_ha_allergie, false) = true THEN TRIM(p_descrizione_allergie) ELSE NULL END,
    COALESCE(p_ha_medicinali, false),
    CASE WHEN COALESCE(p_ha_medicinali, false) = true THEN TRIM(p_descrizione_medicinali) ELSE NULL END,
    p_consenso_gdpr,
    v_status,
    v_posizione_lista
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
  SELECT * INTO v_iscrizione
  FROM iscrizioni
  WHERE id = p_iscrizione_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Iscrizione non trovata');
  END IF;
  
  IF v_iscrizione.status = 'CONFIRMED' THEN
    UPDATE iscrizioni
    SET status = 'CANCELLED'
    WHERE id = p_iscrizione_id;
    
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
    UPDATE iscrizioni
    SET status = 'CANCELLED',
        posizione_lista = NULL
    WHERE id = p_iscrizione_id;
    
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
BEGIN
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
  
  UPDATE iscrizioni
  SET status = 'CONFIRMED',
      posizione_lista = NULL
  WHERE id = p_iscrizione_id;
  
  INSERT INTO email_queue (iscrizione_id, email_to, email_type)
  VALUES (p_iscrizione_id, v_iscrizione.email, 'PROMOZIONE');
  
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
-- GRANT PERMESSI
-- ============================================
GRANT EXECUTE ON FUNCTION crea_iscrizione TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cancella_iscrizione TO authenticated;
GRANT EXECUTE ON FUNCTION promuovi_iscrizione TO authenticated;
GRANT EXECUTE ON FUNCTION get_turno_stats TO authenticated;
GRANT EXECUTE ON FUNCTION promuovi_da_lista_attesa TO authenticated;
GRANT EXECUTE ON FUNCTION riordina_lista_attesa TO authenticated;
