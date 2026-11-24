-- Configuracion idempotente para las confirmaciones de la invitacion.
-- Reemplaza REEMPLAZA_CON_UID_DEL_DUENO por el User UID del propietario
-- en la politica de SELECT antes de ejecutar este archivo.
--
-- Este script no elimina ni reinicia los invitados existentes.

create table if not exists public.invitados (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  acompanantes integer not null default 0,
  created_at timestamptz not null default now(),
  constraint invitados_acompanantes_check
    check (acompanantes between 0 and 20),
  constraint invitados_nombre_check
    check (char_length(btrim(nombre)) > 0)
);

alter table public.invitados enable row level security;

grant usage on schema public to anon, authenticated;

-- Se reinician las politicas de esta tabla para asegurar que no queden
-- permisos de SELECT, UPDATE o DELETE mas amplios que los especificados.
do $$
declare
  existing_policy record;
begin
  for existing_policy in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'invitados'
  loop
    execute format(
      'drop policy %I on public.invitados',
      existing_policy.policyname
    );
  end loop;
end
$$;

create policy "anon puede insertar confirmaciones"
on public.invitados
for insert
to anon
with check (
  char_length(btrim(nombre)) > 0
  and acompanantes between 0 and 20
);

-- Sin reemplazar el marcador, el script termina correctamente, pero ningun
-- usuario autenticado podra leer la lista hasta configurar el UID correcto.
create policy "solo el dueño puede consultar invitados"
on public.invitados
for select
to authenticated
using (
  auth.uid()::text = '50e59e5e-f928-44c9-8b74-c856b165cca2'
);

revoke all on table public.invitados from public, anon, authenticated;
grant insert on table public.invitados to anon;
grant select on table public.invitados to authenticated;

create or replace function public.contar_invitados()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    sum(1 + i.acompanantes)::bigint,
    0::bigint
  )
  from public.invitados as i;
$$;

revoke all on function public.contar_invitados() from public, anon, authenticated;
grant execute on function public.contar_invitados() to anon, authenticated;

-- Actualiza la caché de esquema que usa la API REST de Supabase para RPC.
notify pgrst, 'reload schema';

-- Prueba manual opcional en el SQL Editor:
-- select public.contar_invitados();
