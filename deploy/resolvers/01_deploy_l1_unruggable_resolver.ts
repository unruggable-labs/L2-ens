import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const GATEWAY_URLS = {
  'opDevnetL1':'http://localhost:8080/{sender}/{data}.json',
  'sepolia':'https://ens-chain-sepolia.unruggablegateway.com/{sender}/{data}.json',
}

const L2_OUTPUT_ORACLE_ADDRESSES = {
  'sepolia': '0xCd6DCeD0D5D951F99d6A43b780571b0E831D0609'
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  
  const { getNamedAccounts, deployments, network } = hre
  const { deploy }                                 = deployments
  const { deployer, owner }                        = await getNamedAccounts()

  const L2_OUTPUT_ORACLE_ADDRESS = L2_OUTPUT_ORACLE_ADDRESSES[network.name]

  console.log('OPVerifier', [[GATEWAY_URLS[network.name]], L2_OUTPUT_ORACLE_ADDRESS])
  
  await deploy('OPVerifier', {
    from: deployer,
    args: [[GATEWAY_URLS[network.name]], L2_OUTPUT_ORACLE_ADDRESS],
    log: true,
  });

  const OPVerifier = await deployments.get('OPVerifier');

  const l2PublicResolver = await hre.companionNetworks['l2'].deployments.get('L2PublicResolver');
  const l2OwnedResolver = await hre.companionNetworks['l2'].deployments.get('OwnedResolver');

  await deploy('L1UnruggableResolver', {
    from: deployer,
    args: [OPVerifier.address, l2PublicResolver.address],
    log: true,
  })
}

func.tags         = ['resolver']
func.dependencies = []

export default func
