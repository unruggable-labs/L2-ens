import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const ZERO_HASH =
  '0x0000000000000000000000000000000000000000000000000000000000000000'

const GATEWAY_URLS = {
  'opDevnetL1':'http://localhost:8080/{sender}/{data}.json',
  'goerli':'https://goerli.unruggablegateway.com/{sender}/{data}.json',
}

const L2_OUTPUT_ORACLE_ADDRESSES = {
  'goerli': '0xE6Dfba0953616Bacab0c9A8ecb3a9BBa77FC15c0'
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  
  const { getNamedAccounts, deployments, network } = hre
  const { deploy }                                 = deployments
  const { deployer, owner }                        = await getNamedAccounts()

  /**
   *    IEVMVerifier _evmVerifier, 
        ENS _ens, 
        address _l2Resolver 
  */


  const L2_OUTPUT_ORACLE_ADDRESS = L2_OUTPUT_ORACLE_ADDRESSES[network.name]

  console.log('OPVerifier', [[GATEWAY_URLS[network.name]], L2_OUTPUT_ORACLE_ADDRESS])
  await deploy('OPVerifier', {
    from: deployer,
    args: [[GATEWAY_URLS[network.name]], L2_OUTPUT_ORACLE_ADDRESS],
    log: true,
  });


  const OPVerifier = await deployments.get('OPVerifier');

  const l2EnsRegistryAddress = "0x3624029970EF97ae44588FC5D23d88f46F4e645e";

  await deploy('OpOffchainResolver', {
    from: deployer,
    args: [OPVerifier.address, l2EnsRegistryAddress],
    log: true,
  })
 
  return true
}

func.tags         = ['layerone', 'l1Resolver']
func.dependencies = []

export default func
