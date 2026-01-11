// ⚠️ SOSTITUISCI QUESTI VALORI CON I TUOI
const SUPABASE_URL = 'https://kneoivwhuafmqpownblh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZW9pdndodWFmbXFwb3duYmxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDI3OTgsImV4cCI6MjA4MzcxODc5OH0.n5wq8hZMFdoOnSDw7y14pT_cOeL-zUShHH2OuDavizQ';

// Variabile globale per Supabase client
let supabase;

// Inizializzazione
async function init() {
  try {
    // Import Supabase
    const { createClient } = await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
    supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    
    console.log('✅ Supabase inizializzato correttamente');
    
    // Carica i turni
    await caricaTurni();
  } catch (error) {
    console.error('❌ Errore inizializzazione:', error);
    document.getElementById('error-message').textContent = 'Errore di connessione. Riprova più tardi.';
    document.getElementById('error-message').style.display = 'block';
  }
}

// Carica i turni dal database
async function caricaTurni() {
  const loadingDiv = document.getElementById('loading');
  const errorDiv = document.getElementById('error-message');
  const turniContainer = document.getElementById('turni-container');

  loadingDiv.style.display = 'block';
  errorDiv.style.display = 'none';
  turniContainer.innerHTML = '';

  try {
    console.log('🔄 Caricamento turni...');
    
    const { data: turni, error } = await supabase
      .from('turni')
      .select('*')
      .eq('attivo', true)
      .order('data_inizio', { ascending: true });

    if (error) {
      console.error('❌ Errore query:', error);
      throw error;
    }

    console.log('✅ Turni caricati:', turni);

    loadingDiv.style.display = 'none';

    if (!turni || turni.length === 0) {
      turniContainer.innerHTML = '<p style="text-align: center; color: #8D6E63; padding: 40px;">Nessun turno disponibile al momento.</p>';
      return;
    }

    turni.forEach(turno => {
      const card = creaTurnoCard(turno);
      turniContainer.appendChild(card);
    });

  } catch (error) {
    console.error('❌ Errore caricamento turni:', error);
    loadingDiv.style.display = 'none';
    errorDiv.textContent = `Errore: ${error.message || 'Impossibile caricare i turni'}`;
    errorDiv.style.display = 'block';
  }
}

// Crea card HTML per un turno
function creaTurnoCard(turno) {
  const card = document.createElement('div');
  card.className = 'turno-card';

  const postiDisponibili = turno.posti_totali - turno.posti_occupati;
  const pieno = postiDisponibili <= 0;

  const dataInizio = new Date(turno.data_inizio + 'T00:00:00').toLocaleDateString('it-IT', { 
    day: 'numeric', 
    month: 'long' 
  });
  const dataFine = new Date(turno.data_fine + 'T00:00:00').toLocaleDateString('it-IT', { 
    day: 'numeric', 
    month: 'long', 
    year: 'numeric' 
  });

  let postiHTML = '';
  if (!pieno) {
    postiHTML = `<span class="posti-disponibili">${postiDisponibili} posti disponibili</span>`;
  } else {
    postiHTML = `<span class="posti-esauriti">Posti esauriti - Lista d'attesa</span>`;
  }

  card.innerHTML = `
    <h3>${turno.nome}</h3>
    <p class="turno-date">📅 ${dataInizio} - ${dataFine}</p>
    <p class="turno-location">📍 ${turno.luogo}</p>
    <div class="turno-posti">
      <p class="posti-info">${postiHTML}</p>
    </div>
    <button class="btn-primary" onclick="vaiIscrizione(${turno.id})">
      ${pieno ? 'Iscriviti alla lista d\'attesa' : 'Iscriviti ora'}
    </button>
  `;

  return card;
}

// Vai alla pagina di iscrizione
function vaiIscrizione(turnoId) {
  window.location.href = `turno.html?id=${turnoId}`;
}

// Avvia l'applicazione
init();