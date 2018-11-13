const puppeteer = require('puppeteer');
const path = require('path');
const dotenv_path = path.resolve(process.cwd(), '../.env');
require('dotenv').config({ path: dotenv_path });

const PAL_ID = process.env.PAL_USER_ID;
const PAL_PASSWORD = process.env.PAL_PASSWORD;
const BUTTON_XPATH = "//a[contains(.,'ログイン')]";

async function waitUntilLoad(page, asyncFunc) {
  let loadPromise = page.waitForNavigation({waitUntil: "domcontentloaded"});
  await asyncFunc(page);
  await loadPromise;
}

async function goto(page, url) {
  await waitUntilLoad(page, async (page) => page.goto(url));
}

async function fillIn(page, selector, value) {
  await page.focus(selector);
  await page.type(selector, value);
}

async function login(page) {
  await goto(page, 'https://shop.pal-system.co.jp/iplg/login.htm');
  await fillIn(page, "input[name=S9_]", PAL_ID);
  await fillIn(page, "input[id=password]", PAL_PASSWORD);
  await waitUntilLoad(page, async () => (await page.$x(BUTTON_XPATH))[0].click());
}

async function scrapeDeliveryDates(page) {
  await goto(page, 'https://shop.pal-system.co.jp/ipsc/restTermEntry.htm');
  await goto(page, 'https://shop.pal-system.co.jp/ipsc/restTermInput.htm');
  const result = await page.evaluate(scanDeliveries);
  return result;
}

function scanDeliveries() {
  const titles = [...document.querySelectorAll('.list-input.orderRest .col.title')].map((node) => node.textContent);
  const regex = /(\d+月.+?)　(\d+)月(\d+)日/;
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth() + 1;
  return titles.map((title) => {
    const m = regex.exec(title);
    const month = parseInt(m[2]);
    const year = month < currentMonth ? currentYear + 1 : currentYear;
    return {name: m[1], deliveryDate: `${year}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}`};
  });
}

function squeeze(str) {
  return str.replace(/[\n\s]+/g, ' ').trim();
}

function parseIntWithComma(str) {
  return parseInt(str.replace(/,/g, ''))
}

async function scrapeLatestOrder(page) {
  await goto(page, 'https://shop.pal-system.co.jp/pal/OrderReferenceDirect.do');
  const title = await page.$eval('.section.record > h2', (node) => node.textContent );
  const m = /(\d+月\d回)/.exec(title);
  const name = m[1];
  const rows = await page.$x("//table[contains(@class,'order-table1')]/tbody/tr[td[contains(@class,'item')]]");
  const items = await Promise.all(rows.map(async (row) => {
    const name = squeeze(
      await row.$eval(
        'td.item',
        item => [].reduce.call(item.childNodes, (a, b) => (a + (b.nodeType === 3 ? b.textContent : '')), '')
      )
    );
    const quantity = parseIntWithComma(await row.$eval('.quantity', item => item.textContent));
    const price = parseIntWithComma(await row.$eval('.price', item => item.textContent));
    const total = parseIntWithComma(await row.$eval('.total', item => item.textContent));
    return { name, price, quantity, total };
  }));
  return { name, items };
}

async function scrapeAll(page) {
  await login(page);
  const deliveryDates = await scrapeDeliveryDates(page);
  const order = await scrapeLatestOrder(page);
  return { deliveryDates, order };
}

(async () => {
  // const browser = await puppeteer.launch();
  const browser = await puppeteer.launch({headless: false})
  const page = await browser.newPage();
  const result = await scrapeAll(page);
  console.log(JSON.stringify(result));
  await browser.close();
})();
