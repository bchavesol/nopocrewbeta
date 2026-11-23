-- Keep cross-project conflict checks atomic with the project save.
create or replace function public.beta_save_project(project jsonb) returns jsonb
language plpgsql security invoker set search_path=public as $$
declare snapshot jsonb; old_project jsonb; saved jsonb; pid text; old_version int; audit jsonb; ph jsonb; fn jsonb; person text;
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
  -- Check conflicts under the same row lock as the write: concurrent saves cannot bypass it.
  for ph in select value from jsonb_array_elements(project->'phases') loop
    for fn in select value from jsonb_array_elements(ph->'functions') loop
      for person in select jsonb_array_elements_text(fn->'crew') loop
        if not exists (
          select 1 from jsonb_array_elements(coalesce(old_project->'phases','[]'::jsonb)) oldph,
          lateral jsonb_array_elements(oldph->'functions') oldfn
          where oldph->>'id'=ph->>'id' and oldph->>'start'=ph->>'start' and oldph->>'end'=ph->>'end'
          and (oldfn->'crew') ? person
        ) and exists (
          select 1 from jsonb_array_elements((select coalesce(jsonb_agg(p),'[]'::jsonb) from jsonb_array_elements(snapshot->'projects') p where p->>'id' is distinct from project->>'id') || jsonb_build_array(project)) other,
          lateral jsonb_array_elements(other->'phases') otherph,
          lateral jsonb_array_elements(otherph->'functions') otherfn
          where other->>'status'<>'Cancelado' and otherph->>'id'<>ph->>'id'
          and otherph->>'start'<ph->>'end' and ph->>'start'<otherph->>'end'
          and (otherfn->'crew') ? person
        ) then raise exception 'CREW_CONFLICT'; end if;
      end loop;
    end loop;
  end loop;
  audit := audit || jsonb_build_array(jsonb_build_object('at',now(),'author','Administrador Beta','action',case when old_version=0 then 'Projeto criado' else 'Projeto atualizado' end));
  saved := project || jsonb_build_object('id',pid,'version',old_version+1,'history',audit);
  snapshot := jsonb_set(snapshot,'{projects}', coalesce((select jsonb_agg(p) from jsonb_array_elements(snapshot->'projects') p where p->>'id'<>pid),'[]'::jsonb) || jsonb_build_array(saved));
  update public.beta_workspaces set data=snapshot,updated_at=now() where owner_id=auth.uid();
  return saved;
end $$;
