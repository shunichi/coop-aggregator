const { palSystem } = require('./index.js')
const path = require('path');
const dotenv_path = path.resolve(process.cwd(), '../../.env');
require('dotenv').config({ path: dotenv_path });

(async () => {
  const req = {
    body: {
      local: true,
      id: process.env.PAL_USER_ID,
      password: process.env.PAL_PASSWORD
    }
  };
  const res = {
    set: (name, value) => {
    },
    send: (result) => {
      console.log(JSON.stringify(result));
    }
  };
  await palSystem(req, res);
})();
