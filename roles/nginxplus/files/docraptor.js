var ips = [];

// pull down the DocRaptor list once at start, then every day
function refresh() {
  fetch('https://docraptor.com/ips.txt', { method: 'GET' })
    .then(r => r.text())
    .then(t => {
      ips = t.split(/\r?\n/).filter(function(x){ return x; });
      console.log('DocRaptor IP list refreshed (' + ips.length + ' entries)');
    })
    .catch(function(e){
      console.error('DocRaptor fetch error:', e);
    });
}

refresh();
setInterval(refresh, 24 * 60 * 60 * 1000);

function check(r) {
  if (ips.indexOf(r.remoteAddress) !== -1) {
    return;
  }
  r.return(403);
}

export default { check };
