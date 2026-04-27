// Page: Unit Player — full sidebar with module outline, navigation, completion
import { getCourse, getCourseOutline } from '../api/courses.js';
import { getCourseProgress, markComplete } from '../api/progress.js';
import { navigate } from '../router/router.js';
import { getSession } from '../auth/session.js';

function esc(s){return(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;');}
function iconForType(t){return{video:'play_circle',html:'description',problem:'quiz',discussion:'forum',vertical:'view_agenda',sequential:'folder_open',openassessment:'edit_note'}[t]||'article';}
function typeClass(t){return{video:'t-video',html:'t-doc',problem:'t-quiz',discussion:'t-disc',openassessment:'t-assign'}[t]||'t-doc';}

/* mock outline */
function buildMockOutline(){
  return [
    {id:'ch1',title:'Module 1 — Getting started',units:[
      {id:'u1',title:'Welcome & orientation',type:'video',mandatory:true,done:true},
      {id:'u2',title:'Course overview & objectives',type:'html',mandatory:true,done:true},
      {id:'u3',title:'Self-assessment quiz',type:'problem',mandatory:true,done:true},
    ]},
    {id:'ch2',title:'Module 2 — Core concepts',units:[
      {id:'u4',title:'Key frameworks & models',type:'video',mandatory:true,done:true},
      {id:'u5',title:'Case study: Real-world application',type:'html',mandatory:true,done:false},
      {id:'u6',title:'Discussion: Share your experience',type:'discussion',mandatory:false,done:false},
      {id:'u7',title:'Module checkpoint',type:'problem',mandatory:true,done:false},
    ]},
    {id:'ch3',title:'Module 3 — Practical skills',units:[
      {id:'u8',title:'Hands-on workshop',type:'video',mandatory:true,done:false},
      {id:'u9',title:'Supplementary reading',type:'html',mandatory:false,done:false},
      {id:'u10',title:'Practice exercise',type:'problem',mandatory:true,done:false},
      {id:'u11',title:'Peer assessment',type:'openassessment',mandatory:false,done:false},
    ]},
    {id:'ch4',title:'Module 4 — Advanced topics',units:[
      {id:'u12',title:'Deep dive lecture',type:'video',mandatory:true,done:false},
      {id:'u13',title:'Expert interview',type:'video',mandatory:false,done:false},
      {id:'u14',title:'Strategy planning worksheet',type:'html',mandatory:true,done:false},
      {id:'u15',title:'Module assessment',type:'problem',mandatory:true,done:false},
    ]},
    {id:'ch5',title:'Module 5 — Final project & certification',units:[
      {id:'u16',title:'Project brief & guidelines',type:'html',mandatory:true,done:false},
      {id:'u17',title:'Final project submission',type:'openassessment',mandatory:true,done:false},
      {id:'u18',title:'Course wrap-up',type:'video',mandatory:true,done:false},
      {id:'u19',title:'Final exam',type:'problem',mandatory:true,done:false},
      {id:'u20',title:'Bonus: Additional resources',type:'html',mandatory:false,done:false},
    ]},
  ];
}

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
    return {id:ch.id,title:ch.display_name||('Module '+(ci+1)),units};
  });
}

function flatUnits(modules){return modules.flatMap(m=>m.units);}

/* content area based on unit type */
function renderContentArea(unit,courseName){
  const typeLabel={video:'Video Lesson',html:'Reading',problem:'Quiz / Assessment',discussion:'Discussion',openassessment:'Peer Assessment',vertical:'Activity',sequential:'Section'}[unit.type]||'Content';
  const typeIcon=iconForType(unit.type);

  if(unit.type==='video'){
    return `
      <div class="player__video" style="background:#1A1623;border-radius:12px;aspect-ratio:16/9;display:flex;align-items:center;justify-content:center;margin-bottom:24px;position:relative;overflow:hidden;">
        <div style="text-align:center;color:var(--white);">
          <span class="material-symbols-outlined" style="font-size:64px;opacity:0.6;">play_circle</span>
          <p style="margin-top:8px;font-size:14px;opacity:0.7;">Video player — connect to Open edX for playback</p>
        </div>
      </div>
      <div class="player__info">
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
          <span class="type-icon ${typeClass(unit.type)}" style="width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;"><span class="material-symbols-outlined" style="font-size:16px;">${typeIcon}</span></span>
          <span style="font-size:12px;font-weight:600;color:var(--medium-grey);text-transform:uppercase;letter-spacing:0.5px;">${typeLabel}</span>
          ${unit.mandatory?'<span style="font-size:11px;font-weight:600;color:var(--primary);background:rgba(171,59,120,0.1);padding:2px 8px;border-radius:99px;">Required</span>':'<span class="optional-pill">optional</span>'}
        </div>
        <h2 style="margin-bottom:8px;">${esc(unit.title)}</h2>
        <p style="color:var(--medium-grey);font-size:14px;line-height:1.6;">Watch this lesson to understand the key concepts. Take notes and reflect on how these ideas apply to your own context.</p>
      </div>`;
  }

  if(unit.type==='problem'||unit.type==='openassessment'){
    return `
      <div style="background:var(--white);border:1px solid var(--border);border-radius:12px;padding:40px;text-align:center;margin-bottom:24px;">
        <span class="type-icon ${typeClass(unit.type)}" style="width:56px;height:56px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:16px;"><span class="material-symbols-outlined" style="font-size:28px;">${typeIcon}</span></span>
        <div style="display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:8px;">
          <span style="font-size:12px;font-weight:600;color:var(--medium-grey);text-transform:uppercase;">${typeLabel}</span>
          ${unit.mandatory?'<span style="font-size:11px;font-weight:600;color:var(--primary);background:rgba(171,59,120,0.1);padding:2px 8px;border-radius:99px;">Required</span>':'<span class="optional-pill">optional</span>'}
        </div>
        <h2 style="margin-bottom:12px;">${esc(unit.title)}</h2>
        <p style="color:var(--medium-grey);font-size:14px;max-width:480px;margin:0 auto 24px;">Complete this assessment to test your understanding. ${unit.mandatory?'This is required for your certificate.':'This is optional but recommended.'}</p>
        ${unit.lmsUrl?`<a href="${esc(unit.lmsUrl)}" target="_blank" class="btn btn--primary" style="display:inline-flex;"><span class="material-symbols-outlined" style="font-size:18px;">open_in_new</span> Open in LMS</a>`:'<div style="color:var(--medium-grey);font-size:13px;">Assessment will load from Open edX when connected</div>'}
      </div>`;
  }

  // html / discussion / default
  return `
    <div style="background:var(--white);border:1px solid var(--border);border-radius:12px;padding:40px;margin-bottom:24px;">
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px;">
        <span class="type-icon ${typeClass(unit.type)}" style="width:28px;height:28px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;"><span class="material-symbols-outlined" style="font-size:16px;">${typeIcon}</span></span>
        <span style="font-size:12px;font-weight:600;color:var(--medium-grey);text-transform:uppercase;">${typeLabel}</span>
        ${unit.mandatory?'<span style="font-size:11px;font-weight:600;color:var(--primary);background:rgba(171,59,120,0.1);padding:2px 8px;border-radius:99px;">Required</span>':'<span class="optional-pill">optional</span>'}
      </div>
      <h2 style="margin-bottom:12px;">${esc(unit.title)}</h2>
      <div style="color:var(--dark-grey);font-size:14px;line-height:1.7;">
        <p>This content will load from your Open edX instance when connected. For now, here's a placeholder for the reading material.</p>
        <p style="margin-top:12px;">Key topics covered in this section include frameworks, practical applications, and reflection exercises designed to deepen your understanding.</p>
      </div>
      ${unit.lmsUrl?`<a href="${esc(unit.lmsUrl)}" target="_blank" class="btn btn--outline btn--sm" style="display:inline-flex;margin-top:16px;"><span class="material-symbols-outlined" style="font-size:16px;">open_in_new</span> Open in LMS</a>`:''}
    </div>`;
}

export async function render(rootEl,{params}={}){
  const courseId=params?.courseId||'demo',unitId=params?.unitId||'u1',isDemo=courseId==='demo';

  rootEl.innerHTML=`<div class="player" style="display:flex;align-items:center;justify-content:center;min-height:60vh;"><div class="spinner"></div></div>`;

  // fetch course + outline
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

  const courseName=course?.name||'Freelancing 101';
  const all=flatUnits(modules);
  const currentIdx=all.findIndex(u=>u.id===unitId);
  const current=currentIdx>=0?all[currentIdx]:all[0]||{id:'u1',title:'Welcome',type:'video',mandatory:true,done:false};
  const prevUnit=currentIdx>0?all[currentIdx-1]:null;
  const nextUnit=currentIdx<all.length-1?all[currentIdx+1]:null;

  // compute progress
  let doneCount=all.filter(u=>u.done).length;
  const totalCount=all.length;
  const pct=totalCount?Math.round(doneCount/totalCount*100):0;

  // sidebar modules
  const sidebarHtml=modules.map((mod,mi)=>{
    const modUnits=mod.units;
    const modDone=modUnits.filter(u=>u.done).length;
    const hasActive=modUnits.some(u=>u.id===unitId);
    const unitsHtml=modUnits.map(u=>{
      const isActive=u.id===unitId;
      const isDone=u.done;
      const cls=['side-unit'];
      if(isDone) cls.push('is-done');
      if(isActive) cls.push('is-active');
      if(!u.mandatory) cls.push('is-optional');
      const icon=isDone?'check_circle':(isActive?'play_circle':iconForType(u.type));
      const iconStyle=isDone?'color:var(--success);':'';
      return `<div class="${cls.join(' ')}" data-unit-id="${esc(u.id)}" style="cursor:pointer;">
        <span class="type-icon ${typeClass(u.type)}" style="${iconStyle}"><span class="material-symbols-outlined" style="font-size:14px;">${icon}</span></span>
        <span class="side-unit__label">${esc(u.title)}</span>
        ${!u.mandatory?'<span class="optional-pill" style="font-size:9px;">opt</span>':''}
        ${u.mandatory&&!isDone?'<span style="width:5px;height:5px;border-radius:50%;background:var(--primary);flex-shrink:0;" title="Required"></span>':''}
      </div>`;
    }).join('');
    return `<div class="side-module${hasActive?' is-active-mod':''}">
      <div class="side-module__head" data-mod-idx="${mi}" style="cursor:pointer;">
        <span>${esc(mod.title)}</span>
        <span class="count">${modDone}/${modUnits.length}</span>
      </div>
      <div class="side-module__units" style="${hasActive||mi===0?'':'display:none;'}">${unitsHtml}</div>
    </div>`;
  }).join('');

  rootEl.innerHTML=`
  <div class="player">
    <div class="player__main">
      <div class="player__content" style="max-width:860px;margin:0 auto;">
        <div class="player__crumb" style="font-size:13px;color:var(--medium-grey);margin-bottom:14px;">
          <a href="#" id="backToCourse" style="color:var(--link);text-decoration:none;">${esc(courseName)}</a>
          <span class="material-symbols-outlined" style="font-size:14px;vertical-align:middle;">chevron_right</span>
          <span>${esc(current.title)}</span>
        </div>

        ${renderContentArea(current,courseName)}

        <div style="display:flex;gap:12px;margin-top:20px;flex-wrap:wrap;align-items:center;">
          <button class="btn btn--outline btn--sm" id="bookmarkBtn"><span class="material-symbols-outlined" style="font-size:16px;">bookmark</span> Bookmark</button>
          ${current.lmsUrl?`<a href="${esc(current.lmsUrl)}" target="_blank" class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">open_in_new</span> Open in LMS</a>`:''}
          ${!current.done?`<button class="btn btn--primary btn--sm" id="markDoneBtn"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Mark as complete</button>`:`<span style="display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--success);font-weight:600;"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Completed</span>`}
          <div style="flex:1;"></div>
          ${prevUnit?`<button class="btn btn--ghost btn--sm" id="prevBtn"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Previous</button>`:''}
          ${nextUnit?`<button class="btn btn--primary btn--sm" id="nextBtn">Next <span class="material-symbols-outlined" style="font-size:16px;">arrow_forward</span></button>`:`<button class="btn btn--primary btn--sm" id="finishBtn"><span class="material-symbols-outlined" style="font-size:16px;">workspace_premium</span> Finish course</button>`}
        </div>
      </div>
    </div>

    <div class="player__side">
      <div class="player__side-head">
        <a href="#" id="sideBackLink" class="btn btn--ghost btn--sm" style="margin-bottom:8px;"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Back to course</a>
        <h4>${esc(courseName)}</h4>
        <div style="display:flex;align-items:center;gap:8px;margin-top:8px;">
          <div class="progress" style="flex:1;"><div class="progress__fill" style="width:${pct}%;"></div></div>
          <span style="font-size:12px;font-weight:600;color:var(--primary);">${pct}%</span>
        </div>
        <div style="font-size:11px;color:var(--medium-grey);margin-top:4px;">${doneCount}/${totalCount} completed</div>
      </div>
      <div class="player__side-modules">
        <div class="cert-legend">
          <span><span class="dot-req" style="width:6px;height:6px;border-radius:50%;background:var(--primary);display:inline-block;"></span> Required</span>
          <span><span class="dot-opt" style="width:6px;height:6px;border-radius:50%;background:var(--border);border:1px solid var(--medium-grey);display:inline-block;"></span> Optional</span>
        </div>
        ${sidebarHtml}
      </div>
    </div>
  </div>`;

  // ── wire interactions ──
  const goToCourse=e=>{e.preventDefault();navigate('/course/'+encodeURIComponent(courseId));};
  rootEl.querySelector('#backToCourse')?.addEventListener('click',goToCourse);
  rootEl.querySelector('#sideBackLink')?.addEventListener('click',goToCourse);

  // sidebar unit click
  rootEl.querySelectorAll('.side-unit').forEach(el=>{
    el.addEventListener('click',()=>{
      const uid=el.dataset.unitId;
      if(uid) navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(uid));
    });
  });

  // sidebar module accordion
  rootEl.querySelectorAll('.side-module__head').forEach(head=>{
    head.addEventListener('click',()=>{
      const body=head.nextElementSibling;
      if(body) body.style.display=body.style.display==='none'?'':'none';
    });
  });

  // prev/next
  if(prevUnit) rootEl.querySelector('#prevBtn')?.addEventListener('click',()=>navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(prevUnit.id)));
  if(nextUnit) rootEl.querySelector('#nextBtn')?.addEventListener('click',()=>navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(nextUnit.id)));
  rootEl.querySelector('#finishBtn')?.addEventListener('click',()=>navigate('/course/'+encodeURIComponent(courseId)));

  // mark complete
  rootEl.querySelector('#markDoneBtn')?.addEventListener('click',async()=>{
    const btn=rootEl.querySelector('#markDoneBtn');
    btn.disabled=true;
    btn.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">hourglass_empty</span> Saving…';
    try{await markComplete(current.id);}catch(e){console.warn('[unit] mark complete:',e);}
    current.done=true;
    btn.outerHTML='<span style="display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--success);font-weight:600;"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Completed</span>';
    // update sidebar
    const sideUnit=rootEl.querySelector(`.side-unit[data-unit-id="${CSS.escape(current.id)}"]`);
    if(sideUnit){sideUnit.classList.add('is-done');sideUnit.querySelector('.material-symbols-outlined').textContent='check_circle';sideUnit.querySelector('.material-symbols-outlined').style.color='var(--success)';}
    // update progress bar
    doneCount++;
    const newPct=totalCount?Math.round(doneCount/totalCount*100):0;
    const fill=rootEl.querySelector('.player__side-head .progress__fill');
    if(fill) fill.style.width=newPct+'%';
    const pctLabel=rootEl.querySelector('.player__side-head span[style*="font-weight:600"]');
    // auto-advance after short delay
    if(nextUnit) setTimeout(()=>navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(nextUnit.id)),800);
  });

  // bookmark
  rootEl.querySelector('#bookmarkBtn')?.addEventListener('click',()=>{
    const btn=rootEl.querySelector('#bookmarkBtn');
    btn.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">bookmark_added</span> Bookmarked';
    btn.style.color='var(--primary)';
    btn.style.borderColor='var(--primary)';
    setTimeout(()=>{btn.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">bookmark</span> Bookmark';btn.style.color='';btn.style.borderColor='';},2000);
  });
}
