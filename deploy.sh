#!/bin/bash

# ============================================
# SCRIPT DEPLOYMENT - Sistema Campeggi v2.0
# ============================================
# Automazione setup completo
# ============================================

set -e  # Exit on error

echo "🏕️  Sistema Campeggi v2.0 - Deployment Script"
echo "=============================================="
echo ""

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# STEP 1: VERIFICA PREREQUISITI
# ============================================

echo "📋 Step 1: Verifica prerequisiti..."

# Verifica Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git non installato. Installa Git e riprova.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Git trovato${NC}"

# Verifica Supabase CLI (opzionale per email)
if command -v supabase &> /dev/null; then
    echo -e "${GREEN}✅ Supabase CLI trovato${NC}"
    SUPABASE_CLI=true
else
    echo -e "${YELLOW}⚠️  Supabase CLI non trovato (opzionale per email)${NC}"
    SUPABASE_CLI=false
fi

echo ""

# ============================================
# STEP 2: RACCOLTA CREDENZIALI
# ============================================

echo "🔐 Step 2: Configurazione credenziali..."
echo ""

read -p "Supabase Project URL: " SUPABASE_URL
read -p "Supabase Anon Key: " SUPABASE_ANON_KEY
read -p "Nome Repository GitHub: " GITHUB_REPO

echo ""
echo -e "${YELLOW}⚠️  Verifica credenziali:${NC}"
echo "URL: $SUPABASE_URL"
echo "Key: ${SUPABASE_ANON_KEY:0:20}..."
echo "Repo: $GITHUB_REPO"
echo ""

read -p "Confermi? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Deployment annullato."
    exit 0
fi

echo ""

# ============================================
# STEP 3: AGGIORNA FILE FRONTEND
# ============================================

echo "📝 Step 3: Aggiornamento file frontend..."

# Backup originali
cp frontend/app.js frontend/app.js.backup
cp frontend/turno.html frontend/turno.html.backup
cp frontend/admin.html frontend/admin.html.backup

# Aggiorna app.js
sed -i.bak "s|const SUPABASE_URL = '.*'|const SUPABASE_URL = '$SUPABASE_URL'|g" frontend/app.js
sed -i.bak "s|const SUPABASE_ANON_KEY = '.*'|const SUPABASE_ANON_KEY = '$SUPABASE_ANON_KEY'|g" frontend/app.js
rm frontend/app.js.bak

# Aggiorna turno.html
sed -i.bak "s|const SUPABASE_URL = '.*'|const SUPABASE_URL = '$SUPABASE_URL'|g" frontend/turno.html
sed -i.bak "s|const SUPABASE_ANON_KEY = '.*'|const SUPABASE_ANON_KEY = '$SUPABASE_ANON_KEY'|g" frontend/turno.html
rm frontend/turno.html.bak

# Aggiorna admin.html
sed -i.bak "s|const SUPABASE_URL = '.*'|const SUPABASE_URL = '$SUPABASE_URL'|g" frontend/admin.html
sed -i.bak "s|const SUPABASE_ANON_KEY = '.*'|const SUPABASE_ANON_KEY = '$SUPABASE_ANON_KEY'|g" frontend/admin.html
rm frontend/admin.html.bak

echo -e "${GREEN}✅ File aggiornati${NC}"
echo ""

# ============================================
# STEP 4: INIZIALIZZA GIT REPOSITORY
# ============================================

echo "📦 Step 4: Inizializzazione repository Git..."

cd frontend

# Verifica se già inizializzato
if [ -d ".git" ]; then
    echo -e "${YELLOW}⚠️  Repository Git già esistente${NC}"
    read -p "Vuoi reinizializzare? (y/n): " REINIT
    if [ "$REINIT" = "y" ]; then
        rm -rf .git
        git init
    fi
else
    git init
fi

# Crea .gitignore
cat > .gitignore << EOF
.DS_Store
*.backup
*.bak
.vscode/
.idea/
EOF

# Commit iniziale
git add .
git commit -m "Initial commit - Sistema Campeggi v2.0"

echo -e "${GREEN}✅ Repository inizializzato${NC}"
echo ""

# ============================================
# STEP 5: PUSH SU GITHUB
# ============================================

echo "🚀 Step 5: Push su GitHub..."
echo ""
echo -e "${YELLOW}⚠️  Assicurati di aver creato il repository su GitHub:${NC}"
echo "https://github.com/new"
echo "Nome: $GITHUB_REPO"
echo ""

read -p "Repository creato? Premi Enter per continuare..."

git branch -M main
git remote add origin "https://github.com/$GITHUB_REPO.git"
git push -u origin main

echo -e "${GREEN}✅ Codice caricato su GitHub${NC}"
echo ""

# ============================================
# STEP 6: ISTRUZIONI GITHUB PAGES
# ============================================

echo "🌐 Step 6: Configurazione GitHub Pages..."
echo ""
echo -e "${YELLOW}Segui questi passaggi:${NC}"
echo "1. Vai su https://github.com/$GITHUB_REPO/settings/pages"
echo "2. Source: Branch 'main', folder '/ (root)'"
echo "3. Clicca 'Save'"
echo "4. Attendi qualche minuto per il deploy"
echo ""
echo "Il sito sarà disponibile a:"
echo "https://$(echo $GITHUB_REPO | cut -d'/' -f1).github.io/$(echo $GITHUB_REPO | cut -d'/' -f2)/"
echo ""

read -p "GitHub Pages configurato? Premi Enter per continuare..."

echo ""

# ============================================
# STEP 7: VERIFICA DATABASE
# ============================================

echo "💾 Step 7: Verifica database Supabase..."
echo ""
echo -e "${YELLOW}Esegui manualmente in Supabase SQL Editor:${NC}"
echo "1. backend/01-schema.sql"
echo "2. backend/02-functions.sql"
echo "3. backend/03-policies.sql"
echo "4. backend/04-seed.sql"
echo ""
echo "Link: $SUPABASE_URL/project/_/sql"
echo ""

read -p "Database configurato? Premi Enter per continuare..."

echo ""

# ============================================
# STEP 8: CREA UTENTE ADMIN
# ============================================

echo "👤 Step 8: Creazione utente admin..."
echo ""
echo -e "${YELLOW}In Supabase:${NC}"
echo "1. Vai su Authentication > Users"
echo "2. Add user > Create new user"
echo "3. Email: tua@email.com"
echo "4. Password: (scegli password sicura)"
echo "5. Auto Confirm User: ✓"
echo "6. Create user"
echo "7. Clicca sull'utente"
echo "8. Raw User Meta Data:"
echo '   {"role": "admin"}'
echo "9. Save"
echo ""
echo "Link: $SUPABASE_URL/project/_/auth/users"
echo ""

read -p "Utente admin creato? Premi Enter per continuare..."

echo ""

# ============================================
# STEP 9: EDGE FUNCTION (OPZIONALE)
# ============================================

echo "📧 Step 9: Deploy Edge Function per email (opzionale)..."
echo ""

if [ "$SUPABASE_CLI" = true ]; then
    read -p "Vuoi deployare le email automatiche? (y/n): " DEPLOY_EMAIL
    
    if [ "$DEPLOY_EMAIL" = "y" ]; then
        echo "Deployment Edge Function..."
        read -p "Resend API Key: " RESEND_KEY
        
        # Link progetto
        supabase link --project-ref $(echo $SUPABASE_URL | sed 's/https:\/\/\(.*\)\.supabase\.co/\1/')
        
        # Deploy function
        supabase functions deploy send-email
        
        # Set secret
        supabase secrets set RESEND_API_KEY="$RESEND_KEY"
        
        echo -e "${GREEN}✅ Edge Function deployata${NC}"
    else
        echo -e "${YELLOW}⚠️  Email automatiche saltate${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Supabase CLI non disponibile${NC}"
    echo "Per deployare email manualmente:"
    echo "1. Installa CLI: npm install -g supabase"
    echo "2. supabase login"
    echo "3. supabase link --project-ref XXXX"
    echo "4. supabase functions deploy send-email"
    echo "5. supabase secrets set RESEND_API_KEY=XXX"
fi

echo ""

# ============================================
# STEP 10: TEST FINALE
# ============================================

echo "✅ Step 10: Test sistema..."
echo ""

SITE_URL="https://$(echo $GITHUB_REPO | cut -d'/' -f1).github.io/$(echo $GITHUB_REPO | cut -d'/' -f2)/"

echo -e "${GREEN}🎉 Deployment completato!${NC}"
echo ""
echo "📍 URL Sito: $SITE_URL"
echo "📍 Admin: ${SITE_URL}admin.html"
echo ""
echo -e "${YELLOW}📋 PROSSIMI PASSI:${NC}"
echo "1. Apri il sito e verifica caricamento turni"
echo "2. Testa iscrizione completa"
echo "3. Login admin panel"
echo "4. Verifica liste e statistiche"
echo ""
echo "📖 Documentazione completa: README.md"
echo "🧪 Checklist test: TESTING.md"
echo ""

# ============================================
# SALVA RIEPILOGO
# ============================================

cat > ../deployment-info.txt << EOF
============================================
DEPLOYMENT INFO - Sistema Campeggi v2.0
============================================

Data Deploy: $(date)

CREDENZIALI:
- Supabase URL: $SUPABASE_URL
- Repository: $GITHUB_REPO

URL:
- Sito: $SITE_URL
- Admin: ${SITE_URL}admin.html

FILE BACKUP:
- frontend/app.js.backup
- frontend/turno.html.backup
- frontend/admin.html.backup

COMANDI UTILI:
- Update: git pull origin main
- Deploy: git add . && git commit -m "Update" && git push

SUPPORTO:
- README.md: Guida completa
- TESTING.md: Checklist test
- CHANGELOG.md: Differenze v1 vs v2

============================================
EOF

echo -e "${GREEN}📄 Info salvate in deployment-info.txt${NC}"
echo ""
echo "Buon lavoro! 🏕️"
