// SPDX-License-Identifier: MIT 
pragma  solidity >=0.4.22 <0.9.0;

contract BattleShip {

    struct infoGame{
        uint8 gameId;
        address creator;
        address player;
        bool free;
        uint8 counter_ships;
        uint8 counter_ships_creator;
        uint8 counter_ships_player;
        bytes32 merkle_root_creator;
        bytes32 merkle_root_player;
        uint8[] creator_board;
        uint8[] player_board;
        uint8 board_size;
        uint256 deposit;
        bool end_game;
        bool cheat;
        address winner;
        uint256 proposedDeposit;
        bool agreement; //Phase 2.1 lock --> on true
        address accused; //Phase 6 lock
        uint256 acc_time;
        bool accuse;
        address target_address; //Phase 4 --> block shot turn.
        bool available; //Phase 3 lock --> on false
    }

    event SubmitMerkleRoot(uint8 gameId, bytes32 merkle_root, address creator);
    event NewGame(uint8 gameId, uint8 counter_ships, address tx_sender);
    event ProposedDeposit(uint8 gameId, uint256 actual_amount, uint256 new_amount, address tx_sender);
    event ChangeDeposit(uint8 gameId, uint256 eths, address tx_sender);
    event PaidDeposit(uint8 gameId, bool availability, address tx_sender);
    event SelectGame(uint8 gameId, uint8 counter_ships, uint8 board_size, uint256 deposit, address tx_sender);
    event ShotTorpedo(uint8 gameId, address target, uint8 col, uint8 row, address tx_sender);
    event ShotResult(uint8 gameId, bool result, uint8 col, uint8 row, bool end_game, bool cheater, address tx_sender, address shooter_address);
    event SubmitAccuse(uint8 gameId, address accused, uint256 time, address tx_sender);
    event DeleteGame(uint8 gameId, address tx_sender);
    event VerifyAccuse(uint8 gameId, bool accuse, address tx_sender);
    event RemoveAccuse(uint8 gameId, address tx_sender);
    event ValidCheck(uint8 gameId, address tx_sender, bool cheat, address opposer);


    mapping (uint8 => infoGame) games;
    uint8[] gameIds;     //array with all gameIds created
    mapping (uint8 => bool) valid_ids;
    uint8 id = 0;

    constructor(){}

    /*
    * Admitted board size are 2, 4, 8. (reference for 2x2, 4x4, 8x8)
    */
    function checkBoard(uint8 size) private pure returns (bool){
        return (size == 2 || size == 4 || size == 8);
    }

    /*
        Phase 1 Req:
            - Board of correct size
            - Eths must be equal to deposit
            - Until 256 games at the same time

        Vulnerabilities:
        - One single creator can have 255 games opened --> DoS attack
    */ 
    function createGame(uint8 board_size, uint256 deposit) public payable{

        require(checkBoard(board_size), "Uncorrect board size");
        require(msg.value == deposit, "Wrong ETHs to create game");
        require(gameIds.length < 256, "Games space is full.");
        id++;
        uint256 len = board_size*board_size;

        uint8[] memory arr = new uint8[](len);

        for (uint8 i = 0; i < len; i++) {
            arr[i] = 0;
        }

        for(uint8 i = 0; i < gameIds.length; i++) {
            if(gameIds[i] == id) {
                id++;
            }
        }

        gameIds.push(id);

        games[id] = infoGame (id, msg.sender, address(0), true, 0, 0, 0, 0, 0, arr, arr, board_size, msg.value, false, false, address(0), 0, false, address(0), 0, false, address(0), true);
        valid_ids[id] = true;
        if (board_size == 2) {
            games[id].counter_ships = 2;
            games[id].counter_ships_player = games[id].counter_ships;
            games[id].counter_ships_creator = games[id].counter_ships;
        } else if (board_size == 4) {
            games[id].counter_ships = 6;
            games[id].counter_ships_player = games[id].counter_ships;
            games[id].counter_ships_creator = games[id].counter_ships;
        } else if (board_size == 8) {
            games[id].counter_ships = 23;
            games[id].counter_ships_player = games[id].counter_ships;
            games[id].counter_ships_creator = games[id].counter_ships;
        }
        emit NewGame(id, games[id].counter_ships, msg.sender);
    }


   /*
        Phase 1.1 Req:
            - Valid gameId
            - Only creator can delete him/her game
            - No agreement with player

        + All deposit is sent to the creator when he/she deletes a game.
    */
    function deleteGame(uint8 gameId) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(msg.sender == games[gameId].creator, "Only creator can delete his/her game");
        require(games[gameId].agreement == false, "There is an agreement with a player, you cannot delete this game.");
        
        uint256 amount = games[gameId].deposit;
        games[gameId].deposit = 0;
        payable(msg.sender).transfer(amount);

        deleteItem(gameIds, gameId);
        delete(valid_ids[gameId]);

        emit DeleteGame(gameId, msg.sender);
    }


    /*
        Phase 2 Req:
            - Game free
            - Creator cannot join in his/her game
            - At least one game created
    */
    function joinGameRandom() public{
        require(gameIds.length > 0, "There aren't already games.");

        uint8 rand_id;
        bool find = false;


        for(uint8 i = 0; i < gameIds.length; i++) {
            if(games[gameIds[i]].free == true) {
                rand_id = gameIds[i];
                find = true;
                break;
            }
        }

        require(find, "No available game at this moment");
        require(msg.sender != games[rand_id].creator, "You are the creator of this game");

        games[rand_id].player = msg.sender;
        games[rand_id].free = false;
        emit SelectGame(
            games[rand_id].gameId,
            games[rand_id].counter_ships,
            games[rand_id].board_size,
            games[rand_id].deposit,
            msg.sender    
        );

    }


    /*
        Phase 2 Req:
            - Available game
            - An existing gameId
            - You must be not the creator of the game
            - Creator cannot join his/her game
    */
    function joinGameId(uint8 gameId) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].free == true, "There are already two players in this game");
        require(games[gameId].available == true, "Game full, choose another game.");
        require(games[gameId].creator != msg.sender, "You are the creator of the game");

        games[gameId].player = msg.sender;
        games[gameId].free = false;

        emit SelectGame(
                games[gameId].gameId,
                games[gameId].counter_ships,
                games[gameId].board_size,
                games[gameId].deposit,
                msg.sender
            );
    }

    /*
        Phase 2.1 Req:
            - Valid gameId
            - Only player of this game can propose a deposit
            - No zero value
            - No same value of deposit as before
            - No previous agreement for deposit
    */
    function proposeDeposit(uint8 gameId, uint256 new_deposit) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(msg.sender == games[gameId].player, "You are not a player in this game");
        require(new_deposit != 0, "Select a positive amount of ETHs for deposit");
        require(new_deposit != games[gameId].deposit, "Choose a different amount of ETHs for deposit than before");
        require(games[gameId].agreement == false, "Creator has already accepted a propose");
        
        games[gameId].proposedDeposit = new_deposit;
        
        emit  ProposedDeposit(
                gameId,
                games[gameId].deposit,
                games[gameId].proposedDeposit,
                msg.sender
            );
    }


    /*
        Phase 2.2 Req:
            - Valid gameId
            - Only player of this game can propose a deposit
            - No zero value
            - No same value of deposit as before
            - No previous agreement for deposit
    */
    function changeDeposit(uint8 gameId) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        require(msg.sender == games[gameId].creator, "Only the game creator can change deposit");

        if(games[gameId].proposedDeposit > games[gameId].deposit) {
            require(msg.value == (games[gameId].proposedDeposit - games[gameId].deposit), "The new deposit summed to the previous is not equal to the proposed one.");

            games[gameId].deposit += msg.value;
        } else {
            require(msg.value == 0, "Error with propose higher than deposit");

            uint256 diff = games[gameId].deposit - games[gameId].proposedDeposit;
            games[gameId].deposit = games[gameId].proposedDeposit;
            payable(msg.sender).transfer(diff);
        }
        games[gameId].agreement = true;

        emit ChangeDeposit(
            gameId,
            games[gameId].deposit,
            msg.sender
        );
    }


    /*
        Phase 3 Req:
            - Valid gameId
            - Only player can pay to start the game
            - Eths in transaction must be equal to the deposit
            - No previous agreement 
    */
    function payDeposit(uint8 gameId) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        require(msg.sender == games[gameId].player, "You are not player of this game");
        require(msg.value == games[gameId].deposit, "Wrong ETHs to join game");
        require(games[gameId].available == true, "You have already pay deposit");

        games[gameId].agreement = true;
        games[gameId].deposit += msg.value;
        games[gameId].available = false;

        emit PaidDeposit(
            gameId,
            games[gameId].available,
            msg.sender
        );
    }


    /*
        Phase 4 Req:
            - Valid gameId
            - Only players of game can submit merkleRoot
            - No previous merkleRoot stored 
            - 0 value for merkle root is not accepted
    */
    function submitMerkleRoot(uint8 gameId, bytes32 merkle_root) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(merkle_root != 0, "Invalid merkle root");

        if (msg.sender == games[gameId].creator) {
            require(games[gameId].merkle_root_creator == 0, "Merkle Root of creator already stored");
            games[gameId].merkle_root_creator = merkle_root;
        } else if(msg.sender == games[gameId].player){
            require(games[gameId].merkle_root_player == 0, "Merkle Root of player already stored");
            games[gameId].merkle_root_player = merkle_root;
            games[gameId].target_address = games[gameId].creator;
        } else {
            revert("You are not creator or player of this game");
        }

        emit SubmitMerkleRoot(gameId, merkle_root, games[gameId].creator);
    }


    /*
        Phase 5 Req:
            - Valid gameId
            - Only players of game can shot
            - Ony one shot per turn
            - Target address must be submitted
            - Game must be not ended
            - No cheater

        + Creator cannot shot until player has submitted the merkle root, and
        player can't shot first!!

    */
    function shotTorpedo(uint8 gameId,  uint8 col, uint8 row) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].target_address != address(0), "Player has not submitted merkle root. Wait");
        require(games[gameId].target_address == msg.sender, "You can't shot two consecutive times");
        require(games[gameId].end_game == false, "End Game");
        require(games[gameId].cheat == false, "Game ended, someone is a cheater");

        if (msg.sender == games[gameId].creator) {
            games[gameId].target_address = games[gameId].player;
        } else if (msg.sender == games[gameId].player){
            games[gameId].target_address = games[gameId].creator;
        } else {
            revert("You are not creator or player of this game");
        }

        emit ShotTorpedo(
            gameId,
            games[gameId].target_address,
            col,
            row,
            msg.sender
        );
    }



    /*
        Phase 5.1 Req:
            - Valid gameId
            - Only players of game can check 
            - Game must be not ended
            - No cheater in the game
    */
    function shotResult(uint8 gameId, uint8 col, uint8 row, bool result, bytes32 computed_hash, bytes32[] memory merkle_proof) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].end_game == false, "End Game");
        require(games[gameId].cheat == false, "Game ended, someone is a cheater");

        uint8 target_index = row * games[gameId].board_size + col;
        address shooter_address;

        if (msg.sender == games[gameId].creator) { 
            shooter_address = games[gameId].player;

            for (uint8 i = 0; i < merkle_proof.length; i++) {

                if (target_index % 2 == 0) {
                    // Hash(current computed hash + current element of the proof)
                    computed_hash = keccak256(abi.encodePacked(computed_hash, merkle_proof[i]));
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computed_hash = keccak256(abi.encodePacked(merkle_proof[i], computed_hash));
                }
                target_index = target_index / 2;
        
            }

            if(computed_hash == games[gameId].merkle_root_creator) {

                if(result) {
                    games[gameId].counter_ships_creator -= 1;
                    games[gameId].creator_board[row * games[gameId].board_size + col] = 1;
                }
            } else {
                games[gameId].cheat = true;
                games[gameId].end_game = true;
                endGameCheater(gameId, shooter_address);
            }

            if(games[gameId].counter_ships_creator == 0) {

                games[gameId].end_game = true;
            }

        } else if (msg.sender == games[gameId].player){
            shooter_address = games[gameId].creator;


            for (uint8 i = 0; i < merkle_proof.length; i++) {

                if (target_index % 2 == 0) {
                    // Hash(current computed hash + current element of the proof)
                    computed_hash = keccak256(abi.encodePacked(computed_hash, merkle_proof[i]));
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computed_hash = keccak256(abi.encodePacked(merkle_proof[i], computed_hash));
                }
                target_index = target_index/2;
            }
            
            if(computed_hash == games[gameId].merkle_root_player) {
                if(result) {
                    games[gameId].counter_ships_player -= 1;
                    games[gameId].player_board[row * games[gameId].board_size + col] = 1;
                }
            } else {
                games[gameId].cheat = true;
                games[gameId].end_game = true;
                endGameCheater(gameId, shooter_address);
            }
            if(games[gameId].counter_ships_player == 0) {

                games[gameId].end_game = true;
            }
           
        } else {
            revert("You are not creator or player of this game");
        }

        emit ShotResult(gameId, result, col, row, games[gameId].end_game, games[gameId].cheat, msg.sender, shooter_address);
    }



    /*
        Phase 6 Req:
            - Valid gameId
            - Only players of game can accuse
            - No other accused player
    */
    function submitAccuse(uint8 gameId) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].accused == address(0), "Accuse already submitted");

        if (msg.sender == games[gameId].creator) {
           games[gameId].accused = games[gameId].player;
        } else if (msg.sender == games[gameId].player){
            games[gameId].accused = games[gameId].creator;
        } else {
            revert("You are not creator or player of this game");
        }

        games[gameId].acc_time = block.number + 5;

        emit SubmitAccuse(
            gameId,
            games[gameId].accused,
            games[gameId].acc_time,
            msg.sender
        );

    }

    /*
        Phase 6.1 Req:
            - Valid gameId
            - Only players of game can check accuse
            - There must be one accuse
    */
    function verifyAccuse(uint8 gameId) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].accused != address(0), "Accuse was not submitted");

        if (msg.sender != games[gameId].creator && msg.sender != games[gameId].player) {
            revert("You are not creator or player of this game");
        }
        if(games[gameId].acc_time <= block.number) {
            
            payable(msg.sender).transfer(games[gameId].deposit);
            games[gameId].accuse = true;
        }
        emit VerifyAccuse(gameId, games[gameId].accuse, msg.sender);    
    }


    /*
        Phase 6.2 Req:
            - Valid gameId
            - Only players of game can check accuse
            - There must be one accuse
            - Address of accused must be equal to msg.sender
    */
    function removeAccuse(uint8 gameId) public{
        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].accused != address(0), "Accuse was not submitted");
        require(games[gameId].accused == msg.sender, "You are not accused");

        if (msg.sender != games[gameId].creator && msg.sender != games[gameId].player) {
            revert("You are not creator or player of this game");
        }

        games[gameId].accused = address(0);
        emit RemoveAccuse(gameId, msg.sender);
        
    }


    /*
        Phase 7 Req:
            - Valid gameId
            - Only players of game can verify the end of game
            - Game must be finished
            - No previous cheaters in the game
    */
    function verifyEndGame(uint8 gameId, uint256[] memory indexes, uint256[] memory values, uint256[] memory seeds, bytes32[] memory merkle_proofs) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].end_game == true, "Game isn't finished");
        require(games[gameId].cheat == false, "Someone is a cheater");

        bytes32 merkle_root_ver;
        address opposer;
        bytes32 computed_hash;
        uint8 size_merkle_proof;

        if(msg.sender == games[gameId].creator) {
            opposer = games[gameId].player;
            merkle_root_ver = games[gameId].merkle_root_creator;
        } else if(msg.sender == games[gameId].player) {
            opposer = games[gameId].creator;
            merkle_root_ver = games[gameId].merkle_root_player;
        } else {
            revert("You are not creator or player of this game");
        }

        if(games[gameId].board_size == 2) {
            size_merkle_proof = 2;
        } else if (games[gameId].board_size == 4) {
            size_merkle_proof = 4;
        } else {
            size_merkle_proof = 6;
        }

        for(uint8 j = 0; j < values.length; j++) {

            uint256 tmp = values[j] + seeds[j];
            computed_hash = keccak256(abi.encode(tmp));

            for(uint8 i = j*size_merkle_proof; i < (j+1)*size_merkle_proof; i++) {
                
                if (indexes[j] % 2 == 0) {
                    // Hash(current computed hash + current element of the proof)
                    computed_hash = keccak256(abi.encodePacked(computed_hash, merkle_proofs[i]));
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computed_hash = keccak256(abi.encodePacked(merkle_proofs[i], computed_hash));
                }
                indexes[j] = indexes[j] / 2;
            }

            if(computed_hash != merkle_root_ver) {
                games[gameId].cheat = true;
                games[gameId].winner = opposer;
            }
        }

        if(values.length != games[gameId].counter_ships) {
            games[gameId].cheat = true;
            games[gameId].winner = opposer;
        }
        
        games[gameId].winner = msg.sender;
        emit ValidCheck(gameId, msg.sender, games[gameId].cheat, opposer);
    }


    /*
        Phase 8.1 Req:
            - Valid gameId
            - Only players of game can make the final transaction
            - There must be a cheter
            - Game must be not ended
    */
    function endGameCheater(uint8 gameId, address shooter) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].cheat == true, "No cheater in game");
        require(games[gameId].end_game == true, "Game is not ended");

        if (msg.sender != games[gameId].creator && msg.sender != games[gameId].player) {
            revert("You are not creator or player of this game");
        }

        games[gameId].winner = shooter;
        uint256 amount = games[gameId].deposit;
        games[gameId].deposit = 0;

        payable(shooter).transfer(amount);

        endGame(gameId);

    }


    /*
        Phase 8.2 Req:
            - Valid gameId
            - Only players of game can make final transaction
            - Game must be ended
            - No cheater
    */
    function transactionEndGame(uint8 gameId, address receiver) public payable{
        
        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].cheat == false, "There is a cheater in the game");
        require(games[gameId].end_game == true, "Game is not ended");

        if (msg.sender != games[gameId].creator && msg.sender != games[gameId].player) {
            revert("You are not creator or player of this game");
        }
        games[gameId].winner = receiver;

        uint256 amount = games[gameId].deposit;

        games[gameId].deposit = 0;

        payable(games[gameId].creator).transfer(amount/2);
        payable(games[gameId].player).transfer(amount/2);

        endGame(gameId);
    }



    /*
        Phase 8.3 Req:
            - Valid gameId
            - There must be a winner
            - Deposit must be setted to 0.
    */
    function endGame(uint8 gameId) private{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].winner != address(0), "No winner for this game");
        require(games[gameId].deposit == 0, "Deposit wasn't at 0.");
        

        deleteItem(gameIds, gameId);
        delete(valid_ids[gameId]);
    }
    

    function deleteItem(uint8[] storage arr, uint8 item) private{
        
        uint8 index;
        
         for(uint8 i = 0; i < arr.length - 1; i++) {
            if(item == arr[i]) {
                index = i;
            }
        }

        for (uint i = index; i < arr.length - 1; i++) {
            arr[i] = arr[i + 1];
        }

        arr.pop();
    }
}