# Requerir el núcleo de pagy
require "pagy"

# Extras necesarios para que funcione con Turbo y buscadores
require "pagy/extras/metadata"
require "pagy/extras/overflow" # Evita errores si buscas en una página que ya no existe

# Configuración por defecto (opcional)
Pagy::DEFAULT[:items] = 20
Pagy::DEFAULT[:overflow] = :last_page
