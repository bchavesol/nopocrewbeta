-- Independent Beta storage. This migration is applied only to the NEW Beta backend.
create table if not exists public.beta_workspaces (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.beta_workspaces enable row level security;
revoke all on public.beta_workspaces from anon;
grant select, insert, update on public.beta_workspaces to authenticated;
create policy "beta own read" on public.beta_workspaces for select to authenticated using(owner_id=auth.uid());
create policy "beta own insert" on public.beta_workspaces for insert to authenticated with check(owner_id=auth.uid());
create policy "beta own update" on public.beta_workspaces for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());

create or replace function public.beta_load(seed jsonb) returns jsonb
language plpgsql security invoker set search_path=public as $$
declare result jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if jsonb_typeof(seed->'projects') <> 'array' or jsonb_typeof(seed->'staff') <> 'array' then raise exception 'INVALID_SEED'; end if;
  insert into public.beta_workspaces(owner_id,data) values(auth.uid(),seed) on conflict(owner_id) do nothing;
  select data into result from public.beta_workspaces where owner_id=auth.uid();
  return result;
end $$;

create or replace function public.beta_save_project(project jsonb) returns jsonb
language plpgsql security invoker set search_path=public as $$
declare snapshot jsonb; old_project jsonb; saved jsonb; pid text; old_version int; audit jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select data into snapshot from public.beta_workspaces where owner_id=auth.uid() for update;
  if not found then raise exception 'WORKSPACE_MISSING'; end if;
  if nullif(trim(project->>'name'),'') is null or nullif(trim(project->>'reference'),'') is null then raise exception 'INVALID_PROJECT'; end if;
  if jsonb_typeof(project->'phases') <> 'array' then raise exception 'INVALID_PROJECT'; end if;
  if (project->>'end')::date < (project->>'start')::date then raise exception 'INVALID_DATES'; end if;
  pid := project->>'id';
  select p into old_project from jsonb_array_elements(snapshot->'projects') p where p->>'id'=pid;
  if old_project is null and nullif(pid,'') is not null then raise exception 'PROJECT_MISSING'; end if;
  if exists(select 1 from jsonb_array_elements(snapshot->'projects') p where p->>'reference'=trim(project->>'reference') and p->>'id' is distinct from pid) then raise exception 'DUPLICATE_REFERENCE'; end if;
  if old_project is not null then
    old_version := (old_project->>'version')::int;
    if (project->>'version')::int is distinct from old_version then raise exception 'VERSION_CONFLICT'; end if;
    audit := coalesce(old_project->'history','[]'::jsonb);
  else
    pid := gen_random_uuid()::text; old_version := 0; audit := '[]'::jsonb;
  end if;
  audit := audit || jsonb_build_array(jsonb_build_object('at',now(),'author','Administrador Beta','action',case when old_version=0 then 'Projeto criado' else 'Projeto atualizado' end));
  saved := project || jsonb_build_object('id',pid,'version',old_version+1,'history',audit);
  snapshot := jsonb_set(snapshot,'{projects}', coalesce((select jsonb_agg(p) from jsonb_array_elements(snapshot->'projects') p where p->>'id'<>pid),'[]'::jsonb) || jsonb_build_array(saved));
  update public.beta_workspaces set data=snapshot,updated_at=now() where owner_id=auth.uid();
  return saved;
end $$;
revoke execute on function public.beta_load(jsonb), public.beta_save_project(jsonb) from public,anon;
grant execute on function public.beta_load(jsonb), public.beta_save_project(jsonb) to authenticated;
