# Pavios
An experimental, pluggable build system, built on top of Gulp.

## Installation

```
npm install --save-dev pavios
```

Pavios is based around the concept of _tasks_, which are modules that are installed along with `pavios` and define gulp tasks.

## For Task Users
Simply install a pavios module from npm and add its configuration to a `.paviosrc` file in the root of your project or in any directory above your project's `node_modules` folder. See the documentation for the [rc module](https://npmjs.org/package/rc) used in Pavios for more information.

### Config Guide
- Standard config format:

```json
[{
  "src": "src/index.js",
  "dest": "build/"
}, {
  "src": "src/Component.jsx",
  "dest": "build/",
  "opts": {
    "minify": true,
    "sourcemaps": false
  }
}, {
  "src": "src/lib.js",
  "dest": "build/",
  "opts": {
    "renameTo": "vendor.js",
    "compilerOpts": {
      "stage": 1
    }
  }
}]
```

#### Example

```json
{
  "tasks": {
    "babel": [
      {
        "src": "src/index.js",
        "dest": "build/",
        "opts": {
          "minify": true,
          "sourcemaps": false
        }
      }
    ]
  }
}
```

## For Task Creators
Pavios provides a `pavios.API` object for use in the creation of tasks.

```javascript
var pavios = require('pavios');
var gulp = pavios.gulp;
var API = pavios.API;
var getConfig = API.getConfig;
var gulpModule = require('gulp-module');
var config = getConfig('task');

gulp.task('task', function() {
  return gulp.src(config.src)
    .pipe(gulpModule())
    .pipe(gulp.dest(config.dest));
});
```

In ES6/ES2015:

```javascript
let {gulp, API: {getConfig}} = require('pavios');
let gulpModule = require('gulp-module');

let config = getConfig('task');

gulp.task('task', () => {
  return gulp.src(config.src)
    .pipe(gulpModule())
    .pipe(gulp.dest(config.dest));
});
```

In CoffeeScript:

```coffeescript
{gulp, API: {getConfig}} = require 'pavios'
gulpModule = require 'gulp-module'

config = getConfig 'task'

gulp.task 'task', ->
  gulp.src config.src
  .pipe gulpModule()
  .pipe gulp.dest config.dest
```

## Config Guide
### Default Config
## TODO
- Need something more robust than module.exports.order (it's brittle and requires knowledge of pretty much every Pavios task and what it does)
  - Maybe some sort of "beforeFileOperations", "duringFileOperations", "afterFileOperations", "afterStartingServer" thing?
- Error handling in pavios-jade (errors from gulp-jade aren't caught)
- Eslint parsers/plugins have to be installed at the pavios-* level instead of the top level. This needs to be fixed because installing something like babel-eslint in node_modules is unsustainable.
- Coffeelint doesn't detect coffeelint.json for some reason (This is probably not an issue with where the module is, because pavios-eslint detects .eslintrc correctly, and doesn't work with babel-eslint for it)
```coffeescript
pavios = require 'pavios'
{API: {getConfig, $, typeCheck}} = pavios

config = getConfig 'babel'

typeCheck.standard config

pavios.createTask 'babel', ->
  pavios.src 'abc'
  .pipe $.if(prod, $.sourcemaps.init())
  .pipe pavios.dest 'def'
```
