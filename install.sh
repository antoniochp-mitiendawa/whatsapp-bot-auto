#!/data/data/com.termux/files/usr/bin/bash

echo "📦 INSTALANDO BOT WHATSAPP"
echo "========================"
pkg update -y && pkg upgrade -y
pkg install -y nodejs

cd ~
mkdir -p whatsapp-bot
cd whatsapp-bot
mkdir -p /sdcard/MisProductos

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

cat > login.js << 'EOF'
const { default: makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const P = require('pino');
const readline = require('readline');

// ESTA ES LA LÍNEA QUE FALTABA
process.stdin.resume();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('\n🔐 AUTENTICACIÓN WHATSAPP\n');

rl.question('📱 Número (ej: 52123456789): ', async (numero) => {
  const numeroLimpio = numero.replace(/[^0-9]/g, '');
  
  console.log(`⏳ Conectando...`);
  
  const { state, saveCreds } = await useMultiFileAuthState('auth_info');
  const sock = makeWASocket({ auth: state, logger: P({ level: 'silent' }) });
  
  setTimeout(async () => {
    try {
      const codigo = await sock.requestPairingCode(numeroLimpio);
      console.log('\n✅ CÓDIGO: ' + codigo);
      console.log('\nIngrésalo en WhatsApp > Ajustes > Dispositivos vinculados\n');
    } catch (e) {
      console.log('Error:', e.message);
    }
  }, 2000);
  
  sock.ev.on('connection.update', ({ connection }) => {
    if (connection === 'open') {
      console.log('✅ Conectado');
      process.exit(0);
    }
  });
  
  sock.ev.on('creds.update', saveCreds);
});
EOF

echo ""
echo "✅ LISTO"
echo ""
echo "cd ~/whatsapp-bot"
echo "node login.js"
echo ""

cd ~/whatsapp-bot
