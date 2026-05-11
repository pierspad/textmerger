const https = require('https');
const fs = require('fs');

const icons = ['python', 'javascript', 'typescript', 'svelte', 'vuedotjs', 'rust', 'html5', 'css3', 'json', 'markdown', 'git', 'go', 'c', 'cplusplus'];

async function fetchIcon(name) {
  return new Promise((resolve) => {
    https.get(`https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/${name}.svg`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ name, svg: data }));
    });
  });
}

async function main() {
  const results = await Promise.all(icons.map(fetchIcon));
  const dict = {};
  results.forEach(r => dict[r.name] = r.svg);
  fs.writeFileSync('icons.json', JSON.stringify(dict, null, 2));
}

main();
