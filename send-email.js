import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

function buildHtml(type, data) {
  if (type === 'CONFERMA') {
    return `<p>Ciao <strong>${data.nome} ${data.cognome}</strong>, iscrizione confermata per <strong>${data.turno_nome}</strong>.</p>
            <p><strong>📅</strong> ${data.date} — <strong>📍</strong> ${data.luogo}</p>`
  }
  if (type === 'LISTA_ATTESA') {
    return `<p>Ciao <strong>${data.nome} ${data.cognome}</strong>, sei in lista d’attesa per <strong>${data.turno_nome}</strong>.</p>
            <p>Posizione: <strong>${data.posizione}</strong></p>`
  }
  if (type === 'PROMOZIONE') {
    return `<p>Ciao <strong>${data.nome} ${data.cognome}</strong>, sei stato promosso: ora sei <strong>CONFERMATO</strong> per <strong>${data.turno_nome}</strong>.</p>
            <p><strong>📅</strong> ${data.date} — <strong>📍</strong> ${data.luogo}</p>`
  }
  return `<p>Email type non riconosciuto.</p>`
}

async function resendSend({ to, subject, type, data }) {
  const html = buildHtml(type, data)

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RESEND_API_KEY}`
    },
    body: JSON.stringify({
      from: 'Campeggi Parrocchia <onboarding@resend.dev>',
      to: [to],
      subject,
      html
    })
  })

  const json = await res.json()
  if (!res.ok) {
    throw new Error(json?.message || 'Resend error')
  }
  return json
}

serve(async (req) => {
  try {
    if (!RESEND_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing env: RESEND_API_KEY / SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY'
      }), { status: 500 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Processa batch PENDING
    const { data: queue, error: qErr } = await supabase
      .from('email_queue')
      .select('id, email_to, email_type, iscrizione_id, attempts')
      .eq('status', 'PENDING')
      .order('created_at', { ascending: true })
      .limit(20)

    if (qErr) throw qErr

    let sent = 0
    let failed = 0

    for (const item of queue) {
      try {
        // Prendi dati iscrizione + turno per comporre email
        const { data: iscr, error: iErr } = await supabase
          .from('iscrizioni')
          .select('nome,cognome,turno_id,posizione_lista,email')
          .eq('id', item.iscrizione_id)
          .single()
        if (iErr) throw iErr

        const { data: turno, error: tErr } = await supabase
          .from('turni')
          .select('nome,luogo,data_inizio,data_fine')
          .eq('id', iscr.turno_id)
          .single()
        if (tErr) throw tErr

        const date = `${turno.data_inizio} - ${turno.data_fine}`

        const subject =
          item.email_type === 'CONFERMA' ? 'Iscrizione confermata' :
          item.email_type === 'LISTA_ATTESA' ? 'Inserito in lista d’attesa' :
          'Promozione: iscrizione confermata'

        await resendSend({
          to: item.email_to,
          subject,
          type: item.email_type,
          data: {
            nome: iscr.nome,
            cognome: iscr.cognome,
            turno_nome: turno.nome,
            luogo: turno.luogo,
            date,
            posizione: iscr.posizione_lista
          }
        })

        await supabase
          .from('email_queue')
          .update({ status: 'SENT', sent_at: new Date().toISOString(), last_error: null })
          .eq('id', item.id)

        sent++
      } catch (e) {
        await supabase
          .from('email_queue')
          .update({
            status: 'FAILED',
            attempts: (item.attempts ?? 0) + 1,
            last_error: String(e?.message || e)
          })
          .eq('id', item.id)

        failed++
      }
    }

    return new Response(JSON.stringify({ success: true, processed: queue.length, sent, failed }), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
