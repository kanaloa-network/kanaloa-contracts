import {
    Contract,
    ContractFactory,
    utils,
    BytesLike
} from "ethers";
import { parametrizeInitBytecode, ConstructorArgs } from "./constructor-tools";
import { ethers } from "hardhat";

export class CREATE2Deployer {

    private create2: Contract;

    private readonly constructorProm: Promise<Contract>;
    private readonly provider;
    private readonly confirms: number;

    public constructor(
        confirms = 1,
        provider = ethers.getDefaultProvider()
    ) {
        this.constructorProm =
            ethers
                .getContractFactory("CREATE2Deployer")
                .then(c2 => c2.deploy())
                .then(c2 => c2.deployed())
                .catch(error => {
                    console.error(error);
                    process.exit(1);
                });

        this.provider = provider;
        this.confirms = confirms;

    }

    public async init(): Promise<CREATE2Deployer> {
        this.create2 = await this.constructorProm;
        console.log(`CREATE2Deployer deployed to: ${this.create2.address}`);
        return this;
    }

    public async deploy(
        contractName: string,
        salt: string,
        initParams: Array<BytesLike>,
        constructorArgs?: ConstructorArgs<number>
    ): Promise<Contract> {
        const hashedSalt =
            utils.keccak256(utils.defaultAbiCoder.encode(["string"], [salt]));
        const contractFactory = await ethers.getContractFactory(contractName);

        const bytecode =
            (constructorArgs != null) ?
                parametrizeInitBytecode(
                    constructorArgs.types,
                    constructorArgs.args,
                    contractFactory.bytecode
                )
            : contractFactory.bytecode;

        const address =
            await this.create2
                .deploy(bytecode, hashedSalt, initParams)
                .then(tx => tx.wait(this.confirms))
                .then(receipt => receipt.events.pop().args[0])
                .catch(error => {
                    console.error(error);
                    process.exit(1);
                })

        console.log(`${contractName} deployed by CREATE2Deployer to: ${address}`);

        return await contractFactory.attach(address);
    }

}
