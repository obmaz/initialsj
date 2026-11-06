// Chromium touchscreen review of the actual exported game, in a phone landscape viewport.
const {chromium}=require('playwright');
const path=require('path');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader']});
 try{
  const page=await browser.newPage({viewport:{width:896,height:414},hasTouch:true,deviceScaleFactor:1});
  const errors=[];
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text())});
  await page.goto(process.env.INITIALSJ_REVIEW_URL||'http://127.0.0.1:8787/');
  await page.waitForFunction(()=>typeof engine!=='undefined'&&!document.querySelector('#status'),{},{timeout:60000});
  const point=(x,y)=>({x:80+x*0.575,y:y*0.575});
  await page.touchscreen.tap(point(420,590).x,point(420,590).y);
  // Tap all three cards in the real exported UI, returning to the hatch for the drive.
  for (const x of [590,910,270]) {
   await page.touchscreen.tap(point(x,596).x,point(x,596).y);
   await page.waitForTimeout(300);
  }
  await page.screenshot({path:path.resolve(__dirname,'../docs/menu-mobile.png')});
  await page.touchscreen.tap(point(1050,670).x,point(1050,670).y);
  await page.waitForTimeout(10000);
  const cdp=await page.context().newCDPSession(page);
  const touch=(type,points)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points.map(([id,x,y])=>({id,...point(x,y)}))});
  await touch('touchStart',[[1,1150,617]]);
  await page.waitForTimeout(7000);
  await touch('touchStart',[[1,1150,617],[2,213,616]]);
  await page.waitForTimeout(350);
  await page.screenshot({path:path.resolve(__dirname,'../docs/tour/mobile-gas.png')});
  await touch('touchEnd',[]);
  await touch('touchStart',[[3,1216,493]]);
  await page.waitForTimeout(2500);
  await page.screenshot({path:path.resolve(__dirname,'../docs/tour/mobile-nitro.png')});
  await touch('touchStart',[[3,1216,493],[4,1010,617]]);
  await page.waitForTimeout(1800);
  await page.screenshot({path:path.resolve(__dirname,'../docs/tour/mobile-brake.png')});
  await touch('touchEnd',[]);
  await page.touchscreen.tap(point(847,45).x,point(847,45).y);
  await page.waitForTimeout(600);
  await page.screenshot({path:path.resolve(__dirname,'../docs/tour/mobile-pause.png')});
  await page.touchscreen.tap(point(640,525).x,point(640,525).y);
  await page.waitForTimeout(600);
  const viewport=await page.evaluate(()=>({width:canvas.width,height:canvas.height,horizontalOverflow:document.documentElement.scrollWidth>innerWidth}));
  console.log(JSON.stringify({url:page.url(),viewport,errors}));
  if(errors.length||viewport.horizontalOverflow)process.exitCode=1;
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exit(1)});
