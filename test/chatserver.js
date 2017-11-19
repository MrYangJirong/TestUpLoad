var http = require("http");
var fs = require("fs");
var url = require('url')
var path = require('path')
var root = module.dir
function processPostChatData(req,res){
  console.log('call processPostChatData fucntion')

  if (req.method == 'POST') {
    var chunks = [];
    var size = 0;
    req.on('data', function (chunk){
      console.log("on data chunk",chunk.length);
      chunks.push(chunk);
      size += chunk.length;
    });

    req.on('end', function (){
      var date = new Date();
      if (!fs.existsSync("voice"))
        fs.mkdirSync(dir, "voice")

      var dir = "voice/"+date.getYear()+date.getMonth()+date.getDay();
      console.log("console length is ",size);
      //console.log(fs);
      if (!fs.existsSync(dir))
        fs.mkdirSync(dir, "0777")
      var filename = dir+'/'+date.getTime()+'.mp3'
      var fd = fs.openSync(filename,"w","0777");

      var data = new Buffer(size);
      for (var i = 0, pos = 0, l = chunks.length; i < l; i++) {
        var chunk = chunks[i];
        chunk.copy(data, pos);
        pos += chunk.length;
      }

      fs.writeSync(fd,data,0,size);
      fs.closeSync(fd);

      var body = {
        success: true,
        filename: filename
      }
      body = JSON.stringify(body);
      console.log('body ',body)
      res.writeHead(200, {
        ["Content-Type"]: "text/plain"
      })
      res.write(body)
      res.end()
    });
  } else if (req.method == 'GET') {
    console.log("call get method")
    req.uri = url.parse(req.url)
    var pathname = req.uri.pathname
    var root = path.resolve()
    pathname = root+pathname;
    console.log('path is ',pathname)

    fs.stat(pathname, function (err, stat) {
      console.log("err is ",err);
      if (!err) {
        res.writeHead(200, {
          ["Content-Type"]: 'audio/mpeg',
          ["Content-Length"]: stat.size
        })

        fs.createReadStream(pathname).pipe(res)
      }
    })
  }
}

http.createServer(function(request, response) {
  processPostChatData(request,response);
}).listen(1990);
console.log("web server listen at 1990 port");

function noop(err){
  console.log(err.stack);
}
process.on('uncaughtException', noop)
