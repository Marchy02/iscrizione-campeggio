// ============================================
// APP.JS - Homepage Campeggi
// ============================================
// Versione: 2.0 - Sistema rigenerato
// ============================================

// ⚠️ SOSTITUISCI CON LE TUE CREDENZIALI SUPABASE
const SUPABASE_URL = 'https://kneoivwhuafmqpownblh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZW9pdndodWFmbXFwb3duYmxoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgxNDI3OTgsImV4cCI6MjA4MzcxODc5OH0.n5wq8hZMFdoOnSDw7y14pT_cOeL-zUShHH2OuDavizQ';

let supabase;

// ============================================
// INIZIALIZZAZIONE
// ============================================
async function init() {
  try {
    console.log('🚀 Inizializzazione sistema...');
    
    // Import Supabase client
    const { createClient } = await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
    supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    
    console.log('✅ Supabase connesso');
    
    // Carica turni
    await caricaTurni();
    
  } catch (error) {
    console.error('❌ Errore inizializzazione:', error);
    mostraErrore('Errore di connessione. Riprova più tardi.');
  }
}

// ============================================
// CARICA TURNI DAL DATABASE
// ============================================
async function caricaTurni() {
  const loadingDiv = document.getElementById('loading');
  const turniContainer = document.getElementById('turni-container');
  
  loadingDiv.style.display = 'block';
  turniContainer.innerHTML = '';
  
  try {
    // Query solo turni attivi, ordinati per data
    const { data: turni, error } = await supabase
      .from('turni')
      .select('*')
      .eq('attivo', true)
      .order('data_inizio', { ascending: true });
    
    if (error) throw error;
    
    loadingDiv.style.display = 'none';
    
    if (!turni || turni.length === 0) {
      turniContainer.innerHTML = `
        <div style="text-align: center; padding: 60px 20px; color: #8D6E63;">
          <p style="font-size: 1.2rem;">Nessun turno disponibile al momento.</p>
          <p style="margin-top: 10px;">Controlla più tardi per nuove date!</p>
        </div>
      `;
      return;
    }
    
    console.log(`✅ Caricati ${turni.length} turni`);
    
    // Crea card per ogni turno
    turni.forEach(turno => {
      const card = creaTurnoCard(turno);
      turniContainer.appendChild(card);
    });
    
  } catch (error) {
    console.error('❌ Errore caricamento turni:', error);
    loadingDiv.style.display = 'none';
    mostraErrore(`Errore caricamento turni: ${error.message}`);
  }
}

// ============================================
// CREA CARD HTML PER TURNO
// ============================================
function creaTurnoCard(turno) {
  const card = document.createElement('div');
  card.className = 'turno-card';
  
  // Calcola posti disponibili
  const postiDisponibili = turno.posti_totali - turno.posti_occupati;
  const pieno = postiDisponibili <= 0;
  
  // Formatta date
  const dataInizio = formatDate(turno.data_inizio);
  const dataFine = formatDate(turno.data_fine);
  
  // HTML posti
  let postiHTML;
  if (pieno) {
    postiHTML = `<span class="posti-esauriti">⚠️ Posti esauriti - Lista d'attesa disponibile</span>`;
  } else if (postiDisponibili <= 5) {
    postiHTML = `<span class="posti-pochi">⏰ Ultimi ${postiDisponibili} posti disponibili!</span>`;
  } else {
    postiHTML = `<span class="posti-disponibili">✓ ${postiDisponibili} posti disponibili</span>`;
  }
  
  // Costruisci card
  card.innerHTML = `
    <h3>${turno.nome}</h3>
    <p class="turno-date">📅 ${dataInizio} - ${dataFine}</p>
    <p class="turno-location">📍 ${turno.luogo}</p>
    <div class="turno-posti">
      <p class="posti-info">${postiHTML}</p>
      <p class="posti-dettaglio">${turno.posti_occupati} / ${turno.posti_totali} posti occupati</p>
    </div>
    <button class="btn-primary" onclick="vaiIscrizione(${turno.id})">
      ${pieno ? 'Entra in lista d\'attesa' : 'Iscriviti ora'}
    </button>
  `;
  
  return card;
}

// ============================================
// FORMATTA DATA IN ITALIANO
// ============================================
function formatDate(dateString) {
  const date = new Date(dateString + 'T00:00:00');
  return date.toLocaleDateString('it-IT', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
}

// ============================================
// VAI A PAGINA ISCRIZIONE
// ============================================
function vaiIscrizione(turnoId) {
  window.location.href = `turno.html?id=${turnoId}`;
}

// ============================================
// MOSTRA ERRORE
// ============================================
function mostraErrore(messaggio) {
  const errorDiv = document.getElementById('error-message');
  errorDiv.textContent = messaggio;
  errorDiv.style.display = 'block';
  
  // Nascondi dopo 5 secondi
  setTimeout(() => {
    errorDiv.style.display = 'none';
  }, 5000);
}

// ============================================
// AVVIA APPLICAZIONE
// ============================================
init();
