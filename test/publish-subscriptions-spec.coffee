_ = require 'lodash'
uuid = require 'uuid'
redis = require 'fakeredis'
mongojs = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache = require 'meshblu-core-cache'
DeliverSubscriptions = require '../'

describe 'DeliverSubscriptions', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'subscription-test'
      collection: 'subscriptions'

    @datastore.remove done

  beforeEach ->
    @redisKey = uuid.v1()
    @redisPubSubKey = uuid.v1()
    @pepper = 'im-a-pepper'
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @cache = new Cache
      client: _.bindAll redis.createClient @redisPubSubKey
      namespace: 'meshblu'

    options = {
      pepper: 'totally-a-secret'
      @cache
      @datastore
      @jobManager
      @uuidAliasResolver
      @pepper
    }

    dependencies = {@request}
    @client = _.bindAll redis.createClient @redisPubSubKey

    @sut = new DeliverSubscriptions options, dependencies

  describe '->do', ->
    context 'when subscriptions exist', ->
      beforeEach (done) ->
        @client.subscribe 'sent:subscriber-uuid', done

      beforeEach ->
        @client.once 'message', (error, @message) =>

      beforeEach (done) ->
        record =
          type: 'sent'
          emitterUuid: 'emitter-uuid'
          subscriberUuid: 'subscriber-uuid'

        @datastore.insert record, done

      beforeEach (done) ->
        request =
          metadata:
            responseId: 'its-electric'
            toUuid: 'emitter-uuid'
            fromUuid: 'someone-uuid'
            messageType: 'sent'
          rawData: '{"devices":"*"}'

        @sut.do request, (error, @response) => done error

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

      it 'should send a message to my subscribed devices', (done) ->
        _.delay =>
          expect(@message).to.equal '{"devices":"*"}'
          done()
        , 100