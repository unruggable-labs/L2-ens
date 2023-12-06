import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    console.log("here");
    
    const { getNamedAccounts, deployments } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    let deployArguments = [];

    const deployTx = await deploy('OwnedResolver', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (deployTx.newlyDeployed) {

        console.log(`OwnedResolver deployed at  ${deployTx.address}`);

        console.log("Verifying on Etherscan..");

        await hre.run("verify:verify", {
          address: deployTx.address,
          constructorArguments: deployArguments,
        });
    }

    const ex = await hre.storageLayout.export();

    console.log("Export", ex);
}

func.tags         = ['resolvers']
func.dependencies = []

export default func
