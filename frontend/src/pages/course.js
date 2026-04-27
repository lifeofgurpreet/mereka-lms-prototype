// Page: Course Detail — enrolled view with real modules, clickable units,
// mandatory/optional marks, completion %, and certificate download.
import { getCourse, getCourseOutline } from '../api/courses.js';
import { getEnrollment } from '../api/enrollment.js';
import { getCourseProgress } from '../api/progress.js';
import { listMyCertificates } from '../api/certificates.js';
import { navigate } from '../router/router.js';
import { getSession } from '../auth/session.js';

/* ── helpers ───────────────────────────────────────────────── */
function esc(s){return(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;');}
function iconForType(t){return{video:'play_circle',html:'description',problem:'quiz',discussion:'forum',vertical:'view_agenda',sequential:'folder_open',openassessment:'edit_note'}[t]||'article';}
function typeClass(t){return{video:'t-video',html:'t-doc',problem:'t-quiz',discussion:'t-disc',openassessment:'t-assign'}[t]||'t-doc';}
function durLabel(m){if(!m)return'';if(m<60)return m+' min';const h=Math.floor(m/60),r=m%60;return r?h+'h '+r+'m':h+'h';}

/* ── mock outline ──────────────────────────────────────────── */
function buildMockOutline(enrolled){
  const done=enrolled; // if enrolled, simulate partial progress
  return [
    {id:'ch1',title:'Module 1 — Getting started',units:[
      {id:'u1',title:'Welcome & orientation',type:'video',mandatory:true,done:done,duration:12,lmsUrl:null},
      {id:'u2',title:'Course overview & objectives',type:'html',mandatory:true,done:done,duration:8,lmsUrl:null},
      {id:'u3',title:'Self-assessment quiz',type:'problem',mandatory:true,done:done,duration:5,lmsUrl:null},
    ]},
    {id:'ch2',title:'Module 2 — Core concepts',units:[
      {id:'u4',title:'Key frameworks & models',type:'video',mandatory:true,done:done,duration:18,lmsUrl:null},
      {id:'u5',title:'Case study: Real-world application',type:'html',mandatory:true,done:done,duration:12,lmsUrl:null},
      {id:'u6',title:'Discussion: Share your experience',type:'discussion',mandatory:false,done:false,duration:10,lmsUrl:null},
      {id:'u7',title:'Module checkpoint',type:'problem',mandatory:true,done:done,duration:8,lmsUrl:null},
    ]},
    {id:'ch3',title:'Module 3 — Practical skills',units:[
      {id:'u8',title:'Hands-on workshop',type:'video',mandatory:true,done:done,duration:22,lmsUrl:null},
      {id:'u9',title:'Supplementary reading',type:'html',mandatory:false,done:false,duration:15,lmsUrl:null},
      {id:'u10',title:'Practice exercise',type:'problem',mandatory:true,done:done,duration:10,lmsUrl:null},
      {id:'u11',title:'Peer assessment',type:'openassessment',mandatory:false,done:false,duration:20,lmsUrl:null},
    ]},
    {id:'ch4',title:'Module 4 — Advanced topics',units:[
      {id:'u12',title:'Deep dive lecture',type:'video',mandatory:true,done:done,duration:25,lmsUrl:null},
      {id:'u13',title:'Expert interview',type:'video',mandatory:false,done:false,duration:15,lmsUrl:null},
      {id:'u14',title:'Strategy planning worksheet',type:'html',mandatory:true,done:done,duration:12,lmsUrl:null},
      {id:'u15',title:'Module assessment',type:'problem',mandatory:true,done:done,duration:10,lmsUrl:null},
    ]},
    {id:'ch5',title:'Module 5 — Final project & certification',units:[
      {id:'u16',title:'Project brief & guidelines',type:'html',mandatory:true,done:done,duration:8,lmsUrl:null},
      {id:'u17',title:'Final project submission',type:'openassessment',mandatory:true,done:done,duration:45,lmsUrl:null},
      {id:'u18',title:'Course wrap-up',type:'video',mandatory:true,done:done,duration:10,lmsUrl:null},
      {id:'u19',title:'Final exam',type:'problem',mandatory:true,done:done,duration:20,lmsUrl:null},
      {id:'u20',title:'Bonus: Additional resources',type:'html',mandatory:false,done:false,duration:10,lmsUrl:null},
    ]},
  ];
}

/* ── parse real API blocks ─────────────────────────────────── */
function parseBlocksToOutline(data,completionMap){
  const blocks=data.blocks||{},rootId=data.root;
  if(!rootId||!blocks[rootId]) return null;
  const root=blocks[rootId];
  const chapters=(root.children||[]).map(c=>blocks[c]).filter(b=>b&&b.type==='chapter');
  if(!chapters.length) return null;
  return chapters.map((ch,ci)=>{
    const seqs=(ch.children||[]).map(s=>blocks[s]).filter(Boolean);
    const units=[];
    seqs.forEach((seq,si)=>{
      const verts=(seq.children||[]).map(v=>blocks[v]).filter(Boolean);
      if(verts.length){
        verts.forEach((v,vi)=>{
          const blockId=v.id||v.block_id||'';
          units.push({
            id:blockId,title:v.display_name||'Untitled',type:v.type||'vertical',
            mandatory:!v.graded?true:true, // all graded blocks are mandatory
            done:completionMap[blockId]||false,duration:0,
            lmsUrl:v.lms_web_url||null,
          });
        });
      } else {
        const blockId=seq.id||seq.block_id||'';
        units.push({
          id:blockId,title:seq.display_name||'Untitled',type:seq.type||'sequential',
          mandatory:true,done:completionMap[blockId]||false,duration:0,
          lmsUrl:seq.lms_web_url||null,
        });
      }
    });
    return {id:ch.id,title:ch.display_name||('Module '+(ci+1)),units};
  });
}

/* ── compute progress from modules ─────────────────────────── */
function computeProgress(modules){
  let tM=0,dM=0,tA=0,dA=0;
  for(const m of modules) for(const u of m.units){
    tA++; if(u.done) dA++;
    if(u.mandatory){tM++; if(u.done) dM++;}
  }
  return {totalMandatory:tM,doneMandatory:dM,totalAll:tA,doneAll:dA,pct:tM?Math.round(dM/tM*100):0};
}

/* find next incomplete mandatory unit */
function findNextUnit(modules){
  for(const m of modules) for(const u of m.units) if(!u.done&&u.mandatory) return u;
  for(const m of modules) for(const u of m.units) if(!u.done) return u;
  return modules[0]?.units[0]||null;
}

/* ── main render ───────────────────────────────────────────── */
export async function render(rootEl,{params}={}){
  const courseId=params?.courseId||'demo',isDemo=courseId==='demo';

  rootEl.innerHTML=`<div class="course" style="text-align:center;padding:80px 40px;"><div class="spinner" style="margin:0 auto;"></div><p style="margin-top:16px;color:var(--medium-grey);">Loading course…</p></div>`;

  // ── fetch course metadata ──
  let course=null;
  if(!isDemo){ try{course=await getCourse(courseId);}catch(e){console.warn('[course] fetch:',e);} }
  const name=course?.name||'Freelancing 101';
  const org=course?.org||'Soft skills & employability';
  const desc=course?.shortDescription||'Starting a new path in your life can be difficult, and if that path is freelancing, you might find yourself being lost. In this course, you\'ll be provided with everything you need to know.';
  const pacing=course?.pacing==='self'?'Self-paced':'Instructor-led';
  const effort=course?.effort||'8 weeks';
  const imgUrl=course?.image||'';

  // ── check enrollment ──
  const session=getSession();
  let isEnrolled=false, enrollData=null;
  if(session?.username&&!isDemo){
    try{enrollData=await getEnrollment(session.username,courseId);isEnrolled=!!enrollData;}catch(e){console.warn('[course] enrollment check:',e);}
  } else if(isDemo){isEnrolled=true;}

  // ── fetch outline ──
  let modules=null,outlineSource='mock';
  const completionMap={};
  if(!isDemo&&courseId){
    // try progress API for completion data
    if(isEnrolled){
      try{
        const prog=await getCourseProgress(courseId);
        if(prog?.section_scores){
          prog.section_scores.forEach(s=>{(s.subsections||[]).forEach(sub=>{
            if(sub.block_key) completionMap[sub.block_key]=sub.num_points_earned>0;
          });});
        }
      }catch(e){console.warn('[course] progress:',e);}
    }
    try{
      const bd=await getCourseOutline(courseId);
      const p=parseBlocksToOutline(bd,completionMap);
      if(p&&p.length){modules=p;outlineSource='api';}
    }catch(e){console.warn('[course] outline fail:',e);}
  }
  if(!modules) modules=buildMockOutline(isEnrolled);

  // ── check certificate ──
  let cert=null;
  if(isEnrolled&&session?.username){
    try{
      const certs=await listMyCertificates(session.username);
      if(Array.isArray(certs)) cert=certs.find(c=>c.course_id===courseId)||null;
    }catch(e){console.warn('[course] cert:',e);}
  }

  // ── compute stats ──
  const progress=computeProgress(modules);
  const isComplete=progress.pct===100;
  const hasCert=!!cert||isComplete;

  const heroStyle=imgUrl?`background-image:linear-gradient(0deg,rgba(26,22,35,0.75) 0%,rgba(26,22,35,0.3) 60%),url('${esc(imgUrl)}');background-size:cover;background-position:center;`:'';

  const totalUnits=modules.reduce((s,m)=>s+m.units.length,0);
  const totalVid=modules.reduce((s,m)=>s+m.units.filter(u=>u.type==='video').length,0);
  const totalRead=modules.reduce((s,m)=>s+m.units.filter(u=>u.type==='html').length,0);
  const totalQuiz=modules.reduce((s,m)=>s+m.units.filter(u=>u.type==='problem'||u.type==='openassessment').length,0);
  const totalOpt=modules.reduce((s,m)=>s+m.units.filter(u=>!u.mandatory).length,0);
  const totalDur=modules.reduce((s,m)=>s+m.units.reduce((s2,u)=>s2+(u.duration||0),0),0);

  // ── modules HTML ──
  const modulesHtml=modules.map((mod,mi)=>{
    const mandCt=mod.units.filter(u=>u.mandatory).length;
    const doneCt=mod.units.filter(u=>u.done).length;
    const modTotal=mod.units.length;
    const modPct=modTotal?Math.round(doneCt/modTotal*100):0;
    const totalDur=mod.units.reduce((s,u)=>s+(u.duration||0),0);
    const isOpen=mi===0||(isEnrolled&&doneCt<modTotal&&doneCt>0);

    const unitsHtml=mod.units.map(u=>{
      const doneC=u.done?' is-done':'';
      const optC=!u.mandatory?' is-optional':'';
      const icon=u.done?'check_circle':iconForType(u.type);
      const icoStyle=u.done?'color:var(--success);':'';
      const optPill=!u.mandatory?'<span class="optional-pill">optional</span>':'';
      const mDot=u.mandatory
        ?'<span class="dot-req" style="width:6px;height:6px;border-radius:50%;background:var(--primary);flex-shrink:0;" title="Required for certificate"></span>'
        :'<span class="dot-opt" style="width:6px;height:6px;border-radius:50%;background:var(--border);border:1px solid var(--medium-grey);flex-shrink:0;" title="Optional"></span>';
      const dur=u.duration?`<span class="curriculum-unit__dur">${durLabel(u.duration)}</span>`:'';
      const clickable=isEnrolled?'cursor:pointer;':'cursor:default;opacity:0.7;';
      const lockIcon=!isEnrolled?'<span class="material-symbols-outlined" style="font-size:14px;color:var(--medium-grey);">lock</span>':'';
      return `<div class="curriculum-unit${doneC}${optC}" data-unit-id="${esc(u.id)}" data-lms-url="${esc(u.lmsUrl||'')}" style="display:flex;align-items:center;gap:10px;padding:12px 16px;${clickable}">
        ${mDot}
        <span class="type-icon ${typeClass(u.type)}" style="${icoStyle}"><span class="material-symbols-outlined" style="font-size:16px;">${icon}</span></span>
        <span class="curriculum-unit__title" style="flex:1;min-width:0;">${esc(u.title)}</span>
        ${optPill}${dur}${lockIcon}
        ${isEnrolled?'<span class="curriculum-unit__chev material-symbols-outlined">chevron_right</span>':''}
      </div>`;
    }).join('');

    const modProgressBar=isEnrolled?`<div class="progress" style="height:4px;flex:0 0 60px;margin-left:auto;"><div class="progress__fill" style="width:${modPct}%;${modPct===100?' background:var(--success);':''}"></div></div>`:'';

    return `<div class="curriculum-module${isOpen?' is-open':''}" data-module-idx="${mi}">
      <div class="curriculum-module__head" style="display:flex;justify-content:space-between;align-items:center;padding:16px 20px;cursor:pointer;">
        <div style="display:flex;align-items:center;gap:12px;flex:1;min-width:0;">
          <h4 style="margin:0;font-size:15px;">${esc(mod.title)}</h4>
          <span class="chev material-symbols-outlined">expand_more</span>
        </div>
        <div class="curriculum-module__meta" style="display:flex;align-items:center;gap:8px;">
          <span style="font-size:12px;color:${doneCt===modTotal&&isEnrolled?'var(--success)':'var(--medium-grey)'};">${doneCt}/${modTotal}${isEnrolled?' done':''}</span>
          <span style="font-size:12px;color:var(--medium-grey);">·</span>
          <span style="font-size:12px;color:var(--medium-grey);">${mandCt} required</span>
          ${totalDur?`<span style="font-size:12px;color:var(--medium-grey);">· ${durLabel(totalDur)}</span>`:''}
          ${modProgressBar}
        </div>
      </div>
      <div class="curriculum-module__list">${unitsHtml}</div>
    </div>`;
  }).join('');

  // ── cert banner ──
  const certBanner=hasCert&&isEnrolled?`<div class="cert-banner" style="margin-bottom:20px;">
    <span class="material-symbols-outlined">workspace_premium</span>
    <div class="cert-banner__text">
      <strong>Congratulations! You've completed all required components.</strong>
      Your certificate is ready. Download it below or view it in your certificates page.
    </div>
  </div>`:'';

  // ── progress ring helper ──
  const ringSize=100,ringStroke=8,ringRadius=(ringSize-ringStroke)/2,ringCirc=2*Math.PI*ringRadius;
  const ringOffset=ringCirc-(progress.pct/100)*ringCirc;
  const ringColor=isComplete?'var(--success)':'var(--primary)';
  const progressRing=isEnrolled?`
    <div style="position:relative;width:${ringSize}px;height:${ringSize}px;margin:0 auto 16px;">
      <svg width="${ringSize}" height="${ringSize}" style="transform:rotate(-90deg);">
        <circle cx="${ringSize/2}" cy="${ringSize/2}" r="${ringRadius}" fill="none" stroke="var(--border)" stroke-width="${ringStroke}"/>
        <circle cx="${ringSize/2}" cy="${ringSize/2}" r="${ringRadius}" fill="none" stroke="${ringColor}" stroke-width="${ringStroke}" stroke-linecap="round" stroke-dasharray="${ringCirc}" stroke-dashoffset="${ringOffset}" style="transition:stroke-dashoffset .6s ease;"/>
      </svg>
      <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;flex-direction:column;">
        <span style="font-family:var(--font-display);font-weight:700;font-size:24px;color:${ringColor};">${progress.pct}%</span>
        <span style="font-size:10px;color:var(--medium-grey);">complete</span>
      </div>
    </div>`:'';

  // ── render page ──
  rootEl.innerHTML=`
  <div class="course">
    <div class="course__hero"${heroStyle?` style="${heroStyle}"`:''}>
      <div class="course__hero-body">
        <p style="font-size:13px;opacity:0.85;margin-bottom:4px;">${esc(org)}</p>
        <h1>${esc(name)}</h1>
        <p>${esc(desc)}</p>
        <div class="course__hero-meta">
          <span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">schedule</span> ${esc(effort)}</span>
          <span class="dot-sep">·</span>
          <span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">signal_cellular_alt</span> Beginner</span>
          <span class="dot-sep">·</span>
          <span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">groups</span> ${esc(pacing)}</span>
          <span class="dot-sep">·</span>
          <span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">translate</span> EN</span>
          ${isEnrolled?`<span class="dot-sep">·</span><span style="color:var(--success);font-weight:600;"><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">check_circle</span> Enrolled</span>`:''}
          ${isComplete?`<span class="dot-sep">·</span><span style="color:var(--success);font-weight:600;"><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">verified</span> Completed</span>`:''}
        </div>
      </div>
    </div>

    <div style="display:flex;gap:12px;margin-bottom:24px;flex-wrap:wrap;align-items:center;">
      ${isEnrolled?`
        ${!isComplete?`<button class="btn btn--primary" id="continueLearningBtn"><span class="material-symbols-outlined" style="font-size:18px;">play_arrow</span> Continue learning</button>`:''}
        ${isComplete?`<button class="btn btn--primary" id="downloadCertBtnTop"><span class="material-symbols-outlined" style="font-size:18px;">workspace_premium</span> Get certificate</button>`:''}
        <button class="btn btn--outline btn--sm" id="shareBtn"><span class="material-symbols-outlined" style="font-size:16px;">share</span> Share</button>
      `:`
        <button class="btn btn--primary" id="enrollBtn"><span class="material-symbols-outlined" style="font-size:18px;">school</span> Enroll now — Free</button>
        <button class="btn btn--outline btn--sm" id="shareBtn"><span class="material-symbols-outlined" style="font-size:16px;">share</span> Share</button>
      `}
      <button class="btn btn--ghost btn--sm" id="backBtn"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Back</button>
    </div>

    <div class="course__grid">
      <!-- LEFT COLUMN -->
      <div>
        ${certBanner}

        <section class="course__section">
          <h2>What you'll learn</h2>
          <ul class="course__learn">
            <li>Build a personal brand that attracts quality clients</li>
            <li>Set up contracts, invoicing, and payment flows</li>
            <li>Price your services for sustainable income</li>
            <li>Navigate client relationships and scope creep</li>
          </ul>
        </section>

        <section class="course__section">
          <h2>Course outline <span style="font-size:14px;font-weight:400;color:var(--medium-grey);">(${modules.length} modules · ${totalUnits} components)</span></h2>
          <div class="curriculum-legend">
            <span><span class="material-symbols-outlined">school</span> ${modules.length} modules</span>
            <span><span class="material-symbols-outlined">view_agenda</span> ${totalUnits} units</span>
            ${totalDur?`<span><span class="material-symbols-outlined">schedule</span> ${durLabel(totalDur)}</span>`:''}
            <span style="margin-left:auto;">
              <span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--primary);vertical-align:middle;"></span> Required
              <span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--border);border:1px solid var(--medium-grey);vertical-align:middle;margin-left:10px;"></span>
              <span class="opt-mark">Optional</span>
            </span>
          </div>
          ${modulesHtml}
        </section>
      </div>

      <!-- RIGHT COLUMN -->
      <div class="course__side">
        ${isEnrolled?`
        <div class="card" style="padding:24px;margin-bottom:16px;">
          <h3 style="margin:0 0 16px;font-size:16px;text-align:center;">Your progress</h3>
          ${progressRing}
          <div style="font-size:13px;color:var(--dark-grey);display:flex;flex-direction:column;gap:8px;">
            <div style="display:flex;justify-content:space-between;"><span>Required completed</span><span style="font-weight:600;color:${progress.doneMandatory===progress.totalMandatory?'var(--success)':'var(--off-black)'};">${progress.doneMandatory} / ${progress.totalMandatory}</span></div>
            <div style="display:flex;justify-content:space-between;"><span>Optional completed</span><span style="font-weight:600;">${progress.doneAll-progress.doneMandatory} / ${progress.totalAll-progress.totalMandatory}</span></div>
            <div style="display:flex;justify-content:space-between;"><span>Total completed</span><span style="font-weight:600;">${progress.doneAll} / ${progress.totalAll}</span></div>
          </div>
          ${isComplete?`
            <div style="margin-top:16px;padding-top:16px;border-top:1px solid var(--border);">
              <button class="btn btn--primary" id="downloadCertBtn" style="width:100%;justify-content:center;"><span class="material-symbols-outlined" style="font-size:18px;">workspace_premium</span> Download certificate</button>
              <button class="btn btn--outline btn--sm" id="viewCertBtn" style="width:100%;justify-content:center;margin-top:8px;"><span class="material-symbols-outlined" style="font-size:16px;">visibility</span> View certificate</button>
            </div>
          `:`
            <button class="btn btn--primary" id="continueBtn" style="width:100%;justify-content:center;margin-top:16px;"><span class="material-symbols-outlined" style="font-size:18px;">play_arrow</span> Continue learning</button>
          `}
        </div>`:''}

        <div class="card enroll-card">
          <h3 style="margin:0 0 12px;">Instructor</h3>
          <div style="display:flex;gap:12px;align-items:center;">
            <div class="avatar">AM</div>
            <div><strong>Aisha M.</strong><br/><span style="font-size:12px;color:var(--medium-grey);">Senior Consultant</span></div>
          </div>
        </div>

        <div class="card" style="padding:20px;margin-top:16px;">
          <h3 style="margin:0 0 8px;">Course includes</h3>
          <div style="font-size:13px;color:var(--dark-grey);display:flex;flex-direction:column;gap:8px;">
            ${totalVid?`<span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;color:var(--primary);">play_circle</span> ${totalVid} video lessons</span>`:''}
            ${totalRead?`<span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;color:var(--primary);">description</span> ${totalRead} readings & activities</span>`:''}
            ${totalQuiz?`<span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;color:var(--primary);">quiz</span> ${totalQuiz} quizzes & assessments</span>`:''}
            <span><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;color:var(--primary);">workspace_premium</span> Certificate of completion</span>
            ${totalOpt?`<span style="color:var(--medium-grey);"><span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;">info</span> ${totalOpt} optional components</span>`:''}
          </div>
        </div>

        ${!isEnrolled?`
        <div class="card enroll-card" style="margin-top:16px;">
          <div class="price" style="font-family:var(--font-display);font-weight:700;font-size:28px;margin-bottom:12px;">Free</div>
          <button class="btn btn--primary" id="enrollBtnSide" style="width:100%;justify-content:center;"><span class="material-symbols-outlined" style="font-size:18px;">school</span> Enroll now</button>
          <ul class="includes" style="list-style:none;padding:0;margin:16px 0 0;display:flex;flex-direction:column;gap:8px;font-size:13px;color:var(--dark-grey);">
            <li style="display:flex;align-items:center;gap:8px;"><span class="material-symbols-outlined" style="font-size:16px;color:var(--success);">check_circle</span> Full lifetime access</li>
            <li style="display:flex;align-items:center;gap:8px;"><span class="material-symbols-outlined" style="font-size:16px;color:var(--success);">check_circle</span> Access on mobile and desktop</li>
            <li style="display:flex;align-items:center;gap:8px;"><span class="material-symbols-outlined" style="font-size:16px;color:var(--success);">check_circle</span> Certificate upon completion</li>
          </ul>
        </div>`:''}
      </div>
    </div>

    <!-- Certificate Modal -->
    <div id="certModal" style="display:none;position:fixed;inset:0;z-index:1000;background:rgba(0,0,0,0.6);align-items:center;justify-content:center;">
      <div style="background:var(--white);border-radius:16px;max-width:800px;width:95%;max-height:90vh;overflow:auto;position:relative;">
        <button id="closeCertModal" style="position:absolute;top:16px;right:16px;background:none;border:none;cursor:pointer;z-index:2;"><span class="material-symbols-outlined" style="font-size:24px;color:var(--dark-grey);">close</span></button>
        <div style="margin:24px;border:3px solid var(--primary);border-radius:8px;padding:48px 56px;text-align:center;position:relative;overflow:hidden;">
          <div style="width:72px;height:72px;margin:0 auto 20px;background:var(--brand-gradient);border-radius:50%;display:flex;align-items:center;justify-content:center;color:var(--white);"><span class="material-symbols-outlined" style="font-size:36px;">workspace_premium</span></div>
          <div style="font-family:var(--font-display);font-weight:500;font-size:13px;text-transform:uppercase;letter-spacing:2px;color:var(--primary);margin-bottom:10px;">Certificate of Completion</div>
          <h1 style="font-size:36px;margin-bottom:24px;font-family:var(--font-display);background:var(--brand-gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;">Mereka Academy</h1>
          <p style="font-family:var(--font-display);font-weight:700;font-size:28px;color:var(--off-black);border-bottom:1px solid var(--border);padding-bottom:16px;margin-bottom:20px;display:inline-block;padding:0 40px 16px;">${esc(session?.username||'Learner')}</p>
          <p style="color:var(--dark-grey);font-size:14px;margin-bottom:8px;">has successfully completed all required components of</p>
          <p style="font-family:var(--font-display);font-weight:600;font-size:20px;color:var(--off-black);margin-bottom:32px;">${esc(name)}</p>
          <div style="display:flex;justify-content:center;gap:24px;font-size:13px;color:var(--medium-grey);margin-bottom:16px;">
            <span>${progress.doneMandatory}/${progress.totalMandatory} required · ${progress.doneAll}/${progress.totalAll} total</span>
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:32px;margin-top:16px;">
            <div style="text-align:center;"><div style="font-family:var(--font-display);font-weight:600;font-size:15px;border-top:1px solid var(--border);padding-top:8px;">Mereka Academy</div><div style="font-size:12px;color:var(--medium-grey);margin-top:2px;">Issuing Institution</div></div>
            <div style="text-align:center;"><div style="font-family:var(--font-display);font-weight:600;font-size:15px;border-top:1px solid var(--border);padding-top:8px;">${new Date().toLocaleDateString('en-US',{year:'numeric',month:'long',day:'numeric'})}</div><div style="font-size:12px;color:var(--medium-grey);margin-top:2px;">Date of Completion</div></div>
          </div>
        </div>
        <div style="display:flex;gap:12px;justify-content:center;padding:0 24px 24px;">
          <button class="btn btn--primary" id="certDownloadBtn"><span class="material-symbols-outlined" style="font-size:18px;">download</span> Download PDF</button>
          <button class="btn btn--outline" id="certShareBtn"><span class="material-symbols-outlined" style="font-size:18px;">share</span> Share to LinkedIn</button>
        </div>
      </div>
    </div>
  </div>`;

  wireInteractions(rootEl,courseId,modules,isEnrolled,cert);
}

/* ── interactions ──────────────────────────────────────────── */
function wireInteractions(rootEl,courseId,modules,isEnrolled,cert){
  // Module accordion
  rootEl.querySelectorAll('.curriculum-module__head').forEach(head=>{
    head.addEventListener('click',()=>head.closest('.curriculum-module').classList.toggle('is-open'));
  });

  // Clickable units → navigate to unit player (enrolled only)
  if(isEnrolled){
    rootEl.querySelectorAll('.curriculum-unit').forEach(unit=>{
      unit.addEventListener('click',()=>{
        const uid=unit.dataset.unitId;
        if(uid) navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(uid));
      });
    });
  }

  // Enroll buttons
  const goEnroll=()=>navigate('/checkout/'+encodeURIComponent(courseId));
  rootEl.querySelector('#enrollBtn')?.addEventListener('click',goEnroll);
  rootEl.querySelector('#enrollBtnSide')?.addEventListener('click',goEnroll);

  // Continue learning → first incomplete mandatory unit
  const goNext=()=>{
    const next=findNextUnit(modules);
    // For completed courses, start from the beginning for review
    const target=next||modules[0]?.units[0];
    if(target) navigate('/learn/'+encodeURIComponent(courseId)+'/'+encodeURIComponent(target.id));
  };
  rootEl.querySelector('#continueBtn')?.addEventListener('click',goNext);
  rootEl.querySelector('#continueLearningBtn')?.addEventListener('click',goNext);

  // Back
  rootEl.querySelector('#backBtn')?.addEventListener('click',()=>history.back());

  // Share
  rootEl.querySelector('#shareBtn')?.addEventListener('click',()=>{
    if(navigator.share){navigator.share({title:document.title,url:window.location.href});}
    else{navigator.clipboard.writeText(window.location.href).then(()=>{
      const b=rootEl.querySelector('#shareBtn');
      if(b){b.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">check</span> Copied!';setTimeout(()=>{b.innerHTML='<span class="material-symbols-outlined" style="font-size:16px;">share</span> Share';},2000);}
    });}
  });

  // Certificate modal
  const modal=rootEl.querySelector('#certModal');
  const openM=()=>{if(modal) modal.style.display='flex';};
  const closeM=()=>{if(modal) modal.style.display='none';};
  rootEl.querySelector('#viewCertBtn')?.addEventListener('click',openM);
  rootEl.querySelector('#downloadCertBtn')?.addEventListener('click',openM);
  rootEl.querySelector('#downloadCertBtnTop')?.addEventListener('click',openM);
  rootEl.querySelector('#closeCertModal')?.addEventListener('click',closeM);
  if(modal) modal.addEventListener('click',e=>{if(e.target===modal)closeM();});

  // Download cert (if real cert URL, redirect; otherwise simulate)
  rootEl.querySelector('#certDownloadBtn')?.addEventListener('click',()=>{
    if(cert?.download_url&&cert.download_url!=='#'){
      window.open(cert.download_url,'_blank');
    } else {
      const btn=rootEl.querySelector('#certDownloadBtn');
      btn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px;">check</span> Downloaded!';
      btn.disabled=true;
      setTimeout(()=>{btn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px;">download</span> Download PDF';btn.disabled=false;},2000);
    }
  });

  // Share cert to LinkedIn
  rootEl.querySelector('#certShareBtn')?.addEventListener('click',()=>{
    const linkedInUrl='https://www.linkedin.com/sharing/share-offsite/?url='+encodeURIComponent(window.location.href);
    window.open(linkedInUrl,'_blank','width=600,height=400');
  });
}
