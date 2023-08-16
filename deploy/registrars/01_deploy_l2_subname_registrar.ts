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
    const registryAddress             = "0xffED83BDBd2F9906Ac12467288946cf7d8F6f599";
    const usdOracle      = await get('USDOracleMock');

    const minCommitmentAge = 5; //5 seconds
    const maxCommitmentAge = 604800; //one week

    let deployArguments = [
        minCommitmentAge,
        maxCommitmentAge,
        registryAddress,
        l2NameWrapper.address,
        usdOracle.address,
    ];

    const deployTx = await deploy('L2SubnameRegistrar', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    if (deployTx.newlyDeployed) {

        const nameWrapper = await ethers.getContract('L2NameWrapper')

        const addControllerTx = await nameWrapper.setController(deployTx.address, true)
        console.log(
            `Adding L2SubnameRegistrar as a controller of L2NameWrapper (tx: ${addControllerTx.hash})...`,
        )

        console.log(`Deployed L2SubnameRegistrar to ${deployTx.address}`);

        const l2SubnameRegistrar = await ethers.getContractAt(
            'L2SubnameRegistrar',
            deployTx.address,
        )

        console.log("HERE 1");

        if (network.name == "goerli" || network.name == "optimism-goerli") {
            
            console.log("HERE 2");

            //Add fivedollars.eth to the allow list
            await l2SubnameRegistrar.allowName(hexEncodeName("fivedollars.eth"), true);
            console.log("fivedollars.eth added to allow list");
        }

        console.log("HERE 3");
    }
}

func.tags         = ['registrars']
func.dependencies = ['mocks', 'name-wrapper']

export default func
