-- Independent Beta: crew directory CRUD, serialized with project saves.
create or replace function public.beta_save_crew(person jsonb) returns jsonb
language plpgsql security invoker set search_path=public as $$
declare snapshot jsonb; previous jsonb; saved jsonb; pid text; v int;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select data into snapshot from public.beta_workspaces where owner_id=auth.uid() for update;
  if not found then raise exception 'WORKSPACE_MISSING'; end if;
  if nullif(trim(person->>'name'),'') is null or person->>'kind' not in ('Interno','Freelancer favorito','Freelancer') then raise exception 'INVALID_CREW'; end if;
  if coalesce((person->>'dailyRate')::numeric,0)<0 or coalesce((person->>'overtimeRate')::numeric,0)<0 then raise exception 'INVALID_RATE'; end if;
  pid:=person->>'id';
  select p into previous from jsonb_array_elements(snapshot->'staff') p where p->>'id'=pid;
  if previous is null and nullif(pid,'') is not null then raise exception 'CREW_MISSING'; end if;
  if previous is not null then
    v:=coalesce((previous->>'version')::int,1);
    if coalesce((person->>'version')::int,1)<>v then raise exception 'VERSION_CONFLICT'; end if;
  else
    pid:=gen_random_uuid()::text;v:=0;
  end if;
  saved:=person||jsonb_build_object('id',pid,'version',v+1,'name',trim(person->>'name'));
  snapshot:=jsonb_set(snapshot,'{staff}',coalesce((select jsonb_agg(p) from jsonb_array_elements(snapshot->'staff') p where p->>'id'<>pid),'[]'::jsonb)||jsonb_build_array(saved));
  update public.beta_workspaces set data=snapshot,updated_at=now() where owner_id=auth.uid();
  return saved;
end $$;
revoke execute on function public.beta_save_crew(jsonb) from public,anon;
grant execute on function public.beta_save_crew(jsonb) to authenticated;
