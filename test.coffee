BocoFileStore = require './source'
store = BocoFileStore.fileSystem()

steps = []

readContent = (done) ->
  store.read "test/foo/bar", (error, content) ->
    return done error if error?
    console.log 'content:', content.toString()
    done()

steps.push (done) ->
  store.write "test/foo/bar", "hello world", done

steps.push readContent

steps.push (done) ->
  store.write "test/foo/bar", "goodbye world", done

steps.push readContent

steps.push (done) ->
  store.remove "test/foo/bar", (error) ->
    done error

steps.push readContent

require('async').series steps, (error) ->
  throw error if error?
  process.exit 0
