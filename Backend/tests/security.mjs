import fs from 'node:fs';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.DUO_PGLITE_MODULE ?? '@electric-sql/pglite');
const db = new PGlite();
const results = [];
async function test(name, run) { try { await run(); results.push({name, status:'PASS'}); console.log('PASS', name); } catch (e) { results.push({name,status:'FAIL',error:String(e)}); console.log('FAIL',name,String(e)); } }
const alice='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', bob='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', eve='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', fourth='ffffffff-ffff-4fff-8fff-ffffffffffff';
await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key); create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$; grant usage on schema auth to authenticated,anon; grant execute on function auth.uid() to authenticated,anon; insert into auth.users values ('${alice}'),('${bob}'),('${eve}'),('${fourth}');`);
await test('Migration 001 installs on PostgreSQL',async()=>{await db.exec(fs.readFileSync(new URL('../001_schema.sql',import.meta.url),'utf8'));});
await test('Migration 002 installs on PostgreSQL',async()=>{await db.exec(fs.readFileSync(new URL('../002_account_privacy.sql',import.meta.url),'utf8'));});
async function as(id, role='authenticated') { await db.exec('reset role'); await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id ?? '']); await db.exec('set role '+role); }
async function scalar(sql,args=[]) { return Object.values((await db.query(sql,args)).rows[0])[0]; }
async function denied(fn) { await assert.rejects(fn); }
let home, invite, eveHome;
await as(alice);
await test('Create authenticated household',async()=>{ home=await scalar('select public.create_household()'); assert.ok(home); });
await test('Cannot create second household',async()=>{await denied(()=>db.query('select public.create_household()'));});
await test('Invitation creation',async()=>{invite=await scalar('select public.invite_partner()');assert.equal(invite.length,72);});
await as(bob);
await test('Partner can redeem invitation',async()=>{assert.equal(await scalar('select public.join_household($1)',[invite]),home);});
await as(eve);
await test('Consumed invitation cannot be replayed',async()=>{await denied(()=>db.query('select public.join_household($1)',[invite]));});
eveHome=await scalar('select public.create_household()');
await as(alice);
await test('Household refuses third member invitation',async()=>{await denied(()=>db.query('select public.invite_partner()'));});
const food=(q)=>({food:{_0:{name:'riz',quantity:q,unit:'g',category:'Épicerie',location:'Placard',added:0}}});
const id='11111111-1111-4111-8111-111111111111';
const row={id,household_id:home,owner_id:null,revision:0,deleted:false,payload:food(100)};
const push=(rows)=>scalar('select public.apply_records($1::jsonb)',[JSON.stringify(rows)]);
await test('Shared record starts at revision 1',async()=>{const r=await push([row]);assert.equal(r[0].revision,1);});
const privateID='22222222-2222-4222-8222-222222222222';
await test('Owner can create private habit',async()=>{await push([{...row,id:privateID,owner_id:alice,payload:{habit:{_0:{title:'Marche',weeklyGoal:3,completions:[]}}}}]);});
await as(bob);
await test('Partner sees shared data through RLS',async()=>{const rows=(await db.query('select * from public.records')).rows;assert.equal(rows.length,1);assert.equal(rows[0].id,id);});
await test('Private habit is absent from sync RPC',async()=>{const rows=await scalar('select public.read_records()');assert.equal(rows.length,1);});
await test('Cannot guess and overwrite private record',async()=>{await denied(()=>push([{...row,id:privateID,owner_id:bob,revision:1}]));});
await test('Partner can edit shared record',async()=>{const r=await push([{...row,revision:1,payload:food(200)}]);assert.equal(r[0].revision,2);});
await as(alice);
await test('Stale simultaneous edit is rejected',async()=>{await denied(()=>push([{...row,revision:1,payload:food(999)}]));assert.equal((await scalar('select public.read_records()')).find(r=>r.id===id).payload.food._0.quantity,200);});
await test('Missing revision cannot bypass CAS',async()=>{const r={...row,payload:food(999)};delete r.revision;await denied(()=>push([r]));});
await test('Negative food quantity rejected server-side',async()=>{await denied(()=>push([{...row,revision:2,payload:food(-1)}]));});
await test('Fractional pieces rejected server-side',async()=>{const p=food(1.5);p.food._0.unit='piece';await denied(()=>push([{...row,revision:2,payload:p}]));});
await test('Direct writes denied even to member',async()=>{await denied(()=>db.query('update public.records set deleted=true where id=$1',[id]));});
await test('Batch rolls back all rows on conflict',async()=>{await denied(()=>push([{...row,revision:2,payload:food(300)},{...row,id:privateID,revision:999,owner_id:alice,payload:{habit:{_0:{title:'Marche',weeklyGoal:4,completions:[]}}}}]));assert.equal((await scalar('select public.read_records()')).find(r=>r.id===id).revision,2);});
await as(eve);
await test('Other household cannot read records via RLS',async()=>{assert.equal((await db.query('select * from public.records')).rows.length,0);});
await test('Other household cannot read via sync RPC',async()=>{assert.deepEqual(await scalar('select public.read_records()'),[]);});
await test('Cannot forge household ID',async()=>{await denied(()=>push([{...row,revision:2}]));});
await test('Cannot take over global record ID',async()=>{await denied(()=>push([{...row,household_id:eveHome,revision:2}]));});
await test('Cannot forge membership',async()=>{await denied(()=>db.query('update public.members set household_id=$1 where user_id=$2',[home,eve]));});
await as(alice);
await test('Deletion creates a revisioned tombstone',async()=>{const r=await push([{...row,revision:2,deleted:true,payload:food(200)}]);assert.equal(r[0].revision,3);assert.ok(r[0].deleted);});
await as(bob);
await test('Partner receives deletion tombstone',async()=>{assert.ok((await scalar('select public.read_records()')).find(r=>r.id===id).deleted);});
await test('Deleted record cannot be silently resurrected',async()=>{await denied(()=>push([{...row,revision:3,payload:food(200)}]));});
const partnerRecordID='33333333-3333-4333-8333-333333333333';
await test('Record author comes from JWT, not forged client field',async()=>{
 const forged={...row,id:partnerRecordID,revision:0,created_by:alice,payload:food(37)};
 const saved=await push([forged]); assert.equal(saved[0].created_by,bob);
});
await as(alice);
await test('Account erasure is acknowledged',async()=>{assert.equal(await scalar('select public.erase_my_data()'),true);});
await test('Account erasure can be safely retried',async()=>{assert.equal(await scalar('select public.erase_my_data()'),true);});
await test('Deleted account loses read and write RPC access',async()=>{
 await denied(()=>db.query('select public.read_records()'));
 await denied(()=>push([{...row,revision:3,payload:food(400)}]));
});
await test('Deleted identity cannot recreate a household',async()=>{await denied(()=>db.query('select public.create_household()'));});
await as(bob);
await test('Partner authored shared record is preserved',async()=>{
 const rows=await scalar('select public.read_records()');
 assert.equal(rows.find(r=>r.id===partnerRecordID).payload.food._0.quantity,37);
});
await test('Deleted author shared record is redacted tombstone',async()=>{
 const rows=await scalar('select public.read_records()');
 const deleted=rows.find(r=>r.id===id);
 assert.equal(deleted.deleted,true); assert.equal(deleted.created_by,null);
 assert.equal(deleted.payload.task._0.title,'Élément supprimé');
});
await test('Deleted identity private record is erased',async()=>{
 const rows=await scalar('select public.read_records()');
 assert.equal(rows.find(r=>r.id===privateID),undefined);
});
await as(alice);
await test('Erasure marker blocks membership despite still-valid JWT',async()=>{
 const newInvite=await as(bob).then(async()=>scalar('select public.invite_partner()'));
 await as(alice);
 await denied(()=>db.query('select public.join_household($1)',[newInvite]));
});
await as(null,'anon');
await test('Anonymous records access denied',async()=>{await denied(()=>db.query('select * from public.records'));});
await test('Anonymous RPC access denied',async()=>{await denied(()=>db.query('select public.read_records()'));});
await test('Anonymous household creation denied',async()=>{await denied(()=>db.query('select public.create_household()'));});
await as(null);
await test('Missing JWT identity cannot create household',async()=>{await denied(()=>db.query('select public.create_household()'));});
await db.exec('reset role');
const pg=await scalar('select version()');
const report={environment:'PGlite embedded PostgreSQL; synthetic auth.uid() and test identities; not a hosted Supabase end-to-end test',postgres:pg,results,passed:results.filter(r=>r.status==='PASS').length,failed:results.filter(r=>r.status==='FAIL').length};
fs.writeFileSync(new URL('../../Docs/backend-tests.json',import.meta.url),JSON.stringify(report,null,2));
await db.close();
if(report.failed)process.exitCode=1;
