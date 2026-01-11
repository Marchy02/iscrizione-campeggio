// ⚠️ SOSTITUISCI QUESTI VALORI CON I TUOI
const SUPABASE_URL = 'https://kneoivwhuafmqpownblh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZW9pdndodWFmbXFwb3duYmxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDI3OTgsImV4cCI6MjA4MzcxODc5OH0.n5wq8hZMFdoOnSDw7y14pT_cOeL-zUShHH2OuDavizQ';

// Import Supabase
//import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

let currentUser = null;
let currentTurnoId = null;

// Inizializzazione
async function init() {
  console.log('🚀 Inizializzazione admin panel...');
  
  try {
    // Verifica sessione esistente
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    
    if (sessionError) {
      console.error('❌ Errore sessione:', sessionError);
    }
    
    if (session) {
      console.log('✅ Sessione trovata:', session.user.email);
      currentUser = session.user;
      mostraAdmin();
      await caricaTurniSelect();
    } else {
      console.log('ℹ️ Nessuna sessione attiva');
      mostraLogin();
    }

    // Listener cambio auth
    supabase.auth.onAuthStateChange((event, session) => {
      console.log('🔄 Auth state change:', event);
      if (event === 'SIGNED_IN') {
        currentUser = session.user;
        console.log('✅ Login effettuato:', currentUser.email);
        mostraAdmin();
        caricaTurniSelect();
      } else if (event === 'SIGNED_OUT') {
        currentUser = null;
        console.log('ℹ️ Logout effettuato');
        mostraLogin();
      }
    });

    setupEventListeners();
    
  } catch (error) {
    console.error('❌ Errore inizializzazione:', error);
  }
}

function setupEventListeners() {
  // Event listeners
  document.getElementById('login-form').addEventListener('submit', handleLogin);
  document.getElementById('logout-btn').addEventListener('click', handleLogout);
  document.getElementById('turno-select').addEventListener('change', handleTurnoChange);
  document.getElementById('refresh-btn').addEventListener('click', () => {
    if (currentTurnoId) {
      caricaDatiTurno(currentTurnoId);
    }
  });

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

  console.log('🔐 Tentativo login:', email);

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      console.error('❌ Errore login:', error);
      throw error;
    }

    console.log('✅ Login riuscito');
    errorDiv.style.display = 'none';
  } catch (error) {
    console.error('❌ Errore login:', error);
    errorDiv.textContent = 'Email o password errati. ' + error.message;
    errorDiv.style.display = 'block';
  }
}

// Logout
async function handleLogout() {
  try {
    console.log('🚪 Logout...');
    await supabase.auth.signOut();
  } catch (error) {
    console.error('❌ Errore logout:', error);
  }
}

// Carica turni nel select
async function caricaTurniSelect() {
  console.log('🔄 Caricamento turni per select...');
  
  try {
    const { data: turni, error } = await supabase
      .from('turni')
      .select('*')
      .order('data_inizio', { ascending: true });

    if (error) {
      console.error('❌ Errore caricamento turni:', error);
      throw error;
    }

    console.log('✅ Turni caricati:', turni.length);

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
    console.error('❌ Errore caricamento turni:', error);
    alert('Errore nel caricamento dei turni: ' + error.message);
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

  console.log('🔄 Caricamento dati turno:', turnoId);

  try {
    // Carica statistiche
    const { data: turno, error: turnoError } = await supabase
      .from('turni')
      .select('*')
      .eq('id', turnoId)
      .single();

    if (turnoError) {
      console.error('❌ Errore caricamento turno:', turnoError);
      throw turnoError;
    }

    console.log('✅ Turno:', turno);

    // Conta lista d'attesa
    const { count: countAttesa, error: countError } = await supabase
      .from('iscrizioni')
      .select('*', { count: 'exact', head: true })
      .eq('turno_id', turnoId)
      .eq('status', 'WAITING_LIST');

    if (countError) {
      console.error('❌ Errore conteggio attesa:', countError);
      throw countError;
    }

    console.log('✅ Lista attesa:', countAttesa);

    mostraStatistiche(turno, countAttesa || 0);

    // Carica iscrizioni confermate
    await caricaIscrizioni(turnoId, 'CONFIRMED', 'confermati-container');

    // Carica lista d'attesa
    await caricaIscrizioni(turnoId, 'WAITING_LIST', 'attesa-container');

  } catch (error) {
    console.error('❌ Errore caricamento dati:', error);
    alert('Errore nel caricamento dei dati: ' + error.message);
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
  container.innerHTML = '<p style="text-align: center; color: #8D6E63; padding: 20px;">Caricamento...</p>';

  console.log(`🔄 Caricamento iscrizioni ${status} per turno ${turnoId}`);

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

    if (error) {
      console.error(`❌ Errore caricamento iscrizioni ${status}:`, error);
      throw error;
    }

    console.log(`✅ Iscrizioni ${status}:`, iscrizioni.length);

    if (iscrizioni.length === 0) {
      container.innerHTML = `<p style="text-align: center; color: #8D6E63; padding: 20px;">Nessuna iscrizione ${status === 'WAITING_LIST' ? 'in lista d\'attesa' : 'confermata'}</p>`;
      return;
    }

    container.innerHTML = '';
    iscrizioni.forEach(iscrizione => {
      const item = creaIscrizioneItem(iscrizione);
      container.appendChild(item);
    });

  } catch (error) {
    console.error('❌ Errore caricamento iscrizioni:', error);
    container.innerHTML = '<p style="text-align: center; color: #F44336; padding: 20px;">Errore nel caricamento: ' + error.message + '</p>';
  }
}

// Crea elemento iscrizione
function creaIscrizioneItem(iscrizione) {
  const item = document.createElement('div');
  item.className = 'iscrizione-item';

  const dataNascita = new Date(iscrizione.data_nascita + 'T00:00:00').toLocaleDateString('it-IT');
  const dataIscrizione = new Date(iscrizione.created_at).toLocaleDateString('it-IT', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

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
      allergieMedicineHTML += `<div><strong>⚠️ Allergie:</strong> ${iscrizione.allergie_desc || 'Non specificato'}</div>`;
    }
    if (iscrizione.assume_medicinali) {
      allergieMedicineHTML += `<div style="margin-top: 5px;"><strong>💊 Medicinali:</strong> ${iscrizione.medicinali_desc || 'Non specificato'}</div>`;
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

  console.log('↑ Promozione iscrizione:', iscrizioneId);

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

    if (updateError) {
      console.error('❌ Errore promozione:', updateError);
      throw updateError;
    }

    // Riordina le posizioni rimanenti in lista d'attesa
    const { data: iscrizioniAttesa, error: fetchError } = await supabase
      .from('iscrizioni')
      .select('id, posizione_lista')
      .eq('turno_id', currentTurnoId)
      .eq('status', 'WAITING_LIST')
      .order('posizione_lista', { ascending: true });

    if (fetchError) {
      console.error('❌ Errore fetch lista attesa:', fetchError);
      throw fetchError;
    }

    // Aggiorna le posizioni
    for (let i = 0; i < iscrizioniAttesa.length; i++) {
      await supabase
        .from('iscrizioni')
        .update({ posizione_lista: i + 1 })
        .eq('id', iscrizioniAttesa[i].id);
    }

    console.log('✅ Promozione completata');
    alert('Iscrizione promossa con successo!');
    await caricaDatiTurno(currentTurnoId);

  } catch (error) {
    console.error('❌ Errore promozione:', error);
    alert('Errore nella promozione: ' + error.message);
  }
};

// Cancella iscrizione
window.cancellaIscrizione = async function(iscrizioneId) {
  if (!confirm('Sei sicuro di voler cancellare questa iscrizione? Questa azione non può essere annullata.')) return;

  console.log('✕ Cancellazione iscrizione:', iscrizioneId);

  try {
    // Recupera l'iscrizione prima di cancellarla
    const { data: iscrizione, error: fetchError } = await supabase
      .from('iscrizioni')
      .select('*')
      .eq('id', iscrizioneId)
      .single();

    if (fetchError) {
      console.error('❌ Errore fetch iscrizione:', fetchError);
      throw fetchError;
    }

    // Cancella iscrizione
    const { error: deleteError } = await supabase
      .from('iscrizioni')
      .delete()
      .eq('id', iscrizioneId);

    if (deleteError) {
      console.error('❌ Errore cancellazione:', deleteError);
      throw deleteError;
    }

    console.log('✅ Iscrizione cancellata');

    // Se era CONFIRMED, prova a promuovere automaticamente dalla lista d'attesa
    if (iscrizione.status === 'CONFIRMED') {
      await promuoviAutomaticamente(iscrizione.turno_id);
    }

    alert('Iscrizione cancellata con successo');
    await caricaDatiTurno(currentTurnoId);

  } catch (error) {
    console.error('❌ Errore cancellazione:', error);
    alert('Errore nella cancellazione: ' + error.message);
  }
};

// Promuovi automaticamente dalla lista d'attesa
async function promuoviAutomaticamente(turnoId) {
  console.log('🔄 Promozione automatica per turno:', turnoId);
  
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

      if (fetchError && fetchError.code !== 'PGRST116') {
        console.error('❌ Errore fetch primo in attesa:', fetchError);
        throw fetchError;
      }

      if (!primoInAttesa) {
        console.log('ℹ️ Nessuno in lista d\'attesa');
        return;
      }

      console.log('✅ Promozione automatica:', primoInAttesa.nome, primoInAttesa.cognome);

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

      if (iscrizioniAttesa) {
        for (let i = 0; i < iscrizioniAttesa.length; i++) {
          await supabase
            .from('iscrizioni')
            .update({ posizione_lista: i + 1 })
            .eq('id', iscrizioniAttesa[i].id);
        }
      }

      console.log('✅ Promozione automatica completata');
    }

  } catch (error) {
    console.error('❌ Errore promozione automatica:', error);
  }
}

// Inizializza app
init();