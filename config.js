// Conexión a Supabase. La clave "publishable" es pública por diseño: los datos los protege
// el login y las reglas de seguridad de la base (supabase/schema.sql), no esta clave.
window.CONFIG = {
  supabaseUrl: "https://smeppkvogtahhvtxpjut.supabase.co",
  supabaseAnonKey: "sb_publishable_5b4SDeOwJBI3vm7_wbWhEQ_kU_Nj8Ti"
};
