-- Same national holiday calculation used by the calendar; pure function, no data access.
create or replace function public.beta_rest_day(dt date) returns boolean language plpgsql immutable set search_path=pg_catalog,public as $$
declare y int:=extract(year from dt);a int;b int;c int;d int;e int;f int;g int;h int;i int;k int;l int;m int;easter date;
begin
 if extract(isodow from dt) in(6,7) or to_char(dt,'MM-DD') in('01-01','04-25','05-01','06-10','08-15','10-05','11-01','12-01','12-08','12-25') then return true;end if;
 a:=y%19;b:=y/100;c:=y%100;d:=b/4;e:=b%4;f:=(b+8)/25;g:=(b-f+1)/3;h:=(19*a+b-d-g+15)%30;i:=c/4;k:=c%4;l:=(32+2*e+2*i-h-k)%7;m:=(a+11*h+22*l)/451;easter:=make_date(y,(h+l-7*m+114)/31,(h+l-7*m+114)%31+1);
 return dt in(easter-2,easter,easter+60);
end $$;
revoke all on function public.beta_rest_day(date) from public,anon;
grant execute on function public.beta_rest_day(date) to authenticated;
create or replace function public.beta_save_availability(mark jsonb) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare snapshot jsonb;records jsonb;previous jsonb;saved jsonb;person jsonb;mid text;v int;d date;lastday date;audit jsonb;removing boolean;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select data into snapshot from public.beta_workspaces where owner_id=auth.uid() for update;
 if not found then raise exception 'WORKSPACE_MISSING';end if;
 records:=snapshot->'availability';
 if jsonb_typeof(records) is distinct from 'array' then
  select coalesce(jsonb_agg(a||jsonb_build_object('id','nopo-availability-'||(a->>'id'),'sourceId',a->'id','personId',p->>'id','version',1)),'[]'::jsonb) into records
  from jsonb_array_elements(coalesce(snapshot#>'{sourceArchive,payload,availability}','[]'::jsonb)) a
  join jsonb_array_elements(snapshot->'staff') p on p->>'sourceId'=a->>'personId';
 end if;
 mid:=nullif(mark->>'id','');
 select a into previous from jsonb_array_elements(records) a where a->>'id'=mid;
 if previous is null and mid is not null then raise exception 'AVAILABILITY_MISSING';end if;
 if previous is not null then
  v:=coalesce((previous->>'version')::int,1);if (mark->>'version')::int is distinct from v then raise exception 'VERSION_CONFLICT';end if;
 else mid:=gen_random_uuid()::text;v:=0;end if;
 removing:=mark->>'deletedAt' is not null;
 if removing then
  if previous is null then raise exception 'AVAILABILITY_MISSING';end if;
  saved:=previous||jsonb_build_object('deletedAt',now());
 else
  select p into person from jsonb_array_elements(snapshot->'staff') p where p->>'id'=mark->>'personId';
  if person is null or (previous is null and person->>'active'='false') then raise exception 'AVAILABILITY_RULE';end if;
  if mark->>'reason' not in('Folga','Férias','Armazém','Preparação','Baixa médica','Indisponível') or mark->>'reason' is null then raise exception 'AVAILABILITY_RULE';end if;
  if person->>'kind'<>'Interno' and mark->>'reason'<>'Indisponível' then raise exception 'AVAILABILITY_RULE';end if;
  if coalesce(mark->>'start','') !~ '^\d{4}-\d{2}-\d{2}$' or coalesce(mark->>'end','') !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'INVALID_AVAILABILITY';end if;
  d:=(mark->>'start')::date;lastday:=(mark->>'end')::date;
  if lastday<d or lastday-d>366 or length(coalesce(mark->>'notes',''))>2000 or jsonb_typeof(mark->'approved') is distinct from 'boolean' then raise exception 'INVALID_AVAILABILITY';end if;
  if person->>'kind'='Interno' and mark->>'reason'='Indisponível' then
   while d<=lastday loop if not public.beta_rest_day(d) then raise exception 'AVAILABILITY_RULE';end if;d:=d+1;end loop;
  end if;
  saved:=jsonb_build_object('personId',mark->>'personId','start',mark->>'start','end',mark->>'end','reason',mark->>'reason','notes',coalesce(mark->>'notes',''),'approved',case when mark->>'reason'='Folga' then (mark->>'approved')::boolean else false end,'approvedAt',case when mark->>'reason'='Folga' and (mark->>'approved')::boolean then to_jsonb(now()) else 'null'::jsonb end,'createdBy',coalesce(previous->>'createdBy',auth.jwt()->>'email','Administrador Beta'),'deletedAt',null);
 end if;
 audit:=coalesce(previous->'history','[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'author',coalesce(auth.jwt()->>'email','Administrador Beta'),'action',case when removing then 'Marcação apagada' when v=0 then 'Marcação criada' else 'Marcação atualizada' end));
 saved:=saved||jsonb_build_object('id',mid,'version',v+1,'history',audit);
 records:=coalesce((select jsonb_agg(a) from jsonb_array_elements(records) a where a->>'id'<>mid),'[]'::jsonb)||jsonb_build_array(saved);
 update public.beta_workspaces set data=jsonb_set(snapshot,'{availability}',records),updated_at=now() where owner_id=auth.uid();
 return saved;
end $$;
revoke all on function public.beta_save_availability(jsonb) from public,anon;
grant execute on function public.beta_save_availability(jsonb) to authenticated;
