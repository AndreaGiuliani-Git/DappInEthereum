// SPDX-License-Identifier: MIT 
pragma  solidity >=0.4.22 <0.9.0;

contract BattleShip {

    struct infoGame{
        uint256 gameId;
        address creator;
        address player;
        uint8 counter_ships_creator;
        uint8 counter_ships_player;
        bytes32 merkle_root_creator;
        bytes32 merkle_root_player;
        uint8 board;
        uint256 deposit;
        uint256 proposedDeposit;
        address accused;
        uint256 acc_time;
        bool available;
    }

    event NewGame(uint256 gameId);
    event ProposedDeposit(uint256 gameId, uint256 actual_amount, uint256 new_amount);
    event ChangeDeposit(uint256 gameId, uint256 eths);
    event PaidDeposit(uint256 gameId, bool availability);
    event SelectGame(uint256 gameId, address creator, address player, uint8 counter_ships_creator, uint8 counter_ships_player, uint8 board, uint256 deposit);
    event ShotTorpedo(uint256 gameId, address target, uint8 col, uint8 row);
    event ShotResult(uint256 gameId, bool result, uint8 counter_ships, address target_address);
    event Cheater(uint256 gameId, bool result, address cheater);
    event EndGame(uint256 gameId, address winner);
    event SubmitAccuse(uint256 gameId, address accused, uint256 time);


    mapping (uint256 => infoGame) games;
    uint256[] gameIds;     //array with all gameIds created
    mapping (uint256 => bool) valid_ids;

    constructor(){}
    /*
    * Random generator exploiting hash of previous block and the timestamp of actual block
    */
    function randomGenerator() private view returns (uint256){
        return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)));
    }


    /*
    * Admitted board size are 8, 16, 32. (reference for 8x8, 16x16, 32x32)
    */
    function checkBoard(uint8 tmp) private pure returns (bool){
        return (tmp == 8 || tmp == 16 || tmp == 32);
    }

    /*
    * Creator of game can change deposit when joined player makes a new deposit propose,
    * and automatically creator accepts the propose.
    */
    function changeDeposit(uint256 gameId) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        require(msg.sender == games[gameId].creator, "Only the game creator can change deposit");

        uint256 proposed_dep = games[gameId].proposedDeposit;
        uint256 dep = games[gameId].deposit;

        if(proposed_dep > dep) {
            require(msg.value == (proposed_dep - dep), "The new deposit summed to the previous is not equal to the proposed one.");
            dep += msg.value;
        } else {
            uint256 diff = dep - proposed_dep;
            dep = proposed_dep;
           payable(msg.sender).transfer(diff);
        }

        games[gameId].deposit = dep;
        games[gameId].proposedDeposit = proposed_dep;

        emit ChangeDeposit(
            gameId,
            games[gameId].deposit
        );
    }

    /*
    * Player can propose a deposit.
    */
    function proposeDeposit(uint256 gameId, uint256 new_deposit) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(new_deposit > 0, "Select a positive amount of ETHs for deposit");
        require(new_deposit != games[gameId].deposit, "Choose a different amount of ETHs for deposit than before");
        
        if(msg.sender == games[gameId].player) {
            games[gameId].proposedDeposit = new_deposit;
        } else {
            revert("You have no permission to propose a new deposit");
        }
        emit  ProposedDeposit(
                gameId,
                games[gameId].deposit,
                games[gameId].proposedDeposit
            );
    }

    /*
    * Function only for player to pay deposit and finally join the game. After the payment
    * game is not available anymore in the games list.
    */
    function payDeposit(uint256 gameId) public payable{

        require(valid_ids[gameId], "Invalid game identifier");

        if(msg.sender != games[gameId].player) {
            revert("You have no permission to propose a new deposit");
        }

        require(msg.value == games[gameId].deposit, "Wrong ETHs to join game");
        games[gameId].deposit += msg.value;
        games[gameId].available = false;

        emit PaidDeposit(
            gameId,
            games[gameId].available);
    }

    /*
    * Removes a specific game at the end of the game, from gamesIds array and from
    * games map.
    */
    function deleteGame(uint gameId) public{

        require(valid_ids[gameId], "Invalid game identifier");
        
        uint8 index;

        for(uint8 i = 0; i < gameIds.length - 1; i++) {
            if(gameId == gameIds[i]) {
                index = i;
            }
        }

        for(uint8 i = index; i < gameIds.length - 1; i++) {
            gameIds[i] = gameIds[i + 1];
        }

        gameIds.pop();
        delete(games[gameId]);
        delete(valid_ids[gameId]);
    }


    function createGame(uint8 board, uint256 deposit) public payable{

        require(checkBoard(board), "Uncorrect board size");
        require(deposit > 0, "Select a positive amount of ETHs for deposit");
        require(msg.value == deposit, "Wrong ETHs to create game");

        uint256 id = randomGenerator();
        gameIds.push(id);
        games[id] = infoGame (id, msg.sender, address(0), 0, 0, 0, 0, board, msg.value, 0,address(0), 0, true);
        valid_ids[id] = true;

        if (board == 8) {
            games[id].counter_ships_creator = 23;
            games[id].counter_ships_player = 23;
        } else if (board == 16) {
            games[id].counter_ships_creator = 42;
            games[id].counter_ships_player = 42;
        } else {
            games[id].counter_ships_creator = 71;
            games[id].counter_ships_player = 71;
        }
        
        emit NewGame(id);
    }


    function joinGameRandom() public{

        uint256 rand_id;
        rand_id = gameIds[randomGenerator() % gameIds.length];
        require(games[rand_id].available == true, "Game full, choose another game.");

        games[rand_id].player = msg.sender;

        emit SelectGame(
            games[rand_id].gameId,
            games[rand_id].creator,
            games[rand_id].player,
            games[rand_id].counter_ships_creator,
            games[rand_id].counter_ships_player,
            games[rand_id].board,
            games[rand_id].deposit
        );

    }


    function joinGameId(uint256 gameId) public{

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].available == true, "Game full, choose another game.");

        games[gameId].player = msg.sender;

        emit SelectGame(
                games[gameId].gameId,
                games[gameId].creator,
                games[gameId].player,
                games[gameId].counter_ships_creator,
                games[gameId].counter_ships_player,
                games[gameId].board,
                games[gameId].deposit

            );
    }

    function submitMerkleRoot(bytes32 merkle_root, uint256 gameId) public{

        require(valid_ids[gameId], "Invalid game identifier");

        if (msg.sender == games[gameId].creator) {
            require(games[gameId].merkle_root_creator == 0, "Merkle Root of creator already stored");
            games[gameId].merkle_root_creator = merkle_root;
        } else if(msg.sender == games[gameId].player){
            require(games[gameId].merkle_root_player == 0, "Merkle Root of player already stored");
            games[gameId].merkle_root_player = merkle_root;
        } else {
            revert("You are not creator or player of this game");
        }
    }


    function shotTorpedo(uint256 gameId,  uint8 col, uint8 row) public{

        require(valid_ids[gameId], "Invalid game identifier");

        address target_address;
        if (msg.sender == games[gameId].creator) {
            target_address = games[gameId].player;
        } else if (msg.sender == games[gameId].player){
            target_address = games[gameId].creator;
        } else {
            revert("You are not creator or player of this game");
        }

        emit ShotTorpedo(
            gameId,
            target_address,
            col,
            row
        );
    }

    function shotResult(uint256 gameId, bool result, bytes32 leaf, bytes32[] memory merkle_proof) public payable{

        require(valid_ids[gameId], "Invalid game identifier");
        bytes32 computed_hash = leaf;
        address shooter_address;
        address cheater_address;

        if (msg.sender == games[gameId].creator) { 
            shooter_address = games[gameId].player;

            for (uint256 i = 0; i < merkle_proof.length; i++) {

                if (leaf <= merkle_proof[i]) {
                    // Hash(current computed hash + current element of the proof)
                    computed_hash = keccak256(abi.encodePacked(computed_hash, merkle_proof[i]));
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computed_hash = keccak256(abi.encodePacked(merkle_proof[i], computed_hash));
                }
        
            }
            
            if(computed_hash == games[gameId].merkle_root_creator) {
                if(result) {
                    games[gameId].counter_ships_creator -= 1;
                }

                emit ShotResult(
                    gameId,
                    result,
                    games[gameId].counter_ships_creator,
                    shooter_address
                );
            } else {
                //Creator is a cheater, all deposit is sent to Player because Creator's bad beavhiour.
                cheater_address = msg.sender;
                emit Cheater(
                    gameId,
                    result,
                    cheater_address
                );

                uint256 amount = games[gameId].deposit;
                games[gameId].deposit = 0;
                payable(games[gameId].player).transfer(amount);
                deleteGame(gameId);
            }

            if(games[gameId].counter_ships_creator == 0) {

                //Player is the winner, deposit is sent to both creator and Player because
                //they played following rules, without cheating.
                
                uint256 amount = games[gameId].deposit;
                games[gameId].deposit = 0;
                payable(games[gameId].creator).transfer(amount/2);
                payable(games[gameId].player).transfer(amount/2);

                emit EndGame(gameId, shooter_address);
                deleteGame(gameId);
            }

        } else if (msg.sender == games[gameId].player){
            shooter_address = games[gameId].creator;

            for (uint256 i = 0; i < merkle_proof.length; i++) {

                if (leaf <= merkle_proof[i]) {
                    // Hash(current computed hash + current element of the proof)
                    computed_hash = keccak256(abi.encodePacked(computed_hash, merkle_proof[i]));
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computed_hash = keccak256(abi.encodePacked(merkle_proof[i], computed_hash));
                }
        
            }
            
            if(computed_hash == games[gameId].merkle_root_player) {
                if(result) {
                    games[gameId].counter_ships_player -= 1;
                }

                emit ShotResult(
                    gameId,
                    result,
                    games[gameId].counter_ships_player,
                    shooter_address
                );
            } else {
                //Player is a cheater, all deposit is sent to Creator because Player's bad beavhiour.
                cheater_address = msg.sender;
                emit Cheater(
                    gameId,
                    result,
                    cheater_address
                );

                uint256 amount = games[gameId].deposit;
                games[gameId].deposit = 0;
                payable(games[gameId].player).transfer(amount);
                deleteGame(gameId);
            }

            if(games[gameId].counter_ships_player == 0) {

                //Creator is the winner, deposit is sent to both Creator and Player because
                //they played following rules, without cheating.
                
                uint256 amount = games[gameId].deposit;
                games[gameId].deposit = 0;
                payable(games[gameId].creator).transfer(amount/2);
                payable(games[gameId].player).transfer(amount/2);

                emit EndGame(gameId, shooter_address);
                deleteGame(gameId);
            }
           
        } else {
            revert("You are not creator or player of this game");
        }
    }

    function submitAccuse(uint256 gameId) public{

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
            games[gameId].acc_time
        );

    }

    function verifyAccuse(uint256 gameId) public payable returns(bool){

        require(valid_ids[gameId], "Invalid game identifier");
        require(games[gameId].accused != address(0), "Accuse was not submitted");
        bool accuse = false;

        if (msg.sender != games[gameId].creator && msg.sender != games[gameId].player) {
            revert("You are not creator or player of this game");
        }

        if(games[gameId].acc_time <= block.number) {
            uint256 amount = games[gameId].deposit;
            games[gameId].deposit = 0;
            payable(msg.sender).transfer(amount);
            accuse = true;
        }
        return accuse;
    }
}