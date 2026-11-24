import{phaseNames}from'./cloud.js';
import{availabilityRecords}from'./calendar.js';
const fail=m=>{throw Error(m)};
const list=(v,max=1000)=>Array.isArray(v)&&v.length<=max;
const text=(v,max=300)=>typeof v==='string'&&v.length<=max;
const identifier=v=>typeof v==='string'&&/^[a-zA-Z0-9-]{1,80}$/.test(v);
const amount=v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1000000;
function date(v){if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(v))return false;let d=new Date(v+'T12:00:00Z');return !isNaN(d)&&d.toISOString().slice(0,10)===v}
function time(v){return typeof v==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(v)&&date(v.slice(0,10))&&v.slice(11,13)<24&&v.slice(14,16)<60}
export function validate(p,state){
 if(!p||typeof p!=='object'||Array.isArray(p)||JSON.stringify(p).length>1000000)fail('Projeto inválido.');
 for(let k of['reference','name','manager','location','contact','phone','notes','start','end','status','color'])if(!text(p[k],k==='notes'?10000:300))fail('Campo inválido: '+k);
 for(let k of['managerPhone','responsible','responsiblePhone','clientName','clientContact','clientPhone','clientEmail'])if(p[k]!==undefined&&!text(p[k]))fail('Campo inválido: '+k);
 if(p.clientEmail&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(p.clientEmail))fail('Indica um email válido para o cliente.');
 if(!p.reference.trim()||!p.name.trim())fail('A referência e o nome são obrigatórios.');
 if(!['Rascunho','Em preparação','Confirmado','Realizado','Cancelado'].includes(p.status))fail('Estado inválido.');
 if(!date(p.start)||!date(p.end)||p.end<p.start)fail('Verifica as datas do projeto.');
 if(p.id&&!identifier(p.id))fail('Identificador inválido.');
 for(let key of['phases','transport','expenses','documents'])if(!list(p[key]))fail('Lista inválida: '+key);
 if(p.deletedAt!=null&&(typeof p.deletedAt!=='string'||!Number.isFinite(Date.parse(p.deletedAt))))fail('Data de eliminação inválida.');
 let terms=new Map();
 let seen=new Set(),staff=new Set(state.staff.map(s=>s.id));
 for(let ph of p.phases){
  if(!identifier(ph.id)||seen.has(ph.id)||!phaseNames.includes(ph.name))fail('Fase inválida.');seen.add(ph.id);
  if(!time(ph.start)||!time(ph.end)||ph.end<=ph.start||ph.start.slice(0,10)<p.start||ph.end.slice(0,10)>p.end)fail('As fases devem ter horários válidos dentro das datas do projeto.');
  if(!list(ph.functions,100))fail('Funções inválidas.');
  let people=new Set(),functions=new Set();
  for(let f of ph.functions){
   if(!identifier(f.id)||functions.has(f.id)||!text(f.role,100)||!f.role.trim()||!Number.isInteger(f.quantity)||f.quantity<1||f.quantity>100||!list(f.crew,100)||f.crew.length>f.quantity)fail('Função inválida.');functions.add(f.id);
   for(let id of f.crew){if(!staff.has(id)||people.has(id))fail('Técnico inválido ou repetido na fase.');people.add(id)}
   if(f.feeTerms!==undefined){if(!f.feeTerms||typeof f.feeTerms!=='object'||Array.isArray(f.feeTerms))fail('Jornada inválida.');for(let [id,t]of Object.entries(f.feeTerms)){if(!f.crew.includes(id)||!t||!identifier(t.sessionId)||!amount(t.base)||!amount(t.overtimeRate)||typeof t.includedHours!=='number'||!Number.isFinite(t.includedHours)||t.includedHours<=0||t.includedHours>744)fail('Jornada inválida.');let key=id+'|'+t.sessionId,value=JSON.stringify([t.base,t.includedHours,t.overtimeRate]);if(terms.has(key)&&terms.get(key)!==value)fail('Uma jornada deve manter os mesmos valores em todas as fases.');terms.set(key,value)}}
   if(!f.rates||typeof f.rates!=='object'||Array.isArray(f.rates)||Object.values(f.rates).some(v=>!amount(v)))fail('Cachet inválido.');
  }
 }
 for(let trip of p.transport)if(!identifier(trip.id)||!text(trip.vehicle)||!trip.vehicle.trim()||!text(trip.driver)||!text(trip.notes)||!time(trip.start)||!time(trip.end)||trip.end<=trip.start)fail('Transporte inválido.');
 for(let ex of p.expenses)if(!identifier(ex.id)||!['Combustível','Refeições','Estadias','Outros'].includes(ex.category)||!amount(ex.amount)||ex.amount<=0||!date(ex.date)||!text(ex.description))fail('Despesa inválida.');
 for(let doc of p.documents){if(!identifier(doc.id)||!text(doc.name)||!doc.name.trim()||!text(doc.url,2000))fail('Documento inválido.');try{if(!['http:','https:'].includes(new URL(doc.url).protocol))fail('Link inválido.')}catch{fail('Usa um endereço http ou https válido.')}}
 const previous=state.projects.find(x=>x.id===p.id);
 const known=new Set(previous?.phases.flatMap(ph=>ph.functions.flatMap(f=>f.crew.map(id=>[ph.id,ph.start,ph.end,id].join('|')))));
 for(let ph of p.phases)for(let f of ph.functions)for(let id of f.crew){
  if(p.deletedAt)continue;
  if(!previous?.deletedAt&&known.has([ph.id,ph.start,ph.end,id].join('|')))continue;
  for(let a of availabilityRecords(state)){if(a.personId===id&&!a.deletedAt&&!a.rejectedAt&&a.start<=ph.end.slice(0,10)&&a.end>=ph.start.slice(0,10)&&!(ph.end.slice(0,10)===a.start&&ph.end.slice(11,16)==='00:00'))fail('O técnico tem '+a.reason.toLowerCase()+' neste período.');}
  if(state.staff.find(s=>s.id===id)?.active===false)fail('Não é possível atribuir um técnico inativo.');
  for(let other of[...state.projects.filter(x=>x.id!==p.id),p]){if(other.deletedAt||other.status==='Cancelado')continue;for(let otherPh of other.phases){if(other===p&&otherPh.id===ph.id)continue;if(ph.start<otherPh.end&&otherPh.start<ph.end&&otherPh.functions.some(g=>g.crew.includes(id)))fail('Conflito de horário: o técnico já está atribuído em '+other.name+'.')}}
 }
 return true;
}

