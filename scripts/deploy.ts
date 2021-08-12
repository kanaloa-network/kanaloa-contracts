import { 
  Contract, 
  ContractFactory,
  utils
} from "ethers"
import { CREATE2Deployer } from "./create2deployer";
import { ethers } from "hardhat";

const KANALOA_NAMESPACE = "network.kanaloa";

const main = async(): Promise<any> => {

    const create2 = await new CREATE2Deployer().init();
    const refractionEngine: Contract =
        await create2.deploy("RefractionEngine", KANALOA_NAMESPACE, []);
    const erc20Module: Contract =
        await create2.deploy("ERC20Module", KANALOA_NAMESPACE, []);

    const deployer = (await ethers.getSigners()).values().next().value.address;

    let kanaloa: Contract =
        await create2.deploy(
            "RefractionProxy",
            KANALOA_NAMESPACE,
            [],
            {
                types: ["address", "address"],
                args: [deployer, refractionEngine.address]
            }
        );

    console.log("Kanaloa vessel deployed. Initiating ERC20Module installation");

    const kanaloaERC20Params =
        erc20Module.interface.encodeFunctionData(
            "initialize(string,string,uint8,uint256,address)",
            [
                "Kanaloa",
                "KANA",
                "18",
                utils.parseEther("800000000"),
                deployer
            ]
        );

    kanaloa = await ethers.getContractAt("IRefractionEngine", kanaloa.address);

    await kanaloa.installAndInitModule(
        erc20Module.address,
        kanaloaERC20Params
    )

    console.log("ERC20Module installed without errors. Welcome aboard")
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    });
