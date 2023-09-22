var MyContract = artifacts.require("../contracts/BattleShip.sol");

module.exports = function(deployer) {
    // deployment steps
    deployer.deploy(MyContract);
  };