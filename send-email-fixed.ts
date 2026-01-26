// ============================================
// EDGE FUNCTION FIXED - Sistema Campeggi v2.2
// ============================================
// ✅ TypeScript moderno
// ✅ Error handling robusto
// ✅ Retry automatico
// ============================================

/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

// Tipi
interface EmailData {
  nome: string;
  cognome: string;
  turno_nome: string;
  luogo: string;
  date: string;
  posizione?: number;
}

interface EmailQueueItem {
  id: number;
  email_to: string;
  email_type: 'CONFERMA' | 'LISTA_ATTESA' | 'PROMOZIONE';
  iscrizione_id: number;
  attempts: number;
}

interface IscrizioneData {
  nome: string;
  cognome: string;
  turno_id: number;
  posizione_lista: number | null;
  email: string;
}

interface TurnoData {
  nome: string;
  luogo: string;
  data_inizio: string;
  data_fine: string;
}

// ============================================
// ENV VARS
// ============================================
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

// ============================================
// BUILD HTML EMAIL
// ============================================
function buildHtml(type: string, data: EmailData): string {
  const baseStyle = `
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    max-width: 600px;
    margin: 0 auto;
    padding: 20px;
    background-color: #FFF8E7;
    border-radius: 15px;
  `;

  const headerStyle = `
    background: linear-gradient(135deg, #FFA726, #FF9800);
    color: white;
    padding: 30px;
    border-radius: 10px;
    text-align: center;
    margin-bottom: 20px;
  `;

  const bodyStyle = `
    background: white;
    padding: 25px;
    border-radius: 10px;
    line-height: 1.6;
    color: #5D4037;
  `;

  if (type === 'CONFERMA') {
    return `
      <div style="${baseStyle}">
        <div style="${headerStyle}">
          <h1 style="margin: 0;">🎉 Iscrizione Confermata!</h1>
        </div>
        <div style="${bodyStyle}">
          <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
          <p>La tua iscrizione al <strong>${data.turno_nome}</strong> è stata <strong style="color: #4CAF50;">CONFERMATA</strong>!</p>
          
          <div style="background: #FFF8E7; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 5px 0;"><strong>📅 Date:</strong> ${data.date}</p>
            <p style="margin: 5px 0;"><strong>📍 Luogo:</strong> ${data.luogo}</p>
          </div>
          
          <p>Ti aspettiamo! Per qualsiasi informazione contattaci.</p>
          <p style="margin-top: 20px; color: #8D6E63; font-size: 0.9em;">Questa è una email automatica, non rispondere.</p>
        </div>
      </div>
    `;
  }

  if (type === 'LISTA_ATTESA') {
    return `
      <div style="${baseStyle}">
        <div style="${headerStyle}">
          <h1 style="margin: 0;">⏳ Lista d'Attesa</h1>
        </div>
        <div style="${bodyStyle}">
          <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
          <p>Ti abbiamo inserito nella <strong>lista d'attesa</strong> per il <strong>${data.turno_nome}</strong>.</p>
          
          <div style="background: #FFE0B2; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: center;">
            <p style="margin: 0; font-size: 1.2em;">Posizione: <strong style="color: #FF9800;">#${data.posizione}</strong></p>
          </div>
          
          <p>Ti contatteremo appena si libera un posto!</p>
          <p style="margin-top: 20px; color: #8D6E63; font-size: 0.9em;">Questa è una email automatica, non rispondere.</p>
        </div>
      </div>
    `;
  }

  if (type === 'PROMOZIONE') {
    return `
      <div style="${baseStyle}">
        <div style="${headerStyle}">
          <h1 style="margin: 0;">🎊 Promosso dalla Lista!</h1>
        </div>
        <div style="${bodyStyle}">
          <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
          <p><strong style="color: #4CAF50;">Ottima notizia!</strong> Si è liberato un posto per il <strong>${data.turno_nome}</strong>.</p>
          <p>La tua iscrizione è ora <strong style="color: #4CAF50;">CONFERMATA</strong>!</p>
          
          <div style="background: #FFF8E7; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 5px 0;"><strong>📅 Date:</strong> ${data.date}</p>
            <p style="margin: 5px 0;"><strong>📍 Luogo:</strong> ${data.luogo}</p>
          </div>
          
          <p>Ti aspettiamo!</p>
          <p style="margin-top: 20px; color: #8D6E63; font-size: 0.9em;">Questa è una email automatica, non rispondere.</p>
        </div>
      </div>
    `;
  }

  return '<p>Tipo email non riconosciuto</p>';
}

// ============================================
// SEND EMAIL VIA RESEND
// ============================================
async function resendSend(to: string, subject: string, html: string): Promise<void> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: 'Campeggi Parrocchia <onboarding@resend.dev>',
      to: [to],
      subject,
      html,
    }),
  });

  if (!res.ok) {
    const error = await res.json();
    throw new Error(error.message || 'Resend API error');
  }
}

// ============================================
// MAIN HANDLER
// ============================================
serve(async (req: Request) => {
  try {
    // Verifica ENV
    if (!RESEND_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing environment variables' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Prendi batch email PENDING (max 20)
    const { data: queue, error: qErr } = await supabase
      .from('email_queue')
      .select('id, email_to, email_type, iscrizione_id, attempts')
      .eq('status', 'PENDING')
      .order('created_at', { ascending: true })
      .limit(20);

    if (qErr) throw qErr;
    if (!queue || queue.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed: 0, sent: 0, failed: 0 }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    let sent = 0;
    let failed = 0;

    // Processa ogni email
    for (const item of queue as EmailQueueItem[]) {
      try {
        // Prendi dati iscrizione
        const { data: iscr, error: iErr } = await supabase
          .from('iscrizioni')
          .select('nome, cognome, turno_id, posizione_lista, email')
          .eq('id', item.iscrizione_id)
          .single();

        if (iErr) throw iErr;
        if (!iscr) throw new Error('Iscrizione non trovata');

        const iscrizione = iscr as IscrizioneData;

        // Prendi dati turno
        const { data: turno, error: tErr } = await supabase
          .from('turni')
          .select('nome, luogo, data_inizio, data_fine')
          .eq('id', iscrizione.turno_id)
          .single();

        if (tErr) throw tErr;
        if (!turno) throw new Error('Turno non trovato');

        const turnoData = turno as TurnoData;

        // Costruisci email
        const date = `${turnoData.data_inizio} - ${turnoData.data_fine}`;
        
        const emailData: EmailData = {
          nome: iscrizione.nome,
          cognome: iscrizione.cognome,
          turno_nome: turnoData.nome,
          luogo: turnoData.luogo,
          date,
          posizione: iscrizione.posizione_lista ?? undefined,
        };

        const subject = 
          item.email_type === 'CONFERMA' ? '🎉 Iscrizione confermata - Campeggio' :
          item.email_type === 'LISTA_ATTESA' ? '⏳ Lista d\'attesa - Campeggio' :
          '🎊 Promosso! Iscrizione confermata';

        const html = buildHtml(item.email_type, emailData);

        // Invia email
        await resendSend(item.email_to, subject, html);

        // Marca come SENT
        await supabase
          .from('email_queue')
          .update({ 
            status: 'SENT', 
            sent_at: new Date().toISOString(),
            last_error: null 
          })
          .eq('id', item.id);

        sent++;

      } catch (e) {
        // Marca come FAILED
        const errorMessage = e instanceof Error ? e.message : String(e);
        
        await supabase
          .from('email_queue')
          .update({
            status: 'FAILED',
            attempts: item.attempts + 1,
            last_error: errorMessage,
          })
          .eq('id', item.id);

        failed++;
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed: queue.length, 
        sent, 
        failed 
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});