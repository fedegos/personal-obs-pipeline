# db/seeds.rb
# sentimiento: una de Transaction::SENTIMIENTOS.keys => Necesario, Deseo, Inversión, Ahorro, Hormiga

def create_rule(name, pattern, priority, parent = nil, sentimiento: nil)
  CategoryRule.find_or_create_by!(name: name) do |r|
    r.pattern = pattern
    r.priority = priority
    r.parent = parent
    r.sentimiento = sentimiento
  end
end

puts "🌱 Sembrando motor de reglas Audit-X (Versión Unificada 2026)..."

# --- 1. SUPERMERCADO Y ALIMENTOS (Necesario) ---
super_market = create_rule('Supermercado', 'SUPERDIA|DIA%|COTO|JUMBO|DISCO|YULIANGHE|DEHUCHEN|YANGJIANLI|VERDULERIA|LOSCISNES', 10, nil, sentimiento: 'Necesario')
create_rule('Coto', 'COTO', 25, super_market)
create_rule('Dia', 'SUPERDIA|DIA%', 25, super_market)
create_rule('Chinos', 'YULIANGHE|DEHUCHEN|YANGJIANLI', 25, super_market)

# --- 2. VEHÍCULO Y MOVILIDAD (Necesario) ---
auto = create_rule('Vehículo', 'STRIXAUTO|AXIONENERGY|BRAGADO SA|AUSA|AUOESTE', 10, nil, sentimiento: 'Necesario')
create_rule('Peajes', 'AUSA|AUOESTE', 25, auto)
create_rule('Seguridad/Seguimiento', 'STRIXAUTO', 25, auto)
create_rule('Combustible', 'AXIONENERGY', 25, auto)
create_rule('Mecánica', 'BRAGADO SA', 25, auto)

# --- 3. TRANSPORTE PÚBLICO Y APPS (Necesario) ---
trans_pub = create_rule('Transporte Público', 'EMOVA|SUBE|VIAJES', 15, nil, sentimiento: 'Necesario')
create_rule('Subte', 'EMOVA', 25, trans_pub)
create_rule('SUBE', 'SUBE|VIAJES', 25, trans_pub)

apps_mov = create_rule('Apps de Movilidad', 'UBER|CABIFY', 15, nil, sentimiento: 'Necesario')
create_rule('Uber', 'UBER', 25, apps_mov)

# --- 4. HOGAR, BAZAR Y TECH (Necesario) ---
hogar = create_rule('Hogar', 'BAZAR|METRODETELA|FERRETERIA|JUSTARGENTINA|TEMANUN|KITCHEN|AUTHOGAR|PARDO|BIDCOM|DATASOFT|TIENDAS DIG', 10, nil, sentimiento: 'Necesario')
create_rule('Electro y Tech', 'BIDCOM|DATASOFT|TIENDAS DIG|PARDO', 25, hogar)
create_rule('Bazar y Ferretería', 'BAZAR|GASTROPRECIO|FERRETERIA', 25, hogar)
create_rule('Telas y Deco', 'METRODETELA|TEMANUN', 25, hogar)

# --- 5. INDUMENTARIA Y DEPORTES (Deseo) ---
moda = create_rule('Indumentaria', 'NOHARKIDS|PIURAPIMA|JUVIA|ETIQUETA NEGRA|JAZMIN CHEBAR|UNDERARMOUR|GRIMOLDI|OLD BRIDGE|OPEN SPORT|PUNTO DEPORT', 10, nil, sentimiento: 'Deseo')
create_rule('Ropa Adultos', 'ETIQUETA NEGRA|JAZMIN CHEBAR|EL BURGUES', 25, moda)
create_rule('Niños/Bebés', 'NOHARKIDS|PIURAPIMA|JUVIA|MACROBABY', 25, moda)
create_rule('Deportes', 'UNDERARMOUR|OPEN SPORT|PUNTO DEPORT', 25, moda)
create_rule('Calzado', 'GRIMOLDI|OLD BRIDGE', 25, moda)

# --- 6. GASTRONOMÍA Y DELIVERY (Hormiga / Deseo) ---
gastro = create_rule('Gastronomía', 'CAFEMARTINEZ|ATALAYA|SORIABAR|DELICIAS|BURGUES|ELFOGONAR|PEREZ H|RAPPI', 10, nil, sentimiento: 'Hormiga')
create_rule('Café', 'CAFEMARTINEZ|WHOOPIES|DELICIAS', 25, gastro, sentimiento: 'Hormiga')
create_rule('Delivery', 'RAPPI', 25, gastro, sentimiento: 'Hormiga')
create_rule('Restaurantes', 'SORIABAR|ELFOGONAR|EL BURGUES', 25, gastro, sentimiento: 'Deseo')

# --- 7. OCIO, CULTURA Y REGALOS (Deseo) ---
ocio = create_rule('Ocio y Cultura', 'HOYTS|MUBI|CUSPIDE|YENNY|MONOBLOCK', 10, nil, sentimiento: 'Deseo')
create_rule('Librerías', 'YENNY|CUSPIDE', 25, ocio)
create_rule('Streaming', 'MUBI', 25, ocio)
create_rule('Cine/Salidas', 'HOYTS', 25, ocio)
create_rule('Diseño/Regalos', 'MONOBLOCK|PATAGONIA SHOWROOM', 25, ocio)

# --- 8. SERVICIOS, SALUD Y SEGUROS (Necesario / Inversión) ---
servicios = create_rule('Servicios y Salud', 'SPORTCLUB|BIGG|MEDALLAPERROS|AMITIE|O\.S\.P\.O\.C\.E|SANCRISTOBAL', 10, nil, sentimiento: 'Necesario')
create_rule('Gimnasio', 'SPORTCLUB|BIGG', 25, servicios)
create_rule('Mascotas', 'MEDALLAPERROS', 25, servicios)
create_rule('Seguros', 'SANCRISTOBAL', 25, servicios)
create_rule('Obra Social', 'O\.S\.P\.O\.C\.E', 25, servicios)
create_rule('Salud/Celíacos', 'AMITIE', 25, servicios)

# --- 9. VIAJES (Inversión) ---
viajes = create_rule('Viajes', 'DESPEGAR', 10, nil, sentimiento: 'Inversión')

# --- 10. MARKETPLACE (Ahorro / compras planeadas) ---
mkt = create_rule('Marketplace', 'MERCADOLIBRE|MERCADOPAGO|PROVINCIA COMPRAS', 5, nil, sentimiento: 'Ahorro')

puts "✅ #{CategoryRule.count} reglas jerárquicas sembradas exitosamente."
