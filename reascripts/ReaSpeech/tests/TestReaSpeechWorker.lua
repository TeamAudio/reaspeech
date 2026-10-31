package.path = 'source/?.lua;' .. package.path

local lu = require('vendor/luaunit')

require('tests/mock_reaper')

require('libs/Polo')
require('libs/Storage')
require('libs/Logging')

require('vendor/json')

require('main/ReaSpeechWorker')

--

TestReaSpeechWorker = {}

function TestReaSpeechWorker:setUp()
  reaper.__test_setUp()

  self.events = {}
  self.starts = {}
  self.cancels = {}

  reaper.ReaSpeech_StartEx = function(path, options)
    table.insert(self.starts, { path = path, options = json.decode(options) })
    return true, 'job-' .. #self.starts
  end

  reaper.ReaSpeech_Poll = function(id)
    self.last_polled = id
    return table.remove(self.events, 1) or ''
  end

  reaper.ReaSpeech_Cancel = function(id) table.insert(self.cancels, id) end

  self.worker = ReaSpeechWorker.new { requests = {}, responses = {} }
end

function TestReaSpeechWorker:start(data, jobs)
  self.callback = function() end

  table.insert(self.worker.requests, {
    jobs = jobs or { { path = 'audio.wav' } },
    data = data,
    callback = self.callback,
  })

  self.worker:react()
end

function TestReaSpeechWorker:event(event)
  table.insert(self.events, json.encode(event))
end

function TestReaSpeechWorker:testCompletedResponseAndNextJob()
  local jobs = {
    { path = 'one.wav' },
    { path = 'two.wav' },
  }

  self:start({
    model_name = 'medium',
    language = 'fr',
    task = 'translate',
    vad_filter = 'true',
    hotwords = 'Jane',
  }, jobs)

  lu.assertEquals(self.starts[1], {
    path = 'one.wav',
    options = {
      model = 'medium',
      language = 'fr',
      translate = true,
      vad = true,
      hotwords = 'Jane',
      words = true,
      beamSize = 1,
    }
  })

  self:event { type = 'started' }
  self:event { type = 'progress', completed = 1, total = 2, message = 'Working' }
  self.worker:react()

  lu.assertEquals(self.worker:status(), 'Working')
  lu.assertEquals(self.worker:progress(), 0.25)

  local words = { { word = 'Hello' } }

  self:event {
    type = 'segment',
    segment = {
      startMs = 1250,
      endMs = 2500,
      text = 'Hello',
      words = words,
    }
  }

  self:event { type = 'completed' }
  self.worker:react()

  lu.assertEquals(self.worker.responses[1], {
    {
      segments = {
        {
          start = 1.25,
          ['end'] = 2.5,
          text = 'Hello',
          words = words,
        }
      }
    },
    _job = jobs[1],
    callback = self.callback,
  })

  lu.assertEquals(#self.starts, 2)
  lu.assertEquals(self.worker.active_job.job_id, 'job-2')

  self:event { type = 'completed' }
  self.worker:react()

  lu.assertNil(self.worker.active_job)
  lu.assertNil(self.worker:progress())
end

function TestReaSpeechWorker:testStartFailure()
  reaper.ReaSpeech_StartEx = function() return false, 'Model unavailable' end

  self:start(nil, { { path = 'one.wav' }, { path = 'two.wav' } })

  lu.assertEquals(self.worker.responses, { { error = 'Model unavailable' } })
  lu.assertNil(self.worker.active_job)
  lu.assertEquals(self.worker.pending_jobs, {})
  lu.assertNil(self.worker:progress())
end

function TestReaSpeechWorker:testTurboCannotTranslate()
  self:start { model_name = 'large-v3-turbo', task = 'translate' }
  lu.assertFalse(self.starts[1].options.translate)
end

function TestReaSpeechWorker:testCancellationWaitsForTerminalEvent()
  self:start(nil, { { path = 'one.wav' }, { path = 'two.wav' } })
  self.worker:cancel()
  self.worker:cancel()

  lu.assertEquals(self.cancels, { 'job-1' })
  lu.assertEquals(self.worker.pending_jobs, {})
  lu.assertEquals(self.worker:status(), 'Cancelling')
  lu.assertNotNil(self.worker:progress())

  self:event { type = 'started' }
  self:event { type = 'progress', completed = 50, total = 100 }
  self:event { type = 'segment', segment = { text = 'Discard' } }
  self.worker:react()

  lu.assertEquals(self.last_polled, 'job-1')
  lu.assertEquals(self.worker:status(), 'Cancelling')
  lu.assertEquals(#self.starts, 1)

  self:event { type = 'cancelled' }
  self.worker:react()

  lu.assertNil(self.worker.active_job)
  lu.assertNil(self.worker:progress())
  lu.assertEquals(self.worker.responses, {})
end

function TestReaSpeechWorker:testCompletionRacingCancellation()
  self:start()
  self.worker:cancel()
  self:event { type = 'completed' }
  self.worker:react()

  lu.assertNil(self.worker.active_job)
  lu.assertNil(self.worker:progress())
  lu.assertEquals(self.worker.responses, {})
end

function TestReaSpeechWorker:testNewRequestWaitsForCancellation()
  self:start()
  self.worker:cancel()

  table.insert(self.worker.requests, { jobs = { { path = 'new.wav' } } })
  self.worker:react()

  lu.assertEquals(#self.starts, 1)

  self:event { type = 'cancelled' }
  self.worker:react()

  lu.assertEquals(#self.starts, 2)
  lu.assertEquals(self.starts[2].path, 'new.wav')
end

function TestReaSpeechWorker:testMalformedEvents()
  for _, event in ipairs({ '{broken', 'null', 'false', '42', '"text"', '{}' }) do
    self:setUp()
    self:start()

    table.insert(self.events, event)
    self.worker:react()

    lu.assertStrContains(self.worker.responses[1].error, 'Could not decode ReaSpeech Lib response')
    lu.assertNil(self.worker.active_job)
    lu.assertNil(self.worker:progress())
  end
end

function TestReaSpeechWorker:testErrorEvent()
  self:start(nil, { { path = 'one.wav' }, { path = 'two.wav' } })
  self:event { type = 'error', error = 'Decoder failed' }
  self.worker:react()

  lu.assertEquals(self.worker.responses, { { error = 'Decoder failed' } })
  lu.assertEquals(self.worker.pending_jobs, {})
  lu.assertNil(self.worker.active_job)
  lu.assertNil(self.worker:progress())
end

--

os.exit(lu.LuaUnit.run())
