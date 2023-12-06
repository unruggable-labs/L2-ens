import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
const packet = require('dns-packet')

export const hexEncodeName = (name) => {
    return '0x' + packet.name.encode(name).toString('hex')
}

const FUSES = {
  CANNOT_BURN_NAME:      1,
  PARENT_CANNOT_CONTROL: 2 ** 16,
}

const UNRUGGABLE_LABELHASH = "0x0fb49d3befd591078ec044334b6cad68f02609749d39e161fa1ff9bf6ce96d8c";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    const { getNamedAccounts, deployments } = hre
    const { deploy, get }                   = deployments
    const { deployer }                      = await getNamedAccounts()

    //Our Contracts
    const l2NameWrapper = await get('L2NameWrapper');

    //Other Contracts
    const ensRegistry    = await ethers.getContract('ENSRegistry');

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

    const deployTx = await deploy('L2SubnameRegistrar', {
        from: deployer,
        args: deployArguments,
        log:  true,
    })

    //if (deployTx.newlyDeployed) {

        console.log(`Deployed L2SubnameRegistrar to ${deployTx.address}`);

        const nameWrapper = await ethers.getContract('L2NameWrapper')
        const root        = await ethers.getContract('Root')
/*
        const addControllerTx = await nameWrapper.setController(deployTx.address, true)
        console.log(
            `Adding L2SubnameRegistrar as a controller of L2NameWrapper (tx: ${addControllerTx.hash})...`,
        )
*/
        const l2SubnameRegistrar = await ethers.getContractAt(
            'L2SubnameRegistrar',
            deployTx.address,
        )

        const setUnruggableOwnerTx = await root.setSubnodeOwner(
            UNRUGGABLE_LABELHASH, 
            deployer
        ).then((response) => {

            console.log(
              `Set owner of .unruggable TLD in root (tx: ${response.hash})...`,
            )
        });

        console.log("NameWrapper address:", nameWrapper.address);

        await ensRegistry.setApprovalForAll(
            nameWrapper.address,
            true
        ).then((response) => {

            console.log(
              `Approve L2NameWrapper on L2ENSRegistry (tx: ${response.hash})...`,
            )
        });


        const wrapUnruggableTx = await nameWrapper.wrapTLD(
            hexEncodeName("unruggable"), 
            deployer,//l2SubnameRegistrar.address,
            FUSES.PARENT_CANNOT_CONTROL | FUSES.CANNOT_BURN_NAME, //uint16 _minChars, 28 days
            13590337622 //year 2400
        ).then((response) => {

            console.log(
              `Wrapping .unruggable TLD (tx: ${response.hash})...`,
            )

        }).catch((error) => {console.log('error', error);});


        const disableAllowListTx = await l2SubnameRegistrar.disableAllowList(
        ).then((response) => {

            console.log(
              `Disabled Allow List (tx: ${response.hash})...`,
            )

        }).catch((error) => {console.log('error disabling allow list', error);});
/*
        console.log("HERE 1");

        if (network.name == "goerli" || network.name == "optimism-goerli") {
            
            console.log("HERE 2");

            //Add fivedollars.eth to the allow list
            await l2SubnameRegistrar.allowName(hexEncodeName("fivedollars.eth"), true);
            console.log("fivedollars.eth added to allow list");
        }

        console.log("HERE 3");
        */
    //}
}

func.tags         = ['registrars']
func.dependencies = ['mocks', 'name-wrapper']

export default func
