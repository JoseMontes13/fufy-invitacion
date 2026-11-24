-- ============================================
-- Tabla de confirmaciones de invitación
-- ============================================

create table if not exists public.invitados (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  acompanantes integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),

  constraint invitados_acompanantes_check
    check (acompanantes between 0 and 20),

  constraint invitados_nombre_check
    check (char_length(btrim(nombre)) > 0)
);

-- Habilitar Row Level Security
alter table public.invitados enable row level security;

-- Reiniciar políticas existentes para evitar permisos duplicados
drop policy if exists "anon puede insertar confirmaciones" on public.invitados;
drop policy if exists "usuario dueño puede consultar" on public.invitados;
drop policy if exists "ningún usuario puede actualizar" on public.invitados;
drop policy if exists "ningún usuario puede eliminar" on public.invitados;

-- Permitir únicamente INSERT a usuarios anónimos
create policy "anon puede insertar confirmaciones"
on public.invitados
for insert
to anon
with check (true);

-- ============================================
-- SELECT exclusivo para el usuario dueño
-- ============================================

-- REEMPLAZAR_EL_UID_DEL_DUEÑO es el UID del usuario encontrado
-- en Authentication > Users dentro del panel de Supabase.
-- Debe conservarse el tipo UUID.
create policy "usuario dueño puede consultar"
on public.invitados
for select
to authenticated
using (
  auth.uid() = '50e59e5e-f928-44c9-8b74-c856b165cca2'::uuid
);

-- No se crean políticas para UPDATE ni DELETE.
-- Como RLS está activo, los usuarios anónimos no podrán ejecutar
-- estas operaciones. Tampoco existe una política SELECT para anon.

-- Permisos explícitos de tabla
revoke all on table public.invitados from anon, authenticated;

grant insert on table public.invitados to anon;
grant select on table public.invitados to authenticated;

-- ============================================
-- Función pública para contar personas
-- ============================================

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

-- La función no acepta parámetros y devuelve solo un número.
-- No puede exponer nombres ni otros datos individuales.
revoke all on function public.contar_invitados() from public;
grant execute on function public.contar_invitados() to anon, authenticated;