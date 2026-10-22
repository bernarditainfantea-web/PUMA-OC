// Conexión a Supabase. La "anon key" es pública por diseño: los datos los protege
// el login y las reglas de seguridad de la base (supabase/schema.sql), no esta clave.
window.CONFIG = {
  supabaseUrl: "TU_SUPABASE_URL",
  supabaseAnonKey: "TU_SUPABASE_ANON_KEY"
};
