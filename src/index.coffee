'use strict'
require('source-map-support').install()

# Gulp and streaming modules
gulp = require 'gulp'
runSequence = require 'run-sequence'
through = require 'through2'

# Commonly used gulp plugins and node modules
gulpIf = require 'gulp-if'
mergeStream = require 'merge-stream'
sourcemaps = require 'gulp-sourcemaps'
changed = require 'gulp-changed'
rename = require 'gulp-rename'
insert = require 'gulp-insert'
plumber = require 'gulp-plumber'
{typeCheck} = require 'type-check'
debugModule = require 'debug'
bs = require('browser-sync').create()

# Gulpfile-specific modules
notifier = require 'node-notifier'
requireDir = require 'require-dir'
path = require 'path'
loadPlugins = require 'load-plugins'
entries = require 'object.entries'

# The .paviosrc configuration
config = require('rc')('pavios')

debug = debugModule 'Pavios' # Used for debugging the entire Gulpfile, separate instances are used for some functions

debug 'Starting...'

# Config API
getConfig = (taskName) -> config.tasks[taskName]

# notify API
cache = []

notify = (msg, {title, logMsg} = {}) ->
  index = null
  if msg not in cache
    cache.push msg
    index = cache.indexOf msg
    if logMsg? and not msg?
      msg = 'See terminal for more information'
    notifier.notify
      title: title or 'Pavios'
      message: msg
    if logMsg?
      if logMsg instanceof Error
        console.log '\u0007' # beep
        console.log logMsg.stack or logMsg.message
      else
        console.log logMsg
    setTimeout (-> cache.splice index, 1), 1500 # arbitrarily defined timeout (or usual amount of time before the notification is clicked away)

notify.taskFinished = (taskName) ->
  notify "#{taskName} task finished successfully.", title: taskName

# Stream Error Handling API
handleError = (taskName = '?') ->
  handler = (err) ->
    notify "Error in task #{taskName}, see terminal for more info",
      title: taskName
      logMsg: if err.stack? then err.stack.slice(0, 2500) else err # ain't nobody got time for 20000 character stack traces
    @emit 'end'
  plumber.bind plumber, handler

# Type Checking API
typeCheckerTypes =
  minify: 'Boolean'
  sourcemaps: 'Boolean'
  renameTo: 'String | Function | Object'
  insert: '{ prepend: Maybe String, append: Maybe String, wrap: Maybe (String, String) }'
  compilerOpts: 'Object'
  standardOpts: ->
    "{
      minify: Maybe #{@minify},
      sourcemaps: Maybe #{@sourcemaps},
      insert: Maybe #{@insert},
      renameTo: Maybe #{@renameTo},
      compilerOpts: Maybe #{@compilerOpts}
    }"

typeCheckerTypes.standardOpts = typeCheckerTypes.standardOpts() # required for the correct `this` binding

typeCheckErr = (taskName) ->
  console.error "The configuration for the #{taskName} task is in the wrong format. See the config guide for more information: https://github.com/rioc0719/pavios/README.md#config-guide"

standardConfigTypeChecker = (config, taskName, optsType = 'Object') ->
  typeCheckPattern = "[{
    src: String,
    dest: String,
    opts: Maybe #{optsType}
  }]"
  unless typeCheck typeCheckPattern, config
    typeCheckErr taskName
    return false
  true

generateType = (types) ->
  localDebug = debugModule 'Pavios:generateType'
  localDebug 'Generating these types: ', types
  generatedType = '{'
  types = types.filter (type) -> typeCheckerTypes[type]?
  for type in types
    localDebug 'Adding type ', type
    punctuation = if types.indexOf(type) is types.length - 1 then '' else ','
    generatedType += "\n\t#{type}: Maybe #{typeCheckerTypes[type]}#{punctuation}"
  generatedType += '\n}'
  localDebug 'Final generated type: ', generatedType
  generatedType

# Insert API
handleInsert = (obj) ->
  localDebug = debugModule 'Pavios:insert'
  unless obj?
    localDebug 'null passed as argument, returning empty stream'
    return through.obj()
  localDebug 'obj is ', obj
  if typeof obj.prepend is 'string'
    localDebug 'Prepending ', obj.prepend
    return insert.prepend obj.prepend
  if typeof obj.append is 'string'
    localDebug 'Appending ', obj.append
    return insert.append obj.append
  if typeCheck '(String, String)', obj.wrap
    localDebug "Wrapping in #{obj.wrap[0]} and #{obj.wrap[1]}"
    return insert.wrap obj.wrap[0], obj.wrap[1]

# Exported API object

API =
  notify: notify
  merge: mergeStream
  $: # plugins, may be wrapped
    if: gulpIf
    browserSync: bs
    sourcemaps: sourcemaps
    changed: changed
    rename: rename
    insert: handleInsert
  reload: bs.stream
  handleError: handleError
  typeCheck:
    raw: typeCheck
    standard: standardConfigTypeChecker
    types: typeCheckerTypes
    generateType: generateType
    typeCheckErr: typeCheckErr
  debug: debugModule

module.exports = {getConfig, gulp, API} # exporting here because tasks are required in the next section

packageJsonPath = path.join path.dirname(module.parent.filename), 'package.json'
loadPluginsConfig =
  config: require packageJsonPath
  strip: 'pavios-'
  camelize: no

tasks = new Map entries loadPlugins('pavios-*', loadPluginsConfig)

debug 'tasks: ', tasks

tasksByOrder = new Map
tasks.forEach (fn, task) -> tasksByOrder.set task, fn.order

ordersByTask = new Map
tasksByOrder.forEach (order, task) ->
  if ordersByTask.has order
    currTasks = ordersByTask.get(order) or []
    ordersByTask.set order, currTasks.concat [task]
  else
    ordersByTask.set order, [task]

groupedTasks = []
ordersByTask.forEach (tasksList, order) ->
  if tasksList.length > 1
    groupedTasks[order] = [tasksList...]
  else if tasksList.length is 1
    groupedTasks[order] = tasksList[0]
groupedTasks = groupedTasks.filter (x) -> x?

debug 'groupedTasks:', groupedTasks

gulp.task 'watch', ->
  localDebug = debugModule 'Pavios:watch'
  fn = (task, event) ->
    localDebug "File #{event.path} was #{event.type}, running #{task}"

  tasks.forEach ({sources}, task) ->
    if sources?
      unless typeCheck '[String]', sources
        localDebug "Type check on #{JSON.stringify sources} for #{task} failed"
        console.error "Can't watch files for the \"#{task}\" task because the config is invalid."
        return
      localDebug "Watching srcs #{sources}, running #{task} on change"
      watcher = gulp.watch sources, [task]
      watcher.on 'change', fn.bind(null, task)

groupedTasks.push 'watch' # needed because watch isn't a task in tasks/

gulp.task 'default', runSequence groupedTasks...
