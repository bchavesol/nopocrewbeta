-- Permanent reusable codes and sessions until administrative revocation or logout.
create or replace function public.beta_issue_access(p_person text,p_digest text) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare snapshot jsonb; person jsonb; expiry timestamptz:='infinity'::timestamptz;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if p_digest !~ '^[0-9a-f]{64}$' then raise exception 'ACCESS_INVALID';end if;
 select data into snapshot from public.beta_workspaces where owner_id=auth.uid() for update;
 select p into person from jsonb_array_elements(snapshot->'staff') p where p->>'id'=p_person;
 if person is null or coalesce((person->>'accessEnabled')::boolean,false)=false or coalesce((person->>'active')::boolean,true)=false or nullif(trim(person->>'email'),'') is null then raise exception 'ACCESS_DISABLED';end if;
 update public.beta_crew_sessions set revoked=true where access_id in(select id from public.beta_access_codes where owner_id=auth.uid() and person_id=p_person);
 update public.beta_access_codes set revoked=true where owner_id=auth.uid() and person_id=p_person;
 insert into public.beta_access_codes(owner_id,person_id,email,code_digest,valid_until) values(auth.uid(),p_person,lower(trim(person->>'email')),p_digest,expiry);
 return jsonb_build_object('name',person->>'name','email',lower(trim(person->>'email')),'expiresAt',expiry);
end $$;
revoke execute on function public.beta_issue_access(text,text) from public,anon;
grant execute on function public.beta_issue_access(text,text) to authenticated;

create or replace function public.beta_redeem_access(p_email text,p_digest text,p_session text) returns boolean
language plpgsql security definer set search_path=pg_catalog,public as $$
declare code public.beta_access_codes%rowtype;person jsonb;snapshot jsonb;
begin
 if p_digest !~ '^[0-9a-f]{64}$' or p_session !~ '^[0-9a-f]{64}$' then raise exception 'ACCESS_INVALID';end if;
 select * into code from public.beta_access_codes where email=lower(trim(p_email)) and code_digest=p_digest and not revoked and valid_until>now() for update;
 if not found then raise exception 'ACCESS_INVALID';end if;
 select data into snapshot from public.beta_workspaces where owner_id=code.owner_id;
 select p into person from jsonb_array_elements(snapshot->'staff') p where p->>'id'=code.person_id;
 if person is null or coalesce((person->>'accessEnabled')::boolean,false)=false or coalesce((person->>'active')::boolean,true)=false or lower(trim(person->>'email'))<>code.email then raise exception 'ACCESS_INVALID';end if;
 update public.beta_access_codes set redeemed=true where id=code.id;
 insert into public.beta_crew_sessions(token_digest,access_id,expires_at) values(p_session,code.id,'infinity'::timestamptz);
 return true;
end $$;
revoke execute on function public.beta_redeem_access(text,text,text) from public;
grant execute on function public.beta_redeem_access(text,text,text) to anon,authenticated;

create or replace function public.beta_guest_state(p_session text) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare code public.beta_access_codes%rowtype;person jsonb;snapshot jsonb;projects jsonb;
begin
 select a.* into code from public.beta_crew_sessions s join public.beta_access_codes a on a.id=s.access_id where s.token_digest=p_session and s.expires_at>now() and not s.revoked and not a.revoked;
 if not found then raise exception 'ACCESS_INVALID';end if;
 select data into snapshot from public.beta_workspaces where owner_id=code.owner_id;
 select p into person from jsonb_array_elements(snapshot->'staff') p where p->>'id'=code.person_id;
 if person is null or coalesce((person->>'accessEnabled')::boolean,false)=false or coalesce((person->>'active')::boolean,true)=false or lower(trim(person->>'email'))<>code.email then raise exception 'ACCESS_INVALID';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p->>'id','name',p->>'name','reference',p->>'reference','status',p->>'status','start',p->>'start','end',p->>'end','location',p->>'location','manager',p->>'manager','managerPhone',p->>'managerPhone','responsible',p->>'responsible','responsiblePhone',p->>'responsiblePhone','color','#2563eb','notes','','transport','[]'::jsonb,'expenses','[]'::jsonb,'documents','[]'::jsonb,'history','[]'::jsonb,'phases',(
  select coalesce(jsonb_agg(jsonb_build_object('id',ph->>'id','name',ph->>'name','start',ph->>'start','end',ph->>'end','functions',(
   select jsonb_agg(jsonb_build_object('id',f->>'id','role',f->>'role','quantity',1,'crew',jsonb_build_array(code.person_id),'rates','{}'::jsonb)) from jsonb_array_elements(ph->'functions') f where f->'crew' ? code.person_id
  ))),'[]'::jsonb) from jsonb_array_elements(p->'phases') ph where (ph->>'end')::timestamp >= (now() at time zone 'Europe/Lisbon') and exists(select 1 from jsonb_array_elements(ph->'functions') f where f->'crew' ? code.person_id)
 ))),'[]'::jsonb) into projects from jsonb_array_elements(snapshot->'projects') p
 where p->>'deletedAt' is null and p->>'status' not in('Cancelado','Realizado') and (p->>'end')::date>=current_date and exists(select 1 from jsonb_array_elements(p->'phases') ph,lateral jsonb_array_elements(ph->'functions') f where f->'crew' ? code.person_id and (ph->>'end')::timestamp >= (now() at time zone 'Europe/Lisbon'));
 return jsonb_build_object('accessRole','crew','projects',projects,'staff',jsonb_build_array(jsonb_build_object('id',person->>'id','name',person->>'name','kind',person->>'kind','sector',person->>'sector')),'phaseNames',snapshot->'phaseNames','user',jsonb_build_object('name',person->>'name','email',code.email));
end $$;
revoke execute on function public.beta_guest_state(text) from public;
grant execute on function public.beta_guest_state(text) to anon,authenticated;

create or replace function public.beta_guest_logout(p_session text) returns void
language sql security definer set search_path=pg_catalog,public as $$update public.beta_crew_sessions set revoked=true where token_digest=p_session$$;
revoke execute on function public.beta_guest_logout(text) from public;
grant execute on function public.beta_guest_logout(text) to anon,authenticated;


update public.beta_access_codes set valid_until='infinity'::timestamptz where not revoked;
update public.beta_crew_sessions set expires_at='infinity'::timestamptz where not revoked;
