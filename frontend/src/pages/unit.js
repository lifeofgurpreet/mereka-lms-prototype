// Page: Unit Player — sequential modules, mandatory/optional marks,
// completion tracking, certificate on all-mandatory-done
import { getCourse, getCourseOutline } from '../api/courses.js';
import { getCourseProgress, markComplete } from '../api/progress.js';
import { navigate } from '../router/router.js';
import { getSession } from '../auth/session.js';

function esc(s){return(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;');}
function iconForType(t){return{video:'play_circle',html:'description',problem:'quiz',discussion:'forum',vertical:'view_agenda',sequential:'folder_open',openassessment:'edit_note'}[t]||'article';}
function typeClass(t){return{video:'t-video',html:'t-doc',problem:'t-quiz',discussion:'t-disc',openassessment:'t-assign'}[t]||'t-doc';}

/* ── sequential mock outline (Module 1 → Module 5) ──────── */
function buildMockOutline(){
  return [
    {id:'ch1',title:'Module 1 — Getting started',seq:1,units:[
      {id:'u1',title:'Welcome & orientation',type:'video',mandatory:true,done:true,duration:12},
      {id:'u2',title:'Course overview & objectives',type:'html',mandatory:true,done:true,duration:8},
      {id:'u3',title:'Self-assessment quiz',type:'problem',mandatory:true,done:true,duration:5},
    ]},
    {id:'ch2',title:'Module 2 — Core concepts',seq:2,units:[
      {id:'u4',title:'Key frameworks & models',type:'video',mandatory:true,done:true,duration:18},
      {id:'u5',title:'Case study: Real-world application',type:'html',mandatory:true,done:false,duration:12},
      {id:'u6',title:'Discussion: Share your experience',type:'discussion',mandatory:false,done:false,duration:10},
      {id:'u7',title:'Module checkpoint',type:'problem',mandatory:true,done:false,duration:8},
    ]},
    {id:'ch3',title:'Module 3 — Practical skills',seq:3,units:[
      {id:'u8',title:'Hands-on workshop',type:'video',mandatory:true,done:false,duration:22},
      {id:'u9',title:'Supplementary reading',type:'html',mandatory:false,done:false,duration:15},
      {id:'u10',title:'Practice exercise',type:'problem',mandatory:true,done:false,duration:10},
      {id:'u11',title:'Peer assessment',type:'openassessment',mandatory:false,done:false,duration:20},
    ]},
    {id:'ch4',title:'Module 4 — Advanced topics',seq:4,units:[
      {id:'u12',title:'Deep dive lecture',type:'video',mandatory:true,done:false,duration:25},
      {id:'u13',title:'Expert interview',type:'video',mandatory:false,done:false,duration:15},
      {id:'u14',title:'Strategy planning worksheet',type:'html',mandatory:true,done:false,duration:12},
      {id:'u15',title:'Module assessment',type:'problem',mandatory:true,done:false,duration:10},
    ]},
    {id:'ch5',title:'Module 5 — Final project & certification',seq:5,units:[
      {id:'u16',title:'Project brief & guidelines',type:'html',mandatory:true,done:false,duration:8},
      {id:'u17',title:'Final project submission',type:'openassessment',mandatory:true,done:false,duration:45},
      {id:'u18',title:'Course wrap-up',type:'video',mandatory:true,done:false,duration:10},
      {id:'u19',title:'Final exam',type:'problem',mandatory:true,done:false,duration:20},
      {id:'u20',title:'Bonus: Additional resources',type:'html',mandatory:false,done:false,duration:10},
    ]},
  ];
}

/* ── parse real API blocks ─────────────────────────────────── */
function parseBlocksToOutline(data){
  const blocks=data.blocks||{},rootId=data.root;
  if(!rootId||!blocks[rootId]) return null;
  const root=blocks[rootId];
  const chapters=(root.children||[]).map(c=>blocks[c]).filter(b=>b&&b.type==='chapter');
  if(!chapters.length) return null;
  return chapters.map((ch,ci)=>{
    const seqs=(ch.children||[]).map(s=>blocks[s]).filter(Boolean);
    const units=[];
    seqs.forEach(seq=>{
      const verts=(seq.children||[]).map(v=>blocks[v]).filter(Boolean);
      if(verts.length){
        verts.forEach(v=>units.push({id:v.id,title:v.display_name||'Untitled',type:v.type||'vertical',mandatory:true,done:false,lmsUrl:v.lms_web_url||null}));
      } else {
        units.push({id:seq.id,title:seq.display_name||'Untitled',type:seq.type||'sequential',mandatory:true,done:false,lmsUrl:seq.lms_web_url||null});
      }
    });
    return {id:ch.id,title:ch.display_name||('Module '+(ci+1)),seq:ci+1,units};
  });
}

function flatUnits(modules){return modules.flatMap(m=>m.units);}

function computeProgress(modules){
  let tM=0,dM=0,tA=0,dA=0;
  for(const m of modules) for(const u of m.units){
    tA++; if(u.done) dA++;
    if(u.mandatory){tM++; if(u.done) dM++;}
  }
  return {totalMandatory:tM,doneMandatory:dM,totalAll:tA,doneAll:dA,pct:tM?Math.round(dM/tM*100):0};
}

/* ── content area per unit type ────────────────────────────── */
function renderContentArea(unit){
  const typeLabel={video:'Video Lesson',html:'Reading',problem:'Quiz / Assessment',discussion:'Discussion',openassessment:'Peer Assessment',vertical:'Activity',sequential:'Section'}[unit.type]||'Content';
  const typeIcon=iconForType(unit.type);
  const reqBadge=unit.mandatory
    ?'<span style="font-size:11px;font-weight:600;color:var(--primary);background:rgba(171,59,120,0.1);padding:2px 8px;border-radius:99px;">Required</span>'
    :'<span style="font-size:11px;font-weight:600;color:var(--medium-grey);background:var(--surface);border:1px solid var(--border);padding:2px 8px;border-radius:99px;">Optional</span>';

  if(unit.type==='video'){
    return `
      <div style="background:#1A1623;border-radius:12px;aspect-ratio:16/9;display:flex;align-items:center;justify-content:center;margin-bottom:24px;">
        <div style="text-align:center;color:var(--white);">
          <span class="material-symbols-outlined" style="font-size:64px;opacity:0.6;">play_circle</span>
          <p style="margin-top:8px;font-size:14px;opacity:0.7;">Video player — connect to Open edX for playback</p>
        </div>
      </div>
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
        <span class="type-icon ${typeClass(unit.type)}" style="width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;"><span class="material-symbols-outlined" style="font-size:16px;">${typeIcon}</span></span>
        <span style="font-size:12px;font-weight:600;color:var(--medium-grey);text-transform:uppercase;letter-spacing:0.5px;">${typeLabel}</span>
        ${reqBadge}
      </div>
      <h2 style="margin-bottom:8px;">${esc(unit.title)}</h2>
      <p style="color:var(--medium-grey);font-size:14px;line-height:1.6;">Watch this lesson to understand the key concepts. Take notes and reflect on how these ideas apply to your own context.</p>`;
  }
  if(unit.type==='problem'||unit.type==='openassessment'){
    return `
      <div style="background:var(--white);border:1px solid var(--border);border-radius:12px;padding:40px;text-align:center;margin-bottom:24px;">
        <span class="type-icon ${typeClass(unit.type)}" style="width:56px;height:56px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:16px;"><span class="material-symbols-outlined" style="font-size:28px;">${typeIcon}</span></span>
        <div style="display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:8px;">
          <span style="font-size:12px;font-weight:600;color:var(--medium-grey);text-transform:uppercase;">${typeLabel}</span>
          ${reqBadge}
        </div>
        <h2 style="margin-bottom:12px;">${esc(unit.title)}</h2>
        <p style="color:var(--medium-grey);font-size:14px;max-width:480px;margin:0 auto 24px;">${unit.mandatory?'This is <strong>required</strong> for your certificate.':'This is <strong>optional</strong> but recommended.'}</p>
        ${unit.lmsUrl?`<a href="${esc(unit.lmsUrl)}" target="_blank" class="btn btn--primary" style="display:inline-flex;"><span class="material-symbols-outlined" style="font-size:18px;">open_in_new</span> Open in LMS</a>`:'<div style="color:var(--medium-grey);font-size:13px;">Assessment loads from Open edX when connected</div>'}
      </div>`;
  }
  return `
    <div style="background:var(--white);border:1px solid var(--border);border-radius:12px;padding:40px;margin-bottom:24px;">
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px;">
        <span class="type-icon ${typeClass(unit.type)}" style="width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;"><span class="material-symbols-outlined" style="font-size:16px;">${typeIcon}</span></span>
        <span style="font-size:12px;font-weight:600;color:var(--medium-grey);text-transform:uppercase;">${typeLabel}</span>
        ${reqBadge}
      </div>
      <h2 style="margin-bottom:12px;">${esc(unit.title)}</h2>
      <div style="color:var(--dark-grey);font-size:14px;line-height:1.7;">
        <p>This content loads from your Open edX instance. Key topics include frameworks, practical applications, and reflection exercises.</p>
      </div>
      ${unit.lmsUrl?`<a href="${esc(unit.lmsUrl)}" target="_blank" class="btn btn--outline btn--sm" style="display:inline-flex;margin-top:16px;"><span class="material-symbols-outlined" style="font-size:16px;">open_in_new</span> Open in LMS</a>`:''}
    </div>`;
}

/* ── main render ──────────────────────────────────────────── */
export async function render(rootEl,{params}={}){
  const courseId=params?.courseId||'demo',unitId=params?.unitId||'u1',isDemo=courseId==='demo';

  rootEl.innerHTML=`<div class="player" style="display:flex;align-items:center;justify-content:center;min-height:60vh;"><div class="spinner"></div></div>`;

  let course=null,modules=null;
  if(!isDemo){
    try{course=await getCourse(courseId);}catch(e){console.warn('[unit] course:',e);}
    try{
      const bd=await getCourseOutline(courseId);
      const p=parseBlocksToOutline(bd);
      if(p&&p.length) modules=p;
    }catch(e){console.warn('[unit] outline:',e);}
  }
  if(!modules) modules=buildMockOutline();

  // Ensure sequential numbering
  modules.forEach((m,i)=>{m.seq=i+1;if(!m.title.match(/^Module \d/))m.title='Module '+(i+1)+' — '+m.title.replace(/^Module \d+\s*[—–-]\s*/,'');});

  const courseName=course?.name||'Freelancing 101';
  const all=flatUnits(modules);
  const currentIdx=all.findIndex(u=>u.id===unitId);
  const current=currentIdx>=0?all[currentIdx]:all[0]||{id:'u1',title:'Welcome',type:'video',mandatory:true,done:false};
  const prevUnit=currentIdx>0?all[currentIdx-1]:null;
  const nextUnit=currentIdx<all.length-1?all[currentIdx+1]:null;

  // Find which module current unit belongs to
  let currentModule=modules[0];
  for(const m of modules){if(m.units.some(u=>u.id===unitId)){currentModule=m;break;}}
  const currentUnitIdx=currentModule.units.findIndex(u=>u.id===unitId);

  // Progress
  let prog=computeProgress(modules);

  // ── sidebar modules (sequential 1 → N) ──
  const sidebarHtml=modules.map((mod,mi)=>{
    const modDone=mod.units.filter(u=>u.done).length;
    const hasActive=mod.units.some(u=>u.id===unitId);
    const modPct=mod.units.length?Math.round(modDone/mod.units.length*100):0;

    const unitsHtml=mod.units.map((u,ui)=>{
      const isActive=u.id===unitId;
      const isDone=u.done;
      const cls=['side-unit'];
      if(isDone) cls.push('is-done');
      if(isActive) cls.push('is-active');
      if(!u.mandatory) cls.push('is-optional');
      const icon=isDone?'check_circle':(isActive?'play_circle':iconForType(u.type));
      const iconStyle=isDone?'color:var(--success);':'';
      const reqDot=u.mandatory
        ?'<span style="width:5px;height:5px;border-radius:50%;background:var(--primary);flex-shrink:0;" title="Required"></span>'
        :'<span style="width:5px;height:5px;border-radius:50%;background:var(--border);border:1px solid var(--medium-grey);flex-shrink:0;" title="Optional"></span>';
      return `<div class="${cls.join(' ')}" data-unit-id="${esc(u.id)}" style="cursor:pointer;">
        ${reqDot}
        <span class="type-icon ${typeClass(u.type)}" style="${iconStyle}"><span class="material-symbols-outlined" style="font-size:14px;">${icon}</span></span>
        <span class="side-unit__label">${esc(u.title)}</span>
        ${!u.mandatory?'<span class="optional-pill" style="font-size:9px;">opt</span>':''}
      </div>`;
    }).join('');

    return `<div class="side-module${hasActive?' is-active-mod':''}">
      <div class="side-module__head" data-mod-idx="${mi}" style="cursor:pointer;">
        <div style="display:flex;align-items:center;gap:8px;flex:1;min-width:0;">
          <span style="font-size:10px;font-weight:700;color:var(--primary);background:rgba(171,59,120,0.1);width:20px;height:20px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;flex-shrink:0;">${mod.seq}</span>
          <span style="flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${esc(mod.title)}</span>
        </div>
        <span class="count" style="font-size:11px;color:${modDone===mod.units.length?'var(--success)':'var(--medium-grey)'};">${modDone}/${mod.units.length}</span>
      </div>
      <div class="side-module__units" style="${hasActive||mi===0?'':'display:none;'}">${unitsHtml}</div>
    </div>`;
  }).join('');

  // Certificate eligibility banner
  const allMandatoryDone=prog.pct===100;
  const certBannerHtml=allMandatoryDone?`
    <div style="background:linear-gradient(135deg,rgba(171,59,120,0.08),rgba(58,167,109,0.06));border:1px solid rgba(171,59,120,0.18);border-radius:10px;padding:12px 16px;margin:12px 16px;display:flex;gap:10px;align-items:center;">
      <span class="material-symbols-outlined" style="color:var(--primary);font-size:20px;">workspace_premium</span>
      <div style="flex:1;">
        <div style="font-size:12px;font-weight:600;color:var(--off-black);">All required components completed!</div>
        <div style="font-size:11px;color:var(--dark-grey);">Your certificate is ready.</div>
      </div>
      <button class="btn btn--primary btn--sm" id="sidebarCertBtn"><span class="material-symbols-outlined" style="font-size:14px;">download</span> Certificate</button>
    </div>`:'';

  rootEl.innerHTML=`
  <div class="player">
    <div class="player__main">
      <div class="player__content" style="max-width:860px;margin:0 auto;">
        <div style="font-size:13px;color:var(--medium-grey);margin-bottom:14px;display:flex;align-items:center;gap:6px;">
          <a href="#" id="backToCourse" style="color:var(--link);text-decoration:none;">${esc(courseName)}</a>
          <span class="material-symbols-outlined" style="font-size:14px;">chevron_right</span>
          <span style="color:var(--primary);font-weight:500;">Module ${currentModule.seq}</span>
          <span class="material-symbols-outlined" style="font-size:14px;">chevron_right</span>
          <span>Part ${currentUnitIdx+1} of ${currentModule.units.length}</span>
        </div>

        ${allMandatoryDone?`
        <div style="background:linear-gradient(135deg,rgba(58,167,109,0.08),rgba(171,59,120,0.06));border:1px solid rgba(58,167,109,0.2);border-radius:12px;padding:20px 24px;margin-bottom:24px;display:flex;align-items:center;gap:16px;flex-wrap:wrap;">
          <span class="material-symbols-outlined" style="font-size:36px;color:var(--success);">verified</span>
          <div style="flex:1;min-width:200px;">
            <div style="font-weight:700;font-size:16px;color:var(--off-black);margin-bottom:4px;">Course completed — Certificate ready!</div>
            <div style="font-size:13px;color:var(--dark-grey);">You've finished all ${prog.doneMandatory} required components. Download your certificate or continue reviewing.</div>
          </div>
          <button class="btn btn--primary" id="getCertBtn"><span class="material-symbols-outlined" style="font-size:18px;">workspace_premium</span> Download certificate</button>
          <button class="btn btn--outline btn--sm" id="viewCertModalBtn"><span class="material-symbols-outlined" style="font-size:16px;">visibility</span> Preview</button>
        </div>`:''}

        ${renderContentArea(current)}

        <div style="display:flex;gap:12px;margin-top:20px;flex-wrap:wrap;align-items:center;">
          <button class="btn btn--outline btn--sm" id="bookmarkBtn"><span class="material-symbols-outlined" style="font-size:16px;">bookmark</span> Bookmark</button>
          ${current.lmsUrl?`<a href="${esc(current.lmsUrl)}" target="_blank" class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">open_in_new</span> Open in LMS</a>`:''}
          ${!current.done?`<button class="btn btn--primary btn--sm" id="markDoneBtn"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Mark as complete</button>`:`<span style="display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--success);font-weight:600;"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Completed</span>`}
          <div style="flex:1;"></div>
          ${prevUnit?`<button class="btn btn--ghost btn--sm" id="prevBtn"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Previous</button>`:''}
          ${nextUnit?`<button class="btn btn--primary btn--sm" id="nextBtn">Next <span class="material-symbols-outlined" style="font-size:16px;">arrow_forward</span></button>`:`<button class="btn btn--primary btn--sm" id="finishBtn"><span class="material-symbols-outlined" style="font-size:16px;">${allMandatoryDone?'workspace_premium':'flag'}</span> ${allMandatoryDone?'Get certificate':'Finish course'}</button>`}
        </div>
      </div>
    </div>

    <div class="player__side">
      <div class="player__side-head">
        <a href="#" id="sideBackLink" class="btn btn--ghost btn--sm" style="margin-bottom:8px;"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Back to course</a>
        <h4>${esc(courseName)}</h4>
        <div style="display:flex;align-items:center;gap:8px;margin-top:8px;">
          <div class="progress" style="flex:1;"><div class="progress__fill" id="progressFill" style="width:${prog.pct}%;${prog.pct===100?' background:var(--success);':''}"></div></div>
          <span style="font-size:12px;font-weight:600;color:${prog.pct===100?'var(--success)':'var(--primary)'};" id="pctLabel">${prog.pct}%</span>
        </div>
        <div style="font-size:11px;color:var(--medium-grey);margin-top:4px;" id="progressDetail">${prog.doneMandatory}/${prog.totalMandatory} required · ${prog.doneAll}/${prog.totalAll} total</div>
      </div>
      <div class="player__side-modules">
        <div style="display:flex;gap:14px;flex-wrap:wrap;padding:10px 16px;border-bottom:1px solid var(--border);font-size:11px;color:var(--medium-grey);">
          <span style="display:inline-flex;align-items:center;gap:4px;"><span style="width:6px;height:6px;border-radius:50%;background:var(--primary);display:inline-block;"></span> Required</span>
          <span style="display:inline-flex;align-items:center;gap:4px;"><span style="width:6px;height:6px;border-radius:50%;background:var(--border);border:1px solid var(--medium-grey);display:inline-block;"></span> Optional</span>
        </div>
        ${certBannerHtml}
        ${sidebarHtml}
      </div>
    </div>

    <!-- Certificate Modal -->
    <div id="certModal" style="display:none;position:fixed;inset:0;z-index:1000;background:rgba(0,0,0,0.6);align-items:center;justify-content:center;">
      <div style="background:var(--white);border-radius:16px;max-width:800px;width:95%;max-height:90vh;overflow:auto;position:relative;">
        <button id="closeCertModal" style="position:absolute;top:16px;right:16px;background:none;border:none;cursor:pointer;z-index:2;"><span class="material-symbols-outlined" style="font-size:24px;color:var(--dark-grey);">close</span></button>
        <div style="margin:24px;border:3px solid var(--primary);border-radius:8px;padding:48px 56px;text-align:center;">
          <div style="width:72px;height:72px;margin:0 auto 20px;background:var(--brand-gradient);border-radius:50%;display:flex;align-items:center;justify-content:center;color:var(--white);"><span class="material-symbols-outlined" style="font-size:36px;">workspace_premium</span></div>
          <div style="font-family:var(--font-display);font-weight:500;font-size:13px;text-transform:uppercase;letter-spacing:2px;color:var(--primary);margin-bottom:10px;">Certificate of Completion</div>
          <h1 style="font-size:36px;margin-bottom:24px;font-family:var(--font-display);background:var(--brand-gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;">Mereka Academy</h1>
          <p style="font-family:var(--font-display);font-weight:700;font-size:28px;color:var(--off-black);border-bottom:1px solid var(--border);padding:0 40px 16px;margin-bottom:20px;display:inline-block;">Learner</p>
          <p style="color:var(--dark-grey);font-size:14px;margin-bottom:8px;">has successfully completed all required components of</p>
          <p style="font-family:var(--font-display);font-weight:600;font-size:20px;color:var(--off-black);margin-bottom:24px;">${esc(courseName)}</p>
          <div style="font-size:13px;color:var(--medium-grey);margin-bottom:16px;">${prog.doneMandatory}/${prog.totalMandatory} required completed · ${modules.length} modules</div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:32px;">
            <div><div style="font-family:var(--font-display);font-weight:600;font-size:15px;border-top:1px solid var(--border);padding-top:8px;">Mereka Academy</div><div style="font-size:12px;color:var(--medium-grey);margin-top:2px;">Issuing Institution</div></div>
            <div><div style="font-family:var(--font-display);font-weight:600;font-size:15px;border-top:1px solid var(--border);padding-top:8px;">${new Date().toLocaleDateString('en-US',{year:'numeric',month:'long',day:'numeric'})}</div><div style="font-size:12px;color:var(--medium-grey);margin-top:2px;">Date of Completion</div></div>
          </div>
        </div>
        <div style="display:flex;gap:12px;justify-content:center;padding:0 24px 24px;">
          <button class="btn btn--primary" id="certDownloadBtn"><span class="material-symbols-outlined" style="font-size:18px;">download</span> Download PDF</button>
          <button class="btn btn--outline" id="certShareBtn"><span class="material-symbols-outlined" style="font-size:18px;">share</span> Share to LinkedIn</button>
        </div>
      </div>
    </div>
  </div>`;

  // ── wire interactions ──
  const goToCourse=e=>{e.preventDefault();navigate('/course/'+encodeURIComponent(courseId));};
  rootEl.querySelector('#backToCourse')?.addEventListener('click',goToCourse);
  rootEl.querySelector('#sideBackLink')?.addEventListener('click',goToCourse);

  // Sidebar unit click → navigate
  rootEl.querySelectorAll('.side-unit').forEach(el=>{
    el.addEventListener('click',()=>{
      const uid=el.dataset.unitId;
      if(uid) navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(uid));
    });
  });

  // Sidebar module accordion
  rootEl.querySelectorAll('.side-module__head').forEach(head=>{
    head.addEventListener('click',()=>{
      const body=head.nextElementSibling;
      if(body) body.style.display=body.style.display==='none'?'':'none';
    });
  });

  // Prev/Next navigation
  if(prevUnit) rootEl.querySelector('#prevBtn')?.addEventListener('click',()=>navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(prevUnit.id)));
  if(nextUnit) rootEl.querySelector('#nextBtn')?.addEventListener('click',()=>navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(nextUnit.id)));

  // Finish button → certificate or course page
  rootEl.querySelector('#finishBtn')?.addEventListener('click',()=>{
    if(allMandatoryDone){
      const modal=rootEl.querySelector('#certModal');
      if(modal) modal.style.display='flex';
    } else {
      navigate('/course/'+encodeURIComponent(courseId));
    }
  });

  // Mark complete
  rootEl.querySelector('#markDoneBtn')?.addEventListener('click',async()=>{
    const btn=rootEl.querySelector('#markDoneBtn');
    btn.disabled=true;
    btn.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">hourglass_empty</span> Saving…';
    try{await markComplete(current.id);}catch(e){console.warn('[unit] mark complete:',e);}
    current.done=true;

    // Update UI inline
    btn.outerHTML='<span style="display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--success);font-weight:600;"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Completed</span>';

    // Update sidebar unit
    const sideUnit=rootEl.querySelector(`.side-unit[data-unit-id="${CSS.escape(current.id)}"]`);
    if(sideUnit){
      sideUnit.classList.add('is-done');
      const ico=sideUnit.querySelector('.type-icon .material-symbols-outlined');
      if(ico){ico.textContent='check_circle';ico.style.color='var(--success)';}
    }

    // Recalculate progress
    prog=computeProgress(modules);
    const fill=rootEl.querySelector('#progressFill');
    if(fill){fill.style.width=prog.pct+'%';if(prog.pct===100) fill.style.background='var(--success)';}
    const pctLbl=rootEl.querySelector('#pctLabel');
    if(pctLbl){pctLbl.textContent=prog.pct+'%';if(prog.pct===100) pctLbl.style.color='var(--success)';}
    const det=rootEl.querySelector('#progressDetail');
    if(det) det.textContent=prog.doneMandatory+'/'+prog.totalMandatory+' required · '+prog.doneAll+'/'+prog.totalAll+' total';

    // If all mandatory done now, show celebration
    if(prog.pct===100){
      setTimeout(()=>{
        const modal=rootEl.querySelector('#certModal');
        if(modal) modal.style.display='flex';
      },600);
    } else if(nextUnit){
      // Auto-advance after short delay
      setTimeout(()=>navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(nextUnit.id)),800);
    }
  });

  // Certificate modal
  const modal=rootEl.querySelector('#certModal');
  const openCert=()=>{if(modal) modal.style.display='flex';};
  const closeCert=()=>{if(modal) modal.style.display='none';};
  rootEl.querySelector('#getCertBtn')?.addEventListener('click',openCert);
  rootEl.querySelector('#viewCertModalBtn')?.addEventListener('click',openCert);
  rootEl.querySelector('#sidebarCertBtn')?.addEventListener('click',openCert);
  rootEl.querySelector('#closeCertModal')?.addEventListener('click',closeCert);
  if(modal) modal.addEventListener('click',e=>{if(e.target===modal) closeCert();});

  // Download / Share
  rootEl.querySelector('#certDownloadBtn')?.addEventListener('click',()=>{
    const b=rootEl.querySelector('#certDownloadBtn');
    b.innerHTML='<span class="material-symbols-outlined" style="font-size:18px;">check</span> Downloaded!';b.disabled=true;
    setTimeout(()=>{b.innerHTML='<span class="material-symbols-outlined" style="font-size:18px;">download</span> Download PDF';b.disabled=false;},2000);
  });
  rootEl.querySelector('#certShareBtn')?.addEventListener('click',()=>{
    window.open('https://www.linkedin.com/sharing/share-offsite/?url='+encodeURIComponent(window.location.href),'_blank','width=600,height=400');
  });

  // Bookmark
  rootEl.querySelector('#bookmarkBtn')?.addEventListener('click',()=>{
    const b=rootEl.querySelector('#bookmarkBtn');
    b.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">bookmark_added</span> Bookmarked';b.style.color='var(--primary)';b.style.borderColor='var(--primary)';
    setTimeout(()=>{b.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">bookmark</span> Bookmark';b.style.color='';b.style.borderColor='';},2000);
  });
}
