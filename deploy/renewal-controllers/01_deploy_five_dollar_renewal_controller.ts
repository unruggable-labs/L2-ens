import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    const { getNamedAccounts, deployments, network } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    //Other Contracts
    const nameWrapper    = await get('L2NameWrapper');
    const usdOracle      = await get('USDOracleMock');

    console.log("NameWrapper", nameWrapper.address);
    console.log("USDOracleMock", usdOracle.address);

    const SECONDS_IN_YEAR = 31536000;
    const pricePerYear    = 5;
    const pricePerSecond  = Math.round((pricePerYear * 1e18) / SECONDS_IN_YEAR);

    console.log("Price (USD) per year", pricePerYear);

    let deployArguments = [
        nameWrapper.address,
        usdOracle.address,
        pricePerSecond
    ];

    const deployTx = await deploy('L2FixedPriceRenewalController', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (deployTx.newlyDeployed) {
        console.log(`Deployed L2FixedPriceRenewalController to ${deployTx.address}`)

        const fixedPriceRenewalController = await ethers.getContractAt(
            'L2FixedPriceRenewalController',
            deployTx.address,
        )

        if (network.name == "goerli") {
            
            //Set the owner of the renewal controller to the multisig
            await fixedPriceRenewalController.transferOwnership("0xFCcCAd00d38a511236a002c28E8206A25D6e7518");
        }
    }
}

func.tags         = ['renewal-controllers']
func.dependencies = ['registrars']

export default func
