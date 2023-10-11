var gameId = null;
var deposit = null;
var board_size = null;
var counter_ship = null;
var proposed_deposit = null;
var remaining_ships = null;

const scale = 1000000000000000000;

var my_board;
var agreement = null;
var money = null;

let my_cell_name;
let opp_cell_name;

var merkle_root = null;
var merkle_tree = [];
var seed_matrix = [];
var result = null;

var my_turn = null;
var ship_alert = null;

var counter_ship_opp = null;

var row = null;
var col = null;
var cell = null;

var accuse = false;



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
      App.web3Provider = new Web3.provider.HttpProvider("http://localhost:7545");
    }
    web3 = new Web3(App.web3Provider);
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
    $(document).on("click", "#createNewGame-btn", App.newGameView);
    $(document).on("click", "#createGame-btn", App.createGame);
    $(document).on("click", "#findGameRandom-btn", App.findGameRandom);
    $(document).on("click", "#deleteGame-btn", App.deleteGame);
    $(document).on("click", "#backToMainMenu-btn", App.backToMainMenu);
    $(document).on("click", "#findIdGame-btn", App.findIdGame);
    $(document).on("click", "#payDeposit-btn", App.payDeposit);
    $(document).on("click", "#submitPropose-btn", App.submitPropose);
    $(document).on("click", "#acceptPropose-btn", App.acceptPropose);
    $(document).on("click", "#submitAccuse-btn", App.submitAccuse);
    $(document).on("click", "#verifyAccuse-btn", App.verifyAccuse);

    console.log("Button listeners loaded!");

  },

  newGameView: function () {
    document.getElementById("mainMenu").style.display = "none";
    document.getElementById("creationGame").style.display = "block";
  },

  findGameRandom: function () {
    App.findGame(true);
  },

  findIdGame: function () {
    App.findGame(false);
  },


  createGame: function () {
    board_size = document.getElementById("selectValue").value;
    deposit = document.getElementById("depositInput").value;

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
        return battleshipInstance.createGame(board_size, deposit*scale, { value: (deposit*scale) });
      }).then(async function (event) {

        gameId = event.logs[0].args.gameId.toNumber();
        counter_ship = event.logs[0].args.counter_ships.toNumber();
        agreement = false;

        document.getElementById("creationGame").style.display = "none";
        document.getElementById("waitingRoomCreator").style.display = "block";
        document.getElementById("game-info").innerHTML = `<h2>GAMEID: ${gameId}</h2><h2>BOARD SIZE: ${board_size}</h2><h2>DEPOSIT: ${deposit} ETHs</h2><hr/>`;

        App.handleEvent();

      }).catch(function (err) {
        console.log(err.message);
      });
    }
  },

/*
* Creator can delete a game only if no players have already 
* paid or proposed a deposit.
*/
  deleteGame: function () {
    if(proposed_deposit == null) {
      document.getElementById("waitingRoomCreator").style.display = "none";
      document.getElementById("creationGame").style.display = "none";
      document.getElementById("mainMenu").style.display = "block";

      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstace = instance;
        return battleshipInstance.deleteGame(gameId);
      }).then(async function (event) {
      }).catch(function (err) {
        console.log(err.message);
      });
    } else {
      window.alert("Someone is interested in your game. You cannot delete the game now.")
    }
  },

  backToMainMenu: function () {
    document.getElementById("creationGame").style.display = "none";
    document.getElementById("gameMonitor").style.display = "none";
    document.getElementById("verificationPage").style.display = "none";
    document.getElementById("mainMenu").style.display = "block";
  },


  configureBoard: function (size) {
    const my_matrix = document.getElementById('my-grid-container');
    my_matrix.style = "grid-template-columns: repeat(" + size + ", 1fr);grid-template-rows: repeat(" + size + ", 1fr);";
    remaining_ships = counter_ship;

    if(size == 4) {
      document.getElementById("instruction4x4").style.display = "block";
      my_cell_name = "my-cell4";
      opp_cell_name = "opp-cell4";
      ship_alert = "shipAlert4";
    } else if ( size == 8) {
      document.getElementById("instruction8x8").style.display = "block";
      my_cell_name = "my-cell8";
      opp_cell_name = "opp-cell8";
      ship_alert = "shipAlert8";
    } else if(size == 2) {
      document.getElementById("instruction2x2").style.display = "block";
      my_cell_name = "my-cell2";
      opp_cell_name = "opp-cell2";
      ship_alert = "shipAlert2";
    }


    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        const cl = document.createElement("div");
        cl.classList.add(my_cell_name);
        cl.dataset.row = i;
        cl.dataset.col = j;
        cl.addEventListener("click", (location) => App.shipPlacement(location));
        my_matrix.appendChild(cl);
      }
    }

    const opp_matrix = document.getElementById('opp-grid-container');
    opp_matrix.style = "grid-template-columns: repeat(" + size + ", 1fr);grid-template-rows: repeat(" + size + ", 1fr);";

    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) {
        const cl = document.createElement("div");
        cl.classList.add(opp_cell_name);
        cl.id = i + "-" + j;
        cl.dataset.row = i;
        cl.dataset.col = j;
        cl.addEventListener("click", (location) => App.shotTorpedo(location));
        opp_matrix.appendChild(cl);
      }
    }

    my_board = [];
    enemy_board = [];

     for (var i = 0; i < size; i++) {
       my_board[i] = [];
       enemy_board[i] = [];


       for (var j = 0; j < size; j++) {
         my_board[i][j] = 0;
         enemy_board[i][j] = 0;
       }
     }
  },


  payDeposit: function () {
    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstace = instance;
      return battleshipInstance.payDeposit(gameId, { value: (deposit*scale) });
    }).then(async function (event) {

      gameId = event.logs[0].args.gameId.toNumber();
      agreement = true;

      document.getElementById("waitingRoomPlayer").style.display = "none";
      document.getElementById("shipPlacement").style.display = "block";

      App.configureBoard(board_size);

    }).catch(function (err) {
      console.log(err.message);
    });
  },


  acceptPropose: function() {
    document.getElementById("propose-popup").style.display = "none";

    if(proposed_deposit > deposit) {
      money = (proposed_deposit*scale) - (deposit*scale);
    } else {
      money = 0;
    }

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.changeDeposit(gameId, { value: money });
    }).then(async function (event) {

      deposit = event.logs[0].args.eths.toNumber()/scale;
      agreement = event.logs[0].args.agreement;

      document.getElementById("game-info").innerHTML = `<div><h2>GAMEID: ${gameId}</h2><h2>BOARD SIZE: ${board_size}</h2><h2>DEPOSIT: ${deposit} ETHs</h2><hr/></div>`;
    
    }).catch(function (err) {
      console.log(err.message);
    });
  },

  findGame: async function (rand) {
    //Find game with id, if there is a game,
    if (!rand) {
      var identifier = document.getElementById("gameIdentifier").value;

      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstance = instance;
        return battleshipInstance.joinGameId(identifier);
      }).then(async function (event) {

        gameId = event.logs[0].args.gameId.toNumber();
        counter_ship = event.logs[0].args.counter_ships.toNumber();
        board_size = event.logs[0].args.board_size.toNumber();

        deposit = event.logs[0].args.deposit.toNumber()/scale;

        document.getElementById("mainMenu").style.display = "none";
        document.getElementById("waitingRoomPlayer").style.display = "block";
        document.getElementById("game-info-player").innerHTML = `<div><h2>GAMEID: ${gameId}</h2><h2>BOARD SIZE: ${board_size}</h2><h2>DEPOSIT: ${deposit} ETHs</h2><hr/></div>`;
      
        App.handleEvent();

      }).catch(function (err) {
        console.log(err.message);
      });
    } else {
      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstance = instance;
        return battleshipInstance.joinGameRandom();
      }).then(async function (event) {

        gameId = event.logs[0].args.gameId.toNumber();
        counter_ship = event.logs[0].args.counter_ships.toNumber();
        board_size = event.logs[0].args.board_size.toNumber();

        deposit = event.logs[0].args.deposit.toNumber()/scale;

        document.getElementById("mainMenu").style.display = "none";
        document.getElementById("waitingRoomPlayer").style.display = "block";
        document.getElementById("game-info-player").innerHTML = `<h2>GAMEID: ${gameId}</h2><h2>BOARD SIZE: ${board_size}</h2><h2>DEPOSIT: ${deposit} ETHs</h2><hr/>`;

       App.handleEvent();

      }).catch(function (err) {
        console.log(err.message);
      });
    }
  },

  submitPropose: function () {
    var amount_prop = document.getElementById("proposeNewDeposit").value;
    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.proposeDeposit(gameId, (amount_prop*scale));
    }).then(async function (event) {
      proposed_deposit = event.logs[0].args.new_amount.toNumber()/scale;

    }).catch(function (err) {
      console.log(err.message);
    });
  },


  shipPlacement: function(location) {

    row = location.target.dataset.row;
    col = location.target.dataset.col;
    cell = document.querySelector(`div.${my_cell_name}[data-row='${row}'][data-col='${col}']`);

    if (my_board[cell.dataset.row][cell.dataset.col] == 0) {

      cell.classList.add('ship');
      my_board[cell.dataset.row][cell.dataset.col] = 1;
      remaining_ships--;
      document.getElementById(ship_alert).innerHTML = `<h3>${remaining_ships} REMAINING SHIPS TO PLACE</h3>`;

    } else {

      cell.classList.remove('ship');
      my_board[cell.dataset.row][cell.dataset.col] = 0;
      remaining_ships++;

      document.getElementById(ship_alert).innerHTML = `<h3>${remaining_ships} remaining ships to place.</h3>`;

    }


    if (remaining_ships == 0) {
      App.merkleTree();


      counter_ship_opp = counter_ship;
      var myDiv = document.getElementById('my-grid-container');
      var divClone = myDiv.cloneNode(true);

      document.getElementById('battleGrid').appendChild(divClone);
      document.getElementById("shipPlacement").style.display = "none";
      document.getElementById("gameMonitor").style.display = "block";
      document.getElementById("counterOpposerShips").innerHTML = `<p>${counter_ship_opp} REMAINING OPPOSER'S SHIPS</p>`;
    }
  },

  merkleTree: function() {
    

    // leaves creation in Merkle Tree
    var temp = [];

    for (let i = 0; i < board_size; i++) {

      seed_matrix[i] = [];

      for (let j = 0; j < board_size; j++) {
        var seed = Math.floor(Math.random() * 10);
        seed_matrix[i][j] = seed;

        var tmp = my_board[i][j] + seed;

        console.log(tmp);
        temp.push(window.web3Utils.soliditySha3(tmp));
      }
    }
    console.log(seed_matrix)
    merkle_tree.push(temp);

    // creation of the inside nodes
    while (temp.length > 1) {
      const next = [];
      for (let j = 0; j < temp.length; j+=2) {
        const left_child = temp[j];
        const right_child = temp[j + 1];

        next.push(window.web3Utils.soliditySha3(left_child + right_child.slice(2)));
      }

      temp = next;
      merkle_tree.push(next);
    }

    merkle_root = merkle_tree[merkle_tree.length - 1][0];
    console.log(merkle_tree);

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.submitMerkleRoot(gameId, merkle_root);
    }).then(async function (event) {

      if(web3.eth.defaultAccount == event.logs[0].args.creator) {
        my_turn = true;
        document.getElementById("turnCounter").innerHTML = `<h2> YOUR TURN!</h2>`;

      } else {
        my_turn = false;
        document.getElementById("turnCounter").innerHTML = `<h2> ADVERSARY TURN!</h2>`;
      }

    }).catch(function (err) {
      console.log(err.message);
    });

  },
 

  shotTorpedo: function(location) {

    if(my_turn) {

      if(accuse) {
        App.removeAccuse();
      }

      row = location.target.dataset.row;
      col = location.target.dataset.col;
      cell = document.querySelector(`div.${opp_cell_name}[data-row='${row}'][data-col='${col}']`);
      let ciao = cell.className.indexOf("hit") >= 0

      if (cell.className.indexOf("hit") >= 0  || cell.className.indexOf("miss") >= 0) {
        window.alert("Cell unavailable, already shot torpedo here");
      } else {
        App.contracts.BattleShip.deployed().then(async function (instance) {
          battleshipInstance = instance;
          return battleshipInstance.shotTorpedo(gameId, col, row);
        }).then(async function (event) {
  
          cell.innerHTML = "✖";
  
          my_turn = false;
          document.getElementById("turnCounter").innerHTML = `<h2> ADVERSARY TURN!</h2>`;
        }).catch(function (err) {
          console.log(err.message);
        });
      }

    } else if(!my_turn && !accuse) {
      window.alert("This is not your turn. Wait!");
    }
  },


  verifyShot: function(gameId, col, row, result, hash, merkle_proof, cell) {

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.shotResult(gameId, col, row, result, hash, merkle_proof);
    }).then(async function (event) {

      if (event.logs[0].args.end_game && event.logs[0].args.cheater) {

        window.alert("END GAME! You are a cheater. All deposit will be sent to your opposer.");
        App.backToMainMenu();

      } else if (event.logs[0].args.end_game && !event.logs[0].args.cheater) {

        window.alert("END GAME! You have lost. Waiting for veryfication");
        document.getElementById('gameMonitor').style.display = "none";
        document.getElementById('verificationPage').style.display = "block"; 

      } else {

      cell.innerHTML = "✖";
      my_turn = true;
      document.getElementById("turnCounter").innerHTML = `<h2> YOUR TURN!</h2>`;
      }

    }).catch(function (err) {
      console.log(err.message);
    });

  },


  submitAccuse: function() {

    if(!my_turn) {
      App.contracts.BattleShip.deployed().then(async function (instance) {
        battleshipInstance = instance;
        return battleshipInstance.submitAccuse(gameId);
      }).then(async function (event) {

        window.alert("Accuse submit! Check if your opposer has pass time limit");
        document.getElementById("accuseButton").style.display = "none";
        document.getElementById("checkButton").style.display = "block";
      
      }).catch(function (err) {
        console.log(err.message);
      });
    } else {
      window.alert("This is your turn, you cannot accuse");
    }
  },


  removeAccuse: function() {
    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.removeAccuse(gameId);
    }).then(async function (event) {
 
      document.getElementById("accuseButton").style.display = "block";
      accuse = false;
     
    }).catch(function (err) {
      console.log(err.message);
    });
  },

  verifyAccuse: function() {
    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.verifyAccuse(gameId);
    }).then(async function (event) {
 
      if(event.logs[0].args.accuse) {
        window.alert("Time ended. You have won the game for inactivty of opposer. All deposit will be sent to you.")
        App.backToMainMenu();
        App.transaction(address(0), event.logs[0].args.tx_sender, event.logs[0].args.accuse)
      }
     
    }).catch(function (err) {
      console.log(err.message);
    });
  },


  verifyEndGame: function() {

    var merkle_proof = [];
    var seeds = [];
    var ships = [];
    var indexes = [];


    for(let i = 0; i < board_size; i++) {
      for(let j = 0; j < board_size; j++) {
        if (my_board[i][j] == 1) {
          indexes.push(i*board_size+j);
          ships.push(1);
          seeds.push(seed_matrix[i][j]);
          merkle_proof = merkle_proof.concat(App.merkleProof(i, j));
        }
      }
    }

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.verifyEndGame(gameId, indexes, ships, seeds, merkle_proof);
    }).then(async function (event) {



      App.transaction(event.logs[0].args.tx_sender, event.logs[0].args.opposer, event.logs[0].args.cheat);

    }).catch(function (err) {
      console.log(err.message);
    });
  },

  transaction: function(my_address, opp_address, cheat) {

    if(!cheat) {

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.transactionEndGame(gameId, my_address);
    }).then(async function () {

      window.alert("Verification done! You have won! Your deposit will be sent to you because you and your opposer have joint following rules.");
      App.backToMainMenu();

    }).catch(function (err) {
      console.log(err.message);
    });
  } else {

    App.contracts.BattleShip.deployed().then(async function (instance) {
      battleshipInstance = instance;
      return battleshipInstance.endGameCheater(gameId, opp_address);
    }).then(async function () {

      window.alert("Verification done! You have lost because your behaviour! All deposit will be sent to your opposer.");
      App.backToMainMenu();

    }).catch(function (err) {
      console.log(err.message);
    });
  }
  },


  merkleProof: function (row, col) {

    var merkle_proof = [];
    let target_index = (row * board_size) + col;

    for (let i = 0; i < (merkle_tree.length - 1); i++) {
      if (target_index % 2 == 0) {
        merkle_proof.push(merkle_tree[i][target_index + 1]);
        target_index = target_index / 2;
      }
      else {
        merkle_proof.push(merkle_tree[i][target_index - 1]);
        target_index = (target_index - 1) / 2;
      }
    }
    return merkle_proof;
  },



  handleEvent: async function () {

    await battleshipInstance.allEvents(
      (err, events) => {

        //Check event gameId to detect only events belong to actual game 
        if (events.args.gameId.toNumber() != gameId) {
          console.log("Different Game Id");
          return;
        }

        if (events.event == "PaidDeposit" && events.args.tx_sender != web3.eth.defaultAccount) {
          document.getElementById("waitingRoomCreator").style.display = "none";
          document.getElementById("shipPlacement").style.display = "block";

          App.configureBoard(board_size);

        } else if (events.event == "ProposedDeposit" && events.args.tx_sender != web3.eth.defaultAccount) {

          proposed_deposit = events.args.new_amount/scale;

          document.getElementById("proposeVariable").innerHTML = `<p>PROPOSE: ${proposed_deposit} ETHs</p>`;
          document.getElementById("propose-popup").style.display = "block";

        } else if (events.event == "ChangeDeposit" && events.args.tx_sender != web3.eth.defaultAccount) {

          deposit = events.args.eths/scale;
          agreement = events.args.agreement;
          
          document.getElementById("game-info-player").innerHTML = `<h2>GAMEID: ${gameId}</h2><h2>BOARD SIZE: ${board_size}</h2><h2>NEW DEPOSIT: ${deposit} ETHs</h2><hr/>`;
          window.alert("Your propose was accepted by creator. You must pay new deposit to play.");

        } else if (events.event == "ShotTorpedo" && events.args.target == web3.eth.defaultAccount) {

          row = events.args.row.toNumber();
          col = events.args.col.toNumber();

          cell = document.querySelector(`#battleGrid #my-grid-container .${my_cell_name}[data-row='${row}'][data-col='${col}']`);

          if (my_board[cell.dataset.row][cell.dataset.col] == 0) {
            result = false;
          } else {
            result = true;
          }

          var merkle_proof = [];
          var index = (row * board_size) + col;
          var hash = merkle_tree[0][index];

          merkle_proof = App.merkleProof(row, col);
          App.verifyShot(gameId, col, row, result, hash, merkle_proof, cell);


        } else if(events.event == "ShotResult" && events.args.shooter_address == web3.eth.defaultAccount) {

          if (events.args.cheater && events.args.end_game) {

            window.alert("Your opposer is a cheater. All deposit will be sent to you.");
            App.backToMainMenu();

          } else if (events.args.end_game && !events.args.cheater) {

            window.alert("END GAME! You have won. Waiting for veryfication");
            document.getElementById('gameMonitor').style.display = "none";
            document.getElementById('verificationPage').style.display = "block";

            App.verifyEndGame();

          } else {

            col = events.args.col.toNumber();
            row = events.args.row.toNumber();
            cell = document.querySelector(`div.${opp_cell_name}[data-row='${row}'][data-col='${col}']`);
            
            if(events.args.result) {
              cell.classList.add('hit');
              counter_ship_opp--;
              document.getElementById("counterOpposerShips").innerHTML = `<p>${counter_ship_opp} REMAINING OPPOSER'S SHIPS</p>`;
            
            } else {
              cell.classList.add('miss');
            }
          }
        } else if (events.event == "ValidCheck" && events.args.tx_sender != web3.eth.defaultAccount) {
          
          if(events.args.cheat) {

            window.alert("VERIFICATYION DONE! Your opposer is a cheater. All deposit will be sent to you.");
            App.backToMainMenu();

          } else {

            window.alert("VERIFICATION DONE! You have lost. Your deposit will be sent to you.");
            App.backToMainMenu();

          }
        } else if(events.event == "SubmitAccuse" && events.args.accused == web3.eth.defaultAccount) {

          window.alert("You are under accuse of inactivity. Make move to remove the accuse.")
          document.getElementById("accuseButton").style.display = "none";
          accuse = true;

        } else if (events.event == "RemoveAccuse" && events.args.tx_sender != web3.eth.defaultAccount) {

          document.getElementById("accuseButton").style.display = "block";
          document.getElementById("checkButton").style.display = "none";
          window.alert("Your opposer is in game.");

        } else if(events.event == "VerifyAccuse" && events.args.tx_sender != web3.eth.defaultAccount) {
          if(events.args.accuse) {
          App.backToMainMenu();
          window.alert("You have lost all your deposit because your inactivity");
          }
        } else if (events.event == "DeleteGame" && events.args.tx_sender != web3.eth.defaultAccount) {
          window.alert("Game was deleting by the creator.");
          App.backToMainMenu();

        }
      }
    )
  }
};
$(function () {
  $(window).load(function () {
    App.init();
  });
});

