fs = require "fs"
path = require "path"

{Builder} = require "bungle"

builder = new Builder
Pipe = builder.pipe.bind builder



config = require "./" + path.relative __dirname, "be.json"

try
    bowerconfig = JSON.parse fs.readFileSync ".bowerrc", "utf8"
catch e
    bowerconfig = {}


name = config.name || "bower-ember"
hostnames = config.hostnames || []
port = config.port || 8613
csp = config.csp || {}
vendordir = bowerconfig.directory || "bower_components"

middleware = []
if fs.existsSync "middleware.js"
    middleware.push "middleware"


profile = "default"



preprocess = (mainreader = Pipe "file-reader",
    description: "Read files from disk"
    pattern: "{.eslintrc,.jshintrc,*.{js,json,hbs,html},{app,style,tests}/**/*}"
    passthrough: true
    continuous: profile is "default"
    debug: true
#).to Pipe "jshint",
#    description: "Run jshint on all own js files"
#    pattern: "app/**/*.js"
#    passthrough: true
).to Pipe "eslint",
    description: "Run eslint on all own js files"
    pattern: "app/**/*.js"
    passthrough: true
.to Pipe "template-compiler",
    description: "Compile Handlebars templates to HTML"
    pattern: "*.hbs"
    passthrough: true
    context:
        name: name
        modules: profile is "default"
        es6: false
        vendordir: vendordir
.to Pipe "coffee",
    description: "Compile CoffeeScript files to JavaScript"
    passthrough: true
.to Pipe "stylus",
    description: "Compile Stylus files to CSS."
    passthrough: true
.to Pipe "sass",
    description: "Compile .scss files to CSS."
    passthrough: true
Pipe "file-reader",
    description: "Read files a second directory"
    pattern: "{.eslintrc,.jshintrc,*.{js,json,hbs,html},{app,style,tests}/**/*}"
    basedir: "./ember-shared"
    continuous: profile is "default"
    debug: true
.to mainreader if fs.existsSync "ember-shared"



js = preprocess.to Pipe "move",
    description: "Move all sources from /app to / in this branch"
    pattern: "app/**/*"
    dir: ".."
.to Pipe "ember-templates",
    description: "Compile HTMLBars templates to JavaScript modules"
    passthrough: true
.to Pipe "ember-auto-import",
    description: "Create Ember Application that autoimports all modules"
    passthrough: true
    filename: "ember-app.js"
.to Pipe "babel",
    description: "Transpile code to ES5"
    passthrough: true
#.to Pipe "es6-module-transpiler",
#    description: "Transpile from ES6 module syntax to AMD"
#    passthrough: true
#    sourceMap: false
#    strict: true
.to Pipe "move",
    description: "Move everything to the `app` subdirectory."
    dir: "app"



style = preprocess.to Pipe "passthrough",
    description: "Select files in /style"
    pattern: "style/**/*"
.to Pipe "auto-prefixer",
    description: "Add vendor prefixes as needed"
    passthrough: true
    browsers: ["last 2 versions", "Explorer >= 8"]



tests = preprocess.to Pipe "passthrough",
    description: "Select files in /tests"
    pattern: "tests/**/*"
.to Pipe "auto-import",
    description: "Create module that imports all tests"
    passthrough: true
    filename: "tests/tests.js"
.to Pipe "babel",
    description: "Transpile code to ES5"
    passthrough: true
#.to Pipe "es6-module-transpiler",
#    description: "Transpile from ES6 module syntax to AMD"
#    passthrough: true



other = preprocess.to Pipe "passthrough",
    description: "Select all files not claimed by {app,style,tests}"
    pattern: "!{app,style,tests}/**/*"



vendor = Pipe "bower",
    description: "Manage vendor directory with bower and load sources"
    patches: "/home/marko/Code/marko/js/esx-bower/patch.json"
    offline: true
.to Pipe "babel",
    description: "Transpile code to ES5"
    passthrough: true
    strict: false
#.to Pipe "es6-module-transpiler",
#    description: "Transpile from ES6 module syntax to AMD"
#    passthrough: true



jsbundle = (vendor.to js.to Pipe "bundle-amd",
    description: "Create Javascript bundle from modules"
    main: "app/main"
    filename: "app/main-built.js"
    enabled: profile isnt "default"
    debug: true
).to Pipe "uglify",
    description: "Compress JavaScript bundle"
    debug: true



cssbundle = style.to vendor.to Pipe "bundle-css",
    description: "Create CSS bundle from all style files"
    main: "style/style.css"
    filename: "style/main-built.css"
    enabled: profile isnt "default"
    debug: true



merger = Pipe "passthrough",
    description: "Merge all individual processing branches"
js.to style.to tests.to other.to vendor.to jsbundle.to cssbundle.to merger



merger.to Pipe "webserver",
    description: "Serve everything via HTTP"
    middleware: middleware
    reload: "*.html"
    enabled: profile is "default"
    hostnames: hostnames
    port: port
    debug: true
    csp: csp



merger.to Pipe "move",
    description: "Move output files to directory `dist`"
    dir: "dist"
.to Pipe "file-writer",
    description: "Write files to disk"
    pattern: "dist/{*.{html,js},**/main-*,style/img/**/*,**/fonts/*}"
    enabled: profile isnt "default"
    debug: true



builder.bungle.checkconfig = true
builder.run()

