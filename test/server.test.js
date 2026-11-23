import test from'node:test';import assert from'node:assert/strict';
import{seed,originOK}from'../lib/cloud.js';import{validate}from'../lib/validate.js';
import stateHandler from'../api/state.js';import projectHandler from'../api/projects.js';
const copy=o=>structuredClone(o);
test('demo projects validate and have separate references',()=>{let s=seed();assert.equal(s.projects.length,3);for(let p of s.projects)assert.equal(validate(p,s),true);assert.equal(new Set(s.projects.map(p=>p.reference)).size,3)});
test('reject date rollover, negative fees, script document URLs',()=>{let s=seed(),p=copy(s.projects[0]);p.start='2026-02-31';assert.throws(()=>validate(p,s));p=copy(s.projects[0]);p.phases[0].functions[0].rates.t1=-10;assert.throws(()=>validate(p,s));p=copy(s.projects[0]);p.documents=[{id:'doc1',name:'X',url:'javascript:alert(1)'}];assert.throws(()=>validate(p,s))});
test('reject out of range phases and repeated technical assignments',()=>{let s=seed(),p=copy(s.projects[0]);p.phases[0].start='2020-01-01T09:00';assert.throws(()=>validate(p,s));p=copy(s.projects[0]);for(let f of p.phases[0].functions)f.crew=['t1'];assert.throws(()=>validate(p,s))});
test('reject cross-project overlapping allocation',()=>{let s=seed(),p=copy(s.projects[0]);s.projects[0].phases[0].functions[0].crew=['t1'];p.id=undefined;p.reference='NEW';p.phases[0].id='new-phase';p.phases[0].functions[0].crew=['t1'];assert.throws(()=>validate(p,s),/Conflito/)});
test('require same-origin mutations',()=>{assert.equal(originOK({method:'POST',headers:{origin:'https://attacker.invalid',host:'beta.vercel.app'}}),false);assert.equal(originOK({method:'POST',headers:{origin:'https://beta.vercel.app',host:'beta.vercel.app'}}),true)});
function res(){return{headers:{},code:0,body:null,setHeader(k,v){this.headers[k]=v},status(s){this.code=s;return this},json(b){this.body=b;return this}}}
test('anonymous users cannot read or write projects',async()=>{let r=res();await stateHandler({method:'GET',headers:{}},r);assert.equal(r.code,401);r=res();await projectHandler({method:'POST',headers:{origin:'https://beta.vercel.app',host:'beta.vercel.app'}},r);assert.equal(r.code,401)});
