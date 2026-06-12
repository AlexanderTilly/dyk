const http = require('http');
const fs = require('fs');
const path = require('path');

const sessionDir = 'C:\\Users\\tilly\\palma_app\\.superpowers\\brainstorm\\session-20260610130139';
const contentDir = path.join(sessionDir, 'content');
const stateDir = path.join(sessionDir, 'state');
const frameTemplatePath = 'C:\\Users\\tilly\\.claude\\plugins\\cache\\claude-plugins-official\\superpowers\\5.1.0\\skills\\brainstorming\\scripts\\frame-template.html';
const helperJsPath = 'C:\\Users\\tilly\\.claude\\plugins\\cache\\claude-plugins-official\\superpowers\\5.1.0\\skills\\brainstorming\\scripts\\helper.js';

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'POST' && req.url === '/event') {
    let body = '';
    req.on('data', d => body += d);
    req.on('end', () => {
      fs.appendFileSync(path.join(stateDir, 'events'), body + '\n');
      res.writeHead(200); res.end('ok');
    });
    return;
  }
  const files = fs.readdirSync(contentDir).filter(f => f.endsWith('.html'));
  if (!files.length) { res.writeHead(200,{'Content-Type':'text/html'}); res.end('<p>Waiting...</p>'); return; }
  const newest = files.map(f=>({f,t:fs.statSync(path.join(contentDir,f)).mtimeMs})).sort((a,b)=>b.t-a.t)[0].f;
  let html = fs.readFileSync(path.join(contentDir,newest),'utf8');
  if (!html.trim().startsWith('<!DOCTYPE') && !html.trim().startsWith('<html')) {
    const frame = fs.readFileSync(frameTemplatePath,'utf8');
    const helper = fs.readFileSync(helperJsPath,'utf8');
    html = frame.replace('</body>','<script>'+helper+'</script></body>').replace('<div id="content"></div>','<div id="content">'+html+'</div>');
  }
  res.writeHead(200,{'Content-Type':'text/html'}); res.end(html);
});
server.listen(52341,'127.0.0.1',()=>{
  const info = JSON.stringify({type:'server-started',port:52341,url:'http://localhost:52341',screen_dir:contentDir,state_dir:stateDir});
  fs.writeFileSync(path.join(stateDir,'server-info'),info);
  console.log(info);
});
