// Edge Function "usuarios": crea y elimina usuarios desde la página, solo para admins.
// Usa la clave service_role, que vive solo en el servidor de Supabase (nunca en la página).
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const ROLES = ["lector", "editor", "admin"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  // Quién llama: su sesión tiene que ser válida y su rol, admin
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: who, error: whoErr } = await admin.auth.getUser(token);
  if (whoErr || !who?.user?.email) return json({ error: "Sesión inválida. Vuelve a entrar." }, 401);
  const yo = who.user.email.toLowerCase();
  const { data: permiso } = await admin.from("usuarios_permitidos").select("rol").eq("email", yo).maybeSingle();
  if (permiso?.rol !== "admin") return json({ error: "Solo un admin puede administrar usuarios." }, 403);

  let body: { accion?: string; email?: string; password?: string; rol?: string; nombre?: string };
  try { body = await req.json(); } catch { return json({ error: "Solicitud inválida." }, 400); }
  const email = String(body.email || "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "Correo inválido." }, 400);

  const buscar = async (e: string) => {
    for (let page = 1; page <= 20; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) throw error;
      const u = data.users.find((x) => (x.email || "").toLowerCase() === e);
      if (u || data.users.length < 200) return u || null;
    }
    return null;
  };

  try {
    if (body.accion === "crear") {
      const password = String(body.password || "");
      const rol = String(body.rol || "");
      if (password.length < 10) return json({ error: "La clave debe tener al menos 10 caracteres." }, 400);
      if (!ROLES.includes(rol)) return json({ error: "Rol inválido." }, 400);
      // Si la cuenta ya existía (por ejemplo, se le quitó el acceso antes), se le pone la clave nueva
      const existe = await buscar(email);
      if (existe) {
        const { error } = await admin.auth.admin.updateUserById(existe.id, { password, email_confirm: true });
        if (error) throw error;
      } else {
        const { error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
        if (error) throw error;
      }
      const { error } = await admin.from("usuarios_permitidos")
        .upsert({ email, rol, nombre: String(body.nombre || "").trim() || null });
      if (error) throw error;
      return json({ ok: true, reactivado: !!existe });
    }

    if (body.accion === "eliminar") {
      if (email === yo) return json({ error: "No puedes eliminar tu propio usuario." }, 400);
      const { error } = await admin.from("usuarios_permitidos").delete().eq("email", email);
      if (error) throw error;
      const u = await buscar(email);
      if (u) { const { error: e2 } = await admin.auth.admin.deleteUser(u.id); if (e2) throw e2; }
      return json({ ok: true });
    }

    return json({ error: "Acción desconocida." }, 400);
  } catch (e) {
    return json({ error: (e as Error).message || "Error inesperado." }, 500);
  }
});
