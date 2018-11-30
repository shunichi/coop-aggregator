const puppeteer = require('puppeteer');

async function waitUntilLoad(page, asyncFunc) {
  let loadPromise = page.waitForNavigation({waitUntil: "domcontentloaded"});
  await asyncFunc(page);
  await loadPromise;
}

async function goto(page, url) {
  await page.goto(url, {waitUntil: 'domcontentloaded'});
}

async function fillIn(page, selector, value) {
  await page.focus(selector);
  await page.type(selector, value);
}

async function exists(page, baseElemHandle, xpath) {
  const elems = await baseElemHandle.$x(xpath);
  return elems.length > 0;
}

async function login(page, {id, password}) {
  const BUTTON_XPATH = "//a[contains(.,'ログイン')]";
  await goto(page, 'https://shop.pal-system.co.jp/iplg/login.htm');
  await page.waitForSelector("input[name=S9_]", {timeout: 5000});
  await fillIn(page, "input[name=S9_]", id);
  await fillIn(page, "input[id=password]", password);
  await waitUntilLoad(page, async () => (await page.$x(BUTTON_XPATH))[0].click());
}

async function scrapeDeliveryDates(page) {
  await goto(page, 'https://shop.pal-system.co.jp/ipsc/restTermEntry.htm');
  await goto(page, 'https://shop.pal-system.co.jp/ipsc/restTermInput.htm');
  const result = await page.evaluate(scanDeliveries);
  return result.map((data) => {
    data['name'] = addYearToName(data['name']);
    return data;
  });
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

function addYearToName(name) {
  const m = /^(\d+)月/.exec(name);
  if (m) {
    const month = parseInt(m[1]);
    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonth = today.getMonth() + 1;
    const year = (month < currentMonth) ? currentYear + 1 : currentYear;
    return `${year}年${name}`;
  } else {
    return name;
  }
}

function squeeze(str) {
  return str.replace(/[\n\s]+/g, ' ').trim();
}

function parseIntWithComma(str) {
  return parseInt(str.replace(/,/g, ''))
}

function makeChildren(items) {
  const result = [];
  let lastTopLevelItem = null;
  items.forEach((item) => {
    if (item == null) return;
    if (item.isChild) {
      lastTopLevelItem['children'] = lastTopLevelItem['children'] || [];
      delete item.isChild;
      lastTopLevelItem.children.push(item)
    } else {
      lastTopLevelItem = item;
      delete item.isChild;
      result.push(item);
    }
  });
  return result;
}

async function scrapeNextOrder(page) {
  await goto(page, 'https://shop.pal-system.co.jp/pal/OrderConfirm.do');
  const month = await page.$eval('.shop-info .month .num', node => node.textContent);
  const times = await page.$eval('.shop-info .times .num', node => node.textContent);
  const name = addYearToName(`${month.trim()}月${times.trim()}回`);
  await page.waitForSelector('.order-table1 tr.detail');
  const rows = await page.$$('.order-table1 tr.detail');
  const flatItems = await Promise.all(rows.map(async(row) => {
    const isChild = await page.evaluate((node) => node.classList.contains('set-child'), row);
    let name = null;
    // 値引きの行だと .name がないので無視する
    try {
      name = squeeze(await row.$eval('.name', node => node.textContent)).replace(/【毎週】\s*/, '【毎週】');
    } catch (e) {
      return null;
    }
    const cold = await exists(page, row, ".//img[@alt='お届け状態 冷蔵']");
    const frozen = await exists(page, row, ".//img[@alt='お届け状態 冷凍']");
    const quantity = parseInt(await row.$eval('.quantity input.orderQty', node => node.value));
    const price = parseInt((await row.$eval('.price-small', node => node.textContent)).replace(/[^\d]/g, ''));
    const total = parseInt((await row.$eval('.total', node => node.textContent)).replace(/[^\d]/g, ''));
    const imageUrl = await row.$eval('.photo img', node => node.src);
    return { isChild, name, price, quantity, total, imageUrl, cold, frozen };
  }));
  const items = makeChildren(flatItems);
  return { name, items };
}

async function scrapeLatestOrder(page) {
  await goto(page, 'https://shop.pal-system.co.jp/pal/OrderReferenceDirect.do');
  const title = await page.$eval('.section.record > h2', (node) => node.textContent );
  const m = /(\d+月\d回)/.exec(title);
  const name = addYearToName(m[1]);
  const rows = await page.$x("//table[contains(@class,'order-table1')]/tbody/tr[td[contains(@class,'item')]]");
  const flatItems = await Promise.all(rows.map(async (row) => {
    const isChild = await page.evaluate((node) => node.classList.contains('set-child'), row);
    const name = squeeze(
      (await row.$eval(
        'td.item',
        item => [].reduce.call(item.childNodes, (a, b) => (a + (b.nodeType === 3 ? b.textContent : '')), '')
      )).replace('【定期お届け】', '')
    );
    const quantity = parseIntWithComma(await row.$eval('.quantity', item => item.textContent));
    const price = parseIntWithComma(await row.$eval('.price', item => item.textContent));
    const total = parseIntWithComma(await row.$eval('.total', item => item.textContent));
    return { isChild, name, price, quantity, total };
  }));
  const items = makeChildren(flatItems);
  return { name, items };
}

async function scrapeAll(page, credential) {
  await login(page, credential);
  const deliveryDates = await scrapeDeliveryDates(page);
  const nextOrder = await scrapeNextOrder(page);
  const order = await scrapeLatestOrder(page);
  const orders = [order, nextOrder];
  return { deliveryDates, orders };
}

async function getBrowserPage(local) {
  // Launch headless Chrome. Turn off sandbox so Chrome can run under root.
  const options = local ? { headless: false } : { args: ['--no-sandbox'] };
  const browser = await puppeteer.launch(options);
  return { browser: browser, page: await browser.newPage() };
}

exports.palSystem = async (req, res) => {
  const { browser, page } = await getBrowserPage(req.body.local);
  const result = await scrapeAll(page, { id: req.body.id, password: req.body.password });

  res.set('Content-Type', 'application/json');
  res.send(result);
  if (req.body.local) {
    await browser.close();
  }
};
