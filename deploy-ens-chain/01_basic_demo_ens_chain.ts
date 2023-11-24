import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  
  const { getNamedAccounts, deployments, network } = hre
  const { deploy }                                 = deployments
  const { deployer, owner }                        = await getNamedAccounts()

  await deploy('BasicDemoL2', {
    from: deployer,
    args: [],
    log: true,
  })
}

func.tags         = ['basic']
func.dependencies = []

export default func
