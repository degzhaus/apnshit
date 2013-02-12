for key, value of require('../lib/apnshit/common')
  eval("var #{key} = value;")

apnshit = require('../lib/apnshit')
fs      = require('fs')
_       = require('underscore')

Apnshit      = apnshit.Apnshit
Notification = apnshit.Notification

apns            = null
bad             = []
config          = null
device_id       = null
drops           = 0
errors          = []
expected_errors = 0
good            = []
notifications   = []
sample          = 5

describe 'Apnshit', ->

  before ->
    config = fs.readFileSync("#{__dirname}/config.json")
    config = JSON.parse(config)

    apns = new Apnshit(
      cert          : config.cert
      debug         : true
      debug_ignore  : [
        'connect#start'
        'connect#exists'
        'send#start'
        'keepSending'
        'send#write'
        'send#written'
      ]
      key    : config.key
      gateway: "gateway.sandbox.push.apple.com"
    )

    apns.on 'debug', console.log

    apns.on 'error', (n) =>
      errors.push(n)
      process.stdout.write('.')

  unless process.env.BAD
    describe '#connect()', ->
      it 'should connect', (done) ->
        apns.connect().then(=> done())

    describe '#enqueue()', ->
      it 'should send a notification', (done) ->
        n = notification()
        apns.once 'finish', => done()
        apns.enqueue(n)
        notifications.push(n)

  describe '#enqueue()', ->
    it 'should recover from failure (mostly bad)', (done) ->
      apns.on 'send#write', (n) =>
        # process.stdout.write(
        #   if n.alert.indexOf('Good') > -1 then 'g' else 'b'
        # )

      apns.once 'finish', =>
        bad.length.should.equal(expected_errors)
        done()

      for i in [0..sample-1]
        is_good = i == 1 || i == sample - 2
        n = notification(i, !is_good)
        if is_good
          good.push(n)
          notifications.push(n)
        else
          expected_errors += 1
          bad.push(n)
        apns.enqueue(n)

    unless process.env.BAD
      it 'should recover from failure (mostly good)', (done) ->
        apns.once 'finish', =>
          bad.length.should.equal(expected_errors)
          done()

        for i in [0..sample-1]
          is_good = i == 1 || i == sample - 3
          is_good = !is_good
          n = notification(i, !is_good)
          if is_good
            good.push(n)
            notifications.push(n)
          else
            expected_errors += 1
            bad.push(n)
          apns.enqueue(n)

      it 'should send multiple (all good)', (done) ->
        apns.once 'finish', =>
#          errors.length.should.equal(expected_errors)
          done()

        for i in [0..sample-1]
          is_good = true
          n = notification(i, !is_good)
          good.push(n)
          notifications.push(n)
          apns.enqueue(n)

  describe 'verify notifications', ->
    it 'should have sent these notifications', (done) ->
      console.log('')

      bad_diff  = _.filter bad,    (n) => errors.indexOf(n) == -1
      bad_diff  = _.map bad_diff,  (n) => n.alert

      notifications = _.map notifications, (n) =>
        n.alert.replace(/\D+/g, '')

      errors = _.map errors, (n) =>
        n.alert.replace(/\D+/g, '')

      console.log(
        "\nmissed error events:",
        if bad_diff.length then bad_diff.join(", ") else "none!"
      )
      console.log("\nsample size: #{sample}")
      console.log("\ndrops: #{drops}")
      console.log("\n#{errors.length} errors / #{expected_errors} expected")
      console.log("\n#{notifications.length} notifications:")
      console.log("\n#{notifications.join("\n")}")

      done()

# Helpers

notification = (index = null, bad = false) ->
  device_ids = [
    "7b3640bd9953174ea30e1952718405a4b1c0d0a1c9b8ad42fb2ce1140fe6b425"
    "a8718c4cd55b44e582b49b41eb21b22f988b864d257da8991bcf672e5ff3fc7d"
    "20a0fafabcb92642a14fac7a47aafcc8caca019b591a9ebb0bbff2fd6a3c379c"
    "29c587479fcc1a0f2ca12016be28fe30ce86ccc7848f8a79f5edf1db89515491"
    "f5ac02e011147057e3fa26f107453a9681b6a895352fe16a0504e32641874e4c"
    "681308c01c350689d1578613ce4341d55af08492d06607a43aa92410ca43d5a9"
    "7e88bd0bca43705988485633182c6e33be37bcfd64563652872f29e4a3241695"
    "a42f81353842957eac743a45367649e4aa694276fd8d753ea855abecc95701b3"
    "e3be9e9ec7d22c92c76d6f143d2f10e9ce50c2fb8a01c5d99e1dc60f06d82bee"
    "92a667d6fa58aebab8678db1101744c1d520d0d219811d8fe9eb7559b08ff068"
    "f4cc861a65d9f6d31ad963684f25a9dd4fa6a4df8610ad8a8548862b5edfc810"
    "72635ecf38335301cba7d58740e18285dd6ae387ff560dcf61e25efe233aadd2"
    "b7b9b8501092a1bb97d31083c872d4005d5bd7ed0645fff984550aa4e970cdb4"
    "2b39caa14dbc5d9a972fba349d714046a8bd91f0941d00bd431b6136fee3f304"
    "622a1942149f2537a5a020a6ea52de90d30e5b57a930c14dd24f9859f26ebb77"
    "13bd346a38736ec5fa74df9a50cb49167ba7e250bfa5cc32bedefc8cc36223c0"
    "555781f07d29e53bea2754bc72c54714c3d8b6cad782fae3561bbe3566fb897f"
    "0ebb675526acb293e927f43263bf1c23c561c7c2f5c0be0b9bbc33dca89ca3e2"
    "2e1479ac15f89d8ba099daaf3b1dd0323231c94f715c2e0293b3e8da347dd096"
    "05a3c8f63463e739fbc2d403042f870129e4a89dd54cc1627fd3bafbf6a46140"
    "52ef1316e11c44fadd48e14c726a9a115577f6a2a968dc974a12de82d5128766"
    "574ae87cccabfb5064e44b253b8d0a3e151174bbae5461e5f26abeb983128711"
    "2e7ecbec1cfc0b1a0885812d0ddc4babe59cab3c0972c7411b53a759fadd64fc"
    "ec4764742a3cff6d2ffb7787118edd298f062dbac407334ed527f36c86262db4"
    "342077a69d7791098a1557d5b86f3a2076e7e99950909ae1c67795063ea38ac4"
    "b28b879375b860876f13bc91b789a6db4ec28605281c85822b7ed92eb50b3feb"
    "d579d64eafabf62b3bf22fb10c3f6f95ffd3726e27539567d54ddd63c35d7319"
    "9c6a9ea4363b3e87860106c256a98d90f9c92fcb712232b6864bb82465dec596"
    "62d4951dd9efd4da9c68c918a33554d685c29b9502206f015c73e86c3126d4d6"
    "b87dcb82dc96a53e260c1cde8031712eec2e73f2f6ba0f92b3f1dd7a4c02b32c"
    "889a4f0d8118f439344f4d29d10947cf40861d068d8a9d8da98e94efa2534856"
    "6b0dac007ab1e3dd08a48ec06ed0c8843635275091476a156af0f019538319ce"
    "faf0455c460e15457b426df00f5241da6da00d0e13822d45d6ecf98b00b7e88c"
    "782c98407a30a52ecf3de50ec78fae1d1b9205f068a73c1526dd531be7d2acdb"
    "f0f2426140946fb539fc4c868cad864e02fddc4fb683600bd5d3f551289dcb1c"
    "697edea0890318dff1a12fa7fddb89bc35e5b5323b4944783ccd0903a9c98e1b"
    "ac2252bc877bfb87a9b2e324933730795b3568188fe81d17eb6ac41275a7ec34"
    "ccc56d0441e32e762d89483b4cc0e2e0f5994b6b21340bc4d6878ef19874db42"
    "f829c23258a4b2de0893d7b8adcde625e4005effcc315eaa6d08ea846c6f9ace"
    "28bef4bb603290cf710fe454ce16fa61422cd36845000e0f84413be53ee373a6"
    "56cdccc1f8ed7786a928718477647403383240427943a168697b9569f59720bb"
    "dc95deb709cafec0cc490e89a8406cfac63773a3e992a2ef2445c48261ec32bb"
    "20ddcbc33855faaec2238e8cd32564f2ee96eb5d017bba150fc81b5b142ce1b1"
    "e6c8851c4b1191127a655abf23430c4098e0be1a09aa2c6985a0947aa839aed2"
    "94d18443be3f41af264023815efef4de62f01339482191656f40b63d0914780c"
    "7ba4bc5c17100b54312989351d57d453e69e681bb08b9757f18a18b08fc49cf6"
    "39d74d4fa670658554d6c06e279b19db9c0510b65921f7c5a7d892bf99274ce1"
    "b31a4c1611e4a67d1c5b92d9956f7567d75ea921057f6ad889a245c379733274"
    "1b1492d2820d510b2355fc995e051641b9b6f1a3e9f84986bd2fc65e9911aadc"
    "9584e67d13cccb5953d62bbd6f6509636e39aad15cd72dc5e9aa099ba315a0d9"
    "00649b045a60a76539706870738410953c565cac8ed770f7040eac4a8f0b2524"
    "9576b381b3d3d3abd0ddc1bf3a5e2883f1ace3ff920ccd110e79d775ce3218f2"
    "1aac058119d42f35cfb35dfe08271ca51c131f09be71feef9b14f92e7e35c6cf"
    "9eba2f15f0756e87c886a6bd6c7937343768c33d8734c82e0cdbea0686d48cee"
    "5dff66238ced7956e1b45f5ff55220ab1835709281aedefb3b94b8e6beee0355"
    "4d3b51cf56b4523527cedac55c9cfa8813579d1d7934bbc9693d28ebbad7e5ef"
    "12b9ae4f00f13fa8159ef29fe6892b99ab043d3d65380ec65cd8417a477c32fe"
    "23c6b2e57cd23060dcdf7d8fabbc4761f88533bd1092286d1e2e5c0d5179b42e"
    "d3be826f7d65c7a027a8c51077ebfb86cdaf6fbc01a00fa0877dc99303f767e1"
    "1758a4a7626085654b8b7ed751235a63fbaf98c7818b79f71c8b8f767f17e998"
    "bd8a63497fc37b2237728b2ac616d382762306c92c6c6bee5ec8bf53d5473004"
    "6e391081c8884df313c464b7ca84fb76aabdede2b06ebc38b85cc11d0e186bf1"
    "40ce70658473660fbc584d78a191340d0e4be612255b586da5c425dcdfd5ce95"
    "81a63a5e77c4507f519b76694b03984298bdf032138fe687ec8f90a4c37d4d90"
    "35f93539fc2352de411743a3dad8beb05abda90e48b809c1d0ac7adbccb81173"
    "47d1e6e7ab2cca2ea140d81dd1317245cbc977775569cd3b3ceff710ce7d0a51"
    "d5293349d296942b82f0623e361a6ba563e9e3757d1b34736b42eb44404853e0"
    "bb407f006c57fc89ea8670b2a3c1b0ca8ffaaaae48a75259c3a4c349032e1cd0"
    "b5feeb0c60c1c78c0000b76347c03c7e8ab36abff0d6020961eee3376eca7c7b"
    "d6d3e9ffe2b0658de5a1731785972095c1cac8185eddf784ff67942f6987c062"
    "c2a0c62a4ee7f7f3fbbf5cf6b4840529d971a658c2f0d75df3ce5bfec58b9f62"
    "dbfd2e6405e783c16e21deca41b64fce28e7593e077b080cc6d423e104b1bc44"
    "faaa2dd1461e26826bf6767646e986b31ab4c14af5a692b3a7cb7697dffc953d"
    "1c06c381f8f1215437300b8a74c5ba6220895e07c0c339c5c51544d383ebcfc7"
    "fe9459761507efabcfcb417c21999c1d64320e4195ea44b9e191d8ea9d7a88c0"
    "bcce40639533be3336ffb5433a10025a3f5bc82ba3e83e4f7017b60b2ab72ce8"
    "b0f1754193d395132e03a9e97cc748181be73ea68bf6fbd539be89dd55c6c763"
    "a5e2142a9673b4ce6d9a8f0a66d8ac4066da98f0eaa8a2cade67ed267a902a49"
    "ea36d88a0b6b602b722c9c178e8615076aea2ecbeb2519b37dbeac5a0ab541db"
    "be14647f9a81c17b65a1a640e98f8acf42a313a965657272b8e98ab704903261"
    "e179793b36bcd6aeb269f966e320778cab0e351f221ae19fc8ffefd55810114a"
    "b1658a559295b3f5a1846952545c5d06f1e34175b06cabfbb4f325ceafbfe7a8"
    "1b924c377274ae104ba84ba414d8e8eaf23dc1eb25710a7ebcbd9d84c082b6ad"
    "dd1a55f1560c66bcfd6b3c14c9adfa7a9b7575c541317dbdaed1b7f81fcc973c"
    "bb754958bf785d4b248aaa0cbe0633461999e9bca621572003c93fe44e07731a"
    "bda4f4c9fced32ee6ef0d5b13e2bf5648e6a49166192bf872e5158b5ff698163"
    "ff8b2e14cb85a5c5948cbd58b0895a3f0aa23eab9d7f919fc3820b5f8f3a693f"
    "c6223cd383fc51f7e7c62ecd8921d5563009229bbc2a3217212e5582b78041b0"
    "c1f955f0f0afd072d5cfa31fdc08e3425dd7a52f228f9ae9525502e83e75eab5"
    "e1b7e9c52eeb5418daa1d45a931937a6da02f9e5f8329dd31df116f25f42ceba"
    "cece65066c69a0032fb9d56973ff7f15e9642c00ba547eefdcbed7604a9bd823"
    "dc35d52ebca48abdaa078bc35901adcd3aa28a3b372e747a0636235e64091b76"
    "dfa2856b46db46ec853171dda7e0e37e1391d8233e20505fba554ee9fde9e0ad"
    "b86a61a42f4d883e4c49dea481f565c031f2a4c0c156b5ddd3cc2ebf9d483951"
    "bd0c17048113f48044cc11221c681aa981f7482b8263f80b5784a68bcaa03753"
    "efb8322bf2a7304ab8cc7c557f87c88fc457a7e93684002e8c60caffca702e19"
    "f45132c2ad7bf5573581bb5ccf3ee47277a21866a0e11f5843f7a12fa9125e27"
    "c5b6f9ea2e7859ca0ae106d6e91ca80c85c2b258012ba2dc43885a0a4a999863"
    "afd32ffff6e0644d8365a14fd172428ceaac58ec708f6ad64850a01b98ed18a6"
    "0bdbf988fa7f88dc45c58b50e02d0b954b03afb5fd9908ecf7440b5990d4a0da"
  ]

  noti = new Notification()

  noti.alert =
    "#{
      if bad then "Bad" else "Good"
    } notification: #{
      Math.floor(Math.random()*10000)
    }"
  noti.badge = 0
  if bad
    noti.device = device_ids[index % 100]
  else
    noti.device = config.device_id

  noti