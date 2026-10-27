-- Control Fill Rate · esquema de base de datos (Supabase / Postgres)
-- Acceso: solo los correos registrados en usuarios_permitidos ven o cambian datos.
--   lector  → solo mira
--   editor  → sube archivos, gestiona OCs y notas de crédito
--   admin   → además elimina notas de crédito y administra usuarios

create table if not exists usuarios_permitidos (
  email  text primary key,
  rol    text not null default 'editor' check (rol in ('lector','editor','admin')),
  nombre text,
  creado timestamptz not null default now()
);

create or replace function mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select rol from usuarios_permitidos where email = lower(auth.jwt() ->> 'email')
$$;

create table if not exists cargas (
  id        uuid primary key default gen_random_uuid(),
  tipo      text not null check (tipo in ('sugerido','oc','despacho')),
  cliente   text,
  clientes  jsonb not null default '[]',
  ocs       jsonb not null default '[]',
  oc_lbl    text,
  fecha     date,
  vence     date,
  archivo   text,
  filas     int  not null default 0,
  unidades  numeric not null default 0,
  monto     numeric not null default 0,
  creado    timestamptz not null default now(),
  creado_por text default (auth.jwt() ->> 'email')
);

-- v2: cada OC puede pertenecer a un sugerido
alter table cargas add column if not exists sugerido_id uuid references cargas(id) on delete set null;

-- v4: despacho FACTURADO (último paso, base del fill rate). Se guarda con tipo 'packing' por historia;
--     el tipo 'despacho' es el despacho CREADO (export SAP). Flujo: sugerido → oc → despacho creado → facturado.
alter table cargas drop constraint if exists cargas_tipo_check;
alter table cargas add constraint cargas_tipo_check check (tipo in ('sugerido','oc','despacho','packing'));

create table if not exists carga_filas (
  id          bigint generated always as identity primary key,
  carga_id    uuid not null references cargas(id) on delete cascade,
  cliente     text not null,
  oc          text not null default '',
  sku         text not null,
  talla       text not null,
  q           numeric not null,
  precio      numeric not null default 0,
  descripcion text
);
create index if not exists carga_filas_carga on carga_filas(carga_id);

create table if not exists estado_oc (
  cliente     text not null,
  oc          text not null,
  cerrada     boolean not null default false,
  actualizado timestamptz not null default now(),
  primary key (cliente, oc)
);

create table if not exists notas_credito (
  id          uuid primary key default gen_random_uuid(),
  numero      text,
  cliente     text not null,
  oc          text not null default '',
  fecha       date,
  motivo      text not null,
  estado      text not null check (estado in ('Solicitada','En revisión','Aprobada','Emitida','Aplicada','Rechazada')),
  monto       numeric not null check (monto > 0),
  lineas      jsonb not null default '[]',
  notas       text,
  historial   jsonb not null default '[]',
  creado      timestamptz not null default now(),
  actualizado timestamptz not null default now(),
  creado_por  text default (auth.jwt() ->> 'email')
);

-- v3: una nota de crédito puede ir a una OC o al sugerido completo
alter table notas_credito add column if not exists sugerido_id uuid references cargas(id) on delete set null;

create table if not exists config (
  clave text primary key,
  valor jsonb not null
);

-- Seguridad por filas
alter table usuarios_permitidos enable row level security;
alter table cargas        enable row level security;
alter table carga_filas   enable row level security;
alter table estado_oc     enable row level security;
alter table notas_credito enable row level security;
alter table config        enable row level security;

do $$
declare t text;
begin
  foreach t in array array['cargas','carga_filas','estado_oc','notas_credito','config'] loop
    execute format('drop policy if exists leer on %I', t);
    execute format('drop policy if exists crear on %I', t);
    execute format('drop policy if exists editar on %I', t);
    execute format('drop policy if exists borrar on %I', t);
    execute format('create policy leer   on %I for select to authenticated using (mi_rol() is not null)', t);
    execute format('create policy crear  on %I for insert to authenticated with check (mi_rol() in (''editor'',''admin''))', t);
    execute format('create policy editar on %I for update to authenticated using (mi_rol() in (''editor'',''admin'')) with check (mi_rol() in (''editor'',''admin''))', t);
  end loop;
end $$;

-- Eliminar: editores pueden borrar notas de crédito y reemplazar OCs; solo admin borra el resto
drop policy if exists borrar on cargas;
drop policy if exists borrar on carga_filas;
drop policy if exists borrar on notas_credito;
drop policy if exists borrar on estado_oc;
drop policy if exists borrar on config;
create policy borrar on cargas        for delete to authenticated using (mi_rol() in ('editor','admin'));
create policy borrar on carga_filas   for delete to authenticated using (mi_rol() in ('editor','admin'));
create policy borrar on notas_credito for delete to authenticated using (mi_rol() = 'admin');
create policy borrar on estado_oc     for delete to authenticated using (mi_rol() = 'admin');
create policy borrar on config        for delete to authenticated using (mi_rol() = 'admin');

drop policy if exists ver_usuarios on usuarios_permitidos;
drop policy if exists admin_usuarios on usuarios_permitidos;
create policy ver_usuarios   on usuarios_permitidos for select to authenticated using (mi_rol() is not null);
create policy admin_usuarios on usuarios_permitidos for all    to authenticated using (mi_rol() = 'admin') with check (mi_rol() = 'admin');

-- Cambios en vivo para que todos vean lo mismo sin recargar
do $$ begin
  begin alter publication supabase_realtime add table cargas;        exception when others then null; end;
  begin alter publication supabase_realtime add table estado_oc;     exception when others then null; end;
  begin alter publication supabase_realtime add table notas_credito; exception when others then null; end;
  begin alter publication supabase_realtime add table config;        exception when others then null; end;
end $$;
