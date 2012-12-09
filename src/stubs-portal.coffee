spawn = require('child_process').spawn
should = require 'should'
http = require 'http'
path = require 'path'
qs = require 'querystring'

command = process.argv[2]
args = process.argv[3..] ? []

port = 8882

createRequest = (context) ->
   options =
      port: port
      method: context.method
      path: context.url
      headers: context.requestHeaders

   if context.query?
      options.path += "?#{qs.stringify context.query}"

   request = http.request options, (response) ->
      data = ''
      response.on 'data', (chunk) ->
         data += chunk
      response.on 'end', ->
         response.data = data
         context.response = response
         context.done = true

   request.write context.post if context.post?
   request.end()
   return request

describe 'stubs-portal', ->
   stubby = null
   context = null

   before (done) ->
      stubby = spawn command, (args.concat ['-d', 'data.yaml']), {
         cwd: path.resolve __dirname, '../data'
         env: process.env
      }
      stubby.stderr.on 'data', (data) -> console.log data.toString()
      poller = ->
         req = http.request {
            port: port
            method: 'get'
            path: '/ping'
         }, (response) ->
            data = ''
            response.on 'data', (chunk) ->
               data += chunk
            response.on 'end', ->
               if response.statusCode is 404 then return done()
               process.nextTick poller
         req.on 'error', ->
            process.nextTick poller
         req.end()
      process.nextTick poller

   beforeEach ->
      context =
         done: false

   after (done) ->
      stubby.on 'exit', done.bind @, null
      stubby.kill()

   it "should return 404 for an endpoint that has not been configured", (done) ->
      context.url = '/not/configured'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 404
         done()

      check()

   it """
should react with 200 to a basic GET endoint

      -  request:
            url: /basic/get


""", (done) ->

      context.url = '/basic/get'
      context.method = 'get'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should react with 200 to a basic PUT endoint

      -  request:
            url: /basic/put
            method: PUT


""", (done) ->

      context.url = '/basic/put'
      context.method = 'put'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should react with 200 to a basic POST endoint

      -  request:
            url: /basic/post
            method: post


""", (done) ->

      context.url = '/basic/post'
      context.method = 'post'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should reject with 404 when post data does't match

      -  request:
            url: /basic/post/data
            method: post
            post: a string!


""", (done) ->

      context.url = '/basic/post/data'
      context.method = 'post'
      context.post = 'the wrong string!'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 404
         done()

      check()

   it """
should react with 200 to a basic DELETE endoint

      -  request:
            url: /basic/delete
            method: DELETE


""", (done) ->

      context.url = '/basic/delete'
      context.method = 'delete'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should react with 200 to a basic HEAD endoint

      -  request:
            url: /basic/head
            method: head


""", (done) ->

      context.url = '/basic/head'
      context.method = 'head'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should return a body from a GET endpoint

   -  request:
         url: /get/body
         method: GET
      response:
         body: "plain text"

""", (done) ->
      context.url = '/get/body'
      context.method = 'get'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.data.should.equal 'plain text'
         done()

      check()

   it """
should return a body from a json GET endpoint

   -  request:
         url: /get/json
         method: GET
      response:
         headers:
            content-type: application/json
         body: >
            {"property":"value"}

""", (done) ->
      context.url = '/get/json'
      context.method = 'get'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.data.trim().should.equal '{"property":"value"}'
         context.response.headers['content-type'].should.equal 'application/json'
         done()

      check()

   it """
should be able to return a 420 status GET endpoint

   -  request:
         url: /get/420
         method: GET
      response:
         status: 420

""", (done) ->
      context.url = '/get/420'
      context.method = 'get'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 420
         done()

      check()

   it """
should be able to handle query params

   -  request:
         url: /get/query
         method: GET
         query:
            first: value1 with spaces!
            second: value2
      response:
         status: 200

""", (done) ->
      context.url = '/get/query'
      context.query =
         first: 'value1 with spaces!'
         second: 'value2'
      context.method = 'get'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should return 404 if query params are not matched

   -  request:
         url: /get/query
         method: GET
         query:
            first: value1 with spaces!
            second: value2
      response:
         status: 200

""", (done) ->
      context.url = '/get/query'
      context.query =
         first: 'invalid value'
         second: 'value2'
      context.method = 'get'
      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 404
         done()

      check()

   it """
should be able to handle authorized posts

   -  request:
         url: /post/auth
         method: POST
         post: some=data
         headers:
            authorization: Basic c3R1YmJ5OnBhc3N3b3Jk
      response:
         status: 201
         headers:
            location: /some/endpoint/id
         body: "resource has been created"

""", (done) ->
      context.url = '/post/auth'
      context.method = 'post'
      context.post = 'some=data'
      context.requestHeaders =
         authorization: "Basic c3R1YmJ5OnBhc3N3b3Jk"

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 201
         context.response.headers.location.should.equal '/some/endpoint/id'
         context.response.data.should.equal 'resource has been created'
         done()

      check()

   it """
should reject endpoint when headers don't match

   -  request:
         url: /post/auth
         method: POST
         post: some=data
         headers:
            authorization: Basic c3R1YmJ5OnBhc3N3b3Jk
      response:
         status: 201
         headers:
            location: /some/endpoint/id
         body: "resource has been created"

""", (done) ->
      context.url = '/post/auth'
      context.method = 'post'
      context.post = 'some=data'
      context.requestHeaders =
         authorization: "Basic c3R1YmJ5OnBhc3Nabd3b3Jk"

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 404
         done()

      check()

   it """
should be able to handle authorized posts were the yaml wasnt pre-encoded

   -  request:
         url: /post/auth/pair
         method: POST
         post: some=data
         headers:
            authorization: stubby:passwordZ0r
      response:
         status: 201
         headers:
            location: /some/endpoint/id
         body: "resource has been created"

""", (done) ->
      context.url = '/post/auth/pair'
      context.method = 'post'
      context.post = 'some=data'
      context.requestHeaders =
         authorization: "Basic c3R1YmJ5OnBhc3N3b3JkWjBy"

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 201
         context.response.headers.location.should.equal '/some/endpoint/id'
         context.response.data.should.equal 'resource has been created'
         done()

      check()

   it """
should be able to handle requests with multiple headers

   -  request:
         url: /post/auth/pair
         method: POST
         post: some=data
         headers:
            authorization: stubby:passwordZ0r
            client: mozilla
      response:
         status: 201
         headers:
            location: /some/endpoint/id
         body: "resource has been created"

""", (done) ->
      context.url = '/post/auth/pair'
      context.method = 'post'
      context.post = 'some=data'
      context.requestHeaders =
         authorization: "Basic c3R1YmJ5OnBhc3N3b3JkWjBy"
         client: "mozilla"

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 201
         context.response.headers.location.should.equal '/some/endpoint/id'
         context.response.data.should.equal 'resource has been created'
         done()

      check()

   it """
should wait if a 2000ms latency is specified

   -  request:
         url: /put/latency
         method: PUT
      response:
         status: 200
         latency: 2000
         body: "updated"

""", (done) ->
      @timeout 2100
      startTime = process.hrtime()
      context.url = '/put/latency'
      context.method = 'put'

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         [seconds, millis] = process.hrtime startTime
         (seconds * 1000 + millis).should.be.above 2000
         done()

      check()

   it """
should handle fallback to body if specified response file cannot be found

      -  request:
            url: /file/body/missingfile
         response:
            file: endpoints-nonexistant.file
            body: body contents!

""", (done) ->
      context.url = '/file/body/missingfile'

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.data.should.equal 'body contents!'
         done()

      check()

   it """
should handle file response when file can be found

      -  request:
            url: /file/body
         response:
            file: endpoints.file
            body: body contents!

""", (done) ->
      context.url = '/file/body'

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.data.trim().should.equal 'file contents!'
         done()

      check()

   it """
should handle fallback to post if specified request file cannot be found

      -  request:
            url: /file/post/missingfile
            method: POST
            file: endpoints-nonexistant.file
            post: post contents!

""", (done) ->
      context.url = '/file/post/missingfile'
      context.method = 'post'
      context.post = 'post contents!'

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()

   it """
should handle file request when file can be found

      -  request:
            url: /file/post
            method: POST
            file: endpoints.file
            post: post contents!
         response: {}

""", (done) ->
      context.url = '/file/post'
      context.method = 'post'
      context.post = 'file contents!'

      createRequest context

      check = ->
         unless context.done
            return process.nextTick check
         context.response.statusCode.should.equal 200
         done()

      check()
