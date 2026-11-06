// Verify the actual shell history bridge with a same-document history model.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const shell = fs.readFileSync('web/coast-rush-shell.html','utf8');
const start = shell.indexOf('(function () {',shell.indexOf('// Android/browser Back'));
assert(start >= 0);
const code = shell.slice(start,shell.indexOf('}());',start)+5);
function harness() {
  const listeners = {};
  const entries = [{url:'https://example.com/previous',state:null},{url:'https://obmaz.github.io/initialsj/',state:{other:'preserved'}}];
  let cursor = 1, exits = 0;
  const dialog = {open:false,close(){this.open=false;}};
  const history = {
    get state(){return entries[cursor].state;},
    replaceState(state,_,url){entries[cursor]={state,url};},
    pushState(state,_,url){entries.splice(cursor+1);entries.push({state,url});cursor++;},
    back(){
      if (!cursor) return;
      cursor--;
      if (entries[cursor].url === entries[1].url) listeners.popstate({state:entries[cursor].state});
      else exits++;
    },
    forward(){
      if (cursor+1 >= entries.length) return;
      cursor++;
      if (entries[cursor].url === entries[1].url) listeners.popstate({state:entries[cursor].state});
    }
  };
  const window = {history,location:{href:entries[1].url},addEventListener(name,fn){listeners[name]=fn;}};
  vm.runInNewContext(code,{window,document:{getElementById(){return dialog;}}});
  return {window,history,entries,dialog,exits:()=>exits};
}
{
  const h = harness();
  let calls = 0;
  h.window.initialsjObserveBack(()=>calls++,true);
  assert.equal(h.entries.length,3);
  assert.equal(h.history.state.other,'preserved');
  for (let i=0;i<30;i++) h.history.back();
  assert.equal(calls,30);
  assert.equal(h.exits(),0);
  assert.equal(h.entries.length,3,'Repeated Back must reuse a single guard entry');
  assert(h.entries.slice(1).every(entry=>entry.url===h.window.location.href));
  h.window.initialsjObserveBack(()=>calls++,true);
  assert.equal(h.entries.length,3,'Observer setup/reload must not stack extra guards');
  h.dialog.open = true;
  h.history.back();
  assert(!h.dialog.open);
  assert.equal(calls,30,'The install dialog must close before navigating the game');
  h.window.initialsjSetBackEnabled(false);
  h.history.back();
  assert.equal(h.exits(),1,'Back at the main menu must leave normally');
  h.history.forward();
  assert.equal(h.exits(),1,'Forward into a bfcache-restored game must not bounce back out');
  assert.equal(h.history.state.__initialsjBack,'guard');
  assert.equal(calls,30,'Forward must restore the page without issuing a game Back action');
  h.history.back();
  assert.equal(h.exits(),2,'A restored game must still permit normal main-menu Back');
}
{
  const h = harness();
  h.window.initialsjObserveBack(()=>{},true);
  h.window.initialsjObserveBack(null,false);
  h.history.back();
  assert.equal(h.exits(),1,'A destroyed game must release browser navigation');
}
console.log('Android/browser history guard / repeated Back / dialog / normal exit: PASS');
