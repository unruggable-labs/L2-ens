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

  /*console.log('OPVerifier', [[GATEWAY_URLS[network.name]], L2_OUTPUT_ORACLE_ADDRESS])
  await deploy('OPVerifier', {
    from: deployer,
    args: [[GATEWAY_URLS[network.name]], L2_OUTPUT_ORACLE_ADDRESS],
    log: true,
  });*/


  //const OPVerifier = await deployments.get('OPVerifier');

  const l2OwnedResolver = await hre.companionNetworks['l2'].deployments.get('OwnedResolver');

  const l1Verifier = "0x1ffb59a9F74c1862780a4708AB19F63d0A02bbD3";

  await deploy('L1Resolver', {
    from: deployer,
    args: [l1Verifier, l2OwnedResolver.address],
    log: true,
  })
}

func.tags         = ['layerone', 'l1Resolverr']
func.dependencies = []

export default func
