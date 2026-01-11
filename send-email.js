import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

serve(async (req) => {
  try {
    const { to, subject, type, data } = await req.json()

    let htmlContent = ''

    switch(type) {
      case 'CONFERMA':
        htmlContent = `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: 'Arial', sans-serif; background-color: #FFF8E7; padding: 20px; }
              .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
              .header { background: linear-gradient(135deg, #FFA726, #FF9800); color: white; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px; }
              .content { color: #5D4037; line-height: 1.6; }
              .button { display: inline-block; background: #FF9800; color: white; padding: 15px 30px; border-radius: 12px; text-decoration: none; font-weight: 600; margin: 20px 0; }
              .footer { text-align: center; color: #8D6E63; margin-top: 30px; font-size: 14px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>🏕️ Iscrizione Confermata!</h1>
              </div>
              <div class="content">
                <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
                <p>Siamo felici di confermarti l'iscrizione al <strong>${data.turno_nome}</strong>!</p>
                <p><strong>📅 Date:</strong> ${data.date}</p>
                <p><strong>📍 Luogo:</strong> ${data.luogo}</p>
                <p>Ti aspettiamo per un'estate indimenticabile! 🌞</p>
                <p>Per qualsiasi domanda, contattaci a: <a href="mailto:campeggi@parrocchia.it">campeggi@parrocchia.it</a></p>
              </div>
              <div class="footer">
                <p>Parrocchia San Giuseppe - Campeggi Estivi 2025</p>
              </div>
            </div>
          </body>
          </html>
        `
        break

      case 'LISTA_ATTESA':
        htmlContent = `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: 'Arial', sans-serif; background-color: #FFF8E7; padding: 20px; }
              .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
              .header { background: linear-gradient(135deg, #FFB74D, #FFA726); color: white; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px; }
              .content { color: #5D4037; line-height: 1.6; }
              .footer { text-align: center; color: #8D6E63; margin-top: 30px; font-size: 14px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>⏳ Lista d'Attesa</h1>
              </div>
              <div class="content">
                <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
                <p>Grazie per l'interesse al <strong>${data.turno_nome}</strong>!</p>
                <p>Purtroppo il turno è al completo, ma sei stato inserito in lista d'attesa alla <strong>posizione ${data.posizione}</strong>.</p>
                <p>Ti contatteremo immediatamente se si libera un posto!</p>
                <p>Per qualsiasi domanda, contattaci a: <a href="mailto:campeggi@parrocchia.it">campeggi@parrocchia.it</a></p>
              </div>
              <div class="footer">
                <p>Parrocchia San Giuseppe - Campeggi Estivi 2025</p>
              </div>
            </div>
          </body>
          </html>
        `
        break

      case 'PROMOZIONE':
        htmlContent = `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: 'Arial', sans-serif; background-color: #FFF8E7; padding: 20px; }
              .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
              .header { background: linear-gradient(135deg, #4CAF50, #66BB6A); color: white; padding: 30px; border-radius: 15px; text-align: center; margin-bottom: 30px; }
              .content { color: #5D4037; line-height: 1.6; }
              .footer { text-align: center; color: #8D6E63; margin-top: 30px; font-size: 14px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>🎉 Ottima Notizia!</h1>
              </div>
              <div class="content">
                <p>Ciao <strong>${data.nome} ${data.cognome}</strong>,</p>
                <p>Abbiamo una bellissima notizia! 🎊</p>
                <p>Si è liberato un posto al <strong>${data.turno_nome}</strong> e la tua iscrizione è stata <strong>confermata</strong>!</p>
                <p><strong>📅 Date:</strong> ${data.date}</p>
                <p><strong>📍 Luogo:</strong> ${data.luogo}</p>
                <p>Ci vediamo presto! 🌞</p>
                <p>Per qualsiasi domanda, contattaci a: <a href="mailto:campeggi@parrocchia.it">campeggi@parrocchia.it</a></p>
              </div>
              <div class="footer">
                <p>Parrocchia San Giuseppe - Campeggi Estivi 2025</p>
              </div>
            </div>
          </body>
          </html>
        `
        break
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'Campeggi Parrocchia <noreply@tuodominio.com>',
        to: [to],
        subject: subject,
        html: htmlContent
      })
    })

    const result = await res.json()

    return new Response(
      JSON.stringify({ success: true, data: result }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})