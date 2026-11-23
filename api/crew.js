import{auth,reply,remote,originOK,friendly}from'../lib/cloud.js';
import{validateCrew}from'../lib/crew.js';
export default async function handler(req,res){
 if(req.method!=='POST')return reply(res,405,{error:'Método não permitido.'});
 if(!originOK(req))return reply(res,403,{error:'Origem inválida.'});
 try{const{token}=await auth(req,res);const person=typeof req.body==='string'?JSON.parse(req.body):req.body;validateCrew(person);const saved=await remote('/rest/v1/rpc/beta_save_crew',{token,method:'POST',body:{person}});return reply(res,200,saved)}catch(e){return reply(res,e.status===401?401:e.message?.includes('VERSION_CONFLICT')?409:400,{error:friendly(e)})}
}
