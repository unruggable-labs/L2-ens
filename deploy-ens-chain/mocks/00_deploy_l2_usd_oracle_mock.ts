import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    const { getNamedAccounts, deployments } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    let deployArguments = [];

    const tx = await deploy('USDOracleMock', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (tx.newlyDeployed) {

        console.log(`Deployed USDOracleMock to ${tx.address}`);
    }
}

func.tags         = ['mocks']
func.dependencies = []

export default func
