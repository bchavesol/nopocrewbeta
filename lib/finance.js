// Shared arithmetic for project totals, technician totals and exports. Fees are fixed per phase.
export function financeData(state,{projectId='',month=''}={}){
 const labor=[],expenses=[];
 const included=date=>!month||(date||'').slice(0,7)===month;
 const projects=state.projects.filter(p=>p.status!=='Cancelado'&&(!projectId||p.id===projectId));
 for(const p of projects){
  for(const ph of p.phases){if(!included(ph.start))continue;for(const f of ph.functions)for(const id of f.crew){const s=state.staff.find(s=>s.id===id),configured=Object.hasOwn(f.rates||{},id);labor.push({projectId:p.id,project:p.name,reference:p.reference,phase:ph.name,date:ph.start.slice(0,10),crewId:id,name:s?.name||'Técnico removido',kind:s?.kind||'Freelancer',role:f.role,configured,amount:Number(f.rates?.[id]||0)})}}
  for(const e of p.expenses){if(included(e.date))expenses.push({...e,projectId:p.id,project:p.name,reference:p.reference})}
 }
 const internal=labor.filter(r=>r.kind==='Interno').reduce((a,r)=>a+r.amount,0),freelance=labor.filter(r=>r.kind!=='Interno').reduce((a,r)=>a+r.amount,0),manual=expenses.reduce((a,e)=>a+e.amount,0);
 const byProject=projects.map(p=>{let rows=labor.filter(r=>r.projectId===p.id),i=rows.filter(r=>r.kind==='Interno').reduce((a,r)=>a+r.amount,0),f=rows.filter(r=>r.kind!=='Interno').reduce((a,r)=>a+r.amount,0),e=expenses.filter(r=>r.projectId===p.id).reduce((a,r)=>a+r.amount,0);return{id:p.id,name:p.name,reference:p.reference,internal:i,freelance:f,expenses:e,total:i+f+e,missing:rows.filter(r=>!r.configured).length}}).filter(p=>!month||labor.some(r=>r.projectId===p.id)||expenses.some(r=>r.projectId===p.id));
 const byCrew=[...new Set(labor.map(r=>r.crewId))].map(id=>{let rows=labor.filter(r=>r.crewId===id);return{id,name:rows[0].name,kind:rows[0].kind,phases:rows.length,projects:new Set(rows.map(r=>r.projectId)).size,total:rows.reduce((a,r)=>a+r.amount,0),missing:rows.filter(r=>!r.configured).length}}).sort((a,b)=>a.name.localeCompare(b.name));
 return{labor,expenses,internal,freelance,manual,total:internal+freelance+manual,byProject,byCrew,missing:labor.filter(r=>!r.configured).length};
}
