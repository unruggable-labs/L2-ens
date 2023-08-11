# L2 ENS Names by Unruggable Labs
![Test](https://github.com/kamescg/delegatable-sol/actions/workflows/test.yml/badge.svg)

## Why ENS on L2? 

Registering .eth names on L1 Ethereum can be very expensive with costs of $30 or more when gas prices on the network are high. While registering second-level .eth names like vitalik.eth is limited to L1 Ethereum, subnames such as mike.isme.eth can be registered off-chain or on Layer 2, offering significantly lower fees.

## Our Approach 

Currently, there is no official ENS Layer 2 registry for subname registration. Using a mix of ENS contracts from L1 Ethererum, modified ENS contracts and new contracts we have create a system for registering subnames on L2s, as well as demonstrated the ability to register second level .eth names, such as vitalik.eth. Key objectives include:

- Enabling universal subname registration on an EVM-based Layer 2s.
- Allowing anyone to rent subnames using Renewal Controllers.
- Implementing Referrer accounts.

### Registering Subnames on L2 

To register subnames on L2, we use the ENS registry along with an upgraded version of the NameWrapper (L2NameWrapper) contract. The ERC-721 based resolver, currently present on L1, has been removed, as its functionality is now integrated into our L2NameWrapper contract. For registering subnames on L2 we use a new custom registrar, that allows any parent name owner to easily configure their name for subname rentals using Renewal Controllers, a specialized contract used exclusivly for renewing subnames.  

### Renewal Controllers 

Renewal Controllers enable subname owners to renew their subnames, such as mike.isme.eth, without needing permission from the parent name owner, i.e., isme.eth. Subnames can be assigned a renewal controller upon registration, which cannot be removed by anyone and can be owned by third parties, whose role is to ensure a stable long-term price for renewing subnames.    

### Referrer Accounts 

ENS currently has no system in place for compensating referrers who refer users to register .eth names on L1 Ethereum. Referrer Accounts on L2 allow for anyone who refers a user to register or renew a .eth name to receive a cut of the fees, which acrue over time and can be withdrawn by the referrer onchain.

## Research and Development 

As well as creating a registration and renewal system for ENS subnames on L2, we have also designed the L2NameWrapper contract to allow for the registration of second-level .eth names, such as vitalik.eth. The ENS DAO controls the resolver record of .eth and, therefore, is able to permit the registration of second-level .eth names on an L2 if they choose. Alongside the L2NameWrapper contract, we have developed a custom registrar contract (L2EthRegistrar) that could be owned and operated by the ENS DAO to register ENS second-level names on L2. We also intend to enhance the system further with an upgraded version of the L1 NameWrapper smart contract that enables any name on L2 to upgrade to L1 at any time. 

## Licensing 

All contracts within this repository are open source and use the MIT license.

## Developer guide 

### How to set up 

```
git clone https://github.com/unruggable-labs/L2-ens
cd L2-ens
git submodule update --init --recursive
```

### How to run tests

```
forge test
```

### Security and Audits

 The contracts in this repository are currently under development, and our team is diligently working to ensure their security. We advise refraining from deploying these smart contracts in a production environment until a security audit has been successfully conducted.

### Contributions

We welcome contributions including the submission of issues on GitHub. For direct communication, please DM @nxt3d on Twitter. To contribute code, please fork the repository, create a feature branch (features/$BRANCH_NAME), or a bug fix branch (fix/$BRANCH_NAME), and then submit a pull request against the corresponding branch. 
