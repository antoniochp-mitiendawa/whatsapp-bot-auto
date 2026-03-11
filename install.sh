#!/data/data/com.termux/files/usr/bin/bash

# ==============================================
# INSTALADOR BOT WHATSAPP - ESTADOS AUTOMÁTICOS
# ==============================================

echo "📦 INICIANDO INSTALACIÓN"
echo "========================"
pkg update -y && pkg upgrade -y
pkg install -y nodejs ffmpeg

cd ~
mkdir -p whatsapp-bot-estados
cd whatsapp-bot-estados
mkdir -p /sdcard/MisProductos
mkdir -p overlays

# ==============================================
# CREAR PACKAGE.JSON
# ==============================================
cat > package.json << 'EOF'
{
  "name": "bot-estados",
  "version": "1.0.0",
  "dependencies": {
    "@whiskeysockets/baileys": "^6.5.0",
    "node-cron": "^3.0.3",
    "fluent-ffmpeg": "^2.1.2",
    "pino": "^8.17.2"
  }
}
EOF

npm install

# ==============================================
# CREAR BOT PRINCIPAL (con emparejamiento de tu proyecto)
# ==============================================
cat > bot.js << 'EOF'
// ============================================
// BOT DE ESTADOS AUTOMÁTICOS
// Con sistema de emparejamiento de tu proyecto
// ============================================

const { default: makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const fs = require('fs');
const path = require('path');
const cron = require('node-cron');
const ffmpeg = require('fluent-ffmpeg');
const P = require('pino');
const readline = require('readline');

// Configuración
const CONFIG = {
    productosDir: '/sdcard/MisProductos',
    overlaysDir: './overlays',
    tempDir: './temp',
    gruposFile: './grupos.json',
    checkInterval: '*/30 * * * *'
};

// Crear carpetas
if (!fs.existsSync(CONFIG.tempDir)) fs.mkdirSync(CONFIG.tempDir, { recursive: true });

// ============================================
// FUNCIÓN PARA PEDIR NÚMERO (de tu proyecto)
// ============================================
function pedirNumero() {
    return new Promise((resolve) => {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
        rl.question('📱 Tu número (ej: 52123456789): ', (numero) => {
            rl.close();
            resolve(numero.trim());
        });
    });
}

// ============================================
// FUNCIÓN PRINCIPAL
// ============================================
async function iniciarBot() {
    console.log('\n🚀 INICIANDO BOT DE ESTADOS');
    console.log('===========================\n');

    // Verificar si ya hay sesión guardada
    const existeSesion = fs.existsSync('./auth_info/creds.json');

    // Si no hay sesión, pedir número primero
    if (!existeSesion) {
        console.log('📱 PRIMERA CONFIGURACIÓN\n');
        const numero = await pedirNumero(); // <--- ESPERA AQUÍ
        
        console.log(`\n🔄 Conectando con número: ${numero}...`);

        try {
            const { state, saveCreds } = await useMultiFileAuthState('auth_info');
            
            const sock = makeWASocket({
                auth: state,
                logger: P({ level: 'silent' }),
                browser: ['Bot Estados', 'Chrome', '1.0']
            });

            // Solicitar código de emparejamiento
            setTimeout(async () => {
                try {
                    const codigo = await sock.requestPairingCode(numero);
                    console.log('\n====================================');
                    console.log('🔐 TU CÓDIGO ES:', codigo);
                    console.log('====================================');
                    console.log('\n1. Abre WhatsApp');
                    console.log('2. 3 puntos → Dispositivos vinculados');
                    console.log('3. Vincular con número de teléfono');
                    console.log('4. Ingresa este código\n');
                } catch (err) {
                    console.log('❌ Error generando código:', err.message);
                }
            }, 2000);

            sock.ev.on('connection.update', (update) => {
                const { connection } = update;
                if (connection === 'open') {
                    console.log('\n✅ CONECTADO A WHATSAPP');
                    console.log('🎉 Bot listo para enviar estados\n');
                }
                if (connection === 'close') {
                    console.log('\n❌ Conexión cerrada. Reintentando en 30s...');
                    setTimeout(iniciarBot, 30000);
                }
            });

            sock.ev.on('creds.update', saveCreds);

        } catch (error) {
            console.log('❌ Error:', error.message);
            setTimeout(iniciarBot, 5000);
        }
    } else {
        // Si ya hay sesión, conectar directamente
        console.log('📱 Usando sesión existente...');
        
        try {
            const { state, saveCreds } = await useMultiFileAuthState('auth_info');
            
            const sock = makeWASocket({
                auth: state,
                logger: P({ level: 'silent' }),
                browser: ['Bot Estados', 'Chrome', '1.0']
            });

            sock.ev.on('connection.update', (update) => {
                const { connection } = update;
                if (connection === 'open') {
                    console.log('\n✅ CONECTADO A WHATSAPP');
                    console.log('🎉 Bot listo para enviar estados\n');
                }
                if (connection === 'close') {
                    console.log('\n❌ Conexión cerrada. Reintentando en 30s...');
                    setTimeout(iniciarBot, 30000);
                }
            });

            sock.ev.on('creds.update', saveCreds);

        } catch (error) {
            console.log('❌ Error:', error.message);
            setTimeout(iniciarBot, 5000);
        }
    }
}

// Iniciar
iniciarBot();

// Mantener proceso vivo
process.on('uncaughtException', () => {});
EOF

# ==============================================
# OVERLAYS BÁSICOS
# ==============================================
for g in oferta promo nuevo descuento destacado; do
    echo "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" > overlays/$g.gif
done

echo ""
echo "===================================="
echo "✅ INSTALACIÓN COMPLETA"
echo "===================================="
echo ""
echo "📱 PRIMERA VEZ:"
echo "   node bot.js"
echo ""
echo "🖼️  Tus productos: /sdcard/MisProductos/"
echo ""

cd ~/whatsapp-bot-estados
