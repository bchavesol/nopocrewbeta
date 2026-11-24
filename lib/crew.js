export const sectors=['Som','Vídeo','Iluminação','Rigging','Produção','Estruturas','Outro'];
export function validateCrew(p){
 const fail=m=>{throw Error(m)};
 if(!p||typeof p!=='object'||Array.isArray(p))fail('Ficha inválida.');
 for(let key of['name','phone','email','role','notes','sector','kind'])if(typeof p[key]!=='string'||p[key].length>(key==='notes'?3000:300))fail('Campo inválido: '+key);
 if(!p.name.trim())fail('O nome é obrigatório.');
 if(!sectors.includes(p.sector)||!['Interno','Freelancer favorito','Freelancer'].includes(p.kind))fail('Setor ou tipo inválido.');
 if(p.email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(p.email))fail('Indica um email válido.');
 for(let key of['dailyRate','overtimeRate'])if(p[key]!==null&&(typeof p[key]!=='number'||!Number.isFinite(p[key])||p[key]<0||p[key]>1000000))fail('Valor inválido: '+key);
 if(typeof p.active!=='boolean')fail('Estado inválido.');
 if(p.id&&!/^[a-zA-Z0-9-]{1,80}$/.test(p.id))fail('Identificador inválido.');
 if(p.includedHours!==undefined&&(typeof p.includedHours!=='number'||!Number.isFinite(p.includedHours)||p.includedHours<=0||p.includedHours>744))fail('Horas incluídas inválidas.');
 if(p.accessEnabled!==undefined&&typeof p.accessEnabled!=='boolean')fail('Acesso inválido.');
 for(let k of ['emergencyContact','address','postalCity','companyName','taxNumber','bankAccount','externalReference','documentsUrl'])if(p[k]!==undefined&&(typeof p[k]!=='string'||p[k].length>2000))fail('Campo inválido: '+k);
 if(p.accessEnabled&&!p.email)fail('O email é obrigatório para permitir acesso.');
 if(p.documentsUrl){try{if(!['https:','http:'].includes(new URL(p.documentsUrl).protocol))fail('Link inválido.')}catch{fail('Link inválido.')}}
 return true;
}
