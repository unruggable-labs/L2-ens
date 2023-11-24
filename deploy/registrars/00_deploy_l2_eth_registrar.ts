import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
const packet = require('dns-packet')

export const hexEncodeName = (name) => {
    return '0x' + packet.name.encode(name).toString('hex')
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    const { getNamedAccounts, deployments } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    //Our Contracts
    const l2NameWrapper = await get('L2NameWrapper');

    //Other Contracts
    const ensRegistry    = await get('ENSRegistry');
    const usdOracle      = await get('USDOracleMock');

    const minCommitmentAge = 5; //5 seconds
    const maxCommitmentAge = 604800; //one week

    let deployArguments = [
        minCommitmentAge,
        maxCommitmentAge,
        ensRegistry.address,
        l2NameWrapper.address,
        usdOracle.address,
    ];

    const deployTx = await deploy('L2EthRegistrar', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (deployTx.newlyDeployed) {

        const ethRegistrar = await ethers.getContract('L2EthRegistrar');

        const setParamsTx = await ethRegistrar.setParams(
            "2419200", //uint64 _minRegistrationDuration, 
            "31556952", //uint64 _maxRegistrationDuration,
            "3", //uint16 _minChars, 28 days
            "64", //uint16 _maxChars 1 year
        );

        console.log(
          `Setting .eth registration params (tx: ${setParamsTx.hash})...`,
        )

        const nameWrapper = await ethers.getContract('L2NameWrapper')

        const addControllerTx = await nameWrapper.setController(deployTx.address, true)

        console.log(
          `Adding L2EthRegistrar as a controller of L2NameWrapper (tx: ${addControllerTx.hash})...`,
        )
    }
}

func.tags         = ['registrars']
func.dependencies = ['mocks', 'name-wrapper']

export default func
