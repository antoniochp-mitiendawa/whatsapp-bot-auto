#!/data/data/com.termux/files/usr/bin/bash

# ==============================================
# INSTALADOR AUTOMÁTICO - BOT WHATSAPP
# Una sola línea para instalar todo
# ==============================================

echo "📦 INICIANDO INSTALACIÓN DEL BOT WHATSAPP"
echo "========================================"

# 1. ACTUALIZAR TERMUX
echo "🔄 Actualizando Termux..."
pkg update -y && pkg upgrade -y

# 2. INSTALAR DEPENDENCIAS BÁSICAS
echo "📥 Instalando paquetes necesarios..."
pkg install -y nodejs ffmpeg git termux-services

# 3. CREAR CARPETA DEL BOT
echo "📁 Creando estructura de carpetas..."
cd ~
mkdir -p whatsapp-bot
cd whatsapp-bot

# 4. CREAR CARPETA PARA PRODUCTOS DEL USUARIO
echo "🖼️ Creando carpeta para tus productos..."
mkdir -p /sdcard/MisProductos

# 5. CREAR CARPETA PARA OVERLAYS
mkdir -p overlays

# 6. CREAR ARCHIVO package.json
echo "📦 Creando package.json..."
cat > package.json << 'EOF'
{
  "name": "whatsapp-bot-auto",
  "version": "1.0.0",
  "description": "Bot automático para WhatsApp",
  "main": "bot.js",
  "dependencies": {
    "@whiskeysockets/baileys": "^6.5.0",
    "node-cron": "^3.0.3",
    "fluent-ffmpeg": "^2.1.2",
    "qrcode-terminal": "^0.12.0",
    "pino": "^8.17.2"
  }
}
EOF

# 7. INSTALAR DEPENDENCIAS NODE
echo "📦 Instalando dependencias de Node.js..."
npm install

# 8. CREAR ARCHIVO DEL BOT (bot.js) - VERSIÓN CON PAUSA PARA NÚMERO
echo "🤖 Creando archivo principal del bot..."
cat > bot.js << 'EOF'
// ==============================================
// BOT WHATSAPP AUTOMÁTICO - VERSIÓN ESTABLE
// ==============================================

const { default: makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const fs = require('fs');
const path = require('path');
const cron = require('node-cron');
const ffmpeg = require('fluent-ffmpeg');
const P = require('pino');
const readline = require('readline');

// Configuración
const CONFIG = {
  productsDir: '/sdcard/MisProductos',
  overlaysDir: './overlays',
  tempDir: './temp',
  sentLog: './sent_log.json',
  groupsFile: './groups.json',
  checkInterval: '*/30 * * * *',
  groupsPerBatch: 5
};

// Crear directorios necesarios
if (!fs.existsSync(CONFIG.tempDir)) fs.mkdirSync(CONFIG.tempDir, { recursive: true });
if (!fs.existsSync(CONFIG.sentLog)) fs.writeFileSync(CONFIG.sentLog, '[]');
if (!fs.existsSync(CONFIG.groupsFile)) fs.writeFileSync(CONFIG.groupsFile, '{}');

// Variables globales
let sock = null;
let reconnectAttempts = 0;
let isConnected = false;
let pairingCodeRequested = false;

// Cargar registros
function loadSentLog() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG.sentLog));
  } catch {
    return [];
  }
}

function saveSentLog(log) {
  fs.writeFileSync(CONFIG.sentLog, JSON.stringify(log, null, 2));
}

// Obtener productos no usados
function getNextProduct() {
  if (!fs.existsSync(CONFIG.productsDir)) return null;
  
  const products = fs.readdirSync(CONFIG.productsDir)
    .filter(f => f.match(/\.(jpg|jpeg|png|webp)$/i));
  
  if (products.length === 0) return null;
  
  const sentLog = loadSentLog();
  const available = products.filter(p => !sentLog.includes(p));
  
  if (available.length === 0) {
    saveSentLog([]);
    return products[Math.floor(Math.random() * products.length)];
  }
  
  return available[Math.floor(Math.random() * available.length)];
}

// Generar GIF con overlay
async function generateGif(productFile) {
  return new Promise((resolve, reject) => {
    const productPath = path.join(CONFIG.productsDir, productFile);
    
    let overlays = [];
    try {
      overlays = fs.readdirSync(CONFIG.overlaysDir).filter(f => f.endsWith('.gif'));
    } catch {
      return reject('No hay overlays');
    }
    
    if (overlays.length === 0) return reject('No hay overlays');
    
    const overlay = overlays[Math.floor(Math.random() * overlays.length)];
    const outputPath = path.join(CONFIG.tempDir, `output_${Date.now()}.gif`);
    
    ffmpeg()
      .input(productPath)
      .input(path.join(CONFIG.overlaysDir, overlay))
      .complexFilter([{ filter: 'overlay', options: { x: '(W-w)/2', y: '(H-h)/2' } }])
      .on('end', () => resolve(outputPath))
      .on('error', reject)
      .save(outputPath);
  });
}

// Obtener grupos disponibles
async function getAvailableGroups() {
  if (!sock) return [];
  
  try {
    const groupsData = await sock.groupFetchAllParticipating();
    const allGroups = Object.keys(groupsData);
    
    let currentGroups = {};
    try {
      currentGroups = JSON.parse(fs.readFileSync(CONFIG.groupsFile));
    } catch {
      currentGroups = {};
    }
    
    const now = Date.now();
    const oneWeek = 7 * 24 * 60 * 60 * 1000;
    
    const available = allGroups.filter(id => {
      const lastSent = currentGroups[id] || 0;
      return now - lastSent > oneWeek;
    });
    
    return available.slice(0, CONFIG.groupsPerBatch);
  } catch (err) {
    return [];
  }
}

// Enviar estado a grupos
async function sendToGroups(gifPath, targetGroups) {
  try {
    const gifBuffer = fs.readFileSync(gifPath);
    
    for (const groupId of targetGroups) {
      try {
        await sock.sendMessage(groupId, {
          image: gifBuffer,
          caption: '✨ Nuestros productos ✨',
          viewOnce: true
        });
        
        let groups = {};
        try {
          groups = JSON.parse(fs.readFileSync(CONFIG.groupsFile));
        } catch {
          groups = {};
        }
        
        groups[groupId] = Date.now();
        fs.writeFileSync(CONFIG.groupsFile, JSON.stringify(groups, null, 2));
        
        await new Promise(r => setTimeout(r, 2000));
      } catch (err) {}
    }
  } catch (err) {}
}

// Tarea principal
async function mainTask() {
  if (!isConnected || !sock) return;
  
  try {
    const productFile = getNextProduct();
    if (!productFile) return;
    
    const gifPath = await generateGif(productFile);
    if (!gifPath) return;
    
    const targetGroups = await getAvailableGroups();
    if (targetGroups.length === 0) return;
    
    await sendToGroups(gifPath, targetGroups);
    
    const sentLog = loadSentLog();
    sentLog.push(productFile);
    saveSentLog(sentLog);
    
    try { fs.unlinkSync(gifPath); } catch {}
    
  } catch (err) {}
}

// ==============================================
// FUNCIÓN DE CONEXIÓN - VERSIÓN ESTABLE
// ==============================================
async function connectToWhatsApp() {
  console.log('🔄 Conectando a WhatsApp...');
  
  try {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info');
    
    sock = makeWASocket({
      auth: state,
      logger: P({ level: 'silent' }),
      browser: ['WhatsApp Bot', 'Chrome', '1.0.0'],
      syncFullHistory: false,
      generateHighQualityLinkPreview: false
    });
    
    pairingCodeRequested = false;
    
    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;
      
      if (connection === 'open') {
        console.log('\n✅ CONECTADO A WHATSAPP EXITOSAMENTE');
        console.log('🎉 El bot ya está funcionando\n');
        isConnected = true;
        reconnectAttempts = 0;
        pairingCodeRequested = true; // Marcar como ya solicitado
      }
      
      if (connection === 'close') {
        console.log('❌ Conexión cerrada');
        isConnected = false;
        
        // Solo reconectar si NO estamos esperando código
        if (!pairingCodeRequested) {
          reconnectAttempts++;
          const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 60000);
          console.log(`⏳ Reintentando en ${delay/1000} segundos...`);
          setTimeout(connectToWhatsApp, delay);
        } else {
          console.log('⏳ Esperando que ingreses el código de emparejamiento...');
        }
      }
      
      // Mostrar QR si aparece (método alternativo)
      if (qr) {
        console.log('📱 Código QR detectado (método alternativo):');
        console.log(qr);
      }
      
      // Cuando el socket está listo, solicitar código de emparejamiento (solo una vez)
      if (connection === 'connecting' && !pairingCodeRequested) {
        pairingCodeRequested = true;
        
        // Crear interfaz readline
        const rl = readline.createInterface({
          input: process.stdin,
          output: process.stdout
        });
        
        // Pedir número de teléfono
        rl.question('\n📱 Escribe tu número de teléfono (ej: 52123456789): ', async (phoneNumber) => {
          // Limpiar número
          phoneNumber = phoneNumber.replace(/[^0-9]/g, '');
          
          console.log(`⏳ Solicitando código para: ${phoneNumber}`);
          
          try {
            // Solicitar código de emparejamiento
            const pairingCode = await sock.requestPairingCode(phoneNumber);
            
            console.log('\n========================================');
            console.log('✅ TU CÓDIGO DE EMPAREJAMIENTO ES:');
            console.log('========================================');
            console.log(`🔐 ${pairingCode}`);
            console.log('========================================');
            console.log('\n📱 Abre WhatsApp en tu teléfono');
            console.log('➡️  Ajustes > Dispositivos vinculados');
            console.log('➡️  "Vincular un dispositivo"');
            console.log('➡️  "Vincular con número de teléfono"');
            console.log('➡️  Ingresa este código\n');
            console.log('⏳ Esperando conexión... (esto puede tardar unos segundos)\n');
            
            // Cerrar readline después de mostrar el código
            rl.close();
            
          } catch (err) {
            console.log('❌ Error solicitando código:', err.message);
            rl.close();
            pairingCodeRequested = false; // Permitir reintentar
          }
        });
      }
    });
    
    sock.ev.on('creds.update', saveCreds);
    
  } catch (err) {
    console.log('Error conectando:', err);
    setTimeout(connectToWhatsApp, 5000);
  }
}

// Iniciar
console.log('🚀 Iniciando Bot WhatsApp...');
console.log('📱 Versión con código de emparejamiento\n');
connectToWhatsApp();

// Programar tarea
cron.schedule(CONFIG.checkInterval, mainTask);
console.log(`⏰ Tarea programada cada 30 minutos`);

// Mantener proceso vivo
process.on('uncaughtException', (err) => {});
EOF

# 9. CREAR OVERLAYS BÁSICOS
echo "🎨 Creando overlays básicos..."

cat > overlays/oferta.gif << 'EOF'
R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7
EOF

cat > overlays/promo.gif << 'EOF'
R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7
EOF

cat > overlays/nuevo.gif << 'EOF'
R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7
EOF

cat > overlays/descuento.gif << 'EOF'
R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7
EOF

cat > overlays/destacado.gif << 'EOF'
R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7
EOF

# 10. CONFIGURAR INICIO AUTOMÁTICO
echo "⚙️ Configurando inicio automático..."
mkdir -p ~/.termux/boot

cat > ~/.termux/boot/start-bot.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/whatsapp-bot
node bot.js
EOF

chmod +x ~/.termux/boot/start-bot.sh

# 11. MENSAJE FINAL
echo ""
echo "========================================"
echo "✅ INSTALACIÓN COMPLETADA"
echo "========================================"
echo ""
echo "📱 PASOS PARA CONECTAR EL BOT:"
echo ""
echo "1️⃣  El bot iniciará automáticamente"
echo "2️⃣  Te pedirá tu número de teléfono"
echo "3️⃣  Escríbelo completo (ej: 52123456789)"
echo "4️⃣  Recibirás un código de 8 dígitos"
echo "5️⃣  Abre WhatsApp > Ajustes > Dispositivos vinculados"
echo "6️⃣  Elige 'Vincular con número de teléfono'"
echo "7️⃣  Ingresa el código"
echo ""
echo "🖼️ Para poner tus productos:"
echo "   📁 /sdcard/MisProductos/"
echo ""
echo "✅ El bot se reinicia solo si:"
echo "   - Se desconecta de internet"
echo "   - Reinicias tu teléfono"
echo ""
echo "========================================"
echo ""

# 12. INICIAR BOT
cd ~/whatsapp-bot
echo "🚀 Iniciando el bot..."
node bot.js
