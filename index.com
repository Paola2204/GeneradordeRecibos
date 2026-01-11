<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Generador de Recibos - Lemustech (Euros)</title>
    
    <!-- Configuración de Web App (Iconos y Pantalla Completa) -->
    <link rel="icon" href="https://ui-avatars.com/api/?name=Lemus+Tech&background=1e3a8a&color=fff&rounded=true&size=128" type="image/png">
    <link rel="apple-touch-icon" href="https://ui-avatars.com/api/?name=Lemus+Tech&background=1e3a8a&color=fff&rounded=true&size=512">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="Lemustech">

    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap');
        body { font-family: 'Inter', sans-serif; -webkit-tap-highlight-color: transparent; }
        .animate-fade-in { animation: fadeIn 0.3s ease-in-out; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        
        /* Estilos para impresión */
        @media print {
            .no-print { display: none !important; }
            body { background: white; }
            .shadow-2xl { box-shadow: none; }
        }
        
        /* Animación de carga */
        .spin { animation: spin 1s linear infinite; }
        @keyframes spin { 100% { transform: rotate(360deg); } }
    </style>
</head>
<body class="bg-gray-100 text-gray-800 min-h-screen">

    <div class="max-w-2xl mx-auto bg-white min-h-screen shadow-2xl flex flex-col">
        
        <!-- Encabezado -->
        <header class="bg-blue-900 text-white p-6 pt-10"> <!-- pt-10 para respetar el notch del iPhone -->
            <div class="flex justify-between items-center">
                <div>
                    <h1 class="font-bold text-xl"><i class="fas fa-laptop-medical mr-2"></i>Lemustech</h1>
                    <p class="text-xs text-blue-200 uppercase tracking-wide">Generador de Recibos</p>
                </div>
                <div class="text-right">
                    <div class="text-xs text-blue-300">Fecha</div>
                    <input type="date" id="invoiceDate" class="bg-blue-800 text-white text-sm rounded border-none p-1 focus:ring-0 cursor-pointer">
                </div>
            </div>
        </header>

        <!-- Configuración Rápida (Tasa y Control) -->
        <div class="bg-blue-50 p-4 border-b border-blue-100 flex items-center gap-4">
            <!-- Tasa BCV (EURO) con Botón de API -->
            <div class="flex-1 relative">
                <label class="text-xs font-bold text-blue-900 block mb-1 flex justify-between">
                    <span>Tasa BCV (Bs/€)</span>
                    <button onclick="fetchBCV(true)" id="btn-refresh" class="text-blue-600 hover:text-blue-800" title="Actualizar Tasa Euro BCV">
                        <i class="fas fa-sync-alt"></i>
                    </button>
                </label>
                <div class="relative">
                    <input type="number" id="exchangeRate" placeholder="0.00" class="w-full border border-blue-200 rounded p-2 text-sm focus:border-blue-500 outline-none pr-8" oninput="calculateTotal(); saveSettings()">
                    <span class="absolute right-2 top-2 text-gray-400 text-xs font-bold">Bs</span>
                </div>
            </div>

            <!-- Número de Control Auto-incrementable -->
            <div class="flex-1">
                <label class="text-xs font-bold text-blue-900 block mb-1">N° Control (Auto)</label>
                <input type="text" id="invoiceNumber" value="001" class="w-full border border-blue-200 rounded p-2 text-sm focus:border-blue-500 outline-none text-center font-mono font-bold" oninput="saveSettings()">
            </div>
        </div>

        <!-- Datos del Cliente -->
        <div class="p-6 space-y-4">
            <h2 class="text-sm font-bold text-gray-400 uppercase tracking-wider">Datos del Cliente</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <input type="text" id="clientName" placeholder="Nombre del Cliente" class="border border-gray-300 p-3 rounded-lg w-full bg-gray-50 focus:bg-white focus:border-blue-500 outline-none transition-colors">
                <input type="tel" id="clientPhone" placeholder="WhatsApp (Ej. 58412...)" class="border border-gray-300 p-3 rounded-lg w-full bg-gray-50 focus:bg-white focus:border-blue-500 outline-none transition-colors">
            </div>
        </div>

        <!-- Items de la Factura -->
        <div class="flex-1 p-6 bg-gray-50">
            <div class="flex justify-between items-center mb-4">
                <h2 class="text-sm font-bold text-gray-400 uppercase tracking-wider">Detalle del Servicio</h2>
                <button onclick="addItem()" class="no-print text-blue-600 text-sm font-bold hover:text-blue-800 transition-colors flex items-center gap-1">
                    <i class="fas fa-plus-circle"></i> Agregar Fila
                </button>
            </div>

            <div id="items-container" class="space-y-3">
                <!-- Los items se agregan aquí dinámicamente -->
            </div>
        </div>

        <!-- Notas y Garantía -->
        <div class="px-6 pb-2">
            <h2 class="text-sm font-bold text-gray-400 uppercase tracking-wider mb-2">Notas Técnicas / Garantía</h2>
            <textarea id="notes" class="w-full border border-gray-300 rounded-lg p-3 text-sm h-20 focus:border-blue-500 outline-none resize-none" placeholder="Ej: Equipo recibido sin cargador. Garantía de 15 días por software."></textarea>
        </div>

        <!-- Métodos de Pago (Collapsible) -->
        <div class="px-6 py-2 no-print">
            <details class="bg-gray-50 rounded-lg border border-gray-200" open>
                <summary class="p-3 font-bold text-sm text-gray-600 cursor-pointer flex justify-between items-center bg-gray-100 rounded-t-lg">
                    <span>💳 Configurar Métodos de Pago</span>
                    <i class="fas fa-chevron-down"></i>
                </summary>
                <div class="p-4 space-y-3 border-t border-gray-200 bg-white rounded-b-lg">
                    
                    <div>
                        <label class="text-xs font-bold text-gray-500 flex items-center gap-1"><i class="fas fa-mobile-alt text-blue-500"></i> Pago Móvil</label>
                        <input type="text" id="payMobile" class="w-full border p-2 rounded text-xs mt-1" placeholder="Banesco - 0412... - CI..." oninput="saveSettings()">
                    </div>

                    <div>
                        <label class="text-xs font-bold text-gray-500 flex items-center gap-1"><i class="fas fa-university text-green-600"></i> Transferencias Bancarias (Bs)</label>
                        <textarea id="payBank" rows="4" class="w-full border p-2 rounded text-xs mt-1 font-mono" oninput="saveSettings()"></textarea>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                        <div>
                            <label class="text-xs font-bold text-gray-500 flex items-center gap-1"><i class="fas fa-wallet text-purple-500"></i> Wally</label>
                            <input type="text" id="payWally" class="w-full border p-2 rounded text-xs mt-1" placeholder="ID / Teléfono" oninput="saveSettings()">
                        </div>
                        <div>
                            <label class="text-xs font-bold text-gray-500 flex items-center gap-1"><i class="fas fa-paper-plane text-pink-500"></i> Zinli</label>
                            <input type="text" id="payZinli" class="w-full border p-2 rounded text-xs mt-1" placeholder="Correo electrónico" oninput="saveSettings()">
                        </div>
                        <div>
                            <label class="text-xs font-bold text-gray-500 flex items-center gap-1"><i class="fab fa-bitcoin text-yellow-500"></i> Binance</label>
                            <input type="text" id="payBinance" class="w-full border p-2 rounded text-xs mt-1" placeholder="Pay ID / USDT" oninput="saveSettings()">
                        </div>
                    </div>
                    
                    <p class="text-xs text-blue-500 mt-2 text-center bg-blue-50 p-2 rounded">
                        <i class="fas fa-info-circle"></i> Tus datos bancarios ya están precargados. Edítalos si es necesario.
                    </p>
                </div>
            </details>
        </div>

        <!-- Totales -->
        <div class="p-6 bg-white border-t space-y-2">
            <div class="flex justify-between text-gray-600">
                <span>Subtotal</span>
                <span id="subtotalDisplay">€0.00</span>
            </div>
            <div class="flex justify-between text-xl font-bold text-gray-800 pt-2 border-t">
                <span>Total (€)</span>
                <span id="totalDisplay">€0.00</span>
            </div>
            <div id="bsContainer" class="flex justify-between text-sm font-bold text-blue-600 hidden">
                <span>Total (Bs)</span>
                <span id="totalBsDisplay">Bs 0.00</span>
            </div>
        </div>

        <!-- Botones de Acción -->
        <div class="p-6 bg-gray-100 flex gap-3 no-print pb-10">
            <button onclick="generateWhatsAppLink()" class="flex-1 bg-green-500 hover:bg-green-600 text-white font-bold py-4 rounded-xl shadow-lg flex items-center justify-center gap-2 transition-transform hover:scale-105 active:scale-95">
                <i class="fab fa-whatsapp text-2xl"></i> Enviar Recibo y Siguiente (+1)
            </button>
            <button onclick="window.print()" class="px-6 bg-gray-800 text-white rounded-xl hover:bg-gray-700 transition-colors" title="Guardar como PDF">
                <i class="fas fa-print"></i>
            </button>
        </div>

    </div>

    <!-- Template para Items (Oculto) -->
    <template id="item-template">
        <div class="p-3 border border-gray-200 rounded-lg bg-white shadow-sm item-row animate-fade-in relative group hover:border-blue-300 transition-colors">
            <!-- Botón Eliminar (Flotante) -->
            <button onclick="removeItem(this)" class="no-print absolute -top-2 -right-2 bg-red-100 text-red-500 hover:bg-red-500 hover:text-white rounded-full w-6 h-6 flex items-center justify-center shadow-sm transition-colors text-xs z-10">
                <i class="fas fa-times"></i>
            </button>

            <!-- Selección Rápida -->
            <div class="mb-2 no-print">
                <select onchange="fillItem(this)" class="service-select w-full text-xs bg-blue-50 text-blue-800 border-none rounded px-2 py-1 font-semibold focus:ring-0 cursor-pointer hover:bg-blue-100 transition-colors">
                    <option value="">⚡ Elegir servicio rápido...</option>
                    <!-- Options injected by JS -->
                </select>
            </div>
            
            <!-- Inputs -->
            <div class="flex gap-2">
                <div class="flex-1">
                    <input type="text" placeholder="Descripción del servicio" class="item-desc w-full border border-gray-300 p-2 rounded text-sm focus:border-blue-500 outline-none transition-colors">
                </div>
                <div class="w-16">
                    <input type="number" placeholder="Cant." value="1" min="1" class="item-qty w-full border border-gray-300 p-2 rounded text-sm text-center focus:border-blue-500 outline-none" oninput="calculateTotal()">
                </div>
                <div class="w-24 relative">
                    <span class="absolute left-2 top-2 text-gray-400 text-sm">€</span>
                    <input type="number" placeholder="Precio" class="item-price w-full border border-gray-300 p-2 pl-5 rounded text-sm focus:border-blue-500 outline-none" oninput="calculateTotal()">
                </div>
            </div>
        </div>
    </template>

    <script>
        // --- 🛠️ CONFIGURACIÓN DE ITEMS PREDETERMINADOS (En Euros) ---
        const predefinedServices = [
            { name: "Formateo & Instalación Limpia de S.O. + Drivers", price: 60 },
            { name: "Mantenimiento Preventivo Integral de Hardware", price: 40 },
            { name: "Upgrade macOS en Equipos No Compatibles (Patching)", price: 80 },
            { name: "Instalación de Unidad SSD", price: 85 },
            { name: "Soporte Técnico Remoto Especializado (x Hora)", price: 40 },
            { name: "Licenciamiento Microsoft Office Suite", price: 25 },
            { name: "Diagnóstico Técnico & Troubleshooting", price: 10 },
            { name: "Despliegue de Software & Utilitarios Básicos", price: 15 }
        ];

        // --- 🏦 DATOS BANCARIOS PRECARGADOS ---
        const defaultBankData = `BANESCO
0134-0224-87-2241030305
Luis Lemus | CI: 20.297.129
llemus1292@gmail.com

BANPLUS
0174-0126-21-1264042910
Luis Lemus | CI: 20.297.129
llemus1292@gmail.com

BANCO DE VENEZUELA
0102-0339-25-0000496465
Luis Lemus | CI: 20.297.129
Llemus1292@gmail.com`;

        const defaultMobileData = "Banesco/Banplus - 0424-1353496 - CI: 20.297.129 (Lemustech)";
        const defaultWallyData = "llemus1292@Gmail.com";
        const defaultZinliData = "llemus1292@outlook.com";
        const defaultBinanceData = "Pay ID: 519506837 | User: Llemus43 | llemus1217@gmail.com";

        // --- 💾 SISTEMA DE GUARDADO AUTOMÁTICO ---
        function saveSettings() {
            const settings = {
                rate: document.getElementById('exchangeRate').value,
                invoiceNum: document.getElementById('invoiceNumber').value,
                payMobile: document.getElementById('payMobile').value,
                payBank: document.getElementById('payBank').value,
                payWally: document.getElementById('payWally').value,
                payZinli: document.getElementById('payZinli').value,
                payBinance: document.getElementById('payBinance').value
            };
            localStorage.setItem('lemustech_settings_eur', JSON.stringify(settings)); // Clave nueva para Euros
        }

        function loadSettings() {
            const saved = localStorage.getItem('lemustech_settings_eur');
            
            // Valores por defecto si es la primera vez
            if (!saved) {
                document.getElementById('payBank').value = defaultBankData;
                document.getElementById('payMobile').value = defaultMobileData;
                document.getElementById('payWally').value = defaultWallyData;
                document.getElementById('payZinli').value = defaultZinliData;
                document.getElementById('payBinance').value = defaultBinanceData;
                return;
            }

            // Cargar datos guardados
            const settings = JSON.parse(saved);
            if(settings.rate) document.getElementById('exchangeRate').value = settings.rate;
            if(settings.invoiceNum) document.getElementById('invoiceNumber').value = settings.invoiceNum;
            
            // Cargar métodos de pago (o usar defaults si están vacíos)
            document.getElementById('payMobile').value = settings.payMobile || defaultMobileData;
            document.getElementById('payBank').value = settings.payBank || defaultBankData;
            document.getElementById('payWally').value = settings.payWally || defaultWallyData;
            document.getElementById('payZinli').value = settings.payZinli || defaultZinliData;
            document.getElementById('payBinance').value = settings.payBinance || defaultBinanceData;
        }

        // --- 🌐 API BCV (EURO) ---
        async function fetchBCV(isManual = false) {
            const btn = document.getElementById('btn-refresh');
            const icon = btn.querySelector('i');
            const input = document.getElementById('exchangeRate');

            // Animación de carga
            icon.className = 'fas fa-sync-alt spin';
            btn.disabled = true;

            // Función auxiliar para intentar un fetch y parsear
            const tryFetch = async (url, parser) => {
                try {
                     const res = await fetch(url);
                     if (!res.ok) throw new Error(`HTTP ${res.status}`);
                     const json = await res.json();
                     return parser(json);
                } catch (e) {
                    console.warn(`Fetch falló para ${url}:`, e); // Warn silencioso
                    throw e;
                }
            };

            try {
                let rate = null;
                
                // 1. Intentar API Principal (DolarApi)
                try {
                    rate = await tryFetch('https://ve.dolarapi.com/v1/euros/oficial', d => d.promedio);
                } catch (err1) {
                    // 2. Intentar API Respaldo (PyDolarVenezuela)
                    try {
                        rate = await tryFetch('https://pydolarvenezuela-api.vercel.app/api/v1/euro?page=bcv', d => {
                             return d.monitors?.bcv?.price || d.price || d.promedio;
                        });
                    } catch (err2) {
                        // 3. Fallback Último Recurso (Open Exchange Rates - Global)
                        // Esto devuelve tasa de mercado internacional, mejor que nada
                        rate = await tryFetch('https://open.er-api.com/v6/latest/EUR', d => d.rates.VES);
                    }
                }

                if (!rate) throw new Error("Sin datos de tasa");

                // Actualizar input
                input.value = parseFloat(rate).toFixed(2);
                
                // Recalcular y Guardar
                calculateTotal();
                saveSettings();
                
                // Feedback visual (verde)
                icon.className = 'fas fa-check text-green-500';
                setTimeout(() => { icon.className = 'fas fa-sync-alt'; }, 2000);

            } catch (error) {
                console.warn("No se pudo obtener la tasa automática:", error);
                
                // Solo alertar si fue un clic manual del usuario
                if (isManual) {
                    alert("⚠️ No se pudo conectar a los servidores del BCV.\n\nPor favor ingresa la tasa manualmente por hoy.");
                } else {
                    // Si es automático, solo poner placeholder y no molestar
                    input.placeholder = "Ingresar Tasa";
                }
                
                icon.className = 'fas fa-exclamation-triangle text-yellow-500';
            } finally {
                icon.classList.remove('spin');
                btn.disabled = false;
            }
        }

        // Inicialización
        document.getElementById('invoiceDate').valueAsDate = new Date();
        document.addEventListener('DOMContentLoaded', () => {
            loadSettings(); // Cargar datos guardados
            addItem();      // Agregar primera fila
            
            // Cargar tasa BCV automáticamente al abrir (modo silencioso: isManual = false)
            fetchBCV(false); 
        });

        function addItem() {
            const container = document.getElementById('items-container');
            const template = document.getElementById('item-template');
            const clone = template.content.cloneNode(true);
            
            const select = clone.querySelector('.service-select');
            predefinedServices.forEach((service, index) => {
                const option = document.createElement('option');
                option.value = index;
                option.textContent = `${service.name} (€${service.price})`; // Símbolo Euro
                select.appendChild(option);
            });

            container.appendChild(clone);
        }

        function fillItem(selectElement) {
            const index = selectElement.value;
            const card = selectElement.closest('.item-row');
            const descInput = card.querySelector('.item-desc');
            const priceInput = card.querySelector('.item-price');

            if (index !== "") {
                const service = predefinedServices[index];
                descInput.value = service.name;
                priceInput.value = service.price;
            } else {
                descInput.value = "";
                priceInput.value = "";
            }
            calculateTotal();
        }

        function removeItem(btn) {
            const container = document.getElementById('items-container');
            const row = btn.closest('.item-row');
            row.classList.add('opacity-0', 'transform', 'scale-95');
            setTimeout(() => {
                row.remove();
                if (container.children.length === 0) addItem();
                calculateTotal();
            }, 200);
        }

        function calculateTotal() {
            let total = 0;
            const rows = document.querySelectorAll('.item-row');
            rows.forEach(row => {
                const qty = row.querySelector('.item-qty').value || 0;
                const price = row.querySelector('.item-price').value || 0;
                total += (qty * price);
            });

            document.getElementById('subtotalDisplay').textContent = `€${total.toFixed(2)}`;
            document.getElementById('totalDisplay').textContent = `€${total.toFixed(2)}`;

            const rate = document.getElementById('exchangeRate').value;
            const bsContainer = document.getElementById('bsContainer');
            
            if (rate && rate > 0) {
                const totalBs = total * rate;
                document.getElementById('totalBsDisplay').textContent = `Bs ${totalBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
                bsContainer.classList.remove('hidden');
            } else {
                bsContainer.classList.add('hidden');
            }

            return { total, rate };
        }

        function generateWhatsAppLink() {
            const clientName = document.getElementById('clientName').value || "Cliente";
            const clientPhone = document.getElementById('clientPhone').value; 
            const invoiceInput = document.getElementById('invoiceNumber');
            const invoiceNum = invoiceInput.value;
            const notes = document.getElementById('notes').value;
            
            // Datos de Pago
            const payMobile = document.getElementById('payMobile').value;
            const payBank = document.getElementById('payBank').value;
            const payWally = document.getElementById('payWally').value;
            const payZinli = document.getElementById('payZinli').value;
            const payBinance = document.getElementById('payBinance').value;

            // --- AUTO-INCREMENTO DEL CONTROL ---
            try {
                let currentNum = parseInt(invoiceNum);
                if (!isNaN(currentNum)) {
                    let nextNum = currentNum + 1;
                    let formattedNext = nextNum.toString().padStart(Math.max(invoiceNum.length, 3), '0');
                    invoiceInput.value = formattedNext;
                }
            } catch (e) {
                console.log("No se pudo incrementar el control automáticamente");
            }
            saveSettings();


            // Formatear fecha
            const rawDate = document.getElementById('invoiceDate').value;
            const [year, month, day] = rawDate.split('-');
            const date = `${day}/${month}/${year}`;
            
            const { total, rate } = calculateTotal();
            
            // --- CONSTRUIR MENSAJE (EN EUROS) ---
            let msg = `🧾 *RECIBO DE PAGO - LEMUSTECH*\n`;
            msg += `🏢 *Lemustech Co.*\n`;
            msg += `📱 *Oficial:* +58 424-1353496\n`;
            msg += `────────────────\n`;
            msg += `📄 Control N°: ${invoiceNum}\n`; 
            msg += `📅 Fecha: ${date}\n`;
            msg += `👤 Cliente: *${clientName}*\n\n`;
            msg += `*DETALLE DEL SERVICIO:*\n`;

            let hasItems = false;
            const rows = document.querySelectorAll('.item-row');
            rows.forEach(row => {
                const desc = row.querySelector('.item-desc').value;
                const qty = row.querySelector('.item-qty').value;
                const price = row.querySelector('.item-price').value;
                if(desc && price) {
                    hasItems = true;
                    const subtotal = (price * qty).toFixed(2);
                    msg += `▪️ ${desc} (x${qty}) - €${subtotal}\n`; // Símbolo Euro
                }
            });

            if (!hasItems) return alert("Agrega al menos un servicio con precio 😅");

            msg += `\n────────────────\n`;
            msg += `💰 *TOTAL: €${total.toFixed(2)}*`; // Símbolo Euro

            if (rate && rate > 0) {
                const totalBs = total * rate;
                msg += `\n🇻🇪 *En Bolívares: Bs ${totalBs.toLocaleString('es-VE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}*\n`;
                msg += `_(Tasa: ${rate} Bs/€)_`; // Tasa en Euros
            }

            // Agregar Métodos de Pago si existen
            let hasPaymentMethods = payMobile || payBank || payWally || payZinli || payBinance;
            
            if (hasPaymentMethods) {
                msg += `\n\n💳 *MÉTODOS DE PAGO:*\n`;
                if(payMobile && payMobile !== defaultMobileData) msg += `🔹 *Pago Móvil:* ${payMobile}\n`;
                
                if(payBank) {
                    msg += `\n🏦 *TRANSFERENCIAS BANCARIAS:*\n${payBank}\n`;
                }
                
                if(payWally) msg += `🔹 *Wally:* ${payWally}\n`;
                if(payZinli) msg += `🔹 *Zinli:* ${payZinli}\n`;
                if(payBinance) msg += `🔹 *Binance:* ${payBinance}\n`;
            }

            // Agregar Notas si existen
            if (notes) {
                msg += `\n📝 *NOTA:* ${notes}`;
            }

            msg += `\n\n✅ _Gracias por su confianza._`;
            
            // Pie de página con Redes y Contacto
            msg += `\n────────────────\n`;
            msg += `🌐 www.lemustech.net\n`;
            msg += `📸 @Lemustech.ve\n`;
            msg += `📞 +58 424-1353496`;

            // Enviar
            let url = "";
            if (clientPhone) {
                url = `https://wa.me/${clientPhone}?text=${encodeURIComponent(msg)}`;
            } else {
                url = `https://wa.me/?text=${encodeURIComponent(msg)}`;
            }

            window.open(url, '_blank');
        }
    </script>
</body>
</html>