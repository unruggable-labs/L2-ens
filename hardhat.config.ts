//import '@nomiclabs/hardhat-ethers'
import "hardhat-deploy-ethers";
import '@typechain/hardhat'
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import 'hardhat-deploy'

import dotenv from 'dotenv'

// Load environment variables from .env file. Suppress warnings using silent
// if this file is missing. dotenv will never modify any environment variables
// that have already been set.
// https://github.com/motdotla/dotenv
dotenv.config({ debug: true })

let real_accounts = undefined
if (process.env.DEPLOYER_KEY) {
  real_accounts = [
    process.env.DEPLOYER_KEY,
    process.env.OWNER_KEY || process.env.DEPLOYER_KEY,
  ]
}

export const ensContractsPath       = './lib/ens-contracts/deployments/'

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      saveDeployments: true,
      tags: ['test', 'legacy', 'use_root'],
      allowUnlimitedContractSize: false,
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      saveDeployments: true,
      chainId: 31337,
      tags: ['test', 'legacy', 'use_root'],
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      tags: ['test', 'legacy', 'use_root'],
      chainId: 4,
      accounts: real_accounts,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      tags: ['test', 'legacy', 'use_root'],
      chainId: 3,
      accounts: real_accounts,
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/tUTlvOS8uBoP5SqTOlV91Hb3gaVTf816`,
      tags: ['test', 'legacy', 'use_root'],
      chainId: 5,
      accounts: real_accounts,
    },
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/qwzEYMR0sNAZdroXZO7KW-P08W4EMvWh`,
      tags: ['legacy', 'use_root'],
      chainId: 1,
      accounts: real_accounts,
    },
    "optimism-goerli": {
      url: `${process.env.OPTIMISM_GOERLI_RPC_URL}`,
      tags: ['use_root'],
      chainId: 420,
      accounts: real_accounts,
      gasPrice: 50000000000
    },
  },
  abiExporter: {
    path: './build/contracts',
    runOnCompile: true,
    clear: true,
    flat: true,
    except: [
      'Controllable$',
      'INameWrapper$',
      'SHA1$',
      'Ownable$',
      'NameResolver$',
      'TestBytesUtils$',
      'legacy/*',
    ],
    spacing: 2,
    pretty: true,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    owner: {
      default: 0,
    },
  },
  external: {
    /*deployments: {
      localhost: [ensContractsPath + "/localhost"],
      goerli:    [ensContractsPath + "/goerli"],
      mainnet:   [ensContractsPath + "/mainnet"],
    },*/
  },
  etherscan: {
    apiKey: {
      goerli: 'G3CDT3CR9Y8HZWEW4HQPU4SJZRCEVB6GZN',
    },
  },
  typechain: {
      outDir: "typechain",
      target: "ethers-v5",
  },
};