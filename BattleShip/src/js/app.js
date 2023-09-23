const { ethers } = require('ethers');


var gameId = null;
var deposit = null;
var board_size = null;
var counter_ship = null;
var proposed_deposit = null;
var creator = null;
var tmp = ethers.isAddressable("xbsbd");

//var merkleTree = null;
// var merkleRoot = null;
// var myBoardMatrix = null;
// var opponentBoardMatrix = null;
// var gameStarted = false;
// var iHostTheGame = false;
// var isMyTurn = false;
// var iWasAccused = false;


App = {
  web3Provider: null,
  contracts: {},

  init: async function () {
    return await App.initWeb3();
  },

  initWeb3: async function () {
    if (window.ethereum) {
      App.web3Provider = window.ethereum;
      try {
        await window.ethereum.enable();
      } catch (error) {
        console.error("User denied account access");
      }
    }
    else if (window.web3) {
      App.web3Provider = window.web3.currentProvider;
    }
    else {
      App.web3Provider = new web3.provider.HttpProvider("http://localhost:7545");
    }
    const web3 = new Web3(App.web3Provider);
    web3.eth.defaultAccount = web3.eth.accounts[0];
    return App.initContract();
  },

  initContract: async function () {
    $.getJSON("BattleShip.json", function (data) {
      var BattleShipArtifact = data;
      App.contracts.BattleShip = TruffleContract(BattleShipArtifact);
      App.contracts.BattleShip.setProvider(App.web3Provider);
    });
    return App.bindEvents();
  },

  bindEvents: async function () {
    document.getElementById("createNewGame-btn").onclick = App.newGameView;
    document.getElementById("createGame-btn").onclick = App.createGame;
    document.getElementById("findGameRandom-btn").addEventListener("click", App.findGameRandom);
    document.getElementById("findIdGame-btn").addEventListener("click", App.findIdGame);
    document.getElementById("payDeposit-btn").addEventListener("click", App.payDeposit);
    document.getElementById("submitBoard-btn").addEventListener("click", App.submitBoard);
    document.getElementById("depositEths-btn").addEventListener("click", App.depositEths);
    document.getElementById("backToMainMenu-btn").addEventListener("click", App.backToMainMenu);
    document.getElementById("submitPropose-btn").addEventListener("click", App.submitPropose);
    document.getElementById("acceptPropose-btn").addEventListener("click", App.cceptPropose);
    document.getElementById("declinePropose-btn").addEventListener("click", App.eclinePropos);
    document.getElementById("submitAccuse-btn").addEventListener("click", App.submitAccuse);

    console.log("Button listeners loaded!");

  },

  newGameView: function () {
    document.getElementById('mainMenu').style.visibility = "hidden";
    document.getElementById('creationGame').style.visibility = "visible";

    console.log("AAAAA");
  },

  findGameRandom: function () {
    App.findGame(true);
  },

  findIdGame: function () {
    App.findGame(false);
  },

  backToMainMenu: function () {
    $('mainMenu').show();
    $('waitingRoomCreator').hide();
    $('waitingRoomPlayer').hide();

    if (creator) {
      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstace = instance;
        return battleshipInstance.deleteGame(gameId);
      });
    }
  },

  createGame: async function () {
    board_size = document.getElementById("selectValue").value;
    deposit = document.getElementById("depositInput").value;
    creator = true;

    if (!board_size || !deposit) {
      alert("You must insert values to create a game");
    } else {
      if (deposit <= 0) {
        alert("Deposit must be greater than 0");
        return;
      }

      //Call smart contract function, adding also the amount of eths to pay deposit.
      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstance = instance;
        return battleshipInstance.createGame(board_size, deposit, { value: deposit });
      }).then(async function (event) {
        gameId = event.logs[0].args.gameId.toNumber();
        console.log("Inside smart contract function");
        document.getElementById("infoWaitingRoom").innerHTML = `<h1>Your gameId: ${gameId}.</h1>`;

      }).catch(function (err) {
        console.log(err.message);
        App.backToMainMenu();
      });
    }
    console.log("Outside smart contract function");
    document.getElementById('creationGame').style.visibility = "hidden";
    document.getElementById('waitingRoomCreator').style.visibility = "visible";

    App.handleEvent();
  },

  configureBoard: function (size) {
    var arr = Array.from(Array(size), () => new Array(size));
    return arr;
  },

  payDeposit: function () {
    $('waitingRoom').hide();
    $('gameMonitor').show();

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstace = instance;
      return battleshipInstance.payDeposit(gameId, { value: deposit });
    }).then(async function (event) {
      gameId = event.logs[0].args.gameId.toNumber();

    }).catch(function (err) {
      console.log(err.message);
    });
  },

  findGame: function (rand) {
    //Find game with id, if there is a game,
    if (!rand) {
      var identifier = document.getElementById("gameIdentifier").value;

      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstace = instance;
        return battleshipInstance.joinGameId(identifier);
      }).then(async function (event) {

        gameId = event.logs[0].args.gameId.toNumber();
        counter_ship = event.logs[0].args.counter_ships_creator.toNumber();
        board_size = event.logs[0].args.board.toNumber();
        deposit = event.logs[0].args.deposit.toNumber();

        creator_board = configureBoard(board_size);
        player_board = configureBoard(board_size);

      }).catch(function (err) {
        console.log(err.message);
        App.backToMainMenu();
      });
    } else {
      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstace = instance;
        return battleshipInstance.joinGameRandom();
      }).then(async function (event) {

        gameId = event.logs[0].args.gameId.toNumber();
        count_ship = event.logs[0].args.counter_ships_creator.toNumber();
        board_size = event.logs[0].args.board.toNumber();
        deposit = event.logs[0].args.deposit.toNumber();

        creator_board = configureBoard(board_size);
        player_board = configureBoard(board_size);

      }).catch(function (err) {
        console.log(err.message);
        App.backToMainMenu();
      });
    }
    $('waitingRoomPlayer').show();
    document.getElementById("depositTitle").innerHTML = `<h1>Your gameId: ${gameId}. Deposit for game: ${deposit}. Board size: ${board_size}</h1>`;

    App.handleEvent();
  },

  submitPropose: function () {
    proposed_deposit = document.getElementById("proposeNewDeposit").value;

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstace = instance;
      return battleshipInstance.proposeDeposit(gameId, proposed_deposit);
    }).then(async function (event) {
      proposed_deposit = event.logs[0].new_amount.toNumber();
      deposit = event.logs[0].actual_amount.toNumber();
    });

    App.handleEvent();
  },


  handleEvent: async function () {

    await battleshipInstance.allEvent(
      (err, events) => {

        if (events.args.gameId.toNumber() != gameId) {
          console.log("Different Game Id");
          return;
        }

        if (events.event == "PaidDeposit") {
          $('gameMonitor').show();
          $('waitingRoomCreator').hide();
          $('waitingRoomPlayer').hide();

          //Display board table...
        } else if (events.event == "ProposedDeposit") {

          if (confirm('New Propose from Player:' + events.event.args.new_amount + '. Accept?')) {

            App.contracts.BattleShip.deployed().then(async function (instance) {
              battleshipInstace = instance;
              return battleshipInstance.changeDeposit(gameId);
            }).then(async function (event) {
              deposit = event.logs[0].args.eths.toNumber();
            });
          }
        } else if (events.event == "ChangeDeposit") {
          document.getElementById("depositTitle").innerHTML = `<h1>Your gameId: ${gameId}. New deposit for game: ${deposit}. Board size: ${board_size}</h1>`;
        }
      }
    );
  }
};
$(function () {
  $(window).load(function () {
    App.init();
  });
});

