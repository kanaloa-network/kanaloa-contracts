import { 
  Contract, 
  ContractFactory,
  utils
} from "ethers"
import { CREATE2Deployer } from "./create2deployer";
import { ethers } from "hardhat";

const KANALOA_NAMESPACE = "network.kanaloa";

const main = async(): Promise<any> => {

    const usmMainnet = "0x8740AE96E6cB91EaEA2b1ba61C347792e308eBF2";
    const kanaMainnet = "0x0328a69b363a16f66810b23cb0b8d32abadb203d";
    const pancakeRouter = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    const deployer = (await ethers.getSigners()).values().next().value.address;


    const TokenMigratorV0: ContractFactory =
        await ethers.getContractFactory("TokenMigratorV0");

    const migrator: Contract =
        await TokenMigratorV0
            .deploy(
                usmMainnet,
                kanaMainnet,
                pancakeRouter,
                -1000,
                10,
                deployer
            )
            .then(c => c.deployed());
    console.log(`TokenMigratorV0 deployed at ${migrator.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    });
