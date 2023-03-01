import 'dotenv/config';
import { HardhatUserConfig } from 'hardhat/types';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-etherscan';

const config: any = {
  solidity: {
    compilers: [
      {
        version: '0.8.7',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: 'http://localhost:8545',
      accounts: [process.env['PRIVATE_KEY']]
    },
    kovan: {
      url: 'https://kovan.infura.io/v3/793313070ca041298eed2aa197b71ede',
      accounts: [process.env['PRIVATE_KEY']],
      allowUnlimitedContractSize: true
    },
    bsc_testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: [process.env['PRIVATE_KEY']]
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org',
      accounts: [process.env['PRIVATE_KEY_MAINNET']]
    },

  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 200,
  },
  etherscan: {
    apiKey: process.env['ETHERSCAN_API_KEY']
  },
  namedAccounts: {
    deployer: 0,
  },
};

export default config;
