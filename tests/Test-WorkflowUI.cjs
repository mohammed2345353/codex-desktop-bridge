// No browser, packages or network required. Exercise the shipped UI logic with a
// minimal DOM, including Graphlib itself, rather than reimplementing transitions.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const template=fs.readFileSync(path.join(root,'templates/workflow.html'),'utf8');
const task=(id,deps=[],status='planned')=>({id,number:1,title:id,providerId:'p',providerName:'p',status,dependsOn:deps,privacy:'public',capability:'writing',instruction:'</script><img onerror=alert(1)>',reason:'fixture'});
const plan={title:'عربي',steps:[task('a'),task('b',['a']),task('c',['a']),task('d',['b','c']),task('blocked',[],'blocked')],toolMap:{providers:[]},budgetUsd:0,estimatedCostUsd:0};
class Element{constructor(){this.children=[];this.files=[];}append(...c){this.children.push(...c);}prepend(...c){this.children.unshift(...c);}replaceChildren(...c){this.children=c;}setAttribute(){}focus(){}click(){}}
const elements=new Map();const doc={createElement:()=>new Element(),createElementNS:()=>new Element(),getElementById:id=>{if(!elements.has(id))elements.set(id,new Element());return elements.get(id);},querySelector:()=>new Element()};
const context=vm.createContext({console,TextDecoder,Uint8Array,Set,Map,URL,Blob,atob:s=>Buffer.from(s,'base64').toString('binary'),document:doc,window:{print(){}},setTimeout});
vm.runInContext(fs.readFileSync(path.join(root,'vendor/graphlib/graphlib.js'),'utf8'),context);
const app=template.match(/<script id="workflow-app">([\s\S]*?)<\/script>/)[1].replace('__PLAN_BASE64__',Buffer.from(JSON.stringify(plan)).toString('base64')).replace('__LICENSES_BASE64__',Buffer.from('license').toString('base64'));
vm.runInContext(app,context);
const run=s=>vm.runInContext(s,context);
assert.equal(run("state(byId.get('b'))"),'waiting');
assert.equal(run("setComplete('b')"),false);
assert.equal(run("setComplete('blocked')"),false);
assert.equal(run("setComplete('a')"),true);
assert.equal(run("state(byId.get('b'))"),'ready');
run("setComplete('b');setComplete('c');setComplete('d');undo('b')");
assert.equal(run("completed.has('d')"),false);assert.equal(run("completed.has('c')"),true);
run("undo('a')");assert.equal(run('completed.size'),0);
run("graph.setEdge('d','a')");assert.throws(()=>run('graphlib.alg.topsort(graph)'));
assert.ok(!/fetch\(|XMLHttpRequest|WebSocket|localStorage|innerHTML|eval\(/.test(app));
run("graph.removeEdge('d','a')");
(async()=>{
 const restore=elements.get('restore').onchange;
 async function load(data){await restore({target:{files:[{size:100,text:async()=>JSON.stringify(data)}],value:'fixture'}});}
 const fingerprint=run('fingerprint');
 await load({schemaVersion:1,fingerprint,completed:['b']});assert.equal(run('completed.size'),0);
 await load({schemaVersion:1,fingerprint:'different',completed:['a']});assert.equal(run('completed.size'),0);
 await load({schemaVersion:1,fingerprint,completed:['blocked']});assert.equal(run('completed.size'),0);
 await load({schemaVersion:1,fingerprint,completed:['a','b']});assert.equal(run('completed.size'),2);
 console.log('PASS UI dependency gates, branch/join undo, blocked tasks, cycle detection, safe text and progress import validation.');
})().catch(error=>{console.error(error);process.exitCode=1;});
