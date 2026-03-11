#!/data/data/com.termux/files/usr/bin/bash

echo "📦 INSTALANDO BOT WHATSAPP"
echo "========================"
pkg update -y && pkg upgrade -y
pkg install -y nodejs ffmpeg

cd ~
mkdir -p whatsapp-bot
cd whatsapp-bot
mkdir -p /sdcard/MisProductos
mkdir -p overlays

# Package.json
cat > package.json << 'EOF'
{
  "name": "bot",
  "dependencies": {
    "@whiskeysockets/baileys": "^6.5.0",
    "pino": "^8.17.2"
  }
}
EOF

npm install

# Crear autenticador - VERSIÓN SIMPLE
cat > login.js << 'EOF'
const { default: makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const P = require('pino');
const readline = require('readline');

async function main() {
  console.log('\n🔐 AUTENTICACIÓN WHATSAPP\n');
  
  // Crear interfaz ANTES de cualquier cosa
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  // Función para preguntar
  const pregunta = (texto) => new Promise((resolve) => {
    rl.question(texto, resolve);
  });
  
  try {
    // 1. PEDIR NÚMERO (esto espera hasta que el usuario escriba)
    const numero = await pregunta('📱 Tu número (ej: 52123456789): ');
    const numeroLimpio = numero.replace(/[^0-9]/g, '');
    
    console.log(`\n⏳ Conectando con ${numeroLimpio}...`);
    
    // 2. INICIAR SESIÓN
    const { state, saveCreds } = await useMultiFileAuthState('auth_info');
    
    const sock = makeWASocket({
      auth: state,
      logger: P({ level: 'silent' }),
      browser: ['Bot', 'Chrome', '1.0']
    });
    
    // 3. SOLICITAR CÓDIGO
    setTimeout(async () => {
      try {
        const codigo = await sock.requestPairingCode(numeroLimpio);
        console.log('\n✅ CÓDIGO: ' + codigo);
        console.log('\n📱 WhatsApp > Ajustes > Dispositivos vinculados');
        console.log('➡️  "Vincular con número de teléfono"\n');
        console.log('⏳ Esperando conexión...\n');
      } catch (e) {
        console.log('Error:', e.message);
      }
    }, 2000);
    
    // 4. ESPERAR CONEXIÓN
    sock.ev.on('connection.update', (update) => {
      const { connection } = update;
      if (connection === 'open') {
        console.log('✅ CONECTADO! Ya puedes usar: node bot.js');
        rl.close();
        process.exit(0);
      }
    });
    
    sock.ev.on('creds.update', saveCreds);
    
  } catch (e) {
    console.log('Error:', e);
    rl.close();
  }
}

main();
EOF

# Bot principal simple
cat > bot.js << 'EOF'
const { default: makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const P = require('pino');

async function start() {
  const { state, saveCreds } = await useMultiFileAuthState('auth_info');
  const sock = makeWASocket({ auth: state, logger: P({ level: 'silent' }) });
  
  sock.ev.on('connection.update', ({ connection }) => {
    if (connection === 'open') console.log('✅ Bot funcionando');
  });
  
  sock.ev.on('creds.update', saveCreds);
}

console.log('🚀 Iniciando bot...');
start();
EOF

# Overlays básicos
for g in oferta promo nuevo descuento; do
  echo "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" > overlays/$g.gif
done

echo ""
echo "✅ INSTALACIÓN COMPLETA"
echo "======================"
echo ""
echo "📱 AUTENTICAR (PRIMERA VEZ):"
echo "   cd ~/whatsapp-bot"
echo "   node login.js"
echo ""
echo "🤖 INICIAR BOT:"
echo "   node bot.js"
echo ""
echo "🖼️ PRODUCTOS: /sdcard/MisProductos/"
echo ""

cd ~/whatsapp-bot
