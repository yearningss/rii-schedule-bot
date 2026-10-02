const {chromium} = require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true, channel:process.env.BROWSER_CHANNEL || undefined});
 for(const scheme of ['light','dark']) for(const width of [320,390,840]) {
  const page=await browser.newPage({viewport:{width,height:900},colorScheme:scheme,serviceWorkers:'block'});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('https://telegram.org/**',r=>r.fulfill({body:''}));
  const day={1:{isDouble:true,subj1:'Математический анализ',subj2:'Физика',aud1:'211',aud2:'312',teacher1:'Иванов И. И.',teacher2:'Петров П. П.'},2:{subj1:'Информационные технологии',aud1:'401'}};
  const week=Object.fromEntries([1,2,3,4,5,6].map(d=>[d,day]));
  await page.route('**/api/**',r=>{
   const url=r.request().url(); const data=url.includes('/api/groups')?[{id:1,name:'ИВТ-61',course:1},{id:2,name:'Э-21',course:2}]:url.includes('/api/schedule')?{weekNumber:1,scheduleData:{1:week,2:week},paraTimes:{}}:{};
   return r.fulfill({json:data});
  });
  await page.goto(process.env.BASE_URL || 'http://127.0.0.1:8765/');
  await page.locator('.para-card').first().waitFor();
  assert.equal(await page.locator('.para-card').count(),2);
  if (width < 600) {
   assert.ok((await page.locator('.app-header').boundingBox()).height < 190, 'Шапка должна оставлять место расписанию');
   assert.ok((await page.locator('.para-card').nth(1).boundingBox()).height < 160, 'Обычная карточка должна помещаться компактно');
   assert.ok((await page.locator('.app-footer').boundingBox()).height < 84, 'Фильтр подгруппы не должен перекрывать расписание');
  }

  await page.locator('[data-sg="1"]').click();
  assert.equal(await page.locator('#scheduleCards').getByText('Физика',{exact:true}).count(),0);
  await page.locator('[data-sg="0"]').click();
  await page.locator('#week2Btn').click();
  await page.locator('[data-day="2"]').click();
  await page.locator('#groupSelectBtn').click();
  await page.locator('#groupSearchInput').fill('Э-21');
  assert.equal(await page.locator('.group-item-btn').count(),1);
  await page.locator('#closeModalBtn').click();
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  assert.deepEqual(errors,[]);
  if (process.env.OUTPUT_DIR) await page.screenshot({path:require("node:path").join(process.env.OUTPUT_DIR, `mini-app-${scheme}-${width}.png`),fullPage:true});
  console.log(`УСПЕХ Mini App ${scheme} ${width}`);await page.close();
 }
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
