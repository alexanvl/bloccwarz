var BloccWarz = artifacts.require('./BloccWarz.sol')

module.exports = function(deployer, network) {
  deployer.deploy(BloccWarz)
}
