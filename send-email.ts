// ============================================
// EDGE FUNCTION: send-email CORRETTA
// ============================================
// Fix: Tipi TypeScript corretti
// Fix: Error handling con type guard
// ============================================

/// <reference types="https://deno.land/x/types/index.d.ts" />

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const FROM_EMAIL = 'Campeggi Parrocchia <noreply@tuodominio.com>'

interface EmailRequest {
  to: string;
  subject?: string;
  type: 'CONFERMA' | 'LISTA_ATTESA' | 'PROMOZIONE';
  data: EmailData;
}

interface EmailData {
  nome: string;
  cognome: string;
  turno_nome: string;
  date: string;
  luogo: string;
  posizione?: number;
}

serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json() as EmailRequest
    const { to, subject, type, data } = body

    if (!to || !type || !data) {
      throw new Error('Parametri mancanti: to, type, data richiesti')
    }

    let htmlContent = ''

    switch(type) {
      case 'CONFERMA':
        htmlContent = generateConfirmaEmail(data)
        break

      case 'LISTA_ATTESA':
        htmlContent = generateListaAttesaEmail(data)
        break

      case 'PROMOZIONE':
        htmlContent = generatePromozioneEmail(data)
        break

      default:
        throw new Error(`Tipo email non valido: ${type}`)
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [to],
        subject: subject || getDefaultSubject(type),
        html: htmlContent
      })
    })

    const result = await res.json()

    if (!res.ok) {
      throw new Error(`Resend error: ${JSON.stringify(result)}`)
    }

    return new Response(
      JSON.stringify({ success: true, data: result }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('Error sending email:', error)
    
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: errorMessage
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})

function getDefaultSubject(type: string): string {
  switch(type) {
    case 'CONFERMA':
      return '🎉 Iscrizione Confermata - Campeggio Estivo'
    case 'LISTA_ATTESA':
      return '⏳ Inserito in Lista d\'Attesa - Campeggio Estivo'
    case 'PROMOZIONE':
      return '🎊 Posto Confermato! Promozione da Lista d\'Attesa'
    default:
      return 'Campeggi Estivi - Parrocchia'
  }
}

function generateConfirmaEmail(data: EmailData): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Arial', sans-serif; background-color: #FFF8E7; padding: 20px; margin: 0; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #FFA726, #FF9800); color: white; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { color: #5D4037; line-height: 1.6; }
        .info-box { background: #FFF8E7; padding: 20px; border-radius: 12px; margin: 20px 0; border-left: 4px solid #FF9800; }
        .footer { text-align: center; color: #8D6E63; margin-top: 30px; font-size: 14px; border-top: 2px solid #FFE0B2; padding-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🏕️ Iscrizione Confermata!</h1>
        </div>
        <div class="content">
          <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
          <p>Siamo felici di confermarti l'iscrizione al campeggio estivo!</p>
          
          <div class="info-box">
            <p style="margin: 0 0 10px 0;"><strong>📋 Dettagli Turno:</strong></p>
            <p style="margin: 5px 0;"><strong>Turno:</strong> ${data.turno_nome}</p>
            <p style="margin: 5px 0;"><strong>📅 Date:</strong> ${data.date}</p>
            <p style="margin: 5px 0;"><strong>📍 Luogo:</strong> ${data.luogo}</p>
          </div>
          
          <p style="background: #E8F5E9; padding: 15px; border-radius: 10px; color: #2E7D32; font-weight: 600; text-align: center;">
            ✓ Il tuo posto è confermato!
          </p>
          
          <p>Ti aspettiamo per un'estate indimenticabile! 🌞</p>
          
          <p style="margin-top: 25px; font-size: 14px;">
            Riceverai ulteriori informazioni prima della partenza. 
            Per qualsiasi domanda, contattaci a: <a href="mailto:campeggi@parrocchia.it" style="color: #FF9800;">campeggi@parrocchia.it</a>
          </p>
        </div>
        <div class="footer">
          <p><strong>Parrocchia San Giuseppe</strong></p>
          <p>Campeggi Estivi 2025</p>
        </div>
      </div>
    </body>
    </html>
  `
}

function generateListaAttesaEmail(data: EmailData): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Arial', sans-serif; background-color: #FFF8E7; padding: 20px; margin: 0; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #FFB74D, #FFA726); color: white; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { color: #5D4037; line-height: 1.6; }
        .info-box { background: #FFF3E0; padding: 20px; border-radius: 12px; margin: 20px 0; border-left: 4px solid #FFB74D; }
        .footer { text-align: center; color: #8D6E63; margin-top: 30px; font-size: 14px; border-top: 2px solid #FFE0B2; padding-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⏳ Lista d'Attesa</h1>
        </div>
        <div class="content">
          <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
          <p>Grazie per l'interesse al nostro campeggio estivo!</p>
          
          <div class="info-box">
            <p style="margin: 0 0 10px 0;"><strong>📋 Dettagli:</strong></p>
            <p style="margin: 5px 0;"><strong>Turno:</strong> ${data.turno_nome}</p>
            <p style="margin: 5px 0;"><strong>📅 Date:</strong> ${data.date}</p>
            <p style="margin: 5px 0;"><strong>📍 Luogo:</strong> ${data.luogo}</p>
            <p style="margin: 15px 0 5px 0; font-size: 18px;"><strong>Posizione in lista:</strong> <span style="color: #FF9800; font-size: 24px;">${data.posizione || 'N/A'}</span></p>
          </div>
          
          <p style="background: #FFF3E0; padding: 15px; border-radius: 10px; color: #E65100; text-align: center;">
            Purtroppo il turno è al completo, ma sei stato inserito in lista d'attesa.
          </p>
          
          <p><strong>Ti contatteremo immediatamente se si libera un posto!</strong></p>
          
          <p style="margin-top: 25px; font-size: 14px;">
            Conserva questa email. Per qualsiasi domanda, contattaci a: 
            <a href="mailto:campeggi@parrocchia.it" style="color: #FF9800;">campeggi@parrocchia.it</a>
          </p>
        </div>
        <div class="footer">
          <p><strong>Parrocchia San Giuseppe</strong></p>
          <p>Campeggi Estivi 2025</p>
        </div>
      </div>
    </body>
    </html>
  `
}

function generatePromozioneEmail(data: EmailData): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Arial', sans-serif; background-color: #FFF8E7; padding: 20px; margin: 0; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #4CAF50, #66BB6A); color: white; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { color: #5D4037; line-height: 1.6; }
        .info-box { background: #E8F5E9; padding: 20px; border-radius: 12px; margin: 20px 0; border-left: 4px solid #4CAF50; }
        .footer { text-align: center; color: #8D6E63; margin-top: 30px; font-size: 14px; border-top: 2px solid #FFE0B2; padding-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎉 Ottima Notizia!</h1>
        </div>
        <div class="content">
          <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
          <p style="font-size: 18px; color: #4CAF50; font-weight: 600;">Abbiamo una bellissima notizia per te! 🎊</p>
          
          <p>Si è liberato un posto al campeggio e la tua iscrizione è stata <strong style="color: #4CAF50;">CONFERMATA</strong>!</p>
          
          <div class="info-box">
            <p style="margin: 0 0 10px 0;"><strong>📋 Dettagli Turno:</strong></p>
            <p style="margin: 5px 0;"><strong>Turno:</strong> ${data.turno_nome}</p>
            <p style="margin: 5px 0;"><strong>📅 Date:</strong> ${data.date}</p>
            <p style="margin: 5px 0;"><strong>📍 Luogo:</strong> ${data.luogo}</p>
          </div>
          
          <p style="background: #E8F5E9; padding: 15px; border-radius: 10px; color: #2E7D32; font-weight: 600; text-align: center; font-size: 18px;">
            ✓ Il tuo posto è ora CONFERMATO!
          </p>
          
          <p>Ci vediamo presto! 🌞</p>
          
          <p style="margin-top: 25px; font-size: 14px;">
            Riceverai ulteriori informazioni prima della partenza. 
            Per qualsiasi domanda, contattaci a: <a href="mailto:campeggi@parrocchia.it" style="color: #FF9800;">campeggi@parrocchia.it</a>
          </p>
        </div>
        <div class="footer">
          <p><strong>Parrocchia San Giuseppe</strong></p>
          <p>Campeggi Estivi 2025</p>
        </div>
      </div>
    </body>
    </html>
  `
}
