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

async function login(page, {id, password}) {
  await goto(page, 'https://weekly.coopdeli.jp/order/index.html');

  const html = await page.evaluate(() => document.body.innerHTML);
  if (/メンテナンスのお知らせ/.test(html))
    return false;

  await page.waitForSelector('input[name=j_username]', {timeout: 5000});
  await fillIn(page, 'input[name=j_username]', id);
  await fillIn(page, 'input[name=j_password]', password);
  await waitUntilLoad(page, async () => page.click('.FW_submitLink'));
  await page.waitForSelector('#accountMyPage');
  return true;
}

function makeDateString(month, day) {
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth() + 1;
  const year = month < currentMonth ? currentYear + 1 : currentYear;
  return `${year}-${(month + '').padStart(2, '0')}-${(day + '').padStart(2, '0')}`
}

function squeeze(str) {
  return str.replace(/[\n\s]+/g, ' ').trim();
}

function parseIntWithComma(str) {
  return parseInt(str.replace(/,/g, ''))
}

async function textValue(page, baseElemHandle, xpath) {
  const elemHandle = (await baseElemHandle.$x(xpath))[0];
  return await page.evaluate(node => node.textContent, elemHandle);
}

async function intValue(page, baseElemHandle, xpath) {
  const text = await textValue(page, baseElemHandle, xpath);
  return parseIntWithComma(text);
}

async function inputIntValue(page, baseElemHandle, xpath) {
  const elemHandle = (await baseElemHandle.$x(xpath))[0];
  const text = await page.evaluate(node => node.value, elemHandle);
  return parseInt(text);
}

async function exists(page, baseElemHandle, xpath) {
  const elems = await baseElemHandle.$x(xpath);
  return elems.length > 0;
}

async function scrapeAll(page, credential) {
  if (await login(page, credential)) {
    const osks = (await page.$$eval('select[name="osk"] option', options => options.map(option => option.value))).slice(0, 3);
    const odc = await page.$eval('input[name="curodc"]', node => node.value);
    const orders = [];
    for(let osk of osks) {
      const m = /^(\d{4})(\d{2})(\d{2})$/.exec(osk);
      if (m) {
        name_year = parseInt(m[1]);
        name_month = parseInt(m[2]);
        name_time = parseInt(m[3]);
        await goto(page, `https://weekly.coopdeli.jp/order/index.html?osk=${osk}&odc=${odc}`);
        const dateElemHandle = (await page.$x("//div[@class='cartWeekOrder']/dl/dd[3]"))[0];
        const deliveryDateText = await page.evaluate(node => node.textContent, dateElemHandle);
        const m2 = /^(\d+)月(\d+)日/.exec(deliveryDateText);
        if (m2) {
          const deliveryName = `${name_year}年${name_month}月${name_time}回`;
          const deliveryDate = makeDateString(parseInt(m2[1]), parseInt(m2[2]))
          const rows = await page.$x("//tr[not(@class) and td[@class='cartItemDetail']]");
          const items = await Promise.all(rows.map(async (row) => {
            const name = squeeze(await textValue(page, row, "td[@class='cartItemDetail']/p"));
            const cold = await exists(page, row, "td[@class='cartItemDetail']//img[@alt='冷蔵でお届けの商品']");
            const frozen = await exists(page, row, "td[@class='cartItemDetail']//img[@alt='冷凍でお届けの商品']");
            let quantity = await intValue(page, row, "td[@class='cartItemQty']");
            if (isNaN(quantity)) {
              quantity = await inputIntValue(page, row, "td[@class='cartItemQty']/input");
            }
            const price = await intValue(page, row, "td[@class='cartItemLot']");
            const total = await intValue(page, row, "td[@class='cartItemPrice']");
            return { name, quantity, price, total, cold, frozen };
          }));
          orders.push({ deliveryName, deliveryDate, items });
        }
      }
    }
    return { orders };
  } else {
    return { orders: [] };
  }
}

async function getBrowserPage(local) {
  // Launch headless Chrome. Turn off sandbox so Chrome can run under root.
  const options = local ? { headless: false } : { args: ['--no-sandbox'] };
  const browser = await puppeteer.launch(options);
  return { browser: browser, page: await browser.newPage() };
}

exports.coopDeli = async (req, res) => {
  const { browser, page } = await getBrowserPage(req.body.local);
  const result = await scrapeAll(page, { id: req.body.id, password: req.body.password });

  res.set('Content-Type', 'application/json');
  res.send(result);
  if (req.body.local) {
    await browser.close();
  }
};
