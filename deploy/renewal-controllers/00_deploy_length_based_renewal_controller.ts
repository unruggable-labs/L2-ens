import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    const { getNamedAccounts, deployments } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    //Other Contracts
    const nameWrapper    = await get('L2NameWrapper');
    const usdOracle      = await get('USDOracleMock');

    let deployArguments = [
        nameWrapper.address,
        usdOracle.address,
    ];

    const deployTx = await deploy('L2PricePerCharRenewalController', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (deployTx.newlyDeployed) {

        console.log(`Deployed L2PricePerCharRenewalController to ${deployTx.address}`);

        const pricePerCharRenewalController = await ethers.getContractAt(
            'L2PricePerCharRenewalController',
            deployTx.address,
        )

        const SECONDS_IN_YEAR    = 31536000;
        const fiveDollars        = Math.round((5 * 1e18) / SECONDS_IN_YEAR);
        const oneThousandDollars = Math.round((1000 * 1e18) / SECONDS_IN_YEAR);
        const oneHundredDollars  = Math.round((100 * 1e18) / SECONDS_IN_YEAR);
        const tenDollars         = Math.round((10 * 1e18) / SECONDS_IN_YEAR);

        const tx = await pricePerCharRenewalController.setPricingForAllLengths([
            fiveDollars,
            oneThousandDollars,
            oneHundredDollars,
            tenDollars
        ]);

        console.log(`Setting character pricing (tx: ${tx.hash})...`);

        await tx.wait()

        console.log(`Pricing set`);
    }
}

func.tags         = ['renewal-controllers']
func.dependencies = ['registrars']

export default func
