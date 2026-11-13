// 실제 터치 입력 뒤 GDScript의 읽기 전용 상태와 물리 반응을 확인한다.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const output=path.resolve(__dirname,'../build/reports/touch');
const timeout=Number(process.env.INITIALSJ_TOUCH_TIMEOUT_MS||180000);
fs.mkdirSync(output,{recursive:true});
(async()=>{
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader']});
  try {
    const page=await browser.newPage({viewport:{width:896,height:414},hasTouch:true,deviceScaleFactor:1});
    const errors=[];
    page.on('pageerror',error=>errors.push(String(error)));
    page.on('console',message=>{if(message.type()==='error')errors.push(message.text())});
    const url=new URL(process.env.INITIALSJ_TEST_URL||'http://127.0.0.1:8787/');
    url.searchParams.set('diagnostics','1');
    await page.goto(url.href);
    await page.waitForFunction(()=>typeof window.initialsjReadDiagnostics==='function'&&!document.querySelector('#status'),null,{timeout});
    const read=()=>page.evaluate(()=>new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>reject(new Error('게임 진단 응답 없음')),5000);
      window.initialsjReadDiagnostics(json=>{clearTimeout(timer);resolve(JSON.parse(json));});
    }));
    async function until(predicate,label,limit=timeout) {
      const deadline=Date.now()+limit;
      let state;
      do {
        state=await read();
        if(predicate(state)){console.log(label+": PASS");return state;}
        await page.waitForTimeout(100);
      }while(Date.now()<deadline);
      throw new Error(label+': '+JSON.stringify(state));
    }
    let state=await until(s=>s.schema===1&&s.state==='menu','실제 메인 메뉴');
    const initialFrame=state.frame;
    await until(s=>s.frame>initialFrame,'게임 프레임 진행');
    async function point(name,index) {
      const s=await read();
      const rect=index===undefined?s.targets[name]:s.targets[name][index];
      assert(rect&&rect.width>0&&rect.height>0,'실제 HUD 입력 영역 '+name);
      const box=await page.locator('#canvas').boundingBox();
      const pixels=await page.locator('#canvas').evaluate(canvas=>({width:canvas.width,height:canvas.height}));
      const x=s.ui_offset.x+(rect.x+rect.width/2)*s.ui_scale;
      const y=s.ui_offset.y+(rect.y+rect.height/2)*s.ui_scale;
      const t=s.screen_transform;
      return {
        x:box.x+(t[0]*x+t[2]*y+t[4])*box.width/pixels.width,
        y:box.y+(t[1]*x+t[3]*y+t[5])*box.height/pixels.height,
      };
    }
    async function tap(name,index) {const p=await point(name,index);await page.touchscreen.tap(p.x,p.y);}
    await tap('home_settings');
    state=await until(s=>s.state==='settings','설정 진입');
    if(state.auto_accelerate)await tap('settings_auto');
    await until(s=>!s.auto_accelerate,'터치로 자동 가속 끄기');
    await tap('settings_close');
    await until(s=>s.state==='menu','설정 닫기');
    await tap('home_tour');
    state=await until(s=>s.state==='ready','차량 선택 진입');
    assert(state.targets.garage_cards.length>=4);
    for(let i=0;i<state.targets.garage_cards.length;i++) {
      await tap('garage_cards',i);
      await until(s=>s.selected_vehicle===i,'차량 선택 '+i);
    }
    await tap('garage_cards',0);
    await until(s=>s.selected_vehicle===0,'주행 차량 선택');
    await page.screenshot({path:path.join(output,'menu-mobile.png')});
    await tap('garage_start');
    await until(s=>s.state==='racing','카운트다운 뒤 실제 주행');
    const cdp=await page.context().newCDPSession(page);
    async function touch(type,items) {
      const points=[];
      for(const [id,name] of items)points.push({id,...await point(name)});
      await cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});
    }
    const before=(await read()).speed_mps;
    await touch('touchStart',[[1,'gas']]);
    await until(s=>s.pedals.gas&&s.throttling&&s.speed_mps>before+3,'가스 입력과 실제 가속');
    await until(s=>s.speed_mps>28,'니트로 최소 속도 확보',60000);
    await touch('touchStart',[[1,'gas'],[2,'brake']]);
    const braking=await until(s=>s.pedals.gas&&s.pedals.brake&&s.braking,'두 손가락 동시 페달');
    await touch('touchEnd',[]);
    await touch('touchStart',[[2,'brake']]);
    await until(s=>!s.pedals.gas&&s.braking&&s.speed_mps<braking.speed_mps-1,'브레이크 실제 감속');
    await page.screenshot({path:path.join(output,'mobile-brake.png')});
    await touch('touchEnd',[]);
    await touch('touchStart',[[1,'gas']]);
    await until(s=>s.speed_mps>28,'니트로 전 재가속',60000);
    await touch('touchStart',[[1,'gas'],[3,'nitro']]);
    await until(s=>s.pedals.gas&&s.pedals.nitro&&s.nitro_active,'실제 니트로 작동');
    await page.screenshot({path:path.join(output,'mobile-nitro.png')});
    await touch('touchEnd',[]);
    await until(s=>!s.pedals.gas&&!s.pedals.brake&&!s.pedals.nitro,'손을 떼면 입력 해제');
    await tap('pause');
    await until(s=>s.state==='paused','일시정지');
    await page.screenshot({path:path.join(output,'mobile-pause.png')});
    await tap('resume');
    await until(s=>s.state==='racing','실제 재개');
    assert.deepEqual(errors,[]);
    assert(!await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth));
    console.log('실제 모바일 메뉴·4차량 선택·가속·동시 페달·감속·니트로·일시정지/재개: PASS');
  }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
