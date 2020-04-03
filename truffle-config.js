require('babel-register');
require('babel-polyfill');
require('dotenv').config();

const HDWalletProvider = require('truffle-hdwallet-provider-privkey')
console.log(HDWalletProvider)
const privateKeys = process.env.PRIVATE_KEYS;

console.log("Emmett Test : " + process.env)
console.log("Emmett Test INFURA_API_KEY: " + process.env.INFURA_API_KEY)

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    kovan:{
      provider: function(){
        return new HDWalletProvider(
          privateKeys.split(','), 
          `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}` 
        )
      },
      gas: 5000000, 
      gasPrice: 25000000000,
      network_id: 42 
    }
  },
  contracts_directory: './src/contracts/',
  contracts_build_directory: './src/abis/',
  compilers: {
    solc: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
