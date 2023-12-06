import { ethers } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments } = hre
  const { deploy } = deployments
  const { deployer, owner } = await getNamedAccounts()

  const registry = await ethers.getContract('ENSRegistry', owner)
  const nameWrapper = await ethers.getContract('L2NameWrapper', owner)
  //const controller = await ethers.getContract('ETHRegistrarController', owner)
  //const reverseRegistrar = await ethers.getContract('ReverseRegistrar', owner)

  const controllerAddress = "0x0000000000000000000000000000000000000000";

  const deployArgs = {
    from: deployer,
    args: [
      registry.address,
      nameWrapper.address,
      controllerAddress,
      //reverseRegistrar.address,
    ],
    log: true,
  }
  const publicResolver = await deploy('L2PublicResolver', deployArgs)
  if (!publicResolver.newlyDeployed) return

  const tx = await reverseRegistrar.setDefaultResolver(publicResolver.address)
  console.log(
    `Setting default resolver on ReverseRegistrar to PublicResolver (tx: ${tx.hash})...`,
  )
  await tx.wait()

  if ((await registry.owner(ethers.utils.namehash('resolver.eth'))) === owner) {
    const pr = (await ethers.getContract('L2PublicResolver')).connect(
      await ethers.getSigner(owner),
    )
    const resolverHash = ethers.utils.namehash('resolver.eth')
    const tx2 = await registry.setResolver(resolverHash, pr.address)
    console.log(
      `Setting resolver for resolver.eth to PublicResolver (tx: ${tx2.hash})...`,
    )
    await tx2.wait()

    const tx3 = await pr['setAddr(bytes32,address)'](resolverHash, pr.address)
    console.log(
      `Setting address for resolver.eth to PublicResolver (tx: ${tx3.hash})...`,
    )
    await tx3.wait()
  } else {
    console.log(
      'resolver.eth is not owned by the owner address, not setting resolver',
    )
  }
}

func.id = 'resolver'
func.tags = ['resolver']
/*func.dependencies = [
  'registry',
  'ETHRegistrarController',
  'NameWrapper',
  'ReverseRegistrar',
]*/

export default func
