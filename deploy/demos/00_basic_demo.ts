import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  
  const { getNamedAccounts, deployments, network } = hre
  const { deploy }                                 = deployments
  const { deployer, owner }                        = await getNamedAccounts()

const opVerifier  = await hre.deployments.get('OPVerifier');
const basicDemoL2 = await hre.companionNetworks['l2'].deployments.get('BasicDemoL2');

  await deploy('BasicDemo', {
    from: deployer,
    args: [opVerifier.address, basicDemoL2.address],
    log: true,
  })
}

func.tags         = ['demo']
func.dependencies = []

export default func
