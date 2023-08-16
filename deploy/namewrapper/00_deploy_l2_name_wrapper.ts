import { ethers }                    from 'hardhat'
import { DeployFunction }            from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { keccak256 }                 from 'js-sha3'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {

    const { getNamedAccounts, deployments, network } = hre
    const { deploy, get }                            = deployments
    const { deployer }                               = await getNamedAccounts()

    //Other Contracts
    const registryAddress             = "0xffED83BDBd2F9906Ac12467288946cf7d8F6f599";

    //Just use the mainnet one for now for metadata
    const nameWrapperAddress          = "0xd4416b13d2b3a9abae7acd5d6c2bbdbe25686401";

    //const network = await ethers.getDefaultProvider().getNetwork();
    console.log("Network name=", network.name);

    let metadataDeployArguments = [
        `https://metadata.ens.domains/${network.name}/${nameWrapperAddress}/`
    ];

    console.log("Metadata args", metadataDeployArguments);

    const metadataTx = await deploy('L2MetadataService', {
        from: deployer,
        args: metadataDeployArguments,
        log: true,
    })

    let deployArguments = [
        registryAddress,
        metadataTx.address
    ];

    const tx = await deploy('L2NameWrapper', {
        from: deployer,
        args: deployArguments,
        log: true,
    })

    if (tx.newlyDeployed) {
        
        console.log(`Deployed L2NameWrapper to ${tx.address}`);
    }
}

func.tags         = ['name-wrapper']

export default func
