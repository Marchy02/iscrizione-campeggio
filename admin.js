// Configurazione Supabase
const SUPABASE_URL = 'https://kneoivwhuafmqpownblh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZW9pdndodWFmbXFwb3duYmxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDI3OTgsImV4cCI6MjA4MzcxODc5OH0.n5wq8hZMFdoOnSDw7y14pT_cOeL-zUShHH2OuDavizQ';

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

let currentUser = null;
let currentTurnoId = null;

// Inizializzazione
async function init() {
  // Verifica sessione esistente
  const { data: { session } } = await supabase.auth.getSession();
  
  if (session) {
    currentUser = session.user;
    mostraAdmin();
    await caricaTurniSelect();
  } else {
    mostraLogin();
  }

  // Listener cambio auth
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN') {
      currentUser = session.user;
      mostraAdmin();
      caricaTurniSelect();
    } else if (event === 'SIGNED_OUT') {
      currentUser = null;
      mostraLogin();
    }
  });

  // Event listeners
  document.getElementById('login-form').addEventListener('submit', handleLogin);
  document.getElementById('logout-btn').addEventListener('click', handleLogout);
  document.getElementById('turno-select').addEventListener('change', handleTurnoChange);
  document.getElementById('refresh-btn').addEventListener('click', () => caricaDatiTurno(currentTurnoId));

  // Tabs
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', function() {
      const tab = this.dataset.tab;
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
      this.classList.add('active');
      document.getElementById(`${tab}-tab`).classList.add('active');
    });
  });
}

// Mostra sezione login
function mostraLogin() {
  document.getElementById('login-section').style.display = 'flex';
  document.getElementById('admin-section').style.display = 'none';
  document.getElementById('user-info').style.display = 'none';
}

// Mostra sezione admin
function mostraAdmin() {
  document.getElementById('login-section').style.display = 'none';
  document.getElementById('admin-section').style.display = 'block';
  document.getElementById('user-info').style.display = 'flex';
  document.getElementById('user-email').textContent = currentUser.email;
}

// Login
async function handleLogin(e) {
  e.preventDefault();
  
  const email = document.getElementById('login-email').value;
  const password = document.getElementById('login-password').value;
  const errorDiv = document.getElementById('login-error');

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) throw error;

    errorDiv.style.display = 'none';
  } catch (error) {
    console.error('Errore login:', error);
    errorDiv.textContent = 'Email o password errati';
    errorDiv.style.display = 'block';
  }
}

// Logout
async function handleLogout() {
  try {
    await supabase.auth.signOut();
  } catch (error) {
    console.error('Errore logout:', error);
  }
}

// Carica turni nel select
async function caricaTurniSelect() {
  try {
    const { data: turni, error } = await supabase
      .from('turni')
      .select('*')
      .order('data_inizio', { ascending: true });

    if (error) throw error;

const select = document.getElementById('turno-select');
    select.innerHTML = '<option value="">-- Seleziona un turno --</option>';

    turni.forEach(turno => {
      const option = document.createElement('option');
      option.value = turno.id;
      option.textContent = turno.nome;
      select.appendChild(option);
    });

    // Seleziona automaticamente il primo turno
    if (turni.length > 0) {
      select.value = turni[0].id;
      currentTurnoId = turni[0].id;
      await caricaDatiTurno(turni[0].id);
    }

  } catch (error) {
    console.error('Errore caricamento turni:', error);
  }
}

// Cambio turno
async function handleTurnoChange(e) {
  const turnoId = e.target.value;
  if (turnoId) {
    currentTurnoId = parseInt(turnoId);
    await caricaDatiTurno(currentTurnoId);
  }
}

// Carica dati completi del turno
async function caricaDatiTurno(turnoId) {
  if (!turnoId) return;

  try {
    // Carica statistiche
    const { data: turno, error: turnoError } = await supabase
      .from('turni')
      .select('*')
      .eq('id', turnoId)
      .single();

    if (turnoError) throw turnoError;

    // Conta lista d'attesa
    const { count: countAttesa, error: countError } = await supabase
      .from('iscrizioni')
      .select('*', { count: 'exact', head: true })
      .eq('turno_id', turnoId)
      .eq('status', 'WAITING_LIST');

    if (countError) throw countError;

    mostraStatistiche(turno, countAttesa || 0);

    // Carica iscrizioni confermate
    await caricaIscrizioni(turnoId, 'CONFIRMED', 'confermati-container');

    // Carica lista d'attesa
    await caricaIscrizioni(turnoId, 'WAITING_LIST', 'attesa-container');

  } catch (error) {
    console.error('Errore caricamento dati:', error);
    alert('Errore nel caricamento dei dati');
  }
}

// Mostra statistiche
function mostraStatistiche(turno, countAttesa) {
  const postiDisponibili = turno.posti_totali - turno.posti_occupati;
  
  const statsSection = document.getElementById('stats-section');
  statsSection.innerHTML = `
    <div class="stat-card">
      <h4>Posti Totali</h4>
      <div class="stat-value">${turno.posti_totali}</div>
    </div>
    <div class="stat-card">
      <h4>Posti Occupati</h4>
      <div class="stat-value">${turno.posti_occupati}</div>
    </div>
    <div class="stat-card">
      <h4>Posti Disponibili</h4>
      <div class="stat-value">${postiDisponibili}</div>
    </div>
    <div class="stat-card">
      <h4>Lista d'Attesa</h4>
      <div class="stat-value">${countAttesa}</div>
    </div>
  `;
}

// Carica iscrizioni
async function caricaIscrizioni(turnoId, status, containerId) {
  const container = document.getElementById(containerId);
  container.innerHTML = '<p style="text-align: center; color: #8D6E63;">Caricamento...</p>';

  try {
    let query = supabase
      .from('iscrizioni')
      .select('*')
      .eq('turno_id', turnoId)
      .eq('status', status);

    if (status === 'WAITING_LIST') {
      query = query.order('posizione_lista', { ascending: true });
    } else {
      query = query.order('created_at', { ascending: true });
    }

    const { data: iscrizioni, error } = await query;

    if (error) throw error;

    if (iscrizioni.length === 0) {
      container.innerHTML = `<p style="text-align: center; color: #8D6E63;">Nessuna iscrizione ${status === 'WAITING_LIST' ? 'in lista d\'attesa' : 'confermata'}</p>`;
      return;
    }

    container.innerHTML = '';
    iscrizioni.forEach(iscrizione => {
      const item = creaIscrizioneItem(iscrizione);
      container.appendChild(item);
    });

  } catch (error) {
    console.error('Errore caricamento iscrizioni:', error);
    container.innerHTML = '<p style="text-align: center; color: #F44336;">Errore nel caricamento</p>';
  }
}

// Crea elemento iscrizione
function creaIscrizioneItem(iscrizione) {
  const item = document.createElement('div');
  item.className = 'iscrizione-item';

  const dataNascita = new Date(iscrizione.data_nascita).toLocaleDateString('it-IT');
  const dataIscrizione = new Date(iscrizione.created_at).toLocaleDateString('it-IT');

  let posizioneHTML = '';
  if (iscrizione.status === 'WAITING_LIST' && iscrizione.posizione_lista) {
    posizioneHTML = `<span class="posizione-badge">Posizione #${iscrizione.posizione_lista}</span>`;
  }

  let genitoreHTML = '';
  if (!iscrizione.maggiorenne && iscrizione.genitore_nome) {
    genitoreHTML = `
      <div class="iscrizione-detail">
        <strong>Genitore:</strong> ${iscrizione.genitore_nome} ${iscrizione.genitore_cognome}
      </div>
    `;
  }

  let allergieMedicineHTML = '';
  if (iscrizione.ha_allergie || iscrizione.assume_medicinali) {
    allergieMedicineHTML = '<div class="iscrizione-detail" style="grid-column: 1 / -1; background: #FFF3E0; padding: 10px; border-radius: 8px; margin-top: 10px;">';
    if (iscrizione.ha_allergie) {
      allergieMedicineHTML += `<div><strong>⚠️ Allergie:</strong> ${iscrizione.allergie_desc || 'N/D'}</div>`;
    }
    if (iscrizione.assume_medicinali) {
      allergieMedicineHTML += `<div style="margin-top: 5px;"><strong>💊 Medicinali:</strong> ${iscrizione.medicinali_desc || 'N/D'}</div>`;
    }
    allergieMedicineHTML += '</div>';
  }

  item.innerHTML = `
    <div class="iscrizione-header">
      <div>
        <div class="iscrizione-nome">${iscrizione.nome} ${iscrizione.cognome}</div>
        ${posizioneHTML}
      </div>
      <div class="iscrizione-actions">
        ${iscrizione.status === 'WAITING_LIST' ? 
          `<button class="btn-success" onclick="promuoviIscrizione('${iscrizione.id}')">↑ Promuovi</button>` : 
          ''}
        <button class="btn-danger" onclick="cancellaIscrizione('${iscrizione.id}')">✕ Cancella</button>
      </div>
    </div>
    <div class="iscrizione-details">
      <div class="iscrizione-detail">
        <strong>📧 Email:</strong> ${iscrizione.email}
      </div>
      <div class="iscrizione-detail">
        <strong>📞 Telefono:</strong> ${iscrizione.telefono}
      </div>
      <div class="iscrizione-detail">
        <strong>🎂 Nato il:</strong> ${dataNascita}
      </div>
      <div class="iscrizione-detail">
        <strong>📍 Luogo:</strong> ${iscrizione.luogo_nascita}
      </div>
      <div class="iscrizione-detail">
        <strong>🏠 Residenza:</strong> ${iscrizione.residenza_via}, ${iscrizione.residenza_citta}
      </div>
      <div class="iscrizione-detail">
        <strong>📅 Iscritto il:</strong> ${dataIscrizione}
      </div>
      ${genitoreHTML}
      ${allergieMedicineHTML}
    </div>
  `;

  return item;
}

// Promuovi da lista d'attesa
window.promuoviIscrizione = async function(iscrizioneId) {
  if (!confirm('Confermi la promozione di questo partecipante?')) return;

  try {
    // Aggiorna status a CONFIRMED
    const { error: updateError } = await supabase
      .from('iscrizioni')
      .update({ 
        status: 'CONFIRMED', 
        posizione_lista: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', iscrizioneId);

    if (updateError) throw updateError;

    // Riordina le posizioni rimanenti in lista d'attesa
    const { data: iscrizioniAttesa, error: fetchError } = await supabase
      .from('iscrizioni')
      .select('id, posizione_lista')
      .eq('turno_id', currentTurnoId)
      .eq('status', 'WAITING_LIST')
      .order('posizione_lista', { ascending: true });

    if (fetchError) throw fetchError;

    // Aggiorna le posizioni
    for (let i = 0; i < iscrizioniAttesa.length; i++) {
      await supabase
        .from('iscrizioni')
        .update({ posizione_lista: i + 1 })
        .eq('id', iscrizioniAttesa[i].id);
    }

    alert('Iscrizione promossa con successo!');
    await caricaDatiTurno(currentTurnoId);

  } catch (error) {
    console.error('Errore promozione:', error);
    alert('Errore nella promozione dell\'iscrizione');
  }
};

// Cancella iscrizione
window.cancellaIscrizione = async function(iscrizioneId) {
  if (!confirm('Sei sicuro di voler cancellare questa iscrizione? Questa azione non può essere annullata.')) return;

  try {
    // Recupera l'iscrizione prima di cancellarla
    const { data: iscrizione, error: fetchError } = await supabase
      .from('iscrizioni')
      .select('*')
      .eq('id', iscrizioneId)
      .single();

    if (fetchError) throw fetchError;

    // Cancella iscrizione
    const { error: deleteError } = await supabase
      .from('iscrizioni')
      .delete()
      .eq('id', iscrizioneId);

    if (deleteError) throw deleteError;

    // Se era CONFIRMED, prova a promuovere automaticamente dalla lista d'attesa
    if (iscrizione.status === 'CONFIRMED') {
      await promuoviAutomaticamente(iscrizione.turno_id);
    }

    alert('Iscrizione cancellata con successo');
    await caricaDatiTurno(currentTurnoId);

  } catch (error) {
    console.error('Errore cancellazione:', error);
    alert('Errore nella cancellazione dell\'iscrizione');
  }
};

// Promuovi automaticamente dalla lista d'attesa
async function promuoviAutomaticamente(turnoId) {
  try {
    // Verifica se ci sono posti disponibili
    const { data: turno } = await supabase
      .from('turni')
      .select('posti_totali, posti_occupati')
      .eq('id', turnoId)
      .single();

    const postiDisponibili = turno.posti_totali - turno.posti_occupati;

    if (postiDisponibili > 0) {
      // Prendi il primo in lista d'attesa
      const { data: primoInAttesa, error: fetchError } = await supabase
        .from('iscrizioni')
        .select('*')
        .eq('turno_id', turnoId)
        .eq('status', 'WAITING_LIST')
        .order('posizione_lista', { ascending: true })
        .limit(1)
        .single();

      if (fetchError || !primoInAttesa) return;

      // Promuovi
      await supabase
        .from('iscrizioni')
        .update({ 
          status: 'CONFIRMED', 
          posizione_lista: null,
          updated_at: new Date().toISOString()
        })
        .eq('id', primoInAttesa.id);

      // Riordina posizioni rimanenti
      const { data: iscrizioniAttesa } = await supabase
        .from('iscrizioni')
        .select('id, posizione_lista')
        .eq('turno_id', turnoId)
        .eq('status', 'WAITING_LIST')
        .order('posizione_lista', { ascending: true });

      for (let i = 0; i < iscrizioniAttesa.length; i++) {
        await supabase
          .from('iscrizioni')
          .update({ posizione_lista: i + 1 })
          .eq('id', iscrizioniAttesa[i].id);
      }

      console.log('Promozione automatica completata');
    }

  } catch (error) {
    console.error('Errore promozione automatica:', error);
  }
}

// Inizializza app
init();