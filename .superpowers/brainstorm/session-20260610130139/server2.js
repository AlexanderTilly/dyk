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
  if (!files.length) {
    res.writeHead(200,{'Content-Type':'text/html'});
    res.end('<p style="font-family:sans-serif;padding:2em">Waiting...</p>');
    return;
  }
  const newest = files.map(f=>({f,t:fs.statSync(path.join(contentDir,f)).mtimeMs})).sort((a,b)=>b.t-a.t)[0].f;
  let html = fs.readFileSync(path.join(contentDir,newest),'utf8');
  if (!html.trim().startsWith('<!DOCTYPE') && !html.trim().startsWith('<html')) {
    let frame = fs.readFileSync(frameTemplatePath,'utf8');
    let helper = fs.readFileSync(helperJsPath,'utf8');
    // Inject content into the placeholder comment
    frame = frame.replace('<!-- CONTENT -->', html);
    // Inject helper script before </body>
    frame = frame.replace('</body>', '<script>' + helper + '</script></body>');
    html = frame;
  }
  res.writeHead(200,{'Content-Type':'text/html'}); res.end(html);
});
server.listen(52342,'127.0.0.1',()=>{
  const info = JSON.stringify({type:'server-started',port:52342,url:'http://localhost:52342',screen_dir:contentDir,state_dir:stateDir});
  fs.writeFileSync(path.join(stateDir,'server-info'),info);
  console.log(info);
});
