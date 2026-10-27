# Control Fill Rate · PUMA

Plataforma web para seguir el ciclo **sugerido → orden de compra → despacho → nota de crédito**, con fill rate por SKU y talla, alertas automáticas, historial de OCs y sugeridos, y gestión de notas de crédito.

- **Sitio:** GitHub Pages, gratis (archivos estáticos: `index.html` + `config.js`).
- **Datos y login:** Supabase (Postgres + autenticación). Los datos **nunca** quedan en este repositorio.

## Puesta en marcha (gratis, una sola vez)

Todo se crea con el **correo de PUMA**, no con cuentas personales.

### 1. Base de datos (Supabase, plan Free)
1. Crea una cuenta en [supabase.com](https://supabase.com) con tu correo de PUMA y luego un **New project** en la región **South America (São Paulo)**. Guarda la contraseña de la base de datos.
2. En **SQL Editor → New query**, pega todo `supabase/schema.sql` y pon **Run**.
3. En **Authentication → Sign In / Providers → Email**, desactiva **Allow new users to sign up**.
4. En **Project Settings → API** copia la **Project URL** y la **anon public key** y pégalas en `config.js`.

### 2. Usuarios (tú y tu equipo)
Para cada persona:
1. **Authentication → Users → Add user → Create new user**: correo de PUMA, contraseña y *Auto confirm user*.
2. En **SQL Editor**:
   ```sql
   insert into usuarios_permitidos (email, rol, nombre)
   values ('nombre.apellido@puma.com', 'admin', 'Nombre Apellido');
   ```
   Roles:
   - `lector`: solo mira.
   - `editor`: sube archivos y gestiona OCs y notas de crédito.
   - `admin`: además elimina notas de crédito y administra usuarios.

### 2b. Crear usuarios desde la página (pestaña *Usuarios*, solo admin)
Después del primer admin (creado con los pasos de arriba), los demás usuarios se crean desde la página. Para eso hay que publicar **una vez** la función `usuarios`:
1. En Supabase: **Edge Functions → Deploy a new function → Via Editor**.
2. Nombre: `usuarios`. Pega todo el contenido de `supabase/functions/usuarios/index.ts` y pon **Deploy**. Deja activado **Verify JWT**.
3. Listo: en la página aparece la pestaña **Usuarios** para los admin. Ahí se crea el usuario (correo, rol y clave temporal), se cambia el rol o se elimina.

La función usa la clave `service_role`, que Supabase le entrega sola en su servidor. **Nunca pongas esa clave en `config.js` ni en la página**: daría acceso total a la base a cualquiera.

### 3. Publicar la página (GitHub Pages, gratis)
1. Crea una cuenta en [github.com](https://github.com) con tu correo de PUMA.
2. **New repository** → nombre `puma-oc` → **Public** (Pages gratis exige repo público; el código no contiene datos) → Create.
3. **Add file → Upload files** y arrastra `index.html`, `config.js`, `README.md` y la carpeta `supabase`. Luego **Commit changes**.
4. **Settings → Pages → Source: Deploy from a branch → Branch: main / (root) → Save**.
5. En 1 o 2 minutos aparece el link en esa misma pantalla: `https://<tu-usuario>.github.io/puma-oc/`.

### Para tener en cuenta
- **Plan gratis de Supabase:** si nadie entra en 7 días, el proyecto se pausa. No se pierde nada: se reactiva desde el dashboard con un clic.
- **Respaldo:** usa el botón *Descargar Excel* una vez al mes.
- **Continuidad:** invita a una persona de tu equipo como Owner en Supabase (**Organization → Team**) y como colaboradora en GitHub, para que el sistema no dependa solo de ti.

## Uso
Todo se organiza por **sugerido**: el sugerido y las OCs que nacen de él, con sus despachos.
1. **Sugeridos → Nuevo sugerido:** elige el cliente (MELI 1P o MELI 3P), ponle nombre y sube el Excel del sugerido. El formato de sugerido PUMA (hoja con "Cod", "SUGERIDO CARGA UN." y "CURVAS A CARGAR") se lee solo.
2. **Dentro del sugerido → Cargar OCs:** arrastra una o varias OCs. Quedan asociadas al sugerido.
3. **Dentro de cada OC → Cargar packing lists:** sube lo que PUMA envía (packing list). Cada archivo trae el N° de OC y se cruza por OC + SKU + talla.
4. **Dentro de cada OC → Cargar despachos:** sube el despacho ingresado por el cliente. El **fill rate se calcula sobre lo ingresado**; la diferencia packing list − ingresado se muestra como "PL sin ingresar" (en tránsito o diferencia de recepción).
5. **El detalle del sugerido** muestra el avance sugerido → OC → packing list → ingresado, por OC, SKU y talla.
6. **Resumen / Por SKU / Por talla / Órdenes de compra:** fill rate y alertas de todas las OCs.
7. **Notas de crédito:** flujo Solicitada → En revisión → Aprobada → Emitida → Aplicada (o Rechazada).

## Estructura
```
index.html                 la aplicación completa
config.js                  URL y anon key de Supabase
supabase/schema.sql        tablas, reglas de seguridad y cambios en vivo
```
