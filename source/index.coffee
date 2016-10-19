class Dependencies
  Error: null
  Path: null
  FileSystem: null
  LockManager: null
  setImmediate: null
  mkdirp: null

  constructor: (props) ->
    @[key] = val for own key, val of props

    @Error ?= try Error

    @setImmediate ?= do ->
      return setImmediate if typeof setImmediate is 'function'
      return ((fn) -> setTimeout fn, 0) if typeof setTimeout is 'function'

    if typeof require is 'function'
      @Path ?= require 'path'
      @FileSystem ?= require 'fs'
      @LockManager ?= require('boco-mutex').LockManager
      @mkdirp ?= require 'mkdirp'

configure = (props) ->
  {
    Error
    Path
    FileSystem
    LockManager
    setImmediate
    mkdirp
  } = dependencies = new Dependencies props

  class Exception extends Error
    @getMessage: (payload) -> null

    constructor: (payload) ->
      super()

      @payload = payload
      @name = @constructor.name
      @message = @constructor.getMessage payload

      if typeof Error.captureStackTrace is 'function'
        Error.captureStackTrace @, @constructor

  class NotImplemented extends Exception
    @getMessage: (payload) -> "Not implemented."

  class PathDoesNotExist extends Exception
    @getMessage: ({fullPath}) -> "Path does not exist: #{fullPath}"

  class FileStore
    @getDefaultBasePath: -> '/'

    basePath: null
    lockManager: null

    constructor: (props) ->
      @[key] = val for own key, val of props
      @basePath ?= @constructor.getDefaultBasePath()
      @lockManager ?= new LockManager

    serialize: (content, done) ->
      done null, content

    deserialize: (content, done) ->
      done null, content

    getFullPath: (path) ->
      Path.join @basePath, path

    getLock: (path) ->
      @lockManager.get path

    lockSync: (path, work, done) ->
      @getLock(path).sync work, done

    write: (path, content, done) ->
      @serialize content, (error, serialized) =>
        return done error if error?

        fullPath = @getFullPath path
        work = @writeFile.bind @, fullPath, serialized

        @lockSync path, work, done

    read: (path, done) ->
      fullPath = @getFullPath path
      work = @readFile.bind @, fullPath

      @lockSync path, work, (error, serialized) =>
        return done error if error?
        @deserialize serialized, done

    remove: (path, done) ->
      fullPath = @getFullPath path
      work = @removeFile.bind @, fullPath
      @lockSync path, work, done

    writeFile: (fullPath, content, done) ->
      done new NotImplemented

    readFile: (fullPath, done) ->
      done new NotImplemented

    removeFile: (fullPath, done) ->
      done new NotImplemented

  class FileSystemFileStore extends FileStore
    @getDefaultBasePath: -> Path.resolve '.'

    ensurePathDir: (fullPath, done) ->
      dir = Path.parse(fullPath).dir
      mkdirp dir, done

    isNotExistError: (error) ->
      error?.code is 'ENOENT'

    readFile: (fullPath, done) ->
      FileSystem.readFile fullPath, (error, content) =>
        return done new PathDoesNotExist {fullPath} if @isNotExistError(error)
        return done error if error?
        return done null, content

    writeFile: (fullPath, content, done) ->
      FileSystem.writeFile fullPath, content, (error) =>
        return done() unless error?
        return done error unless @isNotExistError(error)

        @ensurePathDir fullPath, (error) =>
          return done error if error?
          return @writeFile fullPath, content, done

    removeFile: (fullPath, done) ->
      FileSystem.unlink fullPath, (error) =>
        return done new PathDoesNotExist {fullPath} if @isNotExistError(error)
        return done error if error?
        return done()

  class MemoryFileStore extends FileStore
    memory: null

    constructor: (props) ->
      super props
      @memory ?= {}

    readFile: (fullPath, done) ->
      setImmediate =>
        done null, @memory[fullPath]

    writeFile: (fullPath, content, done) ->
      setImmediate =>
        @memory[fullPath] = content
        done()

    removeFile: (fullPath, done) ->
      setImmediate =>
        delete @memory[fullPath]
        done()

  fileSystem = (props) -> new FileSystemFileStore props
  memory = (props) -> new MemoryFileStore props

  {
    configure
    dependencies
    Dependencies
    Exception
    NotImplemented
    PathDoesNotExist
    FileStore
    FileSystemFileStore
    MemoryFileStore
    fileSystem
    memory
  }

module.exports = configure()
